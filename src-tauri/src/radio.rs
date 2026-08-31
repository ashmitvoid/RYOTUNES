//! Internet-radio directory integration for v2.4.
//!
//! Radio Browser is queried only when the Radio surface is opened/searched. There is no polling
//! task, no startup fetch, and no renderer-side CORS dependency. Playback itself remains native:
//! the selected station's resolved HTTP(S) stream is handed straight to libmpv.

use std::collections::HashSet;
use std::time::Duration;

use innertube::SongItem;
use rand::seq::SliceRandom;
use serde::{Deserialize, Serialize};

use crate::orchestrator::PlaybackData;

pub const RADIO_ID_PREFIX: &str = "RYOTUNES_RADIO:";
const DISCOVERY_URL: &str = "https://all.api.radio-browser.info/json/servers";
const FALLBACK_SERVERS: [&str; 3] = [
    "https://de1.api.radio-browser.info",
    "https://nl1.api.radio-browser.info",
    "https://at1.api.radio-browser.info",
];
const USER_AGENT: &str = "Ryotunes/2.4 (+https://github.com/ashmitvoid/ryotunes)";

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RadioStation {
    #[serde(rename = "stationuuid")]
    pub station_uuid: String,
    #[serde(default)]
    pub name: String,
    #[serde(rename = "url_resolved", default)]
    pub stream_url: String,
    #[serde(default)]
    pub url: String,
    #[serde(default)]
    pub homepage: String,
    #[serde(default)]
    pub favicon: String,
    #[serde(default)]
    pub country: String,
    #[serde(rename = "countrycode", default)]
    pub country_code: String,
    #[serde(default)]
    pub tags: String,
    #[serde(default)]
    pub codec: String,
    #[serde(default)]
    pub bitrate: i64,
    #[serde(default)]
    pub votes: i64,
    #[serde(default)]
    pub clickcount: i64,
}

#[derive(Debug, Deserialize)]
struct Mirror {
    name: String,
}

pub fn is_radio_id(id: &str) -> bool {
    id.starts_with(RADIO_ID_PREFIX)
}

fn client() -> Result<reqwest::Client, String> {
    reqwest::Client::builder()
        .user_agent(USER_AGENT)
        .timeout(Duration::from_secs(10))
        .build()
        .map_err(|e| format!("radio client: {e}"))
}

async fn mirrors(client: &reqwest::Client) -> Vec<String> {
    let mut out = match client.get(DISCOVERY_URL).send().await {
        Ok(response) if response.status().is_success() => response
            .json::<Vec<Mirror>>()
            .await
            .unwrap_or_default()
            .into_iter()
            .filter_map(|m| {
                let host = m.name.trim().trim_end_matches('.');
                (!host.is_empty()).then(|| format!("https://{host}"))
            })
            .collect::<Vec<_>>(),
        _ => Vec::new(),
    };

    // Discovery itself can be unavailable. A short multi-server fallback is still materially more
    // robust than pinning the entire feature to one mirror, and the next request retries all of it.
    out.extend(FALLBACK_SERVERS.into_iter().map(str::to_owned));
    let mut seen = HashSet::new();
    out.retain(|url| seen.insert(url.clone()));
    out.shuffle(&mut rand::thread_rng());
    out
}

async fn get_json<T: serde::de::DeserializeOwned>(path: &str) -> Result<T, String> {
    let client = client()?;
    let mut errors = Vec::new();
    for base in mirrors(&client).await {
        let url = format!("{base}{path}");
        match client.get(&url).send().await {
            Ok(response) if response.status().is_success() => match response.json::<T>().await {
                Ok(value) => return Ok(value),
                Err(e) => errors.push(format!("{base}: invalid response ({e})")),
            },
            Ok(response) => errors.push(format!("{base}: HTTP {}", response.status())),
            Err(e) => errors.push(format!("{base}: {e}")),
        }
    }
    Err(if errors.is_empty() {
        "Radio Browser is unavailable right now".into()
    } else {
        format!("Radio Browser is unavailable right now ({})", errors.join("; "))
    })
}

fn http_url(value: &str) -> bool {
    reqwest::Url::parse(value)
        .ok()
        .is_some_and(|url| matches!(url.scheme(), "http" | "https"))
}

