# HomeTA 0.5.6 — reference ribbons and rounded dock

Custom artwork redrawn from the user's two reference screenshots: broad sweeping blue/purple ribbons with luminous edges. This is not an extracted or verified official iOS 27 wallpaper. CarPlay appearance selects blue (light) or purple (dark).

Retains the 0.5.5 stationary wallpaper: a direct sublayer of the Home/application window, below native child layers and outside DBAnimationView. Rendering is cached by size, scale and appearance.

The existing DBStatusBarHostWindow receives a matching translucent gradient behind its contents and a rounded visual mask restricted to the dock strip. The rest of the window remains visible. Existing system/third-party masks are respected, not replaced. No new window or touch view is created; native buttons and their positions remain unchanged. Decorative layers do not hit-test. Scene disconnect removes owned styling.

## Device checks
Install rootless DEB, respring, reconnect. Check rounded dock, blue/purple theme, shortcuts/Home button and edge touches. Open/close apps repeatedly and inspect the stationary background. Check split-screen and reconnect. Look for WALL FIXED and DOCK rounded in HomeTA.log.

Native dock surfaces can obscure the gradient depending on the OS/compositor. Native opaque surfaces may also cover the fixed wallpaper. Build success is not device visual verification. Send a screenshot and log if the old rectangular dock or wallpaper remains.
