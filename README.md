# HomeTA 0.3.10 — Rootless battery window experiment

0.3.9 still did not show the sidebar battery on the user's display. The exact cause is unconfirmed.

This version removes the context-host search and uses one transparent, non-key, touch-through UIWindow in the existing CarPlay UIWindowScene. Its level is one above the Home source window. The battery position is derived from the native Home content inset; unsupported insets are skipped and logged rather than guessed.

- Updates battery data through system notifications, with no polling timer.
- Reuses the battery window during Home layout and updates its frame when geometry changes.
- Hides on scene deactivation and releases the window on disconnection.
- Hides an unknown battery reading instead of displaying a false full battery.
- Keeps the existing icon, label and page appearance styling.
- Injects only into com.apple.CarPlayApp; defaults to the rootless Theos scheme.

The vertical position is still proportional to screen height, not anchored to the native network-status view. Visibility in other apps, sidebar alignment, reconnection and touch passthrough require device testing. A successful build does not establish runtime compatibility.

Diagnostics are written to /var/mobile/HomeTA.log: LOADED, CREATED, POSITION and WAIT. If the battery remains invisible, send the log after reconnecting and opening Home. Do not infer remote-layer ownership from screenshots alone.

RootHide requires a separately built and tested package.
