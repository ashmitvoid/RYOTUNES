# ryotunes-bin AUR packaging

This directory contains the binary AUR recipe for Ryotunes. It downloads the precompiled x86_64 pacman package from the matching GitHub Release; it does not compile Ryotunes locally.

Before publishing to the AUR, verify the release asset exists at the URL in `PKGBUILD`, then run `makepkg --printsrcinfo > .SRCINFO` on an Arch-based system and commit the generated `.SRCINFO`.
