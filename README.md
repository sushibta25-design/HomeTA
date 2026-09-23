# HomeTA 0.3.9 Rootless Sidebar Host Battery Test

The 0.3.8 coordinates were correct, but the remote sidebar layer covered the icon. This build attaches it above the existing `_UIContextLayerHostView` instead.

- Adds a rounded cyan border to native Home icon images.
- Does not insert or remove views.
- Adds a dark glass color and cyan edge to native Home labels.
- Does not enable icon `masksToBounds` or clip icon content.
- Uses no method hook for `DBIconListPageControl`; only its native appearance proxy is configured once at startup.
- Does not hook folder, widget or page-control classes and performs no global view-tree scan.
- Installs the battery icon from the already verified icon hook after the CarPlay window exists.
- Uses system battery-change notifications instead of a timer or polling loop.
- Centers the icon inside the left or right sidebar, below network status and before the dock icons.
- Removes the 0.3.7 dark pill and percentage text; charging state uses the green bolt battery symbol.
- Locates the existing full-screen context host once and adds no new window.
- Walks only the icon's short ancestor chain once to find the native `DBAnimationView` frame, then never intercepts touches.
- Uses no timer, scan loop, gradient panel or overlay window.
- Injects only into `com.apple.CarPlayApp`.

The same HomeTA source can support rootless and RootHide. They should be distributed as separate `.deb` packages because their Theos schemes, bootstrap paths and package architectures differ. This build defaults to `THEOS_PACKAGE_SCHEME=rootless`.

Runtime confirmation is written once to `/var/mobile/HomeTA.log`.
