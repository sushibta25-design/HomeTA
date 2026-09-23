# HomeTA 0.3.3 Rootless Safe Test

This incremental build keeps the verified native Home hooks and adds the verified `DBIconListPageControl` hook.

- Adds a rounded cyan border that follows native Home icon corners.
- Does not insert or remove views.
- Adds a subtler dark glass color and cyan edge to native Home labels.
- Colors the active native page indicator cyan and dims inactive indicators.
- Does not hook folder or widget classes.
- Uses no timer, scan loop, gradient panel or overlay window.
- Injects only into `com.apple.CarPlayApp`.

The same HomeTA source can support rootless and RootHide. They should be distributed as separate `.deb` packages because their Theos schemes, bootstrap paths and package architectures differ. This build defaults to `THEOS_PACKAGE_SCHEME=rootless`.

Runtime confirmation is written once to `/var/mobile/HomeTA.log`.
