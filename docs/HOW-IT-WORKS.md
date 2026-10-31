# How Ledge works

A tour of the code for anyone who wants to read it, fix something or add a tool.

## Two Swift targets

- **`Sources/LedgeCore`** has no UI. Everything that can be decided from plain values lives here and is unit-tested (`Tests/LedgeCoreTests`, Swift Testing): the island state machine, geometry of the notch, the module registry, the calculators (`Calculator`, `ExpressionCalculator`, `ProgrammerCalculator`, `FractionFormat`, `CalculationHistory`), timers (`CountdownTimer`, `Stopwatch`, all on an explicit `now` so tests never wait), the file shelf model, tile arrangement (`TileOrder`, `TileArrangement`), monitor maths (`SystemMetrics`), the Keep Awake session, microphone mute rules, hold-to-exit for cleaning mode, and more.
- **`Sources/Ledge`** is the AppKit shell: windows, views, and the thin wrappers around system services. A system service (Core Audio, IOKit, AVFoundation, the sharing service) always sits behind a small protocol, so the logic that uses it can be tested with a fake.

## The windows

The island is two borderless, non-activating `NSPanel`s:

- `PillPanel` / `PillView`: the *closed* island, a black shape exactly over the hardware notch, plus optional strips beside it for a pinned running time. It receives the click that opens the island and the drag of files that makes it open early.
- `IslandPanel` / `IslandView`: the *open* island, the system Liquid Glass material (`NSGlassEffectView`, with an `NSVisualEffectView` blur on systems without it). It sits one window level above the pill. It becomes the key window while open, because the glass only renders its lit rim and depth in a key window; `IslandController` hands the focus back to the previous app on close.

Opening and closing animate as **one object** (fade plus a slight scale from the top centre). `IslandController` is the glue: display changes, pointer events, the state machine and the two panels.

Hold on to one rule here: anything that "holds" the island open (for example the AirDrop window) must have an exit that does not depend on the other window calling back. Losing app focus always releases the hold.

## Modules

Every feature is a `UIModule` (`Sources/Ledge/Modules`): a title, a tile, optionally a page, and optional hooks (`islandVisibilityChanged`, a drop zone, a compact text for the closed island, a hold handler, a home handler). A new tool is one file plus one line in `AppDelegate.modules`.

`ModuleRegistry` (in `LedgeCore`) starts and stops modules in isolation:

- `start()` throws: that module is marked failed for this run, the others live.
- the app crashed during a module's `start()`: a marker in `UserDefaults` makes the next launch switch that module off (protection against a crash loop); the user can switch it back on.
- every module has an on/off switch in Settings, and **a switched-off module holds no objects and no observers**.

## Event-driven, on purpose

There are no polling timers. The linter fails the build on `Timer.` and friends. Things that must tick (the monitor, running clocks) use a single delayed call per second (`SecondTicker`) and only while someone can see them: the island is open, or a clock is pinned beside the notch. Battery changes arrive as a system event. Timed Keep Awake uses one delayed call on wall-clock time for its end. Core Audio listeners for the microphone are installed when the island opens and removed when it closes.

## Home screen

`IslandView` lays the tiles out by hand in a five-by-two grid (`TileGridLayout`). Hovering a tile swells it and ticks the trackpad (`Haptics`, `NSHapticFeedbackManager`). The user's order and put-away tiles are a `TileArrangement` (shown tiles, hidden tiles; at most five hidden), saved as lists of module ids in `UserDefaults`; modules that appear or vanish later cannot break it (`TileOrder.arranged`). Rearranging is a mouse drag handled in `IslandView.handleDrag`; the tiles shake with a Core Animation loop. A drag that cannot finish (the island closed while the button was down) is cancelled and the order is restored.

## Notes on individual tools

- **Cleaning mode** (`CleaningSession`, `KeyboardBlocker`, `CleaningView`): one black `NSPanel` per display at the shielding window level, `NSApp.presentationOptions` to switch off process switching, hiding and force-quit, and a `CGEvent` tap that swallows every keyboard event (including system-defined media/power keys) and reports only Esc. That tap is why it needs the Accessibility permission. Esc and the on-screen button use `HoldToExit`. A power assertion keeps the display awake. The mode ends if the app loses focus or the displays change.
- **Keep Awake** uses `IOPMAssertionCreateWithName(PreventUserIdleDisplaySleep)`.
- **Microphone** uses the public Core Audio mute property of the default input device, or a remembered volume of zero when the device has no mute.
- **Mirror** is an `AVCaptureSession` with a preview layer, mirrored, created when the window opens and torn down when it closes.
- **Shelf** stores security-scoped bookmarks (references) in a JSON file under Application Support, never copies.
- **Monitor** reads Mach `host_statistics`, per-interface network counters (64-bit), volume capacity and IOKit power sources.
- **AirDrop** uses `NSSharingService(named: .sendViaAirDrop)`; the island stays open (a hold) while the system picker is up.

## Rules the repository enforces

`tools/lint-rules.sh` (run by `tools/run-tests.sh`) fails on: private frameworks or runtime tricks, network APIs, polling timers, and external Swift packages. UI strings go through `L10n` and `Localizable.strings`; a test keeps every language file in step with English.

## Driving the real app

`tools/ui-test` has small Swift tools (move, click, hold, drag, scroll, frame export, GIF building) used to look at the real app from a script. Read its README before using them: a click that lands on the wrong window does real damage.
