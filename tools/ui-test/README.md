# UI test helpers (dev only)

Tiny Swift tools to drive and inspect Ledge from the terminal (the app itself has no test hooks).
Build once: `tools/ui-test/build.sh` → binaries in `.build/ui-test/`. Coordinates are screen points (origin top-left);
on the author's MacBook (1470×956 points) the notch is centred at x≈734, the island opens to 440×176 (+28 above the screen).

| Tool | What it does |
|---|---|
| `move x y` | moves the pointer (posts a real mouse-moved event) |
| `click x y` | mouse down + up (60 ms) at x y |
| `hold x y ms` | mouse down, wait, up: to photograph a pressed button |
| `drag x1 y1 x2 y2 [ms [x3 y3]]` | mouse down, move in small steps, hold over the target, release: drags a file from Finder onto the island; with `x3 y3` it continues there after the wait (drop on a zone inside the opened island) |
| `scroll x y dy count` | `count` precise (pixel) scroll events of `dy` points at x y: drives the timer wheels |
| `export-frames in.mov outdir` | every frame of a recording as PNG named `fNNN_<ms>ms.png` (record with `screencapture -x -v -V <sec> -R x,y,w,h out.mov &`) |
| `contact-sheet out.png cols f1.png f2.png …` | labelled contact sheet of frames |
| `backdrop x y w h` | a neutral gradient window behind the island (below the menu bar and the island panels), for clean screenshots and GIFs; kill it when done |
| `make-gif out.gif fps width dir [step first last]` | builds an animated GIF from exported frames; `GIF_CROP="x,y,w,h"` crops the frames first |
| `lum dir` | prints frames where the mean brightness of the island area changes (finds flicker) |

## Lessons (read before testing)
- **Move first, then click.** A pointer "teleport" (click without a preceding `move` over the target) does not register as
  entering the window, so hover/exit logic behaves differently from real use. Always `move`, wait 0.3 s, `click`.
- **Never click blind.** If the island has closed, a click at island coordinates lands on another app's menu bar.
  Screenshot (`screencapture -x -R400,0,670,260 f.png`) and look before clicking buttons; Escape (`key code 53`) dismisses a stray menu.
- Layout positions change with the page; read button positions from a screenshot (2× pixels → divide by 2, add the crop origin).
- TextEdit for focus tests: `pkill -x TextEdit; open -a TextEdit --args -ApplePersistenceIgnoreState YES`, read text with
  `get text of front document`, not `document 1` (old windows pile up). `timeout` does not exist on macOS.
- `System Events` `keystroke` follows the keyboard layout (Russian layout turns `a` into `ф`): compare character counts, not letters.
- Screen capture of one frame cannot catch a 0.1 s animation; record a video and export frames.
- Launch the app with `open dist/Ledge.app` (as a user would), not by running the binary directly, for focus/activation tests.
- **Drag tests (28.10):** (1) put the Finder window so that it covers the area under the island (`osascript` `set bounds of front Finder window`, `set position of item`), otherwise another app's window under the notch (VS Code is Electron and activates itself when a file drag enters it) steals the focus; (2) activate Finder and drag in the same command, the focus moves to the editor between tool calls; (3) drop in the CENTRE of a zone: an image view inside a drop target takes drags itself and made the zone lose the drag (it looked like the system cancelling a synthetic drag; it was not).

## Screenshots and GIFs for the README (lessons)
- Run the app in English for them: `open dist/Ledge.app --args -AppleLanguages "(en)"`.
- Put `backdrop` behind the island, then capture the island region with `screencapture -x -R494,0,480,196 file.png` (island centred at x≈734).
- **Check the island is really open before every click** (compare a capture with a capture of the closed island); a click that lands on another app's window does real damage. Never reuse tile coordinates from memory: the tile order is the user's own.
- `screencapture -v` does not overwrite an existing movie file: use a new file name each time, or you will keep looking at the old recording.
- In zsh an unquoted variable holding "611 64" is one argument: use `${=var}` to split it.
