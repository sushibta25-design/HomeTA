# HomeTA 0.4.0 — Home theme and dock battery

Implements a visual interpretation of the user's reference images, not a verified reproduction of an Apple release.

## Changes
- Static dark blue curved wallpaper behind the native Home icon hierarchy.
- Removes the strong cyan icon and label outlines. Uses subtle white icon edges and compact dark translucent label backdrops.
- Adds a lightly tinted, rounded, touch-through dock overlay. Native dock icons, status text and actions remain owned by the system.
- Draws battery outline, actual proportional fill and charging bolt directly. Unknown readings show an outline with ? instead of hiding or claiming a full battery.
- Battery updates use UIDevice notifications, including low-power changes.
- The display-only window is above ordinary dashboard windows (StatusBar + 1), never key and never receives touches.
- Allows foreground-inactive scenes, hides when backgrounded, and releases the window on scene disconnect.
- Defers scene/window installation out of the icon layout hook, with only three bounded readiness retries. No recurring timer, remote-layer search or live blur.
- Log rotates at 256 KiB; records Home attachment, battery readings, scene state, frame and window level.

## Unverified device behavior
0.3.10 did not display the battery according to the user. No current runtime log was supplied. Low window level, foreground-active-only visibility, or other scene composition may contribute; none is a confirmed root cause.

This build still locates the sidebar from DBAnimationView's content inset and estimates the vertical battery position as 19% of source window height. The new window cannot guarantee priority over another process's scene. Test both dock sides, native app opening, Home return, reconnect, touch and other overlay tweaks. Wallpaper depends on the native icon containers allowing the inserted background to show. CT belongs to another component and is not removed by HomeTA.

CI compilation is not hardware validation. Install the rootless artifact, respring to reload the tweak, reconnect CarPlay, open Home, check battery beneath signal and compare phone battery/charging state. If incomplete, send one screenshot and /var/mobile/HomeTA.log (and .1 when present).

RootHide requires a separately built package. Baseline 0.3.4 is retained in Git history for connection-regression comparison.
