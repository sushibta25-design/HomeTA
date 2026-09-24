# HomeTA 1.0.0 — iOS 27-style CarPlay Home

Target: rootless (Dopamine), iOS 15–16.x, process `com.apple.CarPlayApp`.

First stable milestone after an extended round of trial-and-error (~40 builds) to find techniques
that actually render on this specific head unit/connection, without ever touching the dock's real
hit-testing. This file describes the final, working design — not the history of what didn't work.

## What it does

- **Wallpaper**: a custom "Celosia"-style layered-curve background (own drawing, not an Apple
  asset), replacing the stock CarPlay wallpaper on the Home screen.
- **Icons**: continuous-corner squircle shape with a Liquid Glass-style gradient rim instead of a
  flat border; labels are plain white text with a soft shadow instead of a dark pill.
- **Battery**: borderless pill in the dock — translucent track, solid fill, no outline. Green when
  charging or full, red at ≤20%, yellow in Low Power Mode, plain white otherwise. Uses the real
  `UIDevice` battery API; the visual design is entirely custom.
- **Dock**: the real dock content and its tap targets are never touched. A separate overlay layer
  sits on top with a rounded hole cut out (3pt margin, 12pt radius) so the real content shows
  through; the margin itself is cropped live from the actual wallpaper bitmap so it blends in
  rather than reading as a mismatched box. A light 42%-alpha wash of the same crop is also laid
  over the visible inner area, tinting the dock toward the wallpaper's color without hiding the
  real icons/clock underneath.

## How the wallpaper actually gets on screen (two layers, deliberately redundant)

1. **Subview inside Home** — an `HTWallpaper` `UIView` is inserted with `insertSubview:atIndex:0`
   directly into `DBAnimationView` (Home's own content view). This is the technique that is
   confirmed working, via a recovered old build's disassembled strings and a live photo/log match:
   inserting a bare `CALayer` into anything (this view, or the window) does not render on this
   unit; a real `UIView` inserted into Home's own view tree does.
2. **Welded replacement** — a second pass walks Home's layer tree looking for the real stock
   background layer (identified by a size signature: a leaf layer, opaque, sized to Home's exact
   bounds, while sibling "page" layers are all 16pt shorter) and hides it, inserting a second
   painted layer directly in its place. This runs as a backstop under layer 1, re-asserting the
   hide every layout pass in case the system ever un-hides its own layer again.

Both are attached from two places: `SBIconImageView.layoutSubviews` (existing icons) and
`DBAnimationView.layoutSubviews` directly (so a freshly recreated Home page gets the wallpaper
immediately, without waiting on a child icon to also lay out — this narrows, but does not
provably eliminate, a very brief stock-color flash some testing caught mid-transition during app
open/close).

## Known remaining limitation

A very brief three-way color blend (app color / fake wallpaper / real stock color) was caught in a
single photo pulled from a video during an app-open/close transition. Extensive frame-by-frame
video review otherwise found no visible leak. The likely cause is a system-level transition
snapshot taken before this tweak's hooks run, which is a different mechanism from anything above
and was not tracked down. Steady-state Home (not mid-transition) and the actual app screens
themselves are unaffected.

## Explicitly out of scope for this build

- Adding a custom wallpaper as a real, selectable entry in Settings → CarPlay → Wallpaper. This
  would mean hooking into Apple's private wallpaper-picker data source and persistence, which is a
  different kind of project from painting over the rendered result — no investigation has been
  done here yet.
- Reshaping the dock into a fully floating, inset-on-all-sides card (as opposed to the current
  rounded-hole overlay). The real dock content and its tap targets are one and the same view; a
  true reshape was judged too high-risk given an earlier build broke dock touch entirely.
- A real Do Not Disturb While Driving indicator. Testing found no such indicator appears on this
  unit's CarPlay at all when the Focus is enabled on the phone, suggesting the phone's iOS version
  does not render one here (independent of this tweak). No reliable API to read that Focus state
  from within this process has been confirmed either.

## Build

GitHub Actions (`.github/workflows/build.yml`) builds `HomeTA-1.0.0-rootless-ios27-style` on Theos
against the iOS 16.5 SDK for `iphoneos-arm64`. Install the resulting `.deb`, then **respring** —
this is mandatory; a stale prior build's dylib coexisting with this one has caused confusing,
inconsistent results in testing before.

## Diagnostics still in the binary

- `DOCKTREE` (once per connect): the dock host window's real view-class tree. Kept because the
  dock is the one place a change has broken touch outright before; if that ever needs debugging
  again, this saves a round-trip.
- `PROBE dock` / `WINDOW` (once per connect, ~3s after Home attaches): which view actually
  receives a touch at several points down the dock, and every window in the scene. Same reasoning.
- `WELD replaced` / `HOMEWALL view attached` / `DOCKMASK`: one-line confirmations that each part of
  the wallpaper/dock system found what it expected and painted.

Log file: `/var/mobile/HomeTA.log` (auto-rotates past 256 KB).
