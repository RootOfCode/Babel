;;;; src/camera.lisp
;;;; Orbital camera around the world origin.
;;;;
;;;; Controls:
;;;;   Left-drag  — orbit (yaw / pitch)
;;;;   Right-drag — pan
;;;;   Scroll     — zoom
;;;;   R          — reset
;;;;   WASD       — nudge pan
;;;;   1–4        — jump to example scenes

(in-package #:babel)

(defstruct camera
  (yaw       30.0   :type single-float)   ; degrees around Y axis
  (pitch     25.0   :type single-float)   ; degrees of elevation
  (distance  80.0   :type single-float)   ; distance from target
  (target-x  0.0    :type single-float)
  (target-y  0.0    :type single-float)
  (target-z  0.0    :type single-float)
  (fov       45.0   :type single-float))

(defvar *camera* (make-camera)
  "The global camera used by the renderer.")

;;; ─── Apply camera to GL matrices ────────────────────────────────────────────

(defun apply-camera (cam width height)
  "Set the OpenGL projection and model-view matrices for CAM."
  (gl:matrix-mode :projection)
  (gl:load-identity)
  (glu:perspective (float (camera-fov cam) 1.0d0)
                   (float (/ (float width) (float height)) 1.0d0)
                   0.1d0
                   2000.0d0)
  (gl:matrix-mode :modelview)
  (gl:load-identity)
  (let* ((yaw   (camera-yaw   cam))
         (pitch (camera-pitch cam))
         (dist  (camera-distance cam))
         (tx    (camera-target-x cam))
         (ty    (camera-target-y cam))
         (tz    (camera-target-z cam))
         ;; Force single-float before trig so results are predictable
         (yr    (* (float yaw   1.0) (float (/ pi 180) 1.0)))
         (pr    (* (float pitch 1.0) (float (/ pi 180) 1.0)))
         (ex    (* dist (cos pr) (sin yr)))
         (ey    (* dist (sin pr)))
         (ez    (* dist (cos pr) (cos yr))))
    (glu:look-at (float (+ tx ex) 1.0d0)
                 (float (+ ty ey) 1.0d0)
                 (float (+ tz ez) 1.0d0)
                 (float tx 1.0d0)
                 (float ty 1.0d0)
                 (float tz 1.0d0)
                 0.0d0 1.0d0 0.0d0)))

;;; ─── Camera input helpers ────────────────────────────────────────────────────

(defun camera-orbit! (cam dx dy)
  (incf (camera-yaw   cam) (* (float dx 1.0) 0.4))
  (setf (camera-pitch cam)
        (max -89.0 (min 89.0 (+ (camera-pitch cam)
                                (* (float dy 1.0) 0.4))))))

(defun camera-zoom! (cam delta)
  (setf (camera-distance cam)
        (max 2.0 (min 1000.0 (+ (camera-distance cam)
                                (* (float delta 1.0) -3.0))))))

(defun camera-pan! (cam dx dy)
  "Pan in the camera's ground plane."
  (let* ((yr    (* (camera-yaw cam) (float (/ pi 180) 1.0)))
         (rx    (cos yr))
         (rz    (- (sin yr)))
         (speed (* (camera-distance cam) 0.005))
         (fdx   (float dx 1.0))
         (fdy   (float dy 1.0)))
    (incf (camera-target-x cam) (float (* fdx speed rx) 1.0))
    (incf (camera-target-z cam) (float (* fdx speed rz) 1.0))
    (incf (camera-target-y cam) (float (* fdy speed)    1.0))))

(defun camera-reset! (cam)
  (setf (camera-yaw       cam) 30.0
        (camera-pitch     cam) 25.0
        (camera-distance  cam) 80.0
        (camera-target-x  cam) 0.0
        (camera-target-y  cam) 0.0
        (camera-target-z  cam) 0.0))
