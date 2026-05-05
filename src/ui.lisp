;;;; src/ui.lisp
;;;; In-window GUI system for BABEL.
;;;;
;;;; The UI is rendered directly into the existing SDL2/OpenGL window so the
;;;; program no longer depends on terminal-only HUD output for everyday use.
;;;; It provides clickable panels, buttons, status readouts, notifications, and
;;;; a help overlay while preserving the 3D wireframe renderer underneath.

(in-package #:babel)

;;; ─── UI state ────────────────────────────────────────────────────────────────

(defvar *ui-enabled* t
  "When true, draw and process the in-window GUI overlay.")

(defvar *ui-buttons* nil
  "Last frame's clickable button rectangles.")

(defvar *ui-hover-id* nil
  "ID of the button currently under the mouse, if any.")

(defvar *ui-mouse-captured* nil
  "True while the UI owns the current mouse press.")

(defvar *ui-message* "READY"
  "Short status text shown in the bottom notification bar.")

(defvar *ui-message-start* 0
  "Internal-real-time at which *UI-MESSAGE* was posted.")

(defvar *ui-show-help* nil
  "Show the on-screen help card. Starts collapsed so the main workspace opens cleanly.")

(defvar *ui-show-code* nil
  "Show the in-window Structure Code editor. Starts collapsed to keep the first-run UI uncluttered.")

(defvar *ui-code-scroll* 0
  "First visible line in the Structure Code editor.")

(defvar *ui-code-buffer* nil
  "Editable Lisp source for the structure shown in the Structure Code editor.")

(defvar *ui-code-cursor* 0
  "Cursor position inside *UI-CODE-BUFFER*.")

(defvar *ui-code-selection-anchor* nil
  "Selection anchor position in *UI-CODE-BUFFER*, or NIL when no selection exists.")

(defvar *ui-code-selection-dragging* nil
  "True while the mouse is dragging a text selection in the Structure Code editor.")

(defvar *ui-code-focused* nil
  "True when keyboard text input is routed to the Structure Code editor.")

(defvar *ui-code-dirty* nil
  "True when the editor buffer differs from the last applied/loaded source.")

(defvar *ui-code-last-scene* :uninitialized
  "Scene identifier that was last loaded into the editor buffer.")

(defvar *ui-code-status* "CLICK EDITOR | OS COPY/PASTE | F9 HOT"
  "Short status line for the Structure Code editor.")

(defvar *ui-code-clipboard-cache* ""
  "Fallback clipboard used when the SDL/native clipboard binding is unavailable.")

(defvar *ui-code-last-import-path* nil
  "Pathname most recently imported into the live Structure Code editor.")

(defvar *ui-code-last-import-write-date* nil
  "FILE-WRITE-DATE recorded for *UI-CODE-LAST-IMPORT-PATH* during import/hot-reload.")

(defvar *ui-hot-reload-enabled* t
  "When true, poll the imported file and apply changed source automatically.")

(defvar *ui-hot-reload-last-check* 0.0
  "Last UI time at which the import file was polled for hot-reload.")

(defparameter *ui-hot-reload-interval* 0.75
  "Seconds between hot-reload file timestamp checks.")

(defvar *ui-last-window* nil
  "Most recent SDL window object, used by screenshot actions.")

(defparameter *ui-left-panel-width* 268)
(defparameter *ui-code-panel-width* 528)
(defparameter *ui-margin* 14)
(defparameter *ui-button-height* 26)
(defparameter *ui-code-editor-scale* 1.0)
(defparameter *ui-code-line-height* 14)
(defparameter *ui-code-content-y-offset* 158)

(defparameter *ui-themes*
  '((:cyan   :panel (0.018 0.024 0.036) :panel2 (0.025 0.032 0.048)
             :accent (0.18 0.86 0.88) :accent2 (0.42 0.78 0.86)
             :hover (0.12 0.24 0.30) :active (0.05 0.34 0.38)
             :text (0.76 0.92 0.90) :muted (0.55 0.72 0.72))
    (:violet :panel (0.026 0.022 0.042) :panel2 (0.038 0.030 0.060)
             :accent (0.74 0.48 1.00) :accent2 (0.95 0.62 1.00)
             :hover (0.20 0.13 0.31) :active (0.32 0.13 0.46)
             :text (0.90 0.84 1.00) :muted (0.72 0.62 0.84))
    (:ember  :panel (0.042 0.026 0.018) :panel2 (0.060 0.036 0.025)
             :accent (1.00 0.55 0.22) :accent2 (0.98 0.72 0.38)
             :hover (0.30 0.16 0.08) :active (0.44 0.18 0.06)
             :text (1.00 0.88 0.74) :muted (0.82 0.64 0.48))
    (:mint   :panel (0.016 0.034 0.026) :panel2 (0.024 0.050 0.038)
             :accent (0.36 1.00 0.64) :accent2 (0.60 0.92 0.72)
             :hover (0.08 0.22 0.16) :active (0.08 0.36 0.22)
             :text (0.82 1.00 0.88) :muted (0.58 0.76 0.64)))
  "UI colour themes.  Kept small and data-driven so the GUI can be restyled live.")

(defvar *ui-theme* :cyan
  "Current GUI theme name.")

(defvar *ui-show-stats* t
  "Show the polished viewport statistics panel.")

(defparameter *ui-toolbar-button-ids*
  '(:fit-camera :view-iso :view-top :view-front :grid :wire
    :stats :theme :font-down :font-up :template :save-code)
  "IDs that belong to the top toolbar.")

(defparameter *ui-code-templates*
  `(("STARTER" . ,(format nil ";; Starter temple. Edit values and press F5/APPLY.~%~%(babel-eval~%  (plane 0.0 0.0 160.0 160.0 0.0)~%  (box 0.0 6.0 0.0 42.0 12.0 42.0)~%  (cylinder 0.0 18.0 0.0 18.0 24.0 32)~%  (sphere 0.0 36.0 0.0 14.0 18))~%"))
    ("TOWERS" . ,(format nil ";; Tower field template.~%~%(babel-eval~%  (plane 0.0 0.0 220.0 220.0 0.0)~%  (loop for x in '(-60 -20 20 60) do~%    (loop for z in '(-60 -20 20 60) do~%      (cylinder x 18.0 z 6.0 36.0 16)~%      (cone x 39.0 z 8.0 18.0 16))))~%"))
    ("ORBIT" . ,(format nil ";; Orbital ring study.~%~%(babel-eval~%  (torus 0.0 26.0 0.0 38.0 4.0 48)~%  (torus 0.0 26.0 0.0 64.0 2.0 64)~%  (sphere 0.0 26.0 0.0 16.0 24)~%  (loop for a from 0 below 360 by 30 do~%    (let* ((r 64.0)~%           (rad (* a (/ pi 180.0)))~%           (x (* r (cos rad)))~%           (z (* r (sin rad))))~%      (sphere x 26.0 z 5.0 10))))~%"))
    ("ARCHES" . ,(format nil ";; Repeating arch corridor.~%~%(babel-eval~%  (plane 0.0 0.0 180.0 220.0 0.0)~%  (loop for z from -80 to 80 by 20 do~%    (arch -22.0 0.0 z 22.0 32.0 5.0 :round)~%    (arch  22.0 0.0 z 22.0 32.0 5.0 :round)~%    (babel-line -22.0 32.0 z 22.0 32.0 z)))~%")))
  "Editable code templates that can be inserted from the top toolbar.")

(defvar *ui-code-template-index* 0
  "Index of the next template inserted by the TEMPLATE button.")

;;; ─── Time / messages ─────────────────────────────────────────────────────────

(defun ui-time-seconds ()
  (/ (float (get-internal-real-time) 1.0)
     internal-time-units-per-second))

(defun ui-message! (control-string &rest args)
  "Post a visible in-window notification.  This replaces terminal-only feedback."
  (setf *ui-message* (string-upcase (apply #'format nil control-string args))
        *ui-message-start* (ui-time-seconds)))

(defun ui-message-age ()
  (- (ui-time-seconds) *ui-message-start*))

(defun ui-current-theme-plist ()
  (or (cdr (assoc *ui-theme* *ui-themes*))
      (cdr (first *ui-themes*))))

(defun ui-theme-rgb (role)
  "Return theme RGB values for ROLE as multiple values."
  (destructuring-bind (r g b)
      (or (getf (ui-current-theme-plist) role)
          (getf (cdr (first *ui-themes*)) role)
          '(0.7 0.9 0.9))
    (values r g b)))

(defun ui-theme-name ()
  (string-upcase (symbol-name *ui-theme*)))

(defun ui-cycle-theme! ()
  "Cycle the GUI colour theme."
  (let* ((names (mapcar #'car *ui-themes*))
         (pos (position *ui-theme* names))
         (next (nth (mod (1+ (or pos 0)) (length names)) names)))
    (setf *ui-theme* next)
    (ui-message! "Theme: ~A" (ui-theme-name))
    next))

(defun ui-shadowed-rect (x y w h &optional (depth 4))
  "Draw a subtle dark drop shadow behind a panel."
  (ui-rect (+ x depth) (+ y depth) w h 0.0 0.0 0.0))

;;; ─── System 8x8 bitmap font ────────────────────────────────────────────────
;;; The project now uses src/font8x8.lisp as its only UI/editor font.  It is
;;; rendered directly as OpenGL quads, preserving the no-extra-font-library rule.

(defparameter *ui-font-step* 9
  "Horizontal advance, in source bitmap pixels, for the 8x8 UI font.")

(defun ui-glyph (ch)
  "Return the 8x8 bitmap glyph array for CH from the system font."
  (ui-font8x8-glyph ch))

(defun ui-font-render-scale (scale)
  "Return the integer pixel scale used for bitmap glyphs.
Fractional or sub-1.0 scales make OpenGL rasterize parts of 8x8 glyph pixels
away on many drivers, which looked like broken/overlapping text.  All UI text
therefore snaps to whole-pixel font sizes while layout uses the same snapped
scale for width/cursor math."
  (max 1 (round (or scale 1.0))))

(defun ui-font-char-step (scale)
  (* *ui-font-step* (ui-font-render-scale scale)))

(defun ui-font-pixel-height (scale)
  (* +ui-font-height+ (ui-font-render-scale scale)))

;;; ─── 2D drawing helpers ─────────────────────────────────────────────────────

(defvar *ui-2d-height* 0
  "Current 2D overlay height, used to convert top-left UI clips to OpenGL scissor rectangles.")

(defun ui-begin-2d (width height)
  (setf *ui-2d-height* height)
  (gl:viewport 0 0 width height)
  (gl:matrix-mode :projection)
  (gl:push-matrix)
  (gl:load-identity)
  (gl:ortho 0.0d0 (float width 1.0d0)
            (float height 1.0d0) 0.0d0
            -1.0d0 1.0d0)
  (gl:matrix-mode :modelview)
  (gl:push-matrix)
  (gl:load-identity)
  (gl:disable :depth-test))

(defun ui-end-2d ()
  (gl:enable :depth-test)
  (gl:matrix-mode :modelview)
  (gl:pop-matrix)
  (gl:matrix-mode :projection)
  (gl:pop-matrix)
  (gl:matrix-mode :modelview))

(defun ui-rect (x y w h r g b)
  (gl:color r g b)
  (gl:begin :quads)
  (gl:vertex (float x 1.0) (float y 1.0) 0.0)
  (gl:vertex (float (+ x w) 1.0) (float y 1.0) 0.0)
  (gl:vertex (float (+ x w) 1.0) (float (+ y h) 1.0) 0.0)
  (gl:vertex (float x 1.0) (float (+ y h) 1.0) 0.0)
  (gl:end))

(defun ui-outline (x y w h r g b &optional (line-width 1.0))
  (gl:line-width line-width)
  (gl:color r g b)
  (gl:begin :line-loop)
  (gl:vertex (float x 1.0) (float y 1.0) 0.0)
  (gl:vertex (float (+ x w) 1.0) (float y 1.0) 0.0)
  (gl:vertex (float (+ x w) 1.0) (float (+ y h) 1.0) 0.0)
  (gl:vertex (float x 1.0) (float (+ y h) 1.0) 0.0)
  (gl:end)
  (gl:line-width 1.0))

(defun ui-line (x1 y1 x2 y2 r g b &optional (line-width 1.0))
  (gl:line-width line-width)
  (gl:color r g b)
  (gl:begin :lines)
  (gl:vertex (float x1 1.0) (float y1 1.0) 0.0)
  (gl:vertex (float x2 1.0) (float y2 1.0) 0.0)
  (gl:end)
  (gl:line-width 1.0))

(defun ui-text-width (text scale)
  (* (length (or text "")) (ui-font-char-step scale)))

(defun ui-fit-text (text max-width scale)
  "Return TEXT shortened to fit MAX-WIDTH pixels at SCALE.
Uses two dots instead of a Unicode ellipsis because the built-in bitmap font is ASCII-only."
  (let* ((s (format nil "~A" (or text "")))
         (max-chars (max 0 (floor (/ (max 0 max-width) (ui-font-char-step scale))))))
    (cond
      ((<= (length s) max-chars) s)
      ((<= max-chars 0) "")
      ((<= max-chars 2) (subseq s 0 max-chars))
      (t (concatenate 'string (subseq s 0 (- max-chars 2)) "..")))))

(defun ui-text (text x y &key (scale 2.0) (r 0.74) (g 0.95) (b 0.92))
  "Draw text with the bundled 8x8 bitmap font.
The draw position and glyph scale are snapped to integer pixels so small labels
do not lose columns/rows or visually overlap on different OpenGL drivers."
  (let* ((draw-scale (ui-font-render-scale scale))
         (base-x (round x))
         (base-y (round y))
         (step (ui-font-char-step scale)))
    (gl:color r g b)
    (loop for ch across (format nil "~A" (or text ""))
          for cx from base-x by step do
      (loop for row from 0 below +ui-font-height+ do
        (loop for col from 0 below +ui-font-width+ do
          (when (= 1 (ui-font-pixel ch col row))
            (ui-rect (+ cx (* col draw-scale))
                     (+ base-y (* row draw-scale))
                     draw-scale draw-scale r g b)))))))

(defmacro ui-with-clip ((x y w h) &body body)
  "Clip subsequent immediate-mode 2D drawing to the UI rectangle X/Y/W/H.
Coordinates use the UI's top-left origin; OpenGL scissor uses bottom-left."
  `(let* ((clip-x (round ,x))
          (clip-y (round (- *ui-2d-height* (+ ,y ,h))))
          (clip-w (round ,w))
          (clip-h (round ,h)))
     (when (and (> clip-w 0) (> clip-h 0))
       (gl:enable :scissor-test)
       (gl:scissor clip-x clip-y clip-w clip-h)
       (unwind-protect
            (progn ,@body)
         (gl:disable :scissor-test)))))

