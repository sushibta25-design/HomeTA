# HomeTA 0.3.5 Rootless Rounded Border Test

This build keeps the exact verified 0.3.4 hook scope and changes only the native icon layer border radius.

- Adds a rounded cyan border to native Home icon images.
- Does not insert or remove views.
- Adds a dark glass color and cyan edge to native Home labels.
- Does not enable icon `masksToBounds` or clip icon content.
- Does not include the 0.3.3 page-control hook.
- Does not hook folder, widget or page-control classes.
- Uses no timer, scan loop, gradient panel or overlay window.
- Injects only into `com.apple.CarPlayApp`.

The same HomeTA source can support rootless and RootHide. They should be distributed as separate `.deb` packages because their Theos schemes, bootstrap paths and package architectures differ. This build defaults to `THEOS_PACKAGE_SCHEME=rootless`.

Runtime confirmation is written once to `/var/mobile/HomeTA.log`.
