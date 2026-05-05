;;;; src/colour.lisp — Wireframe colour modes (7 modes, cycled with C)

(in-package #:babel)

(defparameter *colour-modes*
  '(:depth :normal :layer :heat :mono :pulse :rainbow)
  "Available colour modes in cycle order.")

(defvar *colour-mode* :depth)
(defvar *colour-pulse-phase* 0.0)

(defvar *colour-layer-map*
  '((0 . (0.30 0.30 0.40))
    (1 . (0.20 0.70 0.60))
    (2 . (0.30 0.80 0.30))
    (3 . (0.90 0.70 0.10))
    (4 . (0.90 0.40 0.10))
    (5 . (0.80 0.20 0.50))
    (6 . (0.50 0.20 0.90))))

;;; ─── HSV → RGB ───────────────────────────────────────────────────────────────

(defun hsv->rgb (h s v)
  "Convert HSV (all 0..1) to (values r g b), all single-float."
  (let* ((h6 (* (float h 1.0) 6.0))
         (i  (floor h6))
         (f  (- h6 (float i 1.0)))
         (p  (* v (- 1.0 s)))
         (q  (* v (- 1.0 (* s f))))
         (tv (* v (- 1.0 (* s (- 1.0 f))))))
    (case (mod i 6)
      (0 (values v  tv p))
      (1 (values q  v  p))
      (2 (values p  v  tv))
      (3 (values p  q  v))
      (4 (values tv p  v))
      (t (values v  p  q)))))

;;; ─── Cycle ───────────────────────────────────────────────────────────────────

(defun next-colour-mode! ()
  (let* ((pos  (position *colour-mode* *colour-modes*))
         (next (nth (mod (1+ (or pos 0)) (length *colour-modes*))
                    *colour-modes*)))
    (setf *colour-mode* next)
    (when (fboundp 'ui-message!)
      (ui-message! "Colour mode: ~A" next))))

;;; ─── Per-vertex colour ───────────────────────────────────────────────────────

(defun set-wire-colour (v0 v1 y-min y-max &optional (edge-layer 0))
  "Set gl:color for vertex V0 of an edge toward V1."
  (let* ((y  (float (second v0) 1.0))
         (t1 (if (= y-min y-max) 0.5
                 (max 0.0 (min 1.0 (/ (- y y-min)
                                      (- y-max y-min)))))))
    (ecase *colour-mode*

      (:depth
       (gl:color 0.0 (+ 0.45 (* 0.55 t1)) (+ 0.45 (* 0.55 t1))))

      (:normal
       ;; Edge XZ direction → hue. Guard against zero-length edges.
       (let* ((dx  (- (float (first  v1) 1.0) (float (first  v0) 1.0)))
              (dz  (- (float (third  v1) 1.0) (float (third  v0) 1.0)))
              (len (sqrt (+ (* dx dx) (* dz dz))))
              (h   (if (< len 1.0e-6) 0.0
                       (/ (+ (atan dz dx) (float pi 1.0))
                          (* 2.0 (float pi 1.0))))))
         (multiple-value-bind (r g b) (hsv->rgb h 0.8 0.9)
           (gl:color r g b))))

      (:layer
       (let ((rgb (cdr (assoc (min edge-layer 6) *colour-layer-map*))))
         (if rgb
             (gl:color (first rgb) (second rgb) (third rgb))
             (gl:color 0.7 0.7 0.7))))

      (:heat
       (gl:color t1 (* 0.3 (- 1.0 (abs (- t1 0.5)))) (- 1.0 t1)))

      (:mono
       (gl:color 0.75 0.75 0.78))

      (:pulse
       (let* ((w (+ 0.5 (* 0.5 (sin (+ (* t1 6.283) *colour-pulse-phase*)))))
              (g (+ 0.3 (* 0.7 w)))
              (b (+ 0.5 (* 0.5 w))))
         (gl:color 0.0 g b)))

      (:rainbow
       (multiple-value-bind (r g b)
           (hsv->rgb (mod (+ t1 *colour-pulse-phase*) 1.0) 0.85 0.95)
         (gl:color r g b))))))

(defun tick-colour! (dt)
  (let ((spd (* (float dt 1.0) 2.5)))
    (incf *colour-pulse-phase* spd)
    (when (> *colour-pulse-phase* (* 2.0 (float pi 1.0)))
      (decf *colour-pulse-phase* (* 2.0 (float pi 1.0))))))
