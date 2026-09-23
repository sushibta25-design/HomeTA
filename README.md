# HomeTA 0.3.7 Rootless Battery Indicator Test

This build keeps the verified 0.3.6 behavior and adds a compact live iPhone battery indicator beside the CarPlay sidebar.

- Adds a rounded cyan border to native Home icon images.
- Does not insert or remove views.
- Adds a dark glass color and cyan edge to native Home labels.
- Does not enable icon `masksToBounds` or clip icon content.
- Uses no method hook for `DBIconListPageControl`; only its native appearance proxy is configured once at startup.
- Does not hook folder, widget or page-control classes and performs no global view-tree scan.
- Installs the battery indicator from the already verified icon hook after the CarPlay window exists.
- Uses system battery-change notifications instead of a timer or polling loop.
- Walks only the icon's short ancestor chain once to find the native `DBAnimationView` frame, then never intercepts touches.
- Uses no timer, scan loop, gradient panel or overlay window.
- Injects only into `com.apple.CarPlayApp`.

The same HomeTA source can support rootless and RootHide. They should be distributed as separate `.deb` packages because their Theos schemes, bootstrap paths and package architectures differ. This build defaults to `THEOS_PACKAGE_SCHEME=rootless`.

Runtime confirmation is written once to `/var/mobile/HomeTA.log`.
