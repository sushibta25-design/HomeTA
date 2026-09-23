# HomeTA 0.2.0

HomeTA restyles the native CarPlay Home hierarchy instead of placing another window over it. Version 0.2.0 no longer depends on finding a particular Home view controller or collection-view hierarchy.

- Scans native views only when they are attached or added to the CarPlay Dashboard window.
- Detects icon containers from live geometry, labels, images and interaction instead of private class names.
- Applies glass cards, continuous corners, icon borders and page-control accents.
- Adds a native material panel to the CarPlay dock when a safe dock candidate is found.
- Adds a short spring press response only to identified Home cells.
- Uses no polling timer and contains no MultiTA split, resize or keyboard code.
- Injects only into `com.apple.CarPlayApp`.

Runtime scan signatures and matched icon classes are written only when they change to `/var/mobile/HomeTA.log`.

HomeTA can be installed beside MultiTA. It does not replace or conflict with MultiTA's package or runtime hooks.
