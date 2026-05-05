# BABEL — README Legado antes da Atualização da Documentação

> Página migrada do antigo diretório `docs/` para manter toda a documentação dentro das pastas de idioma. Nomes de funções, exemplos Lisp, formatos de arquivo e símbolos técnicos foram preservados para evitar perda de precisão.

## The Lisp Macro World Compiler

> *"In the beginning was the Word. Then the Word wrote more Words."*

BABEL is a 3D wireframe world generator in **SBCL Common Lisp** where the AI's creative output is new **Lisp functions**. It does not draw fixed worlds — it grows a vocabulary. Every function it invents becomes a new primitive in the language of space. Worlds are programs written in that language. As the vocabulary deepens, the complexity achievable in a single world-expression grows exponentially — because each new function can call all the ones before it.

---

## Quick Start

First-time setup and launch:

```bash
chmod +x install.sh run.sh
./install.sh
```

After dependencies are already installed, use the lightweight launcher:

```bash
./run.sh
```

The SDL window now includes a full in-window GUI overlay. The default layout opens cleanly with a left workflow sidebar, a compact top view toolbar, a scene inspector, and collapsed optional help/editor panels. You can operate scenes, camera/display options, AI generation, saves, screenshots, exports, and edit the live structure source code with clickable buttons instead of relying on terminal commands.

The REPL is still available for live world programming when you want it:

```lisp
(babel:babel-eval
  (fortress 0.0 0.0 50.0)
  (dome 0.0 0.0 0.0 12.0 10))
```

> **Never call `(babel:run)` directly** — it blocks the REPL thread. Always use `run-threaded`, `run.sh`, or `install.sh`.

---

## Starting with Quicklisp

If you already have Quicklisp and SBCL set up, you can load and run BABEL without `install.sh`:

```lisp
;; 1. Register the system (only needed once per session if not in local-projects)
(pushnew "/path/to/Babel/" asdf:*central-registry* :test #'equal)

;; 2. Load it
(ql:quickload :babel-world)

;; 3. Bootstrap the vocabulary
(babel:initialize)

;; 4. Open the window in a background thread — keeps the REPL free
(babel:run-threaded)

;; 5. Evaluate worlds live
(babel:babel-eval
  (fortress 0.0 0.0 50.0)
  (plane 0.0 0.0 200.0 200.0 0.0))
```

If you cloned Babel into `~/quicklisp/local-projects/babel-world/`, Quicklisp will find it automatically and step 1 can be skipped.

> **Never call `(babel:run)` instead of `(babel:run-threaded)`** — `run` hands the calling thread to SDL2 permanently, freezing the REPL.

---

## Prerequisites

| Requirement | Install |
|---|---|
| SBCL >= 2.0 | `sudo apt install sbcl` |
| SDL2 | `sudo apt install libsdl2-dev` |
| Quicklisp | https://www.quicklisp.org/beta/ |

Quicklisp auto-installs: `sdl2`, `cl-opengl`, `cl-glu`, `alexandria`, `bordeaux-threads`, `cffi`.

---

## Architecture

