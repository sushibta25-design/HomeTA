# HomeTA 0.4.1 — dock touch regression repair

User confirmed that 0.4.0 made the native dock unresponsive. This supersedes that build.

Removes the entire overlay UIWindow and dock glass view. A small bitmap CALayer is now attached directly to the existing source window's layer. It creates no window, view hit target, key-window change, or input-routing hook. The offscreen battery drawing helper is never inserted into a view hierarchy. Rendering is cached until size, screen scale, level, charging or low-power state changes. Layer changes disable implicit animations.

Retains 0.4.0's dark curved Home background, subtle icon borders and compact translucent labels. This follows the supplied reference; it is not a claim of exact Apple iOS 27 reproduction.

Pin location still derives from the native Home inset and a proportional vertical offset. Cross-scene visibility on the device remains unverified. Layer zPosition cannot guarantee visibility above another process's scene. No claim of device success follows from CI compilation.

Install the new rootless DEB, respring (required to unload 0.4.0's retained overlay window), then reconnect CarPlay. Check all three dock app shortcuts, Home/dashboard button, page swipes, battery, native app return and reconnect. If incomplete, send a screenshot plus /var/mobile/HomeTA.log. Logs rotate at 256 KiB with one backup.

No new recurring timer, global hook, private touch forwarding, or SpringBoard injection. RootHide needs its own build.
