# HomeTA 0.5.5 — fixed custom background

Based on the 0.5.3 Tweak.xm, as requested. Removes both its wallpaper-class search and its wallpaper UIView inside DBAnimationView. Does not use the 0.5.4 lower-window fallback.

The custom wallpaper is now a non-hit-testable CALayer directly under the existing Home/application UIWindow, below all its native child layers. Its size comes from window bounds, with identity transform and implicit animation disabled. It is outside both the DBAnimationView and its parent, so their transformations and snapshots do not include this wallpaper. Native app and Home animations remain untouched. No additional window is created.

Battery, icons, labels, and dock handling retain the 0.5.3 code. Rendering is cached until bounds, scale, or appearance changes. Source-window layout and appearance hooks only update the tracked CarPlay window. Wallpaper resources are released on scene disconnect.

## Validation
Install the rootless DEB, respring, and reconnect CarPlay. Open/close Phone and Messages repeatedly; the background should stay still at every edge while the app moves. Check dock touch, Home, split-screen, light/dark mode and reconnect. Expected diagnostic: WALL FIXED sourceLevel=-1 ... outsideHome=1 contents=1. Compilation does not verify device rendering: if a native opaque surface covers this layer, send a new video and HomeTA.log.

Target: Dopamine rootless, iOS 15–16.x. The wallpaper is custom drawn, not an official Apple iOS 27 asset.