```
Babel/
├── babel-world.asd      ← ASDF system (:babel-world, avoids clash with cl:babel)
├── doc-en/
│   ├── reference/
│   ├── ai-system.md     ← Inventor engine, scoring, evolution
│   ├── persistence.md   ← Saving/loading worlds, vocabularies, output directory
│   ├── primitives.md    ← Full Layer-0 primitive reference with signatures
│   ├── vocabulary.md    ← Vocabulary layers, hand-crafted macros, custom macros
│   └── worlds.md        ← Writing world programs, babel-eval, examples
├── install.sh           ← Dependency installer, cache cleaner, and first-time launcher
├── run.sh               ← Lightweight GUI launcher for normal use
├── examples/
│   └── import-example.lisp ← Copy to import.lisp for the GUI IMPORT button
├── load.lisp            ← Flat loader (no ASDF needed)
├── README.md
├── repl-tour.lisp       ← Step-by-step guided REPL session
├── src/
│   ├── camera.lisp      ← Orbital camera (yaw/pitch/distance/pan)
│   ├── colour.lisp      ← 7 wireframe colour modes
│   ├── evolution.lisp   ← Mutation + crossover operators
│   ├── export.lisp      ← OBJ / SVG / EDN geometry exporters
│   ├── geometry.lisp    ← EMIT-EDGES + 14 low-level shape emitters
│   ├── gizmo.lisp       ← Screen-corner XYZ axis + ground reference rings
│   ├── inspector.lisp   ← ANSI terminal macro profiler
│   ├── inventor.lisp    ← Template-based AI invention engine + hand-crafted layers
│   ├── layer0.lisp      ← 15 Layer-0 primitive functions
│   ├── main.lisp        ← Entry point, babel-eval, output directory, banner
│   ├── package.lisp     ← Package :babel, 80+ exported symbols
│   ├── persistence.lisp ← .world/.voc formats, session save/load, undo journal
│   ├── registry.lisp    ← babel-macro struct, *babel-registry*, export-library
│   ├── renderer.lisp    ← SDL2 event loop + OpenGL 2.1 wireframe renderer
│   ├── scoring.lisp     ← 6-dimensional fitness scoring
│   ├── scene-source.lisp← Source snippets compiled by the live Structure Code editor
│   ├── terrain.lisp     ← Diamond-square heightmap + plateau emitter
│   ├── ui.lisp          ← In-window GUI panels, buttons, live code editor, help, status bar
│   └── worlds.lisp      ← 11 demo scenes + WORLD macro
└── worlds/
    ├── The_Basilica_Of_Broken_Skies.world
    ├── The_Cathedral_of_Spires.world
    ├── The_Great_Aqueduct.world
    ├── The_Necropolis_of_Ahk-Meren.world
    └── The_Obsidian_Monastery.world
```

---

## GUI Controls

BABEL now has a complete in-window GUI rendered inside the SDL/OpenGL window. The left control panel provides clickable buttons for:

| Panel | Actions |
|---|---|
| Scene | Previous / next scene and direct scene buttons `0`-`10` |
| Camera + Display | Reset camera, fit camera, switch ISO/TOP/FRONT view presets, cycle colour mode, toggle grid, wire thickness, XYZ gizmo, and ground rings |
| System | Grow next AI layer, evolve macros, save library, save `.world`, export OBJ, export 4-view SVG, screenshot, export all |
| Code | Show/hide the Structure Code editor, edit the live source, select/copy/cut/paste code, import source files, hot-reload imported files, apply/reload it, and scroll through it |
| Overlay | Show/hide help, show/hide Scene Inspector, cycle UI themes, hide the GUI |

### New polished editor tools

The latest GUI pass adds a floating **VIEW TOOLS** toolbar and a live **SCENE INSPECTOR** card over the 3D viewport. The toolbar adds:

| Button | Action |
|---|---|
| **FIT** | Frame the current object automatically with the camera |
| **ISO / TOP / FRONT** | Switch camera view presets instantly |
| **GRID** | Toggle the ground grid |
| **WIRE** | Cycle wireframe thickness |
| **STATS** | Show/hide the scene inspector overlay |
| **THEME** | Cycle UI colour themes: cyan, violet, ember, mint |
| **FONT- / FONT+** | Scale the code editor font |
| **TPL** | Load the next editable code template into the Structure Code editor |
| **SAVE** | Save the editor buffer to `output/babel-live-code.lisp` |

The **SCENE INSPECTOR** shows object metrics without the terminal: vertex count, edge count, macro count, colour mode, grid state, bounding box, camera distance, and whether the source code buffer is dirty.

The UI organization pass keeps the busy tools tucked away until needed: **HELP** opens a centered quick-map modal, and **EDITOR** / **F3** opens the Structure Code panel on the right side of the window. It is now a live editor, not a static viewer: it shows the same Lisp source that generates the 3D object currently visible in the main view. Click inside the editor to type, change the scene code, then press **F5** or click **APPLY** to rebuild the 3D object immediately. **RELOAD** discards local edits and reloads the source from the current view. You can select code with mouse drag, Shift+arrow keys, or **SELECT ALL**. **COPY** copies the selected code, or the full buffer when nothing is selected, to the real OS clipboard through SDL2. **Ctrl+X** cuts the selection to the OS clipboard. **PASTE** reads from the OS clipboard and replaces the selection or inserts clipboard text at the cursor. A small internal fallback clipboard is still used only if the desktop/SDL build blocks native clipboard access. **IMPORT** opens the operating-system file explorer/file picker so you can choose a Lisp/code file directly. If no picker helper is available, it falls back to `import.lisp` next to `run.sh`, `output/import.lisp`, and `code.lisp`. After importing, **HOT ON** watches that file and automatically reloads/applies changes while the app is running. If the code has a read/evaluation error, the old 3D view stays active and the editor shows the error message. The bottom status bar shows vertex count, edge count, macro count, FPS, the active scene, and action notifications.

