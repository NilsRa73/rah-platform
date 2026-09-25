# RAH Storm TV Android v1 — Bangladesh Edition

Android / Android TV companion for RAH World Media.

## v1.1 Storm Radio
- Dedicated **Storm Radio** player instead of the TV player layout.
- Separate **Bangladesh Radio** and **World Radio** catalogs.
- Play/pause plus previous/next station controls for touch and Android TV remotes.
- Automatic single retry, then skip to the next radio station when a public stream is dead.
- Radio favorites use the existing local favorites store.
- Radio catalog caching still works offline when a previous catalog is available.

## v1
- Bangladesh TV is the default home catalog.
- World TV catalog.
- Bangladesh radio.
- World radio.
- Favorites stored locally on the device.
- Native Media3 / ExoPlayer playback.
- 4 / 9 / 16 live Mosaic.
- Android TV remote focus support.
- Storm black/gold/cyan interface.
- Public stream catalogs only; no DRM, paywall, account or geoblocking bypass.

## Install
1. Download the debug APK artifact from the GitHub Actions build.
2. On Android: allow **Install unknown apps** for the app used to open the APK.
3. Install the APK.
4. Android TV / Google TV: APK can be sent by USB, Drive, ADB, or a local file-transfer app.
5. Start **RAH Storm TV**.

Package: `com.rah.stormtv`

Data sources:
- Bangladesh TV: iptv-org public country playlist.
- World TV: iptv-org public country-index playlist.
- Bangladesh Radio: Radio Browser public API.
- World Radio: Radio Browser public API, ordered by popular stations.

Some public streams can be offline, geo-limited or intermittent. The app does not bypass those restrictions.

Build target: Android 6.0+ / Android TV, compileSdk 35, JDK 17.
