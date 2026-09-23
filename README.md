# HomeTA 0.3.1 Rootless Safe Test

This recovery build tests one verified native CarPlay class only: `SBIconImageView`.

- Adds a cyan border to native Home icon images.
- Does not insert or remove views.
- Does not hook folder, widget, label or page-control classes.
- Uses no timer, scan loop, gradient panel or overlay window.
- Injects only into `com.apple.CarPlayApp`.

The same HomeTA source can support rootless and RootHide. They should be distributed as separate `.deb` packages because their Theos schemes, bootstrap paths and package architectures differ. This build defaults to `THEOS_PACKAGE_SCHEME=rootless`.

Runtime confirmation is written once to `/var/mobile/HomeTA.log`.