### Mouse
| Input | Action |
|---|---|
| Click GUI buttons | Run scene, display, generation, save, and export actions |
| Left-drag outside GUI | Orbit camera |
| Right-drag outside GUI | Pan camera |
| Scroll outside editor | Zoom in / out |
| Scroll while editor is focused | Scroll source code |
| Drag inside editor | Select code |
| Shift-click / Shift+drag inside editor | Extend code selection |
| COPY button | Copy the selection, or the full source buffer, to the OS clipboard |
| PASTE button | Read from the OS clipboard and replace the selection or paste at the editor cursor |
| SELECT ALL button | Select the full source buffer |
| IMPORT button | Open the OS file explorer/file picker, load the selected source file into the editor, and start watching it |
| HOT ON / HOT OFF button | Toggle hot-reloading for the imported file |


### OS clipboard support

The code editor now uses SDL2's native clipboard API directly through CFFI. That means players can copy code from BABEL and paste it into external editors, browsers, or chat apps, and can copy Lisp code from the operating system clipboard and paste it back into BABEL. The same behavior works from the **COPY**/**PASTE** buttons and from keyboard shortcuts.

### Keyboard Shortcuts
The GUI replaces terminal-only control, but shortcuts remain available for speed:

| Key | Action |
|---|---|
| `F2` | Show / hide GUI |
| `F3` | Show / hide Structure Code editor |
| `F4` | Show / hide Scene Inspector |
| `F5` | Apply edited code and rebuild the 3D object |
| `F6` / `Ctrl+C` / `Cmd+C` | Copy the selection, or copy the full code editor buffer if nothing is selected, to the OS clipboard |
| `Ctrl+X` / `Cmd+X` | Cut the selected code to the OS clipboard |
| `F7` / `Ctrl+V` / `Cmd+V` / `Shift+Insert` | Paste text from the OS clipboard into the editor |
| `Ctrl+A` / `Cmd+A` | Select all code in the editor |
| `Shift+Arrow` / mouse drag | Select code |
| `F8` / `Ctrl+I` / `Cmd+I` | Open the OS file explorer/file picker and import a source file |
| `F9` | Toggle hot-reload for the imported file |
| `F10` | Cycle UI theme |
| `F11` | Fit camera to the current object |
| `Ctrl+S` / `Cmd+S` | Save the Structure Code buffer to `output/babel-live-code.lisp` |
| `Ctrl+Enter` / `Cmd+Enter` | Apply edited code from inside the editor |
| `H` | Toggle in-window help card |
| `R` | Reset camera |
| `I` `K` | Pan forward / back |
| `J` `L` | Pan left / right |
| `<-` `->` | Previous / next scene |
| `1`-`9` | Jump to scenes 0-8 |
| `0` | Scene 9 |
| `F1` | Scene 10 |
| `C` | Cycle colour mode |
| `X` | Toggle XYZ gizmo |
| `O` | Toggle ground rings |
| `G` | Grow next AI layer |
| `E` | Evolve top macros |
| `Z` | Undo last world change |
| `S` | Save macro library |
| `P` | Save world as .world file |
| `W` | Export OBJ (Blender) |
| `V` | Export 4-view SVG |
| `F12` | Screenshot |
| `ESC` | Quit, or unfocus the code editor when editing |

All output goes to `output/` next to `babel-world.asd`.

### Importing Code into the Live Editor

To use the GUI **IMPORT** button:

1. Create or choose any source file, for example by copying `examples/import-example.lisp` to a custom location.
2. Put a valid world program in it, usually wrapped in `(babel-eval ...)`, `(world ...)`, `(lambda () ...)`, or a raw list of shape forms.
3. Launch BABEL with `./run.sh`.
4. Open the Structure Code tab and click **IMPORT** or press `F8`.
5. Choose the file in the OS file explorer/file picker. Linux builds try `zenity`, `kdialog`, then `yad`; macOS uses AppleScript; Windows uses PowerShell/WinForms.
6. Click **APPLY** or press `F5` to compile the imported source into the visible 3D object.
7. Keep **HOT ON** enabled to hot-reload: editing/saving the same imported file in an external editor automatically reloads the buffer and applies it to the 3D view.

