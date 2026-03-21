;;;; src/gizmo.lisp — Screen-corner XYZ axis gizmo + ground reference rings.

(in-package #:babel)

(defvar *show-gizmo*  t "Toggle axis gizmo with X key.")
(defvar *show-origin* t "Toggle ground reference rings with O key.")

;;; ─── Corner gizmo ────────────────────────────────────────────────────────────
;;; We draw the gizmo in a small sub-viewport at the bottom-left so it
;;; always appears in the corner regardless of camera position.

(defun draw-axis-gizmo (width height)
  "Draw a small XYZ axis indicator in the bottom-left corner of the screen."
  (when *show-gizmo*
    (let* ((size 80)        ; sub-viewport size in pixels
           (pad  10))       ; padding from screen edge
      ;; Switch to a small corner viewport
      (gl:viewport pad pad size size)
      (gl:matrix-mode :projection)
      (gl:push-matrix)
      (gl:load-identity)
      (glu:perspective 40.0d0 1.0d0 0.1d0 100.0d0)
      (gl:matrix-mode :modelview)
      (gl:push-matrix)
      (gl:load-identity)
      ;; Copy only the rotation from the camera (ignore translation/zoom)
      (let* ((cam   *camera*)
             (yr    (* (float (camera-yaw   cam) 1.0) (float (/ pi 180) 1.0)))
             (pr    (* (float (camera-pitch cam) 1.0) (float (/ pi 180) 1.0)))
             (ex    (* 3.0 (cos pr) (sin yr)))
             (ey    (* 3.0 (sin pr)))
             (ez    (* 3.0 (cos pr) (cos yr))))
        (glu:look-at (float ex 1.0d0) (float ey 1.0d0) (float ez 1.0d0)
                     0.0d0 0.0d0 0.0d0
                     0.0d0 1.0d0 0.0d0))
      (gl:clear :depth-buffer-bit)
      (gl:line-width 2.5)
      (gl:begin :lines)
      ;; X — red
      (gl:color 0.95 0.25 0.25)
      (gl:vertex 0.0 0.0 0.0) (gl:vertex 1.0 0.0 0.0)
      ;; Y — green
      (gl:color 0.25 0.90 0.25)
      (gl:vertex 0.0 0.0 0.0) (gl:vertex 0.0 1.0 0.0)
      ;; Z — blue
      (gl:color 0.25 0.45 0.95)
      (gl:vertex 0.0 0.0 0.0) (gl:vertex 0.0 0.0 1.0)
      (gl:end)
      (gl:line-width 1.2)
      ;; Restore matrices and viewport
      (gl:matrix-mode :projection)
      (gl:pop-matrix)
      (gl:matrix-mode :modelview)
      (gl:pop-matrix)
      (gl:viewport 0 0 width height))))

;;; ─── Ground reference rings ──────────────────────────────────────────────────

(defun draw-origin-circle (radius steps)
  (when *show-origin*
    (gl:begin :line-loop)
    (gl:color 0.20 0.20 0.30)
    (dotimes (i steps)
      (let ((theta (* 2.0 (float pi 1.0) (/ (float i 1.0) steps))))
        (gl:vertex (* radius (cos theta)) 0.001 (* radius (sin theta)))))
    (gl:end)))

(defun draw-gizmo-overlay ()
  (draw-origin-circle  50.0 64)
  (draw-origin-circle 100.0 64)
  (draw-origin-circle 150.0 64)
  ;; Gizmo last so it draws on top in its own viewport
  (draw-axis-gizmo *window-width* *window-height*))
