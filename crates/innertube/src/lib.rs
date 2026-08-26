//! Pure-Rust InnerTube transport + client identities + models + endpoints + rustypipe fallback.
//!
//! The boundary rule (UI state): this crate knows nothing about Tauri, webviews, mpv, or the
//! OS. It is unit-testable against JSON fixtures with no network. Cipher/PoToken/WEB_REMIX
//! streaming are handled by the desktop orchestration layer rather than this crate.

pub mod clients;
pub mod endpoints;
pub mod models;
pub mod rustypipe_fallback;
pub mod transport;

pub use clients::{
    Clients, YouTubeClient, LYRICS_TIMED_CLIENT, MAIN_CLIENT, METADATA_CLIENT,
    STREAM_FALLBACK_ORDER, UPLOAD_FALLBACK_ORDER,
};
pub use models::browse::{
    AlbumPage, ArtistCarousel, ArtistPage, BrowseItem, HomePage, PlaylistContinuation,
    PlaylistPage, PlaylistSort, SearchCardPage, SearchResults, Section, SortMenu,
};
pub use models::context::Locale;
pub use models::lyrics::{PlainLyrics, TimedLyricLine};
pub use models::metadata::{
    AccountIdentity, AccountInfo, NextResult, Rating, SearchResult, SongItem,
};
pub use models::player::{
    find_format, find_video_format, AudioQuality, Format, PlaybackTracking, PlayerResponse,
    StreamingData,
};
pub use rustypipe_fallback::{FallbackError, StreamCandidate};
pub use transport::{cookie_sapisid, generate_cpn, Error, InnerTube, Session};