pub fn normalize_station(mut station: RadioStation) -> Option<RadioStation> {
    station.station_uuid = station.station_uuid.trim().to_owned();
    station.name = station.name.trim().to_owned();
    station.stream_url = station.stream_url.trim().to_owned();
    station.url = station.url.trim().to_owned();
    station.homepage = station.homepage.trim().to_owned();
    station.favicon = station.favicon.trim().to_owned();
    station.country = station.country.trim().to_owned();
    station.country_code = station.country_code.trim().to_ascii_uppercase();
    station.tags = station.tags.trim().to_owned();
    station.codec = station.codec.trim().to_ascii_uppercase();

    if !http_url(&station.stream_url) {
        station.stream_url = station.url.clone();
    }
    if station.station_uuid.is_empty() || station.name.is_empty() || !http_url(&station.stream_url) {
        return None;
    }
    if !station.homepage.is_empty() && !http_url(&station.homepage) {
        station.homepage.clear();
    }
    if !station.favicon.is_empty() && !http_url(&station.favicon) {
        station.favicon.clear();
    }
    Some(station)
}

/// Top stations for an empty query, or a name search otherwise. Limit is intentionally bounded:
/// Radio Browser can return tens of thousands of rows and the Radio page never needs them at once.
pub async fn stations(query: Option<&str>, offset: usize, limit: usize) -> Result<Vec<RadioStation>, String> {
    let limit = limit.clamp(1, 50);
    let offset = offset.min(10_000);
    let query = query.unwrap_or_default().trim();
    let path = if query.is_empty() {
        format!("/json/stations/topvote?offset={offset}&limit={limit}&hidebroken=true")
    } else {
        format!(
            "/json/stations/search?name={}&order=votes&reverse=true&hidebroken=true&offset={offset}&limit={limit}",
            urlencoding::encode(query)
        )
    };
    let rows: Vec<RadioStation> = get_json(&path).await?;
    Ok(rows.into_iter().filter_map(normalize_station).collect())
}

/// Radio Browser asks clients to register a click when a station is actually played. Best effort:
/// playback is never delayed or failed because analytics for the public directory were unavailable.
pub async fn count_click(station_uuid: &str) {
    let uuid = station_uuid.trim();
    if uuid.is_empty() {
        return;
    }
    let path = format!("/json/url/{}", urlencoding::encode(uuid));
    let _: Result<serde_json::Value, String> = get_json(&path).await;
}

pub fn song_item(station: &RadioStation) -> SongItem {
    let live = match station.country_code.as_str() {
        "" => "Live Radio".to_owned(),
        code => format!("Live Radio · {code}"),
    };
    SongItem {
        video_id: format!("{RADIO_ID_PREFIX}{}", station.station_uuid),
        title: station.name.clone(),
        artists: live,
        album: Some("Internet Radio".into()),
        thumbnail: (!station.favicon.is_empty()).then(|| station.favicon.clone()),
        is_video: false,
        ..Default::default()
    }
}

pub fn playback_data(station: &RadioStation) -> PlaybackData {
    PlaybackData {
        video_id: format!("{RADIO_ID_PREFIX}{}", station.station_uuid),
        stream_url: station.stream_url.clone(),
        itag: 0,
        headers: Default::default(),
        expires_in_seconds: 0,
        loudness_db: None,
        playback_ping: None,
        title: Some(station.name.clone()),
        artists: Some("Live Radio".into()),
        duration: None,
        thumbnail: (!station.favicon.is_empty()).then(|| station.favicon.clone()),
        is_video: Some(false),
        stream_client: "radio".into(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn station_normalization_prefers_resolved_and_rejects_non_http_streams() {
        let good = normalize_station(RadioStation {
            station_uuid: " abc ".into(),
            name: " Test ".into(),
            stream_url: "https://stream.example/live".into(),
            url: "https://fallback.example/live".into(),
            homepage: "javascript:bad".into(),
            favicon: "https://example.test/icon.png".into(),
            country: String::new(),
            country_code: "in".into(),
            tags: String::new(),
            codec: "mp3".into(),
            bitrate: 128,
            votes: 1,
            clickcount: 0,
        })
        .unwrap();
        assert_eq!(good.station_uuid, "abc");
        assert_eq!(good.country_code, "IN");
        assert_eq!(good.codec, "MP3");
        assert!(good.homepage.is_empty());

        let bad = normalize_station(RadioStation { stream_url: "file:///tmp/a".into(), url: String::new(), ..good });
        assert!(bad.is_none());
    }

    #[test]
    fn radio_song_ids_are_namespaced() {
        let station = RadioStation {
            station_uuid: "id".into(),
            name: "Station".into(),
            stream_url: "https://example.test/live".into(),
            url: String::new(),
            homepage: String::new(),
            favicon: String::new(),
            country: String::new(),
            country_code: "US".into(),
            tags: String::new(),
            codec: String::new(),
            bitrate: 0,
            votes: 0,
            clickcount: 0,
        };
        let song = song_item(&station);
        assert_eq!(song.video_id, "RYOTUNES_RADIO:id");
        assert_eq!(song.artists, "Live Radio · US");
    }
}