(defun ui-text-box (text x y max-width
                    &key (scale 2.0) (r 0.74) (g 0.95) (b 0.92)
                         (pad 0))
  "Draw one line of text that is always fitted and clipped to MAX-WIDTH."
  (let* ((safe-width (max 0 (- max-width (* 2 pad))))
         (fitted (ui-fit-text text safe-width scale))
         (tx (+ x pad))
         (ty y)
         (clip-h (+ 3 (ui-font-pixel-height scale))))
    (ui-with-clip (x (- y 1) max-width clip-h)
      (ui-text fitted tx ty :scale scale :r r :g g :b b))))

(defun ui-centered-text (text x y w h &key (scale 2.0) (r 0.82) (g 0.95) (b 0.94))
  (let* ((fitted (ui-fit-text text (- w 8) scale))
         (tx (+ x (/ (- w (ui-text-width fitted scale)) 2.0)))
         (ty (+ y (/ (- h (ui-font-pixel-height scale)) 2.0))))
    (ui-with-clip (x y w h)
      (ui-text fitted tx ty :scale scale :r r :g g :b b))))

(defun ui-section-title (text x y &optional (max-width 210))
  (multiple-value-bind (ar ag ab) (ui-theme-rgb :accent2)
    (ui-text-box text x y max-width :scale 1.35 :r ar :g ag :b ab)
    (ui-line x (+ y 13) (+ x max-width) (+ y 13) ar ag ab 1.0)))

;;; ─── Structure Code editor model ────────────────────────────────────────────

