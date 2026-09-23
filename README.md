# HomeTA 0.5.0 — iOS 27-style CarPlay Home + dock touch hardening

Target: rootless (Dopamine), iOS 15–16.x, process `com.apple.CarPlayApp`. Supersedes 0.4.1.

## Dock touch
- Every layer HomeTA adds (dock battery, Home wallpaper, icon glass rim) is marked non-hit-testable
  via private `CALayer.allowsHitTesting=NO` (guarded by respondsToSelector), so the render server
  cannot route a touch to them.
- Battery layer zPosition lowered from 10000 to 100.
- Home attach now skips any icon inside a view whose class contains `Dock`/`StatusBar`, and only
  accepts a `DBAnimationView` at least half the window width, so nothing is ever inserted into a dock container.
- One-shot diagnostics 3 s after CarPlay connects: `PROBE dock ...` (which view UIKit hit-tests at 4 points
  down the dock) and `WINDOW ...` (every window in the scene). A leftover 0.4.0 overlay window shows up here.

## Look (reference: iOS 27 CarPlay coverage, Sept 2026)
- Wallpaper: layered sweeping curves with soft shadows, inspired by the iOS 27 "Celosia" wallpaper; light/dark variants follow the CarPlay appearance.
- Battery: iOS 27 borderless style — translucent track, no outline, solid fill; percentage punched out of the white fill;
  green + bolt when charging, green when full, red at <=20 %, yellow in Low Power Mode.
- Icons: continuous-corner squircle (22.5 %) with a Liquid Glass-style gradient rim instead of a flat border.
- Labels: dark pill removed, plain label with soft shadow.
This is an approximation drawn on iOS 16; Apple's own assets/material are not reproduced.

## Test
Install DEB, **respring** (mandatory, clears any 0.4.x state), reconnect CarPlay, wait 5 s.
Check: 3 dock shortcuts, Home/dashboard button, page swipes, battery states, app return, reconnect.
If the dock still ignores touches, send `/var/mobile/HomeTA.log` (the PROBE/WINDOW/DOCK lines) + a photo.

No new window, view hit target, recurring timer, global hook, touch forwarding or SpringBoard injection.
