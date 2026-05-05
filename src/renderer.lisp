;;;; src/renderer.lisp
;;;; SDL2 window management and OpenGL wireframe rendering.
;;;;
;;;; The renderer polls SDL events (keyboard, mouse, quit), re-evaluates the
;;;; current WORLD-FN each frame if geometry is dirty, and draws the edge list
;;;; via gl:begin :lines.

(in-package #:babel)

;;; ─── State ───────────────────────────────────────────────────────────────────

(defparameter *window-width*  1280)
(defparameter *window-height*  720)
(defparameter *window-title*  "BABEL — The Lisp Macro World Compiler")

(defvar *world-fn*        nil  "Thunk that populates *edge-buffer*.")
(defvar *world-mutex*     (bt:make-lock "world-mutex")
  "Protects *world-fn* and *geometry-dirty* for safe cross-thread updates.")
(defvar *cached-verts*    #()  "Last rendered vertex array.")
(defvar *cached-edges*    #()  "Last rendered edge array.")
(defvar *geometry-dirty*  t    "Recompute geometry on next frame?")

;;; Mouse drag state
(defvar *mouse-left-down*  nil)
(defvar *mouse-right-down* nil)
(defvar *mouse-last-x*     0)
(defvar *mouse-last-y*     0)

;;; Active scene index (for demo cycling)
(defvar *current-scene*   0)

;;; Visual display options controlled by the in-window GUI.
(defvar *show-grid* t
  "When true, draw the ground reference grid behind the world geometry.")

(defparameter *wire-line-widths* '(1.0 1.4 2.1 3.0)
  "Line thickness presets for the wireframe renderer.")

(defvar *wire-line-width* 1.4
  "Current OpenGL line width for world geometry edges.")

(defun cycle-wire-line-width! ()
  "Cycle through comfortable wireframe thickness presets."
  (let* ((pos (position *wire-line-width* *wire-line-widths* :test #'=))
         (next (nth (mod (1+ (or pos 0)) (length *wire-line-widths*))
                    *wire-line-widths*)))
    (setf *wire-line-width* next)
    (when (fboundp 'ui-message!)
      (ui-message! "Wire width: ~,1F" next))
    next))

;;; FPS tracking
(defvar *frame-count*     0)
(defvar *last-fps-time*   0)
(defvar *current-fps*     0.0)
(defvar *last-frame-time* 0    "Internal-real-time of previous frame for dt.")

;;; ─── Geometry rebuild ────────────────────────────────────────────────────────

(defun rebuild-geometry! ()
  "Re-run *world-fn* to fill geometry buffers and cache the arrays.
   Holds *world-mutex* so a concurrent run-world call from the REPL
   thread cannot swap *world-fn* mid-rebuild."
  (bt:with-lock-held (*world-mutex*)
    (when *world-fn*
      (clear-geometry!)
      (handler-case (funcall *world-fn*)
        (error (e)
          (format t "~&[BABEL] World eval error: ~A~%" e)))
      (multiple-value-bind (v e) (collect-geometry)
        (setf *cached-verts*   v
              *cached-edges*   e
              *geometry-dirty* nil)))))

;;; ─── OpenGL rendering ────────────────────────────────────────────────────────

(defun update-fps! (win)
  "Update the FPS counter and refresh the window title once per second."
  (incf *frame-count*)
  (let ((now (get-internal-real-time)))
    (when (zerop *last-fps-time*)
      (setf *last-fps-time* now))
    (let ((elapsed (/ (float (- now *last-fps-time*))
                      internal-time-units-per-second)))
      (when (>= elapsed 1.0)
        (setf *current-fps*  (/ *frame-count* elapsed)
              *frame-count*  0
              *last-fps-time* now)
        (sdl2:set-window-title
         win
         (format nil "BABEL  |  scene ~D  |  ~D verts ~D edges  |  ~,0f fps  |  ~D macros"
                 *current-scene*
                 (length *cached-verts*)
                 (length *cached-edges*)
                 *current-fps*
                 (hash-table-count *babel-registry*)))))))
(defun render-frame (win width height)
  "Draw the current geometry and GUI into the SDL/GL context."
  ;; ── Delta-time for animated colour modes ────────────────────────────────────
  (let* ((now (get-internal-real-time))
         (dt  (if (zerop *last-frame-time*) 0.016
                  (/ (float (- now *last-frame-time*))
                     internal-time-units-per-second))))
    (setf *last-frame-time* now)
    (tick-colour! dt))
  (when *geometry-dirty* (rebuild-geometry!))
  (gl:clear-color 0.05 0.05 0.08 1.0)
  (gl:clear :color-buffer-bit :depth-buffer-bit)
  ;; ── Ground grid ─────────────────────────────────────────────────────────────
  (when *show-grid*
    (gl:line-width 1.0)
    (gl:begin :lines)
    (gl:color 0.10 0.10 0.15)
    (loop for i from -200 to 200 by 10 do
      (gl:vertex (float i) 0.0 -200.0) (gl:vertex (float i) 0.0  200.0)
      (gl:vertex -200.0 0.0 (float i)) (gl:vertex  200.0 0.0 (float i)))
    (gl:end))
  ;; ── World geometry ───────────────────────────────────────────────────────────
  (let ((verts *cached-verts*)
        (edges *cached-edges*))
    (when (and (plusp (length verts)) (plusp (length edges)))
      (let* ((ys    (map 'vector #'second verts))
             (y-min (reduce #'min ys))
             (y-max (reduce #'max ys)))
        (gl:line-width *wire-line-width*)
        (gl:begin :lines)
        (loop for edge across edges do
          (let* ((i  (first  edge))
                 (j  (second edge))
                 (v0 (aref verts i))
                 (v1 (aref verts j)))
            (set-wire-colour v0 v1 y-min y-max)
            (gl:vertex (first v0) (second v0) (third v0))
            (set-wire-colour v1 v0 y-min y-max)
            (gl:vertex (first v1) (second v1) (third v1))))
        (gl:end))))
  ;; ── Overlay: gizmo + reference circles ──────────────────────────────────────
  (draw-gizmo-overlay)
  ;; ── In-window GUI overlay ───────────────────────────────────────────────────
  (draw-ui! win width height))

;;; ─── Screenshot (portable PPM) ──────────────────────────────────────────────

(defun take-screenshot (win)
  "Save the current framebuffer as a PPM image to /tmp/babel-TIMESTAMP.ppm.
   Pure Lisp — no cffi memcpy, no SDL surface required."
  (declare (ignore win))
  (let* ((ts    (get-universal-time))
         (path  (namestring (babel-out (format nil "babel-~A.ppm" ts))))
         (w     *window-width*)
         (h     *window-height*)
         (total (* w h 3)))
    (handler-case
        (let ((pixels (make-array total :element-type '(unsigned-byte 8))))
          (gl:pixel-store :pack-alignment 1)
          (gl:read-pixels 0 0 w h :rgb :unsigned-byte pixels)
          (with-open-file (f path :direction :output
                               :if-exists :supersede
                               :element-type '(unsigned-byte 8))
            ;; PPM header (ASCII)
            (let ((header (format nil "P6~%~D ~D~%255~%" w h)))
              (loop for ch across header do
                (write-byte (char-code ch) f)))
            ;; Pixel rows — OpenGL origin is bottom-left, PPM is top-left
            (loop for row from (1- h) downto 0 do
              (let ((base (* row w 3)))
                (loop for col from 0 below (* w 3) do
                  (write-byte (aref pixels (+ base col)) f)))))
          (format t "~&[BABEL] Screenshot → ~A~%" path))
      (error (e)
        (format t "~&[BABEL] Screenshot failed: ~A~%" e)))))

(defun init-gl (win gl-ctx width height)
  (sdl2:gl-make-current win gl-ctx)
  (gl:viewport 0 0 width height)
  (gl:enable :depth-test)
  (gl:depth-func :lequal)
  (gl:enable :line-smooth)
  (gl:hint :line-smooth-hint :nicest)
  (gl:line-width 1.2)
  (apply-camera *camera* width height))

;;; ─── GUI status/help trigger ────────────────────────────────────────────────

(defun print-hud ()
  "Show the in-window help/status GUI instead of printing a terminal HUD."
  (setf *ui-show-help* t
        *ui-enabled* t)
  (ui-message! "GUI HUD enabled"))

;;; ─── Main event loop ─────────────────────────────────────────────────────────

(defun run-event-loop (win)
  "SDL2 event loop. Handles input and renders frames."
  (let ((width  *window-width*)
        (height *window-height*))
    (sdl2:with-event-loop (:method :poll)

      (:quit () t)

      (:keydown (:keysym keysym)
       (let ((key (sdl2:scancode-value keysym))
             (camera-dirty nil))
         (unless (ui-handle-key key)
           (cond
           ;; ESC = quit
           ((sdl2:scancode= key :scancode-escape)
            (sdl2:push-quit-event))
           ;; R = reset camera
           ((sdl2:scancode= key :scancode-r)
            (camera-reset! *camera*)
            (setf camera-dirty t))
           ;; 1–7 scene switch
           ((sdl2:scancode= key :scancode-1) (set-scene! 0))
           ((sdl2:scancode= key :scancode-2) (set-scene! 1))
           ((sdl2:scancode= key :scancode-3) (set-scene! 2))
           ((sdl2:scancode= key :scancode-4) (set-scene! 3))
           ((sdl2:scancode= key :scancode-5) (set-scene! 4))
           ((sdl2:scancode= key :scancode-6) (set-scene! 5))
           ((sdl2:scancode= key :scancode-7) (set-scene! 6))
           ((sdl2:scancode= key :scancode-8) (set-scene! 7))
           ((sdl2:scancode= key :scancode-9) (set-scene! 8))
           ((sdl2:scancode= key :scancode-0) (set-scene! 9))
           ((sdl2:scancode= key :scancode-f1) (set-scene! 10))
           ;; Arrow keys: prev / next scene
           ((sdl2:scancode= key :scancode-left)  (prev-scene!))
           ((sdl2:scancode= key :scancode-right) (next-scene!))
           ;; G = grow next AI layer (in background thread)
           ((sdl2:scancode= key :scancode-g)
            (let ((next-layer (ui-next-layer-index)))
              (ui-message! "Inventing layer ~D..." next-layer)
              (bordeaux-threads:make-thread
               (lambda ()
                 (invent-layer! next-layer 20 4)
                 (setf *geometry-dirty* t)
                 (ui-message! "Layer ~D complete" next-layer))
               :name "babel-inventor")))
           ;; E = evolve
           ((sdl2:scancode= key :scancode-e)
            (evolve!)
            (setf *geometry-dirty* t))
           ;; S = save library
           ((sdl2:scancode= key :scancode-s)
            (export-library (babel-out "babel-library.lisp")))
           ;; P = save current world as .world file
           ((sdl2:scancode= key :scancode-p)
            (let ((path (babel-out "babel-world.world")))
              (save-world-file! path "quicksave")
              (format t "~&[BABEL] World → ~A~%" path)))
           ;; F12 = screenshot
           ((sdl2:scancode= key :scancode-f12)
            (take-screenshot win))
           ;; W = export OBJ
           ((sdl2:scancode= key :scancode-w)
            (export-obj!))
           ;; V = export quad SVG
           ((sdl2:scancode= key :scancode-v)
            (export-svg-quad!))
           ;; C = cycle colour mode
           ((sdl2:scancode= key :scancode-c)
            (next-colour-mode!))
           ;; X = toggle axis gizmo
           ((sdl2:scancode= key :scancode-x)
            (setf *show-gizmo* (not *show-gizmo*))
            (format t "~&[BABEL] Gizmo ~A~%" (if *show-gizmo* "ON" "OFF")))
           ;; O = toggle origin circles
           ((sdl2:scancode= key :scancode-o)
            (setf *show-origin* (not *show-origin*)))
           ;; Z = undo last world change
           ((sdl2:scancode= key :scancode-z)
            (world-undo!))
           ;; H = in-window help/status
           ((sdl2:scancode= key :scancode-h)
            (print-hud))
           ;; IJKL pan
           ((sdl2:scancode= key :scancode-i)
            (camera-pan! *camera*  0  5) (setf camera-dirty t))
           ((sdl2:scancode= key :scancode-k)
            (camera-pan! *camera*  0 -5) (setf camera-dirty t))
           ((sdl2:scancode= key :scancode-j)
            (camera-pan! *camera* -5  0) (setf camera-dirty t))
           ((sdl2:scancode= key :scancode-l)
            (camera-pan! *camera*  5  0) (setf camera-dirty t))))
         (when camera-dirty
           (apply-camera *camera* width height))))

      (:textinput (:text text)
       (ui-handle-text-input text))

      (:mousebuttondown (:button button :x x :y y)
       (unless (ui-handle-mouse-down x y win)
         (cond
           ((= button 1)   ; SDL_BUTTON_LEFT
            (setf *mouse-left-down* t *mouse-last-x* x *mouse-last-y* y))
           ((= button 3)   ; SDL_BUTTON_RIGHT
            (setf *mouse-right-down* t *mouse-last-x* x *mouse-last-y* y)))))

      (:mousebuttonup (:button button :x x :y y)
       (ui-handle-mouse-up x y)
       (cond
         ((= button 1) (setf *mouse-left-down* nil))
         ((= button 3) (setf *mouse-right-down* nil))))

      (:mousemotion (:x x :y y)
       (ui-handle-mouse-motion x y)
       (unless *ui-mouse-captured*
         (let ((dx (- x *mouse-last-x*))
               (dy (- y *mouse-last-y*)))
           (cond
             (*mouse-left-down*
              (camera-orbit! *camera* dx dy))
             (*mouse-right-down*
              (camera-pan! *camera* (- dx) dy)))
           (setf *mouse-last-x* x *mouse-last-y* y)
           (apply-camera *camera* width height))))

      (:mousewheel (:y y)
       (unless (ui-handle-mouse-wheel y)
         (camera-zoom! *camera* (float y))
         (apply-camera *camera* width height)))

      (:windowevent (:event event :data1 d1 :data2 d2)
       ;; SDL_WINDOWEVENT_RESIZED = 5
       (when (= event 5)
         (setf width d1
               height d2
               *window-width* d1
               *window-height* d2)
         (gl:viewport 0 0 width height)
         (apply-camera *camera* width height)))

      (:idle ()
       (render-frame win width height)
       (update-fps! win)
       (sdl2:gl-swap-window win)))))

;;; ─── Top-level entry point ───────────────────────────────────────────────────

(defun run ()
  "Open the BABEL window and start the event loop."
  ;; Bootstrap vocabulary if not already done
  (when (zerop (hash-table-count *babel-registry*))
    (bootstrap-vocabulary!))
  ;; Load default scene
  (set-scene! 0)
  (sdl2:make-this-thread-main
   (lambda ()
     (sdl2:with-init (:video)
       (sdl2:gl-set-attr :context-major-version 2)
       (sdl2:gl-set-attr :context-minor-version 1)
       (sdl2:gl-set-attr :doublebuffer 1)
       (sdl2:gl-set-attr :depth-size 24)
       (sdl2:with-window (win
                          :title *window-title*
                          :w *window-width* :h *window-height*
                          :flags '(:shown :opengl :resizable))
         (sdl2:with-gl-context (gl-ctx win)
           (init-gl win gl-ctx *window-width* *window-height*)
           (print-hud)
           (run-event-loop win)))))))