(defun ui-lines-from-string (text)
  (let ((lines '()))
    (with-input-from-string (in (or text ""))
      (loop for line = (read-line in nil nil)
            while line do
              (push (substitute #\space #\Tab line) lines)))
    (if lines (nreverse lines) (list ""))))

(defun ui-code-tab-rect (&optional (width *window-width*) (height *window-height*))
  "Return the right-side editor rectangle as X Y W H values.
The editor anchors to the right on large windows, but stays inside the main workspace on smaller ones."
  (let* ((main-left (+ *ui-margin* *ui-left-panel-width* 20))
         (preferred-w *ui-code-panel-width*)
         (x (if (>= width (+ main-left preferred-w *ui-margin*))
                (- width preferred-w *ui-margin*)
                main-left))
         (y 264)
         (w (max 280 (- width x *ui-margin*)))
         (h (max 170 (- height y 70))))
    (values x y w h)))

(defun ui-point-in-code-panel-p (x y)
  (multiple-value-bind (px py pw ph) (ui-code-tab-rect)
    (and *ui-enabled* *ui-show-code*
         (>= x px) (< x (+ px pw))
         (>= y py) (< y (+ py ph)))))

(defun ui-sdl2-call-if-present (name &rest args)
  "Call an SDL2 helper only when the binding exists in the installed CL-SDL2."
  (multiple-value-bind (sym status) (find-symbol name :sdl2)
    (declare (ignore status))
    (when (and sym (fboundp sym))
      (ignore-errors (apply sym args)))))

(defun ui-start-text-input! ()
  (ui-sdl2-call-if-present "START-TEXT-INPUT"))

(defun ui-stop-text-input! ()
  (ui-sdl2-call-if-present "STOP-TEXT-INPUT"))

(defun ui-set-code-focus! (focused)
  (setf *ui-code-focused* focused)
  (if focused
      (progn
        (ui-start-text-input!)
        (setf *ui-code-status* "EDITING | CTRL/CMD+C/V USE OS CLIPBOARD | F5 APPLY"))
      (progn
        (ui-stop-text-input!)
        (setf *ui-code-status* "CLICK EDITOR | OS COPY/PASTE | F9 HOT"))))

(defun ui-custom-world-code-string ()
  (with-output-to-string (out)
    (format out ";; Custom structure generated from the live editor or BABEL-EVAL~%")
    (format out ";; Edit the forms below and press F5 or APPLY. The 3D object updates immediately.~%~%")
    (format out "(babel-eval~%")
    (dolist (form *current-world-source*)
      (let ((*print-case* :downcase)
            (*print-pretty* t)
            (*print-level* nil)
            (*print-length* nil))
        (pprint form out)))
    (format out "~%)")))

(defun ui-current-code-string ()
  "Return the Lisp source that corresponds to the structure currently shown."
  (cond
    ((and (= *current-scene* -1) *current-world-source*)
     (ui-custom-world-code-string))
    ((and (fboundp 'scene-code-snippet)
          (scene-code-snippet *current-scene*))
     (scene-code-snippet *current-scene*))
    (t
     (format nil ";; Live generated geometry snapshot~%;; No source form is available for this structure.~%~%(:scene ~S~% :vertices ~D~% :edges ~D~% :macros ~D)"
             (ui-scene-name)
             (length *cached-verts*)
             (length *cached-edges*)
             (hash-table-count *babel-registry*)))))

(defun ui-load-code-for-current-scene! (&key force)
  "Synchronize the editor buffer with the active scene/custom world source."
  (let ((scene-key (if (= *current-scene* -1)
                       (list :custom *current-world-source*)
                       *current-scene*)))
    (when (or force
              (null *ui-code-buffer*)
              (and (not *ui-code-dirty*)
                   (not (equal scene-key *ui-code-last-scene*))))
      (setf *ui-code-buffer* (ui-current-code-string)
            *ui-code-cursor* 0
            *ui-code-scroll* 0
            *ui-code-selection-anchor* nil
            *ui-code-selection-dragging* nil
            *ui-code-dirty* nil
            *ui-code-last-scene* scene-key
            *ui-code-status* "SOURCE MATCHES VIEW | EDIT + APPLY"))))

(defun ui-code-clamp-cursor! ()
  (setf *ui-code-cursor*
        (min (max 0 *ui-code-cursor*)
             (length (or *ui-code-buffer* "")))))

(defun ui-code-selection-bounds ()
  "Return START END ACTIVE-P for the current editor selection."
  (ui-code-clamp-cursor!)
  (if (and *ui-code-selection-anchor*
           (/= *ui-code-selection-anchor* *ui-code-cursor*))
      (let ((a (min (max 0 *ui-code-selection-anchor*)
                    (length (or *ui-code-buffer* ""))))
            (b *ui-code-cursor*))
        (values (min a b) (max a b) t))
      (values *ui-code-cursor* *ui-code-cursor* nil)))

(defun ui-code-has-selection-p ()
  (multiple-value-bind (_start _end active) (ui-code-selection-bounds)
    (declare (ignore _start _end))
    active))

(defun ui-code-clear-selection! ()
  (setf *ui-code-selection-anchor* nil
        *ui-code-selection-dragging* nil))

(defun ui-code-set-cursor! (position &key extend-selection)
  "Move the editor cursor. When EXTEND-SELECTION is true, keep/create a selection anchor."
  (let* ((text (or *ui-code-buffer* ""))
         (position (min (max 0 position) (length text))))
    (if extend-selection
        (unless *ui-code-selection-anchor*
          (setf *ui-code-selection-anchor* *ui-code-cursor*))
        (setf *ui-code-selection-anchor* nil))
    (setf *ui-code-cursor* position)
    (ui-code-clamp-cursor!)))

(defun ui-code-selected-text ()
  (multiple-value-bind (start end active) (ui-code-selection-bounds)
    (if active
        (subseq (or *ui-code-buffer* "") start end)
        "")))

(defun ui-code-select-all! ()
  (when (null *ui-code-buffer*)
    (ui-load-code-for-current-scene!))
  (setf *ui-code-selection-anchor* 0
        *ui-code-cursor* (length (or *ui-code-buffer* ""))
        *ui-code-status* "SELECTED ALL | COPY/CUT/TYPE TO REPLACE")
  (ui-message! "Selected all code")
  t)

(defun ui-code-delete-selection! ()
  "Delete the active selection. Return true when text was removed."
  (multiple-value-bind (start end active) (ui-code-selection-bounds)
    (when active
      (ui-code-delete-range! start end)
      (ui-code-clear-selection!)
      t)))

(defun ui-code-line-starts ()
  (let ((starts (list 0))
        (text (or *ui-code-buffer* "")))
    (loop for i from 0 below (length text) do
      (when (char= (char text i) #\Newline)
        (push (1+ i) starts)))
    (nreverse starts)))

(defun ui-code-cursor-line-col ()
  (ui-code-clamp-cursor!)
  (let* ((starts (ui-code-line-starts))
         (line 0)
         (cursor *ui-code-cursor*))
    (loop for s in starts
          for i from 0
          while (<= s cursor) do
            (setf line i))
    (values line (- cursor (nth line starts)))))

(defun ui-code-line-length (line-index)
  (let* ((lines (ui-lines-from-string *ui-code-buffer*)))
    (if (and (>= line-index 0) (< line-index (length lines)))
        (length (nth line-index lines))
        0)))

(defun ui-code-index-from-line-col (line col)
  (let* ((starts (ui-code-line-starts))
         (line (min (max 0 line) (1- (length starts))))
         (start (nth line starts))
         (len (ui-code-line-length line)))
    (min (+ start (min (max 0 col) len))
         (length (or *ui-code-buffer* "")))))

(defun ui-code-move-cursor-line (delta &key extend-selection)
  (multiple-value-bind (line col) (ui-code-cursor-line-col)
    (let* ((lines (ui-lines-from-string *ui-code-buffer*))
           (new-line (min (max 0 (+ line delta)) (1- (length lines)))))
      (ui-code-set-cursor! (ui-code-index-from-line-col new-line col)
                           :extend-selection extend-selection)
      (cond
        ((< new-line *ui-code-scroll*)
         (setf *ui-code-scroll* new-line))
        ((> new-line (+ *ui-code-scroll* 20))
         (setf *ui-code-scroll* (max 0 (- new-line 20))))))))

(defun ui-code-insert-text! (text)
  (when text
    (ui-code-clamp-cursor!)
    (let ((clean (remove-if (lambda (ch)
                              (or (char= ch #\Return)
                                  (and (< (char-code ch) 32)
                                       (not (char= ch #\Newline)))))
                            text)))
      (when (> (length clean) 0)
        (ui-code-delete-selection!)
        (setf *ui-code-buffer*
              (concatenate 'string
                           (subseq *ui-code-buffer* 0 *ui-code-cursor*)
                           clean
                           (subseq *ui-code-buffer* *ui-code-cursor*)))
        (incf *ui-code-cursor* (length clean))
        (ui-code-clear-selection!)
        (setf *ui-code-dirty* t
              *ui-code-status* "MODIFIED | F5/APPLY TO UPDATE 3D VIEW")))))

(defun ui-code-delete-range! (start end)
  (let* ((text (or *ui-code-buffer* ""))
         (start (min (max 0 start) (length text)))
         (end (min (max start end) (length text))))
    (when (< start end)
      (setf *ui-code-buffer* (concatenate 'string
                                          (subseq text 0 start)
                                          (subseq text end))
            *ui-code-cursor* start
            *ui-code-selection-anchor* nil
            *ui-code-selection-dragging* nil
            *ui-code-dirty* t
            *ui-code-status* "MODIFIED | F5/APPLY TO UPDATE 3D VIEW"))))

(defun ui-key-mod-state ()
  "Best-effort SDL key modifier lookup. Returns 0 when unavailable."
  (or (ui-sdl2-call-if-present "GET-MOD-STATE")
      (ui-sdl2-call-if-present "GET-KEY-MOD-STATE")
      0))

(defun ui-control-down-p ()
  "Return true when Ctrl is currently held, when the SDL binding exposes it."
  (let ((mod (ui-key-mod-state)))
    (cond
      ;; SDL KMOD_LCTRL = #x0040, KMOD_RCTRL = #x0080.
      ((integerp mod) (not (zerop (logand mod #x00c0))))
      ((listp mod)
       (some (lambda (entry)
               (member entry '(:ctrl :control :lctrl :rctrl :left-ctrl :right-ctrl
                                :mod-ctrl :kmod-ctrl :kmod-lctrl :kmod-rctrl)
                       :test #'eq))
             mod))
      ((keywordp mod)
       (member mod '(:ctrl :control :lctrl :rctrl :left-ctrl :right-ctrl
                     :mod-ctrl :kmod-ctrl :kmod-lctrl :kmod-rctrl)
               :test #'eq))
      (t nil))))

(defun ui-command-down-p ()
  "Return true when the OS command/super key is held, useful for macOS Cmd shortcuts."
  (let ((mod (ui-key-mod-state)))
    (cond
      ;; SDL KMOD_LGUI = #x0400, KMOD_RGUI = #x0800.
      ((integerp mod) (not (zerop (logand mod #x0c00))))
      ((listp mod)
       (some (lambda (entry)
               (member entry '(:gui :super :meta :command :cmd :lgui :rgui
                                :left-gui :right-gui :left-super :right-super
                                :mod-gui :kmod-gui :kmod-lgui :kmod-rgui)
                       :test #'eq))
             mod))
      ((keywordp mod)
       (member mod '(:gui :super :meta :command :cmd :lgui :rgui
                     :left-gui :right-gui :left-super :right-super
                     :mod-gui :kmod-gui :kmod-lgui :kmod-rgui)
               :test #'eq))
      (t nil))))

(defun ui-shortcut-down-p ()
  "Return true for the platform shortcut modifier: Ctrl on Linux/Windows, Cmd on macOS."
  (or (ui-control-down-p)
      (ui-command-down-p)))

(defun ui-shift-down-p ()
  "Return true when Shift is currently held, when the SDL binding exposes it."
  (let ((mod (ui-key-mod-state)))
    (cond
      ;; SDL KMOD_LSHIFT = #x01, KMOD_RSHIFT = #x02.
      ((integerp mod) (not (zerop (logand mod #x0003))))
      ((listp mod)
       (some (lambda (entry)
               (member entry '(:shift :lshift :rshift :left-shift :right-shift
                                :mod-shift :kmod-shift :kmod-lshift :kmod-rshift)
                       :test #'eq))
             mod))
      ((keywordp mod)
       (member mod '(:shift :lshift :rshift :left-shift :right-shift
                     :mod-shift :kmod-shift :kmod-lshift :kmod-rshift)
               :test #'eq))
      (t nil))))

(defun ui-cffi-clipboard-get ()
  "Read UTF-8 text from the OS clipboard through SDL2's C API.
Returns two values: TEXT and NATIVE-P.  SDL owns the OS integration and works on
Linux/X11/Wayland, Windows, and macOS when the windowing backend supports it."
  (handler-case
      (let ((ptr (cffi:foreign-funcall "SDL_GetClipboardText" :pointer)))
        (if (cffi:null-pointer-p ptr)
            (values nil nil)
            (unwind-protect
                 (values (cffi:foreign-string-to-lisp ptr :encoding :utf-8) t)
              (ignore-errors
                (cffi:foreign-funcall "SDL_free" :pointer ptr :void)))))
    (error ()
      (values nil nil))))

(defun ui-cffi-clipboard-set (text)
  "Write UTF-8 TEXT to the OS clipboard through SDL2's C API."
  (handler-case
      (zerop (cffi:foreign-funcall "SDL_SetClipboardText"
                                   :string (or text "")
                                   :int))
    (error () nil)))

(defun ui-sdl-clipboard-get ()
  "Read text from the real OS clipboard.
Uses direct SDL2/CFFI access first, then falls back to any CL-SDL2 helper that
may exist in the user's installed binding.  Returns two values: TEXT and
NATIVE-P."
  (multiple-value-bind (text native-p) (ui-cffi-clipboard-get)
    (if native-p
        (values text t)
        (let ((helper-text (or (ui-sdl2-call-if-present "GET-CLIPBOARD-TEXT")
                               (ui-sdl2-call-if-present "CLIPBOARD-TEXT"))))
          (if helper-text
              (values helper-text t)
              (values nil nil))))))

(defun ui-sdl-clipboard-set (text)
  "Write text to the real OS clipboard.
Returns true on native success.  The caller may still keep an in-app fallback
copy for restricted SDL builds or sandboxed environments."
  (or (ui-cffi-clipboard-set text)
      (not (null (or (ui-sdl2-call-if-present "SET-CLIPBOARD-TEXT" text)
                     (ui-sdl2-call-if-present "SET-CLIPBOARD" text))))))

(defun ui-code-copy! ()
  "Copy the selected code, or the complete editor buffer when nothing is selected."
  (when (null *ui-code-buffer*)
    (ui-load-code-for-current-scene!))
  (let* ((selected (ui-code-selected-text))
         (using-selection (> (length selected) 0))
         (text (if using-selection selected (or *ui-code-buffer* "")))
         (native-ok (ui-sdl-clipboard-set text)))
    ;; Always keep a local cache too, so copy/paste still works in unusual SDL
    ;; builds or sandboxed desktops where the OS clipboard is blocked.
    (setf *ui-code-clipboard-cache* text)
    (setf *ui-code-status*
          (cond
            ((and using-selection native-ok)
             "COPIED SELECTION TO OS CLIPBOARD")
            (native-ok
             "COPIED FULL BUFFER TO OS CLIPBOARD")
            (using-selection
             "COPIED SELECTION TO INTERNAL FALLBACK")
            (t
             "COPIED FULL BUFFER TO INTERNAL FALLBACK")))
    (ui-message! "Copied ~D chars ~A" (length text)
                 (if native-ok "to OS clipboard" "to fallback clipboard"))
    text))

(defun ui-code-cut! ()
  "Cut the selected code to the clipboard."
  (if (ui-code-has-selection-p)
      (let ((text (ui-code-copy!)))
        (ui-code-delete-selection!)
        (setf *ui-code-status* "CUT SELECTION | F5/APPLY TO UPDATE 3D VIEW")
        (ui-message! "Cut ~D chars" (length text))
        text)
      (progn
        (setf *ui-code-status* "CUT NEEDS A SELECTION")
        (ui-message! "Select code first")
        nil)))

(defun ui-code-paste! ()
  "Paste text from the OS clipboard, falling back to the last in-app copy."
  (ui-load-code-for-current-scene!)
  (multiple-value-bind (native native-p) (ui-sdl-clipboard-get)
    (let* ((native-has-text (and native-p native (> (length native) 0)))
           (fallback-has-text (and *ui-code-clipboard-cache*
                                   (> (length *ui-code-clipboard-cache*) 0)))
           (text (cond
                   (native-has-text native)
                   (fallback-has-text *ui-code-clipboard-cache*)
                   (t "")))
           (source (if native-has-text "OS clipboard" "fallback clipboard")))
      (if (> (length text) 0)
          (progn
            (ui-code-insert-text! text)
            (setf *ui-code-status*
                  (if native-has-text
                      "PASTED FROM OS CLIPBOARD | F5/APPLY TO UPDATE"
                      "PASTED FROM FALLBACK | F5/APPLY TO UPDATE"))
            (ui-message! "Pasted ~D chars from ~A" (length text) source)
            t)
          (progn
            (setf *ui-code-status* "PASTE FAILED | OS CLIPBOARD EMPTY")
            (ui-message! "OS clipboard is empty")
            nil)))))

(defun ui-read-file-into-string (path)
  (with-open-file (in path :direction :input :external-format :utf-8)
    (with-output-to-string (out)
      (loop for line = (read-line in nil nil)
            while line do
              (write-string line out)
              (terpri out)))))

(defun ui-trim-dialog-output (text)
  "Trim the text returned by external file picker commands."
  (and text
       (let ((trimmed (string-trim '(#\Space #\Tab #\Newline #\Return #\Page #\Rubout) text)))
         (unless (zerop (length trimmed))
           trimmed))))

(defun ui-run-file-dialog-command (program args)
  "Run an external file chooser command and return the selected path string.
This is intentionally best-effort so the GUI still works on minimal systems."
  (handler-case
      (ui-trim-dialog-output
       (uiop:run-program (cons program args)
                         :output :string
                         :error-output nil
                         :ignore-error-status t))
    (error () nil)))

(defun ui-command-available-p (program)
  "Return true when PROGRAM can be found on PATH.

Avoid UIOP:FIND-EXECUTABLE because older Quicklisp/UIOP versions do not export
that symbol.  COMMAND -V is available through /bin/sh on the Unix-like systems
where this helper is used for Linux desktop file pickers."
  (not
   (null
    (handler-case
        (ui-trim-dialog-output
         (uiop:run-program
          (list "sh" "-lc" (format nil "command -v ~A 2>/dev/null" program))
          :output :string
          :error-output nil
          :ignore-error-status t))
      (error () nil)))))

(defun ui-linux-file-dialog-path ()
  "Open a Linux file chooser with common desktop helpers.
Only the first installed helper is launched, so pressing Cancel does not cascade
through multiple dialog applications."
  (cond
    ((ui-command-available-p "zenity")
     (ui-run-file-dialog-command
      "zenity"
      '("--file-selection"
        "--title=Import Babel Lisp Code"
        "--file-filter=Lisp files | *.lisp *.cl *.txt"
        "--file-filter=All files | *")))
    ((ui-command-available-p "kdialog")
     (ui-run-file-dialog-command
      "kdialog"
      '("--title" "Import Babel Lisp Code"
        "--getopenfilename" "."
        "*.lisp *.cl *.txt|Lisp/code files")))
    ((ui-command-available-p "yad")
     (ui-run-file-dialog-command
      "yad"
      '("--file"
        "--title=Import Babel Lisp Code"
        "--file-filter=Lisp files | *.lisp *.cl *.txt"
        "--file-filter=All files | *")))
    (t nil)))

(defun ui-macos-file-dialog-path ()
  "Open the native macOS file picker through AppleScript."
  (ui-run-file-dialog-command
   "osascript"
   '("-e"
     "POSIX path of (choose file with prompt \"Import Babel Lisp Code\")")))

(defun ui-windows-file-dialog-path ()
  "Open the native Windows file picker through PowerShell/WinForms."
  (ui-run-file-dialog-command
   "powershell"
   '("-NoProfile" "-STA" "-Command"
     "Add-Type -AssemblyName System.Windows.Forms; $d = New-Object System.Windows.Forms.OpenFileDialog; $d.Title = 'Import Babel Lisp Code'; $d.Filter = 'Lisp files (*.lisp;*.cl;*.txt)|*.lisp;*.cl;*.txt|All files (*.*)|*.*'; if ($d.ShowDialog() -eq 'OK') { $d.FileName }")))

(defun ui-open-import-file-dialog ()
  "Open the host OS file picker and return a pathname, or NIL when cancelled."
  (let ((path-string
          (cond
            ((member :darwin *features*) (ui-macos-file-dialog-path))
            ((or (member :win32 *features*)
                 (member :windows *features*)
                 (member :mswindows *features*))
             (ui-windows-file-dialog-path))
            ((or (member :linux *features*)
                 (member :unix *features*))
             (ui-linux-file-dialog-path))
            (t nil))))
    (when path-string
      (let ((path (ignore-errors (pathname path-string))))
        (and path (probe-file path))))))

(defun ui-project-root-import-path ()
  "Best-effort import.lisp path next to the project root/output directory."
  (when *output-dir*
    (let* ((out-dir (pathname-directory *output-dir*)))
      (when (and (consp out-dir) (string= (car (last out-dir)) "output"))
        (make-pathname :directory (butlast out-dir)
                       :name "import" :type "lisp")))))

(defun ui-import-code-candidates ()
  "Paths searched by the IMPORT button, in priority order."
  (remove nil
          (list (merge-pathnames "import.lisp" *default-pathname-defaults*)
                (ui-project-root-import-path)
                (and *output-dir* (babel-out "import.lisp"))
                (and *output-dir* (merge-pathnames "../import.lisp" *output-dir*))
                (merge-pathnames "code.lisp" *default-pathname-defaults*)
                (and *output-dir* (babel-out "code.lisp")))))

(defun ui-import-code! ()
  "Open the OS file picker and import Lisp source into the live editor buffer.

When no native picker helper is available, fall back to import.lisp/code.lisp in
the project/output directories.  The imported source is loaded into the editor
first; press APPLY/F5 when you want to rebuild the visible 3D object."
  (let* ((dialog-path (ui-open-import-file-dialog))
         (path (or dialog-path
                   (find-if #'probe-file (ui-import-code-candidates)))))
    (if path
        (handler-case
            (let ((text (ui-read-file-into-string path)))
              (setf *ui-code-buffer* text
                    *ui-code-cursor* (length text)
                    *ui-code-scroll* 0
                    *ui-code-selection-anchor* nil
                    *ui-code-selection-dragging* nil
                    *ui-code-dirty* t
                    *ui-code-last-scene* (list :import (namestring path))
                    *ui-code-last-import-path* path
                    *ui-code-last-import-write-date* (ignore-errors (file-write-date path))
                    *ui-code-status* (if dialog-path
                                         "IMPORTED FROM FILE EXPLORER | APPLY TO VIEW"
                                         "IMPORTED FALLBACK FILE | APPLY TO VIEW"))
              (ui-set-code-focus! t)
              (ui-message! "Imported code: ~A" (namestring path))
              text)
          (error (e)
            (setf *ui-code-status* (format nil "IMPORT ERROR: ~A" e))
            (ui-message! "Import error: ~A" e)
            nil))
        (progn
          (setf *ui-code-status* "IMPORT CANCELLED OR NO FILE PICKER AVAILABLE")
          (ui-message! "Import cancelled; fallback files not found")
          nil))))

(defun ui-hot-reload-toggle! ()
  (setf *ui-hot-reload-enabled* (not *ui-hot-reload-enabled*))
  (setf *ui-code-status* (if *ui-hot-reload-enabled*
                             "HOT-RELOAD ON | WATCHING IMPORT FILE"
                             "HOT-RELOAD OFF"))
  (ui-message! "Hot-reload ~A" (if *ui-hot-reload-enabled* "on" "off"))
  *ui-hot-reload-enabled*)

(defun ui-file-write-date-safe (path)
  (when path
    (ignore-errors
      (let ((real (probe-file path)))
        (and real (file-write-date real))))))

(defun ui-hot-reload-check! ()
  "Poll the imported source file. When it changes, reload it and apply to the 3D view."
  (let ((now (ui-time-seconds)))
    (when (and *ui-hot-reload-enabled*
               *ui-code-last-import-path*
               (> (- now *ui-hot-reload-last-check*) *ui-hot-reload-interval*))
      (setf *ui-hot-reload-last-check* now)
      (let ((write-date (ui-file-write-date-safe *ui-code-last-import-path*)))
        (when (and write-date
                   *ui-code-last-import-write-date*
                   (> write-date *ui-code-last-import-write-date*))
          (handler-case
              (let* ((path *ui-code-last-import-path*)
                     (text (ui-read-file-into-string path)))
                (setf *ui-code-buffer* text
                      *ui-code-cursor* (min *ui-code-cursor* (length text))
                      *ui-code-scroll* 0
                      *ui-code-selection-anchor* nil
                      *ui-code-selection-dragging* nil
                      *ui-code-dirty* t
                      *ui-code-last-scene* (list :import (namestring path))
                      *ui-code-last-import-write-date* write-date
                      *ui-code-status* "HOT-RELOADED FILE | APPLYING TO 3D VIEW")
                (ui-message! "Hot-reloaded ~A" (file-namestring path))
                (ui-apply-code-editor!)
                ;; Preserve the file watcher after APPLY changes the scene key to :CUSTOM.
                (setf *ui-code-last-import-path* path
                      *ui-code-last-import-write-date* write-date))
            (error (e)
              (setf *ui-code-status* (format nil "HOT-RELOAD ERROR: ~A" e))
              (ui-message! "Hot-reload error: ~A" e))))))))

(defun ui-code-read-all-forms (source)
  (let ((*package* (find-package :babel))
        (forms '()))
    (with-input-from-string (in source)
      (loop for form = (read in nil :eof)
            until (eq form :eof) do
              (push form forms)))
    (nreverse forms)))

(defun ui-normalized-world-body (forms)
  "Convert editor input into body forms that actually emit the visible 3D geometry."
  (let ((first-form (first forms)))
    (cond
      ((null forms)
       (error "Editor is empty."))
      ;; (babel-eval ...)
      ((and (= (length forms) 1)
            (consp first-form)
            (eq (first first-form) 'babel-eval))
       (rest first-form))
      ;; (world (:seed ...) ...)
      ((and (= (length forms) 1)
            (consp first-form)
            (eq (first first-form) 'world))
       (list first-form))
      ;; (lambda () ...)
      ((and (= (length forms) 1)
            (consp first-form)
            (eq (first first-form) 'lambda))
       (cddr first-form))
      ;; (cons "Scene name" (lambda () ...)) — current built-in scene snippets use this form.
      ((and (= (length forms) 1)
            (consp first-form)
            (eq (first first-form) 'cons)
            (consp (third first-form))
            (eq (first (third first-form)) 'lambda))
       (cddr (third first-form)))
      ;; Raw body: several shape/world forms.
      (t forms))))

(defun ui-apply-code-editor! ()
  "Compile the editor buffer and install it as the live 3D world."
  (when (null *ui-code-buffer*)
    (ui-load-code-for-current-scene!))
  (handler-case
      (let* ((source *ui-code-buffer*)
             (forms (ui-code-read-all-forms source))
             (body  (ui-normalized-world-body forms))
             (rewritten (if (fboundp 'babel-rewrite-forms)
                            (babel-rewrite-forms body)
                            body))
             (fn (compile nil `(lambda () ,@rewritten))))
        ;; Run once before installing so syntax/runtime errors do not destroy the old view.
        (let ((*vertex-buffer* nil)
              (*edge-buffer* nil))
          (funcall fn))
        (setf *current-world-source* body)
        (run-world fn)
        ;; RUN-WORLD synchronizes REPL-created worlds into the editor. For editor-created
        ;; worlds, preserve the exact text the user applied, including comments/formatting.
        (setf *ui-code-buffer* source
              *ui-code-cursor* (min *ui-code-cursor* (length source))
              *ui-code-dirty* nil
              *ui-code-last-scene* (list :custom *current-world-source*)
              *ui-code-status* "APPLIED | 3D VIEW UPDATED")
        (ui-message! "Code applied to 3D view"))
    (error (e)
      (setf *ui-code-status* (format nil "ERROR: ~A" e))
      (ui-message! "Code error: ~A" e))))

(defun ui-code-index-at-point (x y)
  (multiple-value-bind (px py pw ph) (ui-code-tab-rect)
    (declare (ignore pw ph))
    (let* ((scale *ui-code-editor-scale*)
           (line-h *ui-code-line-height*)
           (content-x (+ px 58))
           (content-y (+ py *ui-code-content-y-offset*))
           (line (max 0 (+ *ui-code-scroll* (floor (- y content-y) line-h))))
           (col  (max 0 (round (/ (- x content-x) (ui-font-char-step scale))))))
      (ui-code-index-from-line-col line col))))

(defun ui-code-click-to-cursor! (x y &key extend-selection)
  (ui-code-set-cursor! (ui-code-index-at-point x y)
                       :extend-selection extend-selection))

(defun ui-editor-handle-key (key)
  "Handle non-text editing keys while the code editor has focus."
  (let ((shift (ui-shift-down-p)))
    (cond
      ((sdl2:scancode= key :scancode-escape)
       (ui-set-code-focus! nil)
       t)
      ((and (ui-shortcut-down-p) (sdl2:scancode= key :scancode-a))
       (ui-code-select-all!)
       t)
      ((and (ui-shortcut-down-p) (sdl2:scancode= key :scancode-x))
       (ui-code-cut!)
       t)
      ((or (sdl2:scancode= key :scancode-f6)
           (and (ui-shortcut-down-p) (sdl2:scancode= key :scancode-c)))
       (ui-code-copy!)
       t)
      ((or (sdl2:scancode= key :scancode-f7)
           (and (ui-shortcut-down-p) (sdl2:scancode= key :scancode-v)))
       (ui-code-paste!)
       t)
      ((or (sdl2:scancode= key :scancode-f8)
           (and (ui-shortcut-down-p) (sdl2:scancode= key :scancode-i)))
       (ui-import-code!)
       t)
      ((and (ui-control-down-p) (sdl2:scancode= key :scancode-insert))
       (ui-code-copy!)
       t)
      ((and shift (sdl2:scancode= key :scancode-insert))
       (ui-code-paste!)
       t)
      ((sdl2:scancode= key :scancode-f9)
       (ui-hot-reload-toggle!)
       t)
      ((sdl2:scancode= key :scancode-f5)
       (ui-apply-code-editor!)
       t)
      ((and (ui-shortcut-down-p) (sdl2:scancode= key :scancode-s))
       (ui-save-code-buffer!)
       t)
      ((and (ui-shortcut-down-p) (sdl2:scancode= key :scancode-return))
       (ui-apply-code-editor!)
       t)
      ((sdl2:scancode= key :scancode-return)
       (ui-code-insert-text! (string #\Newline))
       t)
      ((sdl2:scancode= key :scancode-tab)
       (ui-code-insert-text! "  ")
       t)
      ((sdl2:scancode= key :scancode-backspace)
       (unless (ui-code-delete-selection!)
         (when (> *ui-code-cursor* 0)
           (ui-code-delete-range! (1- *ui-code-cursor*) *ui-code-cursor*)))
       t)
      ((sdl2:scancode= key :scancode-delete)
       (unless (ui-code-delete-selection!)
         (ui-code-delete-range! *ui-code-cursor* (1+ *ui-code-cursor*)))
       t)
      ((sdl2:scancode= key :scancode-left)
       (ui-code-set-cursor! (1- *ui-code-cursor*) :extend-selection shift)
       t)
      ((sdl2:scancode= key :scancode-right)
       (ui-code-set-cursor! (1+ *ui-code-cursor*) :extend-selection shift)
       t)
      ((sdl2:scancode= key :scancode-up)
       (ui-code-move-cursor-line -1 :extend-selection shift)
       t)
      ((sdl2:scancode= key :scancode-down)
       (ui-code-move-cursor-line 1 :extend-selection shift)
       t)
      ((sdl2:scancode= key :scancode-home)
       (multiple-value-bind (line col) (ui-code-cursor-line-col)
         (declare (ignore col))
         (ui-code-set-cursor! (ui-code-index-from-line-col line 0)
                              :extend-selection shift))
       t)
      ((sdl2:scancode= key :scancode-end)
       (multiple-value-bind (line col) (ui-code-cursor-line-col)
         (declare (ignore col))
         (ui-code-set-cursor! (ui-code-index-from-line-col line (ui-code-line-length line))
                              :extend-selection shift))
       t)
      ((sdl2:scancode= key :scancode-pageup)
       (setf *ui-code-scroll* (max 0 (- *ui-code-scroll* 12)))
       (ui-code-move-cursor-line -12 :extend-selection shift)
       t)
      ((sdl2:scancode= key :scancode-pagedown)
       (incf *ui-code-scroll* 12)
       (ui-code-move-cursor-line 12 :extend-selection shift)
       t)
      (t t))))

(defun ui-handle-text-input (text)
  "Return true when typed text is inserted into the editor."
  (when (and *ui-enabled* *ui-show-code* *ui-code-focused*)
    (ui-code-insert-text! text)
    t))

(defun ui-handle-mouse-wheel (y)
  "Return true when mouse wheel scrolls the code editor instead of camera zoom."
  (when (and *ui-enabled* *ui-show-code* *ui-code-focused*)
    (setf *ui-code-scroll* (max 0 (- *ui-code-scroll* (* y 3))))
    t))

;;; ─── Layout ─────────────────────────────────────────────────────────────────

(defun ui-scene-name ()
  (if (and (integerp *current-scene*)
           (<= 0 *current-scene*)
           (< *current-scene* (length *scenes*)))
      (car (nth *current-scene* *scenes*))
      "Custom World"))

(defun ui-add-button (buttons id label x y w h &key active)
  (cons (list :id id :label label :x x :y y :w w :h h :active active)
        buttons))

(defun ui-left-layout-metrics ()
  "Shared vertical positions for the organized left control panel."
  (let* ((scene-rows (max 1 (ceiling (max 1 (length *scenes*)) 4)))
         (scene-y 88)
         (nav-y (+ scene-y 26))
         (grid-y (+ nav-y 32))
         (scene-name-y (+ grid-y (* scene-rows 30) 8))
         (camera-y (+ scene-name-y 28))
         (camera-row1 (+ camera-y 26))
         (camera-row2 (+ camera-row1 32))
         (system-y (+ camera-row2 44))
         (system-row1 (+ system-y 26))
         (system-row2 (+ system-row1 32))
         (system-row3 (+ system-row2 32))
         (system-row4 (+ system-row3 32))
         (code-y (+ system-row4 42))
         (code-row1 (+ code-y 26))
         (code-row2 (+ code-row1 32))
         (overlay-y (+ code-row2 40))
         (overlay-row1 (+ overlay-y 26)))
    (list :scene-rows scene-rows
          :scene-y scene-y :nav-y nav-y :grid-y grid-y :scene-name-y scene-name-y
          :camera-y camera-y :camera-row1 camera-row1 :camera-row2 camera-row2
          :system-y system-y :system-row1 system-row1 :system-row2 system-row2
          :system-row3 system-row3 :system-row4 system-row4
          :code-y code-y :code-row1 code-row1 :code-row2 code-row2
          :overlay-y overlay-y :overlay-row1 overlay-row1)))

(defun ui-build-layout (width height)
  (let* ((x *ui-margin*)
         (inner-x (+ x 12))
         (inner-w (- *ui-left-panel-width* 24))
         (btn-h *ui-button-height*)
         (gap 8)
         (col-w (floor (- inner-w gap) 2))
         (metrics (ui-left-layout-metrics))
         (buttons nil))
    (labels ((add (id label bx by bw bh &key active)
               (push (list :id id :label label :x bx :y by :w bw :h bh :active active)
                     buttons))
             (two (id1 label1 id2 label2 by &key active1 active2)
               (add id1 label1 inner-x by col-w btn-h :active active1)
               (add id2 label2 (+ inner-x col-w gap) by col-w btn-h :active active2)))
      ;; Floating top toolbar: grouped into camera/display and workspace tools.
      (multiple-value-bind (tx ty tw th) (ui-toolbar-rect)
        (declare (ignore th))
        (let* ((bh 22)
               (tgap 8)
               (bw (max 36 (floor (- tw 24 (* 5 tgap)) 6)))
               (row1 (+ ty 32))
               (row2 (+ ty 58))
               (x0 (+ tx 12)))
          (add :fit-camera "FIT" x0 row1 bw bh)
          (add :view-iso "ISO" (+ x0 (* 1 (+ bw tgap))) row1 bw bh)
          (add :view-top "TOP" (+ x0 (* 2 (+ bw tgap))) row1 bw bh)
          (add :view-front "FRONT" (+ x0 (* 3 (+ bw tgap))) row1 bw bh)
          (add :grid "GRID" (+ x0 (* 4 (+ bw tgap))) row1 bw bh :active *show-grid*)
          (add :wire "WIRE" (+ x0 (* 5 (+ bw tgap))) row1 bw bh)
          (add :stats "STATS" x0 row2 bw bh :active *ui-show-stats*)
          (add :theme "THEME" (+ x0 (* 1 (+ bw tgap))) row2 bw bh)
          (add :font-down "FONT-" (+ x0 (* 2 (+ bw tgap))) row2 bw bh)
          (add :font-up "FONT+" (+ x0 (* 3 (+ bw tgap))) row2 bw bh)
          (add :template "TPL" (+ x0 (* 4 (+ bw tgap))) row2 bw bh)
          (add :save-code "SAVE" (+ x0 (* 5 (+ bw tgap))) row2 bw bh)))

      ;; Scene navigation.
      (two :prev "PREV" :next "NEXT" (getf metrics :nav-y))
      (loop for i from 0 below (length *scenes*)
            for col = (mod i 4)
            for row = (floor i 4)
            for bx = (+ inner-x (* col 58))
            for by = (+ (getf metrics :grid-y) (* row 30)) do
        (add (list :scene i) (format nil "~D" i) bx by 50 btn-h
             :active (= i *current-scene*)))

      ;; Camera / display controls that are less frequent than the top toolbar.
      (two :reset-camera "RESET" :colour "COLOR" (getf metrics :camera-row1))
      (two :gizmo "GIZMO" :rings "RINGS" (getf metrics :camera-row2)
           :active1 *show-gizmo* :active2 *show-origin*)

      ;; Generation and persistence.
      (two :grow "GROW" :evolve "EVOLVE" (getf metrics :system-row1))
      (two :save-lib "SAVE LIB" :save-world "WORLD" (getf metrics :system-row2))
      (let* ((third-gap 8)
             (third-w (floor (- inner-w (* 2 third-gap)) 3))
             (by (getf metrics :system-row3)))
        (add :export-obj "OBJ" inner-x by third-w btn-h)
        (add :export-svg "SVG" (+ inner-x third-w third-gap) by third-w btn-h)
        (add :screenshot "SHOT" (+ inner-x (* 2 (+ third-w third-gap))) by third-w btn-h))
      (add :export-all "EXPORT ALL" inner-x (getf metrics :system-row4) inner-w btn-h)

      ;; Live code editor controls.
      (add :code "EDITOR" inner-x (getf metrics :code-row1) inner-w btn-h :active *ui-show-code*)
      (two :code-apply "APPLY" :code-reload "RELOAD" (getf metrics :code-row2)
           :active1 *ui-code-dirty*)

      ;; Extra editor controls live inside the right code panel.
      (when *ui-show-code*
        (multiple-value-bind (cx cy cw ch) (ui-code-tab-rect width height)
          (declare (ignore ch))
          (let* ((small-h 24)
                 (egap 8)
                 (bw (max 38 (floor (- cw 28 (* 4 egap)) 5)))
                 (x0 (+ cx 14))
                 (by1 (+ cy 88))
                 (by2 (+ cy 116)))
            (add :code-copy "COPY" x0 by1 bw small-h)
            (add :code-paste "PASTE" (+ x0 bw egap) by1 bw small-h)
            (add :code-import "IMPORT" (+ x0 (* 2 (+ bw egap))) by1 bw small-h)
            (add :code-apply-inline "APPLY" (+ x0 (* 3 (+ bw egap))) by1 bw small-h
                 :active *ui-code-dirty*)
            (add :code-reload-inline "RELOAD" (+ x0 (* 4 (+ bw egap))) by1 bw small-h)
            (add :code-select-all "SELECT ALL" x0 by2 (+ bw bw egap) small-h
                 :active (ui-code-has-selection-p))
            (add :code-hot-reload
                 (if *ui-hot-reload-enabled* "HOT ON" "HOT OFF")
                 (+ x0 (* 2 (+ bw egap))) by2 bw small-h
                 :active *ui-hot-reload-enabled*))))

      ;; Overlay and global visibility.
      (two :help "HELP" :hide-ui "HIDE UI" (getf metrics :overlay-row1)
           :active1 *ui-show-help*)
      (setf *ui-buttons* (nreverse buttons)))))

(defun ui-button-at (x y)
  (find-if (lambda (button)
             (let ((bx (getf button :x))
                   (by (getf button :y))
                   (bw (getf button :w))
                   (bh (getf button :h)))
               (and (>= x bx) (< x (+ bx bw))
                    (>= y by) (< y (+ by bh)))))
           *ui-buttons*))

(defun ui-help-card-rect (&optional (width *window-width*) (height *window-height*))
  "Return a centered help modal rectangle in the main workspace.
The card is intentionally wider than the old compact version so the 8x8
system font can show complete help labels instead of clipping every line."
  (let* ((main-left (+ *ui-margin* *ui-left-panel-width* 16))
         (workspace-w (max 300 (- width main-left *ui-margin*)))
         (w (min 560 workspace-w))
         (h (min 392 (max 318 (- height 90))))
         (x (+ main-left (/ (- workspace-w w) 2.0)))
         (y (max 18 (/ (- height h) 2.0))))
    (values x y w h)))

(defun ui-point-in-panel-p (x y)
  (or (and *ui-enabled*
           (>= x *ui-margin*)
           (< x (+ *ui-margin* *ui-left-panel-width*))
           (>= y *ui-margin*)
           (< y (- *window-height* 14)))
      (and *ui-enabled* *ui-show-help*
           (multiple-value-bind (hx hy hw hh) (ui-help-card-rect)
             (and (>= x hx) (< x (+ hx hw))
                  (>= y hy) (< y (+ hy hh)))))
      (ui-point-in-toolbar-p x y)
      (ui-point-in-stats-panel-p x y)
      (ui-point-in-code-panel-p x y)))

;;; ─── Button actions ─────────────────────────────────────────────────────────

(defun ui-next-layer-index ()
  (let ((max-layer 0))
    (maphash (lambda (_key macro)
               (declare (ignore _key))
               (setf max-layer (max max-layer (babel-macro-layer macro))))
             *babel-registry*)
    (1+ max-layer)))

(defun ui-camera-fit! ()
  "Frame the current geometry with the orbital camera."
  (multiple-value-bind (minx maxx miny maxy minz maxz) (ui-geometry-bounds)
    (if minx
        (let* ((cx (/ (+ minx maxx) 2.0))
               (cy (/ (+ miny maxy) 2.0))
               (cz (/ (+ minz maxz) 2.0))
               (sx (max 1.0 (- maxx minx)))
               (sy (max 1.0 (- maxy miny)))
               (sz (max 1.0 (- maxz minz)))
               (radius (/ (sqrt (+ (* sx sx) (* sy sy) (* sz sz))) 2.0)))
          (setf (camera-target-x *camera*) (float cx 1.0)
                (camera-target-y *camera*) (float cy 1.0)
                (camera-target-z *camera*) (float cz 1.0)
                (camera-distance *camera*) (float (max 24.0 (* radius 2.25)) 1.0))
          (apply-camera *camera* *window-width* *window-height*)
          (ui-message! "Camera fit to object"))
        (ui-message! "No geometry to frame"))))

(defun ui-camera-view! (view)
  "Switch camera orientation while preserving target and distance."
  (ecase view
    (:iso   (setf (camera-yaw *camera*) 35.0  (camera-pitch *camera*) 28.0))
    (:top   (setf (camera-yaw *camera*) 0.0   (camera-pitch *camera*) 89.0))
    (:front (setf (camera-yaw *camera*) 0.0   (camera-pitch *camera*) 0.0))
    (:side  (setf (camera-yaw *camera*) 90.0  (camera-pitch *camera*) 0.0)))
  (apply-camera *camera* *window-width* *window-height*)
  (ui-message! "Camera view: ~A" view))

(defun ui-toggle-grid! ()
  (setf *show-grid* (not *show-grid*))
  (ui-message! "Grid ~A" (if *show-grid* "on" "off"))
  *show-grid*)

(defun ui-toggle-stats! ()
  (setf *ui-show-stats* (not *ui-show-stats*))
  (ui-message! "Stats panel ~A" (if *ui-show-stats* "shown" "hidden"))
  *ui-show-stats*)

(defun ui-code-font-zoom! (delta)
  "Scale the bitmap code font while keeping line metrics usable."
  (setf *ui-code-editor-scale*
        (max 0.75 (min 1.60 (+ *ui-code-editor-scale* delta)))
        *ui-code-line-height*
        (max 10 (round (* 12 *ui-code-editor-scale*))))
  (ui-message! "Code font: ~,2F" *ui-code-editor-scale*)
  *ui-code-editor-scale*)

(defun ui-save-code-buffer! ()
  "Write the current editor buffer to output/babel-live-code.lisp."
  (ui-load-code-for-current-scene!)
  (let ((path (babel-out "babel-live-code.lisp")))
    (handler-case
        (progn
          (with-open-file (out path :direction :output :if-exists :supersede
                                    :if-does-not-exist :create :external-format :utf-8)
            (write-string (or *ui-code-buffer* "") out))
          (setf *ui-code-status* "SAVED EDITOR BUFFER TO OUTPUT"
                *ui-code-last-import-path* path
                *ui-code-last-import-write-date* (ignore-errors (file-write-date path)))
          (ui-message! "Saved code: ~A" (file-namestring path))
          path)
      (error (e)
        (setf *ui-code-status* (format nil "SAVE CODE ERROR: ~A" e))
        (ui-message! "Save code error: ~A" e)
        nil))))

(defun ui-load-next-template! ()
  "Replace the editor buffer with the next built-in editable code template."
  (let* ((entry (nth (mod *ui-code-template-index* (length *ui-code-templates*))
                     *ui-code-templates*))
         (name (car entry))
         (source (cdr entry)))
    (incf *ui-code-template-index*)
    (setf *ui-show-code* t
          *ui-code-buffer* source
          *ui-code-cursor* (length source)
          *ui-code-scroll* 0
          *ui-code-selection-anchor* nil
          *ui-code-selection-dragging* nil
          *ui-code-dirty* t
          *ui-code-last-scene* (list :template name)
          *ui-code-status* (format nil "TEMPLATE ~A LOADED | APPLY TO VIEW" name))
    (ui-set-code-focus! t)
    (ui-message! "Template loaded: ~A" name)
    source))

(defun ui-run-action (id &optional win)
  (cond
    ((eq id :fit-camera)
     (ui-camera-fit!))
    ((eq id :view-iso)
     (ui-camera-view! :iso))
    ((eq id :view-top)
     (ui-camera-view! :top))
    ((eq id :view-front)
     (ui-camera-view! :front))
    ((eq id :grid)
     (ui-toggle-grid!))
    ((eq id :wire)
     (cycle-wire-line-width!))
    ((eq id :stats)
     (ui-toggle-stats!))
    ((eq id :theme)
     (ui-cycle-theme!))
    ((eq id :font-down)
     (ui-code-font-zoom! -0.10))
    ((eq id :font-up)
     (ui-code-font-zoom! 0.10))
    ((eq id :template)
     (ui-load-next-template!))
    ((eq id :save-code)
     (ui-save-code-buffer!))
    ((and (consp id) (eq (first id) :scene))
     (set-scene! (second id))
     (ui-load-code-for-current-scene! :force t)
     (ui-set-code-focus! nil)
     (ui-message! "Scene ~D: ~A" (second id) (ui-scene-name)))
    ((eq id :prev)
     (prev-scene!)
     (ui-load-code-for-current-scene! :force t)
     (ui-set-code-focus! nil)
     (ui-message! "Scene ~D: ~A" *current-scene* (ui-scene-name)))
    ((eq id :next)
     (next-scene!)
     (ui-load-code-for-current-scene! :force t)
     (ui-set-code-focus! nil)
     (ui-message! "Scene ~D: ~A" *current-scene* (ui-scene-name)))
    ((eq id :code)
     (setf *ui-show-code* (not *ui-show-code*))
     (if *ui-show-code*
         (progn
           (ui-load-code-for-current-scene!)
           (ui-set-code-focus! t))
         (ui-set-code-focus! nil))
     ;; Force the button rectangles to include/remove the editor-panel controls
     ;; immediately after this click, instead of waiting for the next frame.
     (ui-build-layout *window-width* *window-height*)
     (ui-message! "Structure code editor ~A" (if *ui-show-code* "shown" "hidden")))
    ((or (eq id :code-apply) (eq id :code-apply-inline))
     (ui-apply-code-editor!))
    ((or (eq id :code-reload) (eq id :code-reload-inline))
     (ui-load-code-for-current-scene! :force t)
     (ui-set-code-focus! nil)
     (ui-message! "Code reloaded from current 3D view"))
    ((eq id :code-copy)
     (ui-code-copy!))
    ((eq id :code-paste)
     (ui-set-code-focus! t)
     (ui-code-paste!))
    ((eq id :code-import)
     (ui-import-code!))
    ((eq id :code-select-all)
     (ui-set-code-focus! t)
     (ui-code-select-all!))
    ((eq id :code-hot-reload)
     (ui-hot-reload-toggle!))
    ((eq id :code-up)
     (setf *ui-code-scroll* (max 0 (- *ui-code-scroll* 8)))
     (ui-message! "Code scroll: ~D" *ui-code-scroll*))
    ((eq id :code-down)
     (incf *ui-code-scroll* 8)
     (ui-message! "Code scroll: ~D" *ui-code-scroll*))
    ((eq id :reset-camera)
     (camera-reset! *camera*)
     (apply-camera *camera* *window-width* *window-height*)
     (ui-message! "Camera reset"))
    ((eq id :colour)
     (next-colour-mode!)
     (ui-message! "Colour mode: ~A" *colour-mode*))
    ((eq id :gizmo)
     (setf *show-gizmo* (not *show-gizmo*))
     (ui-message! "Gizmo ~A" (if *show-gizmo* "on" "off")))
    ((eq id :rings)
     (setf *show-origin* (not *show-origin*))
     (ui-message! "Ground rings ~A" (if *show-origin* "on" "off")))
    ((eq id :grow)
     (let ((layer (ui-next-layer-index)))
       (ui-message! "Inventing layer ~D..." layer)
       (bordeaux-threads:make-thread
        (lambda ()
          (invent-layer! layer 20 4)
          (setf *geometry-dirty* t)
          (ui-message! "Layer ~D complete" layer))
        :name "babel-ui-inventor")))
    ((eq id :evolve)
     (evolve!)
     (setf *geometry-dirty* t)
     (ui-message! "Evolution round complete"))
    ((eq id :save-lib)
     (let ((path (babel-out "babel-library.lisp")))
       (export-library path)
       (ui-message! "Saved library: ~A" (file-namestring path))))
    ((eq id :save-world)
     (let ((path (babel-out "babel-world.world")))
       (save-world-file! path "gui-quicksave")
       (ui-message! "Saved world: ~A" (file-namestring path))))
    ((eq id :export-obj)
     (let ((path (babel-out "babel-world.obj")))
       (export-obj! path)
       (ui-message! "Exported OBJ: ~A" (file-namestring path))))
    ((eq id :export-svg)
     (let ((path (babel-out "babel-quad.svg")))
       (export-svg-quad! path)
       (ui-message! "Exported SVG: ~A" (file-namestring path))))
    ((eq id :screenshot)
     (take-screenshot (or win *ui-last-window*))
     (ui-message! "Screenshot saved"))
    ((eq id :export-all)
     (export-all!)
     (ui-message! "Full export complete"))
    ((eq id :help)
     (setf *ui-show-help* (not *ui-show-help*))
     (ui-message! "Help ~A" (if *ui-show-help* "shown" "hidden")))
    ((eq id :hide-ui)
     (setf *ui-enabled* nil)
     (ui-message! "UI hidden. Press F2 to show it."))))

;;; ─── Event handling ─────────────────────────────────────────────────────────

(defun ui-handle-mouse-motion (x y)
  (when *ui-enabled*
    ;; Rebuild from the current window size on every pointer update.  This keeps
    ;; hit boxes synchronized with the drawn UI after resize, editor open/close,
    ;; or font-scale changes.
    (ui-build-layout *window-width* *window-height*)
    (if *ui-code-selection-dragging*
        (progn
          (ui-code-set-cursor! (ui-code-index-at-point x y) :extend-selection t)
          (setf *ui-mouse-captured* t))
        (let ((button (ui-button-at x y)))
          (setf *ui-hover-id* (and button (getf button :id)))))))

(defun ui-handle-mouse-down (x y &optional win)
  "Return true when the GUI consumes this mouse press."
  (when *ui-enabled*
    ;; Always rebuild before hit-testing.  Stale rectangles were the main reason
    ;; sidebar buttons such as EDITOR could look clickable but fail after layout
    ;; changes or window-size updates.
    (ui-build-layout *window-width* *window-height*)
    (ui-handle-mouse-motion x y)
    (let ((button (ui-button-at x y)))
      (cond
        ((and *ui-show-help*
              (multiple-value-bind (hx hy hw hh) (ui-help-card-rect)
                (and (>= x hx) (< x (+ hx hw))
                     (>= y hy) (< y (+ hy hh)))))
         (setf *ui-mouse-captured* t)
         (ui-set-code-focus! nil)
         t)
        (button
         (setf *ui-mouse-captured* t)
         (ui-run-action (getf button :id) win)
         t)
        ((ui-point-in-code-panel-p x y)
         (ui-load-code-for-current-scene!)
         (setf *ui-mouse-captured* t
               *ui-code-selection-dragging* t)
         (ui-set-code-focus! t)
         (if (ui-shift-down-p)
             (ui-code-click-to-cursor! x y :extend-selection t)
             (let ((index (ui-code-index-at-point x y)))
               (setf *ui-code-selection-anchor* index
                     *ui-code-cursor* index)))
         t)
        ((ui-point-in-panel-p x y)
         (setf *ui-mouse-captured* t)
         (ui-set-code-focus! nil)
         t)
        (t
         (ui-set-code-focus! nil)
         nil)))))

(defun ui-handle-mouse-up (&optional x y)
  (declare (ignore x y))
  (setf *ui-code-selection-dragging* nil
        *ui-mouse-captured* nil)
  (unless (ui-code-has-selection-p)
    (setf *ui-code-selection-anchor* nil))
  nil)

(defun ui-handle-key (key)
  "Return true when the GUI consumes this keyboard event."
  (cond
    ((sdl2:scancode= key :scancode-f2)
     (setf *ui-enabled* (not *ui-enabled*))
     (ui-message! "UI ~A" (if *ui-enabled* "shown" "hidden"))
     t)
    ((and *ui-enabled* (sdl2:scancode= key :scancode-f3))
     (setf *ui-show-code* (not *ui-show-code*))
     (unless *ui-show-code* (ui-set-code-focus! nil))
     (ui-message! "Structure code editor ~A" (if *ui-show-code* "shown" "hidden"))
     t)
    ((and *ui-enabled* (sdl2:scancode= key :scancode-f4))
     (ui-toggle-stats!)
     t)
    ((and *ui-enabled* (sdl2:scancode= key :scancode-f10))
     (ui-cycle-theme!)
     t)
    ((and *ui-enabled* (sdl2:scancode= key :scancode-f11))
     (ui-camera-fit!)
     t)
    ((and *ui-enabled* *ui-code-focused*)
     (ui-editor-handle-key key))
    ((and *ui-enabled* (sdl2:scancode= key :scancode-h))
     (setf *ui-show-help* (not *ui-show-help*))
     (ui-message! "Help ~A" (if *ui-show-help* "shown" "hidden"))
     t)
    ((and *ui-enabled* *ui-show-code* (sdl2:scancode= key :scancode-f5))
     (ui-apply-code-editor!)
     t)
    ((and *ui-enabled* *ui-show-code* (sdl2:scancode= key :scancode-f6))
     (ui-code-copy!)
     t)
    ((and *ui-enabled* *ui-show-code* (sdl2:scancode= key :scancode-f7))
     (ui-set-code-focus! t)
     (ui-code-paste!)
     t)
    ((and *ui-enabled* *ui-show-code* (sdl2:scancode= key :scancode-f8))
     (ui-import-code!)
     t)
    ((and *ui-enabled* *ui-show-code* (sdl2:scancode= key :scancode-f9))
     (ui-hot-reload-toggle!)
     t)
    (t nil)))

;;; ─── Rendering ───────────────────────────────────────────────────────────────

(defun ui-draw-button (button)
  (let* ((id (getf button :id))
         (x  (getf button :x))
         (y  (getf button :y))
         (w  (getf button :w))
         (h  (getf button :h))
         (label (getf button :label))
         (active (getf button :active))
         (hover (equal id *ui-hover-id*)))
    (multiple-value-bind (pr pg pb) (ui-theme-rgb :panel2)
      (multiple-value-bind (hr hg hb) (ui-theme-rgb :hover)
        (multiple-value-bind (ar ag ab) (ui-theme-rgb :active)
          (multiple-value-bind (cr cg cb) (ui-theme-rgb :accent)
            (multiple-value-bind (tr tg tb) (ui-theme-rgb :text)
              ;; Slight inset shadow makes buttons read as controls instead of flat labels.
              (ui-rect (+ x 2) (+ y 2) w h 0.0 0.0 0.0)
              (cond
                (active (ui-rect x y w h ar ag ab))
                (hover  (ui-rect x y w h hr hg hb))
                (t      (ui-rect x y w h pr pg pb)))
              (ui-outline x y w h
                          (if (or active hover) cr 0.14)
                          (if (or active hover) cg 0.32)
                          (if (or active hover) cb 0.38)
                          (if hover 1.7 1.0))
              (ui-line (+ x 2) (+ y 2) (- (+ x w) 2) (+ y 2)
                       (min 1.0 (+ cr 0.10)) (min 1.0 (+ cg 0.10)) (min 1.0 (+ cb 0.10)) 1.0)
              (ui-centered-text label x y w h :scale 1.35
                                :r (if active 0.96 tr)
                                :g (if active 1.00 tg)
                                :b (if active 0.98 tb)))))))))

(defun ui-draw-left-panel ()
  (let* ((x *ui-margin*)
         (y *ui-margin*)
         (w *ui-left-panel-width*)
         (h (- *window-height* 28))
         (inner-x (+ x 12))
         (inner-w (- w 24))
         (metrics (ui-left-layout-metrics)))
    (ui-shadowed-rect x y w h 6)
    (multiple-value-bind (pr pg pb) (ui-theme-rgb :panel2)
      (ui-rect x y w h pr pg pb))
    (multiple-value-bind (ar ag ab) (ui-theme-rgb :accent)
      (ui-outline x y w h ar ag ab 1.0))

    ;; Compact brand/header area. Every label is fitted to its panel lane so
    ;; the larger 8x8 font cannot escape the sidebar.
    (ui-text-box "BABEL" inner-x 26 inner-w :scale 3.0 :r 0.56 :g 0.98 :b 0.95)
    (ui-text-box "LISP MACRO WORLD COMPILER" inner-x 54 inner-w
                 :scale 1.05 :r 0.38 :g 0.66 :b 0.72)
    (ui-line inner-x 74 (+ inner-x inner-w) 74 0.12 0.34 0.42 1.0)

    ;; Scene block.
    (ui-section-title "SCENES" inner-x (getf metrics :scene-y) inner-w)
    (ui-text-box (format nil "ACTIVE ~D/~D" (max 0 *current-scene*) (1- (length *scenes*)))
                 (+ inner-x 128) (+ (getf metrics :scene-y) 1) (- inner-w 128)
                 :scale 0.95 :r 0.55 :g 0.72 :b 0.72)
    (ui-text-box (ui-scene-name) inner-x (getf metrics :scene-name-y) inner-w
                 :scale 1.05 :r 0.62 :g 0.74 :b 0.77)

    ;; Camera block.
    (ui-section-title "CAMERA" inner-x (getf metrics :camera-y) inner-w)
    (ui-text-box (format nil "COLOR ~A | GRID ~A"
                         *colour-mode* (if *show-grid* "ON" "OFF"))
                 (+ inner-x 100) (+ (getf metrics :camera-y) 1) (- inner-w 100)
                 :scale 0.95 :r 0.55 :g 0.72 :b 0.72)

    ;; System block.
    (ui-section-title "SYSTEM" inner-x (getf metrics :system-y) inner-w)
    (ui-text-box "AI, SAVE AND EXPORT" (+ inner-x 92) (+ (getf metrics :system-y) 1) (- inner-w 92)
                 :scale 0.9 :r 0.55 :g 0.72 :b 0.72)

    ;; Editor block.
    (ui-section-title "CODE" inner-x (getf metrics :code-y) inner-w)
    (ui-text-box (if *ui-show-code* "EDITOR OPEN" "EDITOR CLOSED")
                 (+ inner-x 72) (+ (getf metrics :code-y) 1) (- inner-w 72)
                 :scale 0.9 :r 0.55 :g 0.72 :b 0.72)

    ;; Overlay block.
    (ui-section-title "OVERLAY" inner-x (getf metrics :overlay-y) inner-w)
    (dolist (button *ui-buttons*)
      (when (and (< (getf button :x) (+ *ui-margin* *ui-left-panel-width*))
                 (< (getf button :y) (+ y h)))
        (ui-draw-button button)))))

(defun ui-draw-bottom-bar (width height)
  (let* ((x (+ *ui-margin* *ui-left-panel-width* 12))
         (y (- height 58))
         (w (max 220 (- width x *ui-margin*)))
         (h 44)
         (message-visible (< (ui-message-age) 5.0)))
    (ui-shadowed-rect x y w h 5)
    (multiple-value-bind (pr pg pb) (ui-theme-rgb :panel2)
      (ui-rect x y w h pr pg pb))
    (multiple-value-bind (ar ag ab) (ui-theme-rgb :accent)
      (ui-outline x y w h ar ag ab 1.0))
    (let* ((message-w (if message-visible (max 0 (min 460 (- w 30))) 0))
           (status-w (max 80 (- w 34 message-w)))
           (status (format nil "~D VERTS | ~D EDGES | ~D MACROS | ~,0F FPS | ~A"
                           (length *cached-verts*)
                           (length *cached-edges*)
                           (hash-table-count *babel-registry*)
                           (float *current-fps*)
                           (ui-scene-name))))
      (ui-text-box status (+ x 14) (+ y 11) status-w
                   :scale 1.25 :r 0.70 :g 0.90 :b 0.88))
    (when (and message-visible (> w 260))
      (let ((mw (max 80 (min 460 (- w 30)))))
        (ui-rect (- (+ x w) mw 14) (+ y 8) mw 28 0.06 0.12 0.14)
        (multiple-value-bind (ar ag ab) (ui-theme-rgb :accent)
          (ui-outline (- (+ x w) mw 14) (+ y 8) mw 28 ar ag ab 1.0))
        (ui-text-box *ui-message* (- (+ x w) mw 4) (+ y 17) (- mw 18)
                     :scale 1.0 :r 0.78 :g 1.0 :b 0.95)))))

(defun ui-toolbar-rect ()
  (let* ((x (+ *ui-margin* *ui-left-panel-width* 12))
         (available (- *window-width* x *ui-margin*))
         (w (min 464 (max 280 available))))
    (values x 14 w 88)))

(defun ui-point-in-toolbar-p (x y)
  (multiple-value-bind (tx ty tw th) (ui-toolbar-rect)
    (and *ui-enabled*
         (>= x tx) (< x (+ tx tw))
         (>= y ty) (< y (+ ty th)))))

(defun ui-draw-top-toolbar ()
  "Draw a compact command toolbar over the main viewport."
  (multiple-value-bind (x y w h) (ui-toolbar-rect)
    (ui-shadowed-rect x y w h 5)
    (multiple-value-bind (pr pg pb) (ui-theme-rgb :panel)
      (ui-rect x y w h pr pg pb))
    (multiple-value-bind (ar ag ab) (ui-theme-rgb :accent)
      (ui-outline x y w h ar ag ab 1.0))
    (ui-text-box "VIEW TOOLS" (+ x 12) (+ y 8) 96
                 :scale 1.20 :r 0.56 :g 0.98 :b 0.95)
    (let ((meta (format nil "THEME ~A | FONT ~,2F | WIRE ~,1F"
                        (ui-theme-name) *ui-code-editor-scale* *wire-line-width*)))
      (ui-text-box meta (+ x 116) (+ y 9) (- w 130)
                   :scale 0.90 :r 0.55 :g 0.72 :b 0.72))
    (dolist (button *ui-buttons*)
      (when (member (getf button :id) *ui-toolbar-button-ids* :test #'equal)
        (ui-draw-button button)))))

(defun ui-geometry-bounds ()
  "Return geometry bounds as six values, or NIL when the view has no vertices."
  (let ((verts *cached-verts*))
    (when (plusp (length verts))
      (let* ((v0 (aref verts 0))
             (minx (first v0))  (maxx (first v0))
             (miny (second v0)) (maxy (second v0))
             (minz (third v0))  (maxz (third v0)))
        (loop for v across verts do
          (let ((x (first v)) (y (second v)) (z (third v)))
            (setf minx (min minx x) maxx (max maxx x)
                  miny (min miny y) maxy (max maxy y)
                  minz (min minz z) maxz (max maxz z))))
        (values minx maxx miny maxy minz maxz)))))

(defun ui-stats-rect ()
  (let* ((x (+ *ui-margin* *ui-left-panel-width* 12))
         (w (min 448 (max 280 (- *window-width* x *ui-margin*)))))
    (values x 112 w 138)))

(defun ui-point-in-stats-panel-p (x y)
  (multiple-value-bind (sx sy sw sh) (ui-stats-rect)
    (and *ui-enabled* *ui-show-stats*
         (>= x sx) (< x (+ sx sw))
         (>= y sy) (< y (+ sy sh)))))

(defun ui-draw-stats-panel ()
  "Draw live object/camera stats so creators do not need terminal output."
  (when *ui-show-stats*
    (multiple-value-bind (x y w h) (ui-stats-rect)
      (ui-shadowed-rect x y w h 5)
      (multiple-value-bind (pr pg pb) (ui-theme-rgb :panel)
        (ui-rect x y w h pr pg pb))
      (multiple-value-bind (ar ag ab) (ui-theme-rgb :accent)
        (ui-outline x y w h ar ag ab 1.0))
      (ui-text-box "SCENE INSPECTOR" (+ x 12) (+ y 12) 138
                   :scale 1.25 :r 0.56 :g 0.98 :b 0.95)
      (ui-text-box (format nil "~A" (ui-scene-name)) (+ x 158) (+ y 13) (- w 170)
                   :scale 0.95 :r 0.72 :g 0.88 :b 0.86)
      (ui-line (+ x 12) (+ y 34) (- (+ x w) 12) (+ y 34) 0.12 0.34 0.42 1.0)
      (ui-text-box (format nil "GEOMETRY  ~D VERTS / ~D EDGES"
                           (length *cached-verts*) (length *cached-edges*))
                   (+ x 14) (+ y 48) (- w 28)
                   :scale 1.0 :r 0.76 :g 0.90 :b 0.82)
      (ui-text-box (format nil "REGISTRY   ~D MACROS | COLOR ~A | GRID ~A"
                           (hash-table-count *babel-registry*) *colour-mode*
                           (if *show-grid* "ON" "OFF"))
                   (+ x 14) (+ y 68) (- w 28)
                   :scale 1.0 :r 0.76 :g 0.90 :b 0.82)
      (multiple-value-bind (minx maxx miny maxy minz maxz) (ui-geometry-bounds)
        (if minx
            (progn
              (ui-text-box (format nil "BOUNDS X ~,1F..~,1F | Y ~,1F..~,1F" minx maxx miny maxy)
                           (+ x 14) (+ y 88) (- w 28)
                           :scale 0.95 :r 0.62 :g 0.78 :b 0.78)
              (ui-text-box (format nil "BOUNDS Z ~,1F..~,1F | CAMERA D ~,1F"
                                   minz maxz (camera-distance *camera*))
                           (+ x 14) (+ y 106) 236
                           :scale 0.95 :r 0.62 :g 0.78 :b 0.78))
            (ui-text-box "NO GEOMETRY YET" (+ x 14) (+ y 88) (- w 28)
                         :scale 0.95 :r 0.62 :g 0.78 :b 0.78)))
      (ui-text-box (if *ui-code-dirty* "CODE DIRTY - APPLY" "CODE MATCHES VIEW")
                   (+ x 276) (+ y 106) (- w 288)
                   :scale 0.85 :r 0.42 :g 0.78 :b 0.86))))

;;; ─── Structure Code editor rendering ───────────────────────────────────────

(defparameter *ui-lisp-special-forms*
  '("defun" "defmacro" "lambda" "let" "let*" "labels" "flet" "macrolet"
    "if" "when" "unless" "cond" "case" "ecase" "typecase" "progn" "prog1" "prog2"
    "loop" "for" "from" "below" "to" "by" "in" "on" "across" "do" "collect" "append"
    "sum" "maximize" "minimize" "finally" "return" "return-from" "block" "tagbody" "go"
    "setf" "setq" "push" "pop" "incf" "decf" "rotatef" "shiftf" "multiple-value-bind"
    "handler-case" "ignore-errors" "unwind-protect" "with-open-file" "with-input-from-string"
    "format" "list" "vector" "quote" "function" "declare" "ignore" "type" "or" "and" "not"
    "babel-eval" "world" "box" "sphere" "plane" "cone" "cylinder" "torus" "arch"
    "babel-line" "terrain" "plateau" "pyramid" "vault" "staircase" "spire" "wall-segment"
    "flying-buttress" "half-dome")
  "Tokens highlighted as Lisp/control/geometry forms in the built-in editor.")

(defun ui-code-token-delimiter-p (ch)
  (or (find ch " 	()[]{}'`\",;" :test #'char=)
      (char= ch #\Newline)))

(defun ui-code-number-token-p (token)
  (and (> (length token) 0)
       (handler-case
           (multiple-value-bind (value end) (read-from-string token nil nil)
             (and (= end (length token)) (numberp value)))
         (error () nil))))

(defun ui-code-token-class (token)
  (let ((down (string-downcase token)))
    (cond
      ((zerop (length token)) :text)
      ((char= (char token 0) #\:) :keyword)
      ((char= (char token 0) #\#) :reader)
      ((ui-code-number-token-p token) :number)
      ((member down *ui-lisp-special-forms* :test #'string=) :special)
      (t :text))))

(defun ui-code-token-colour (class)
  "Return syntax colour RGB values for CLASS."
  (case class
    (:comment (values 0.36 0.64 0.52))
    (:string  (values 0.96 0.72 0.46))
    (:number  (values 0.66 0.82 1.00))
    (:special (values 0.42 0.92 0.94))
    (:keyword (values 0.94 0.58 1.00))
    (:reader  (values 0.88 0.78 0.48))
    (:paren   (values 0.52 0.68 0.74))
    (:quote   (values 0.80 0.70 1.00))
    (t        (values 0.76 0.90 0.82))))

(defun ui-code-draw-token (text x y scale class)
  (multiple-value-bind (r g b) (ui-code-token-colour class)
    (ui-text text x y :scale scale :r r :g g :b b)))

(defun ui-code-visible-line-fragment (line max-width scale)
  "Return the visible part of LINE, clipped without adding fake editor text."
  (let* ((step (ui-font-char-step scale))
         (max-chars (max 0 (floor (/ (max 0 max-width) step))))
         (line (or line "")))
    (subseq line 0 (min (length line) max-chars))))

(defun ui-draw-code-line-highlighted (line x y max-width scale)
  "Draw one Lisp source line with lightweight syntax highlighting."
  (let* ((text (ui-code-visible-line-fragment line max-width scale))
         (len (length text))
         (step (ui-font-char-step scale))
         (i 0))
    (labels ((draw (start end class)
               (when (< start end)
                 (ui-code-draw-token (subseq text start end)
                                     (+ x (* start step)) y scale class)))
             (scan-token-end (start)
               (loop for j from start below len
                     until (ui-code-token-delimiter-p (char text j))
                     finally (return j))))
      (loop while (< i len) do
        (let ((ch (char text i)))
          (cond
            ((char= ch #\;)
             (draw i len :comment)
             (setf i len))
            ((char= ch #\")
             (let ((j (1+ i))
                   (escaped nil))
               (loop while (< j len) do
                 (let ((c (char text j)))
                   (cond
                     (escaped (setf escaped nil))
                     ((char= c #\\) (setf escaped t))
                     ((char= c #\") (incf j) (return)))
                   (incf j)))
               (draw i (min j len) :string)
               (setf i (min j len))))
            ((find ch "()[]{}" :test #'char=)
             (draw i (1+ i) :paren)
             (incf i))
            ((find ch "'`," :test #'char=)
             (draw i (1+ i) :quote)
             (incf i))
            ((ui-code-token-delimiter-p ch)
             ;; Whitespace has no pixels, but preserving the column math keeps
             ;; following tokens in the correct place.
             (incf i))
            (t
             (let ((end (scan-token-end i)))
               (draw i end (ui-code-token-class (subseq text i end)))
               (setf i end)))))))))

(defun ui-visible-code-lines ()
  (ui-lines-from-string (or *ui-code-buffer* "")))

(defun ui-code-tab-button-id-p (id)
  "True when ID belongs to the floating controls inside the code editor panel."
  (member id
          '(:code-copy :code-paste :code-import :code-apply-inline
            :code-reload-inline :code-select-all :code-hot-reload)
          :test #'equal))

(defun ui-draw-code-tab-buttons (x y w h)
  "Draw only the editor-panel buttons that were created by UI-BUILD-LAYOUT.
This function was referenced by UI-DRAW-CODE-TAB but accidentally omitted in a
previous UI cleanup, so opening the editor crashed the window thread."
  (declare (ignore x y w h))
  (dolist (button *ui-buttons*)
    (when (ui-code-tab-button-id-p (getf button :id))
      (ui-draw-button button))))

(defun ui-draw-code-tab (width height)
  (when *ui-show-code*
    (ui-load-code-for-current-scene!)
    (multiple-value-bind (x y w h) (ui-code-tab-rect width height)
      (let* ((scale *ui-code-editor-scale*)
             (line-h *ui-code-line-height*)
             (content-y (+ y *ui-code-content-y-offset*))
             (lines (ui-visible-code-lines))
             (visible (max 1 (floor (- h (+ *ui-code-content-y-offset* 14)) line-h)))
             (max-scroll (max 0 (- (length lines) visible)))
             (code-x (+ x 58))
             (code-w (max 24 (- w 74)))
             (step (ui-font-char-step scale))
             (max-visible-cols (max 0 (floor (/ code-w step)))))
        (setf *ui-code-scroll* (min (max 0 *ui-code-scroll*) max-scroll))
        (ui-rect x y w h 0.018 0.024 0.036)
        (ui-outline x y w h
                    (if *ui-code-focused* 0.18 0.12)
                    (if *ui-code-focused* 0.86 0.34)
                    (if *ui-code-focused* 0.88 0.42)
                    (if *ui-code-focused* 1.6 1.0))
        ;; Tab strip.
        (ui-rect (+ x 12) (+ y 10) 108 24
                 (if *ui-code-focused* 0.05 0.04)
                 (if *ui-code-focused* 0.34 0.18)
                 (if *ui-code-focused* 0.38 0.22))
        (ui-outline (+ x 12) (+ y 10) 108 24 0.18 0.86 0.88 1.0)
        (ui-centered-text (if *ui-code-dirty* "DIRTY" "CODE")
                          (+ x 12) (+ y 10) 108 24
                          :scale 1.25 :r 0.90 :g 1.0 :b 0.98)
        (ui-text-box "LIVE STRUCTURE EDITOR" (+ x 134) (+ y 15) (- w 154)
                     :scale 1.35 :r 0.56 :g 0.98 :b 0.95)
        (ui-text-box (format nil "VIEW: ~A" (ui-scene-name)) (+ x 14) (+ y 46) (- w 28)
                     :scale 1.0 :r 0.62 :g 0.80 :b 0.80)
        (let ((line-status (format nil "LINES ~D-~D / ~D | ~A"
                                   (if lines (1+ *ui-code-scroll*) 0)
                                   (min (length lines) (+ *ui-code-scroll* visible))
                                   (length lines)
                                   *ui-code-status*)))
          (ui-text-box line-status (+ x 14) (+ y 64) (- w 28)
                       :scale 0.90 :r 0.42 :g 0.78 :b 0.86))
        (ui-line (+ x 14) (+ y 84) (- (+ x w) 14) (+ y 84)
                 0.12 0.34 0.42 1.0)
        (ui-draw-code-tab-buttons x y w h)
        (ui-text-box "SYNTAX HIGHLIGHT | SELECT MOUSE/SHIFT | IMPORT EXPLORER | HOT APPLIES."
                     (+ x 14) (+ y 144) (- w 28)
                     :scale 0.85 :r 0.55 :g 0.72 :b 0.72)
        (multiple-value-bind (sel-start sel-end selection-active) (ui-code-selection-bounds)
          (let ((starts (ui-code-line-starts)))
            (ui-with-clip (code-x (- content-y 2) code-w (- h *ui-code-content-y-offset*))
              (loop for line in (subseq lines
                                        *ui-code-scroll*
                                        (min (length lines) (+ *ui-code-scroll* visible)))
                    for line-no from *ui-code-scroll*
                    for yy from content-y by line-h do
                      (let* ((line-start (nth line-no starts))
                             (line-end (+ line-start (length line))))
                        (multiple-value-bind (cursor-line cursor-col) (ui-code-cursor-line-col)
                          (declare (ignore cursor-col))
                          (when (= cursor-line line-no)
                            (ui-rect code-x (- yy 2) code-w line-h
                                     0.025 0.045 0.060)))
                        (when selection-active
                          (let* ((hs (max sel-start line-start))
                                 (he (min sel-end line-end))
                                 (vis-hs (max 0 (min max-visible-cols (- hs line-start))))
                                 (vis-he (max 0 (min max-visible-cols (- he line-start)))))
                            (when (< vis-hs vis-he)
                              (ui-rect (+ code-x (* vis-hs step))
                                       (- yy 1)
                                       (max 3 (* (- vis-he vis-hs) step))
                                       line-h
                                       0.08 0.26 0.32))))
                        (ui-draw-code-line-highlighted line code-x yy code-w scale))))
            ;; Gutter is drawn outside the code clip so line numbers remain readable.
            (loop with first-line = *ui-code-scroll*
                  with last-line = (min (length lines) (+ *ui-code-scroll* visible))
                  for line-no from first-line below last-line
                  for yy from content-y by line-h do
                    (ui-text-box (format nil "~3,'0D" (1+ line-no)) (+ x 14) yy 36
                                 :scale scale :r 0.30 :g 0.48 :b 0.52))))
        ;; Cursor: clamp it to the visible editor lane instead of drawing through the panel edge.
        (when *ui-code-focused*
          (multiple-value-bind (cursor-line cursor-col) (ui-code-cursor-line-col)
            (when (and (>= cursor-line *ui-code-scroll*)
                       (< cursor-line (+ *ui-code-scroll* visible)))
              (let* ((visible-col (max 0 (min max-visible-cols cursor-col)))
                     (cx (min (- (+ code-x code-w) 2) (+ code-x (* visible-col step))))
                     (cy (+ content-y (* (- cursor-line *ui-code-scroll*) line-h))))
                (ui-rect cx cy 2 (ui-font-pixel-height scale) 0.88 1.0 0.92)))))))))



(defun ui-draw-help-card (width &optional (height *window-height*))
  (declare (ignore width))
  (when *ui-show-help*
    (multiple-value-bind (x y w h) (ui-help-card-rect *window-width* height)
      (ui-shadowed-rect x y w h 7)
      (multiple-value-bind (pr pg pb) (ui-theme-rgb :panel2)
        (ui-rect x y w h pr pg pb))
      (multiple-value-bind (ar ag ab) (ui-theme-rgb :accent)
        (ui-outline x y w h ar ag ab 1.4))
      (ui-with-clip (x y w h)
        (labels ((title (text yy)
                   (ui-text-box text (+ x 18) yy (- w 36)
                                :scale 1.35 :r 0.56 :g 0.98 :b 0.95))
                 (hint (text yy)
                   (ui-text-box text (+ x 18) yy (- w 36)
                                :scale 1.0 :r 0.72 :g 0.88 :b 0.86))
                 (section (text yy)
                   (ui-text-box text (+ x 18) yy (- w 36)
                                :scale 1.0 :r 0.42 :g 0.78 :b 0.86)))
          ;; Keep all help text short and one-line per item.  This avoids the old
          ;; visual bug where long instructions were chopped into "QU.." fragments.
          (title "HELP / QUICK MAP" (+ y 16))
          (ui-text-box "H OR HELP CLOSES" (+ x 304) (+ y 18) (- w 322)
                       :scale 1.0 :r 0.55 :g 0.72 :b 0.72)
          (ui-line (+ x 18) (+ y 42) (- (+ x w) 18) (+ y 42) 0.12 0.34 0.42 1.0)

          (section "MOUSE" (+ y 62))
          (hint "LEFT DRAG: ORBIT CAMERA" (+ y 82))
          (hint "RIGHT DRAG: PAN CAMERA" (+ y 100))
          (hint "WHEEL: ZOOM VIEW; IN EDITOR: SCROLL TEXT" (+ y 118))

          (section "FUNCTION KEYS" (+ y 150))
          (hint "F2 UI   F3 EDITOR   F4 STATS   F5 APPLY" (+ y 170))
          (hint "F8 IMPORT   F9 HOT RELOAD   F10 THEME" (+ y 188))
          (hint "F11 FIT CAMERA   ESC UNFOCUS EDITOR" (+ y 206))

          (section "EDITOR SHORTCUTS" (+ y 238))
          (hint "CTRL/CMD+C COPY   CTRL/CMD+V PASTE" (+ y 258))
          (hint "CTRL/CMD+X CUT    CTRL/CMD+A SELECT ALL" (+ y 276))
          (hint "CTRL/CMD+S SAVE   CTRL/CMD+ENTER APPLY" (+ y 294))

          (section "LAYOUT" (+ y 326))
          (hint "LEFT PANEL: WORKFLOW  TOP BAR: VIEW TOOLS" (+ y 346))
          (hint "RIGHT PANEL: LIVE CODE EDITOR" (+ y 364)))))))

(defun draw-ui! (win width height)
  "Render the complete GUI overlay.  Called once per frame by the renderer."
  (setf *ui-last-window* win)
  (ui-hot-reload-check!)
  (when *ui-enabled*
    (ui-build-layout width height)
    (ui-begin-2d width height)
    (unwind-protect
         (progn
           (ui-draw-left-panel)
           (ui-draw-top-toolbar)
           (ui-draw-stats-panel)
           (ui-draw-code-tab width height)
           (ui-draw-help-card width height)
           (ui-draw-bottom-bar width height))
      (ui-end-2d))))