If no native file picker helper is available, IMPORT still falls back to `import.lisp`, `output/import.lisp`, and `code.lisp` so the app remains usable on minimal systems.

The import operation itself does not replace the visible object immediately. It first loads the source into the editor so you can review or edit it. The visible 3D object changes after **APPLY** succeeds, or automatically on later file saves when hot-reload is enabled. If hot-reload sees invalid Lisp, the old 3D object remains active and the error appears in the GUI.

---

## Layer-0 Primitives (quick reference)

```lisp
(box          x y z  w h d)
(sphere       x y z  r steps)
(half-dome    x y z  r steps)          ; hemisphere, flat base at y
(cylinder     x y z  r h steps)
(cone         x y z  r h steps)
(pyramid      x y z  base-w base-d height)
(torus        x y z  r tube steps)
(arch         x y z  span rise width style)   ; :roman or :gothic
(vault        x y z  span length steps)        ; barrel vault along +Z
(spire        x y z  height base-r sides)
(staircase    x y z  width n-steps step-h step-d)  ; rises along +Z
(wall-segment x0 z0  x1 z1  y-base height thickness)
(flying-buttress  wx wy wz  px py pz  thickness)
(plane        cx cz  w d  y)
(babel-line   x0 y0 z0  x1 y1 z1)
```

See [doc-ptbr/referencia/primitivas.md](primitivas.md) for full parameter descriptions.

---

## Vocabulary Layers

```
Layer 0:  box sphere half-dome cylinder pyramid cone torus arch vault
          spire staircase wall-segment flying-buttress plane babel-line
Layer 1:  tower dome colonnade terrain plateau
Layer 2:  battlement keep
Layer 3:  fortress
Layer 4:  walled-city
Layer 5:  citadel twin-cities monastery
Layer 6+: AI-invented
```

See [doc-ptbr/referencia/vocabulario.md](vocabulario.md) for signatures and patterns.

---

## Further Reading

| Document | Contents |
|---|---|
| [doc-ptbr/referencia/primitivas.md](primitivas.md) | Every Layer-0 function with full parameter docs |
| [doc-ptbr/referencia/vocabulario.md](vocabulario.md) | How to read, write, and extend the vocabulary |
| [doc-ptbr/referencia/sistema-de-ia.md](sistema-de-ia.md) | Invention engine, scoring formula, evolution |
| [doc-ptbr/referencia/mundos.md](mundos.md) | Writing world programs, patterns, examples |
| [doc-ptbr/referencia/persistencia.md](persistencia.md) | Saving/loading, export formats, output dir |
| [repl-tour.lisp](../../repl-tour.lisp) | Interactive step-by-step REPL walkthrough |

---

## License

MIT — Do whatever you like. Build vocabularies. Share them.


## Built-in editor upgrade

The in-window Structure Code editor now uses the bundled `src/font8x8.lisp` bitmap font as the system UI font.  The editor renders Lisp source with lightweight syntax highlighting for comments, strings, numbers, reader forms, keywords, parentheses, special forms, and BABEL geometry primitives.  The current line is softly highlighted and long source lines are clipped without inserting fake characters into the code view.  UI text drawing now routes through fitted/clipped text boxes, so sidebar labels, status text, help text, editor headers, selection blocks, and the cursor stay inside their panels even with the wider 8x8 font or very long scene/source names.

### UI text/button hotfix

This build snaps every bitmap-font glyph to whole screen pixels before drawing.  That avoids the broken/missing columns caused by fractional or sub-pixel 8x8 font scales on some OpenGL drivers.  Layout width, clipping, cursor, and selection math now use the same snapped scale as the renderer, so text should no longer visually spill or overlap.  Mouse hit boxes are also rebuilt from the current window size before every click/hover, and the **EDITOR** button now opens, loads, and focuses the editor immediately.

### UI hotfix: help card + editor button

- Restored the missing `ui-draw-code-tab-buttons` function so clicking **EDITOR** no longer crashes with `BABEL::UI-DRAW-CODE-TAB-BUTTONS is undefined`.
- Rebuilt the help card as a wider, shorter-line modal so the bundled 8x8 font does not clip phrases into fragments such as `QU..`.
- The help overlay now uses concise one-line controls for mouse, function keys, editor shortcuts, and layout.