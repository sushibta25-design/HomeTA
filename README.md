# HomeTA 0.3.0-rh1 (RootHide)

HomeTA applies a lightweight iOS 27-inspired appearance directly to the verified native CarPlay Dashboard classes.

- Styles `DBFolderView` with one fixed glass-gradient panel.
- Styles native `DBIconView` and `SBIconImageView` instances directly.
- Restyles native label backdrops and page indicators.
- Adds matching borders to Dashboard widgets.
- Uses no polling timer, no scan loop and no overlay window.
- Injects only into `com.apple.CarPlayApp`.

The class mapping came from the 0.2.1 view-tree probe. Runtime confirmation is written to `/var/mobile/HomeTA.log` only once per styled component type.

HomeTA can be installed beside MultiTA.

This branch is packaged with the official RootHide Theos scheme as `iphoneos-arm64e`. Enable tweak injection for `CarPlay`/`com.apple.CarPlayApp` in RootHide if the bootstrap does not enable it automatically.
