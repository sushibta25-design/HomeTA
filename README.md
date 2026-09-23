# HomeTA 0.5.4 — transition wallpaper fix

The supplied 0.5.3 device log reports `WALL miss`: the background window is `UIWindow(-2) > UIView`, with no Wallpaper-named view. The Home wallpaper was inside DBAnimationView, so the original background could show while Home animated away.

This version retains named-wallpaper discovery and adds a conservative fallback for a full-screen plain UIView in a lower-level UIWindow in the same scene. It rejects containers with child views, transformed containers, and windows at or above the Home/application window. The wallpaper is installed synchronously when Home is attached and refreshed by Home layout/appearance changes, with cached rendering and cleanup on scene disconnect.

Battery and dock touch behavior are unchanged. No added window or repeating timer. Decorative layers remain excluded from hit testing. If no qualified background host exists, the in-Home wallpaper remains and WALL miss is logged.

Target: Dopamine rootless, iOS 15–16.x, com.apple.CarPlayApp.

## Device verification
Install the 0.5.4 DEB, respring and reconnect CarPlay. Open/return from Phone and Messages repeatedly; inspect all four edges and rounded corners during the animation. Check dock shortcuts, Home button, app touches, light/dark appearance and reconnect. The expected log is WALL dedicated backdrop followed by WALL host and WALL painted. Actual transition rendering still needs device verification; a successful build does not verify CarPlay behavior.

The visual theme is custom drawn; it does not install a newer iOS interface.
