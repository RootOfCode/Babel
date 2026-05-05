# GUI Workflow

BABEL has an in-window GUI overlay drawn inside the SDL2/OpenGL window. The GUI is meant to make the project usable without relying only on REPL commands.

## Main Areas

### Left Workflow Panel

The left panel controls scene selection, camera/display options, generation actions, save/export actions, and overlay toggles.

### Top View Toolbar

The floating toolbar contains quick viewport actions:

* `FIT` — frame the current object
* `ISO` — isometric-style view
* `TOP` — top-down view
* `FRONT` — front view
* `GRID` — toggle the ground grid
* `WIRE` — cycle wire thickness
* `STATS` — show or hide the scene inspector
* `THEME` — cycle UI theme
* `FONT-` / `FONT+` — resize editor text
* `TPL` — load a code template
* `SAVE` — save the editor buffer to `output/babel-live-code.lisp`

### Scene Inspector

The inspector shows live information such as vertex count, edge count, macro count, colour mode, grid state, bounding box, camera distance, and editor dirty state.

### Structure Code Editor

The editor shows and edits Lisp source for the current scene or imported file. It supports selection, copy, cut, paste, apply, reload, import, hot reload, font scaling, and save.

## Mouse Controls

| Input | Action |
|---|---|
| Click GUI buttons | Run scene, display, generation, save, and export actions |
| Left-drag outside GUI | Orbit camera |
| Right-drag outside GUI | Pan camera |
| Scroll outside editor | Zoom |
| Scroll inside editor | Scroll code |
| Drag inside editor | Select code |
| Shift-click or Shift-drag | Extend selection |

## Keyboard Shortcuts

| Key | Action |
|---|---|
| `F2` | Show/hide GUI |
| `F3` | Show/hide Structure Code editor |
| `F4` | Show/hide Scene Inspector |
| `F5` | Apply edited code |
| `F6` / `Ctrl+C` / `Cmd+C` | Copy selection or full buffer |
| `F7` / `Ctrl+V` / `Cmd+V` | Paste from clipboard |
| `F8` | Import a code file |
| `F9` | Toggle hot reload |
| `F10` | Cycle UI theme |
| `F11` | Fit camera |
| `H` | Help overlay |
| `Esc` | Unfocus editor or close overlay |
| `Z` | Undo world change |

## Import and Hot Reload

The import button attempts to open the operating-system file picker. If no picker helper is available, BABEL falls back to common import paths such as `import.lisp`, `output/import.lisp`, and `code.lisp`.

After a source file is imported, hot reload watches it and reapplies it when the file changes.

## Safe Editing Behavior

The live editor is designed for experimentation. If the edited code has a read error or evaluation error:

* the old 3D scene stays active
* the editor reports the error
* the dirty buffer remains available for fixes

This makes the editor practical for iterative Lisp world programming.

## Recommended GUI Loop

1. Select a built-in scene.
2. Press `F3` or `EDITOR`.
3. Modify the structure source.
4. Press `F5` or `APPLY`.
5. Use `FIT` to frame the result.
6. Save a `.world` file or export geometry when satisfied.
