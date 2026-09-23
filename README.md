# HomeTA 0.1.0

HomeTA restyles the native CarPlay Home hierarchy instead of placing another window over it.

- Detects the native Home app grid structurally and by controller name.
- Applies glass cards, continuous corners, icon borders and page-control accents.
- Adds a native material panel to the CarPlay dock when a safe dock candidate is found.
- Adds a short spring press response only to identified Home cells.
- Uses no polling timer and contains no MultiTA split, resize or keyboard code.
- Injects only into `com.apple.CarPlayApp`.

The first device build is intentionally conservative. Runtime matches are written once per controller class to `/var/mobile/HomeTA.log`.

HomeTA can be installed beside MultiTA. It does not replace or conflict with MultiTA's package or runtime hooks.
