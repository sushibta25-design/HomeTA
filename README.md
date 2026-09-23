# HomeTA 0.3.2 Rootless Safe Test

This incremental build keeps the verified `SBIconImageView` hook and adds the verified native `DBIconLabelBackdropView` hook.

- Adds a cyan border to native Home icon images.
- Does not insert or remove views.
- Adds a dark glass color and cyan edge to native Home labels without inserting views.
- Does not hook folder, widget or page-control classes.
- Uses no timer, scan loop, gradient panel or overlay window.
- Injects only into `com.apple.CarPlayApp`.

The same HomeTA source can support rootless and RootHide. They should be distributed as separate `.deb` packages because their Theos schemes, bootstrap paths and package architectures differ. This build defaults to `THEOS_PACKAGE_SCHEME=rootless`.

Runtime confirmation is written once to `/var/mobile/HomeTA.log`.
