# HomeTA 0.7.2 -- dock corner patches now sampled from the real wallpaper bitmap

0.7.2: the two rounded outer-corner patches on the dock were previously filled with a guessed flat navy/light color, which visibly clashed with the actual wallpaper next to it. They are now cropped directly out of the SAME bitmap already painted for the real Home wallpaper (pixel-for-pixel, same window bounds), so the patch is the actual background, not an approximation. Falls back to the old flat color only if the wallpaper bitmap isn't ready yet.

IMPORTANT -- the log from this round showed FOUR different HomeTA versions loading within five minutes (0.5.6, 0.5.5, 0.4.1, then 0.7.1), which is almost certainly why the wallpaper appeared completely stock in one of the photos: 0.4.1 has no wallpaper code at all. Before testing 0.7.2, uninstall HomeTA completely (Sileo/Zebra -> Installed -> HomeTA -> Remove), respring, then install ONLY this .deb, respring again. Testing with more than one version's dylib present makes every other result in this log impossible to trust.
0.7.0: adds the iOS 27-style floating rounded dock card (small gap off the top/bottom/outer screen edge, rounded corners), requested after the Porsche reference photo. Built as an ADDITIVE overlay only: a solid-color frame is painted on top of the real dock, with a rounded rect punched transparent in the middle so the real content shows through the hole. The real dock view (_UITouchPassthroughView per DOCKTREE) keeps its exact original frame and tap targets -- nothing about its size, position, or hit-testing changes. This is deliberately a different technique from whatever the earlier 0.5.6 experiment used to break dock touch; that approach is not reused here.

Gaps used: 6pt top, 6pt bottom, 6pt on the outer (screen-edge) side, 0pt on the inner side (stays flush against the app icons), corner radius up to 18pt. Frame color is a flat dark-navy or light tone matching the wallpaper's base shade (not a live sample of the actual wallpaper pixels, which sit in a different window) -- close, but check for an obvious seam against the wallpaper in test 5 below.

TEST THIS ONE PARKED FIRST. After respring: (1) do all 3 dock icons plus Home/Dashboard buttons and page-swipe still register touches, right up to their visual edge including in the new gap area (they should -- the tap zone hasn't moved, only the paint on top of it has), (2) does the rounded frame look intentional or does it look like a colored box slapped over the dock, (3) do the corners look uniformly rounded in both light and dark CarPlay appearance, (4) reconnect a few times to make sure the mask reappears correctly, (5) compare the frame color against the new wallpaper right next to it for an obvious seam. If ANY touch stops responding, that alone means this technique also does not hold up despite the different approach -- roll back to 0.6.3 immediately and send the log's DOCKMASK lines plus a video.
0.6.2: normal (non-charging, non-critical, non-low-power) battery digits used a destination-out blend to punch the number through the white fill, revealing a transparent hole. Because the layer bitmap is non-opaque, the fill/track boundary crossing a glyph stroke produced two misaligned halves of that stroke, which read as a doubled or ghosted outline (matches the reported look). Replaced with two plain, non-blended fills (dark ink over the filled part, white ink over the empty part) split by the same clip boundary -- same visual intent, no compositing seam. Log confirms 0.6.1 loaded cleanly with no duplicate instance, so the earlier "mat giao dien iOS 27" report is more likely the CarPlay Dashboard screen (a separate screen from Home that HomeTA does not touch) than a regression -- send a photo of exactly which screen looked wrong to confirm.

0.6.1: 0.6.0 failed to build (HTTree undeclared) because the tree-dump helper was accidentally deleted while removing the old wallpaper-search code, but the new dock diagnostic still called it. Re-added HTTree; no other logic changed from 0.6.0.

Target: rootless (Dopamine), iOS 15-16.x, process com.apple.CarPlayApp. Supersedes 0.5.3, which tried to find and paint over the stock wallpaper VIEW (search failed on this device -- "WALL miss" in the log -- so the old red/blue iOS wallpaper still showed at the screen corners and around the app card while it zoomed open/closed). 0.6.0 instead paints one CALayer sized to the FULL WINDOW that hosts Home, inserted at the very bottom of that window's layer stack ("WALL painted ..." in the log). That window never changes during the open/close animation, so the new wallpaper now stays under everything at every corner, in every state. Removed the old in-Home wallpaper view entirely (was view-only, only covered Home's own bounds, not the full screen -- that partial coverage was the root cause).

Dock outer corners: NOT changed yet. Added a one-shot, read-only diagnostic -- DOCKTREE ... in the log -- that dumps the dock rail's real view hierarchy inside DBStatusBarHostWindow. Rounding the wrong view broke dock touch once already (0.4.x); this build only looks, so send the log after connecting and the next build will target the exact backdrop view by class name.

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
