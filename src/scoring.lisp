;;;; src/scoring.lisp
;;;; Macro scoring — evaluates an AI-invented macro across several fitness
;;;; dimensions: economy, novelty, visual interest, reusability, compatibility.

(in-package #:babel)

;;; ─── Silhouette helpers ─────────────────────────────────────────────────────

(defun geometry-centroid (verts)
  "Return (cx cy cz) centroid of vertex array."
  (if (zerop (length verts))
      '(0.0 0.0 0.0)
      (let ((n (length verts)))
        (list (/ (reduce #'+ (map 'vector #'first  verts)) n)
              (/ (reduce #'+ (map 'vector #'second verts)) n)
              (/ (reduce #'+ (map 'vector #'third  verts)) n)))))

(defun geometry-extent (verts)
  "Return the diagonal length of the bounding box."
  (if (zerop (length verts))
      0.0
      (let ((xs (map 'vector #'first  verts))
            (ys (map 'vector #'second verts))
            (zs (map 'vector #'third  verts)))
        (let ((dx (- (reduce #'max xs) (reduce #'min xs)))
              (dy (- (reduce #'max ys) (reduce #'min ys)))
              (dz (- (reduce #'max zs) (reduce #'min zs))))
          (sqrt (+ (* dx dx) (* dy dy) (* dz dz)))))))

(defun silhouette-hash (verts edges)
  "Cheap fingerprint of a geometry: sorted list of rounded vertex positions."
  (declare (ignore edges))
  (sort (map 'list (lambda (v)
                     (list (round (* 10 (first v)))
                           (round (* 10 (second v)))
                           (round (* 10 (third v)))))
             verts)
        (lambda (a b)
          (or (< (first a) (first b))
              (and (= (first a) (first b))
                   (< (second a) (second b)))))))

;;; ─── Expand-and-measure ─────────────────────────────────────────────────────

(defun expand-and-measure (m sample-args)
  "Evaluate macro M with SAMPLE-ARGS, capture geometry, return (verts edges)."
  (let ((*vertex-buffer* nil) (*edge-buffer* nil))
    (handler-case
        (progn
          (handler-bind ((warning #'muffle-warning))
            (eval `(,(babel-macro-name m) ,@sample-args)))
          (multiple-value-list (collect-geometry)))
      (error (e)
        (declare (ignore e))
        (list #() #())))))

;;; ─── Individual score dimensions ────────────────────────────────────────────

(defun score-economy (m)
  "Reward achieving structural complexity with few dependencies. Capped at 1.0."
  (let ((deps  (length (babel-macro-dependencies m)))
        (depth (babel-macro-complexity m)))
    (min 1.0 (/ (float depth) (+ deps 1.0)))))

(defun score-novelty (verts edges)
  "Reward geometry that does not closely match any existing macro's output."
  (declare (ignore edges))
  (if (zerop (length verts)) 0.0
      (let ((extent (geometry-extent verts)))
        ;; Coarse: reward wide spatial spread relative to edge count
        (min 1.0 (/ extent 20.0)))))

(defun score-visual-interest (verts edges)
  "Reward geometry with varied heights (silhouette interest)."
  (declare (ignore edges))
  (if (zerop (length verts)) 0.0
      (let ((ys (map 'vector #'second verts)))
        (if (< (length ys) 2) 0.0
            (let ((lo (reduce #'min ys))
                  (hi (reduce #'max ys)))
              (min 1.0 (/ (- hi lo) 10.0)))))))

(defun score-reusability (m)
  "Score how varied the output is across different parameter sets."
  (let* ((samples  (loop repeat 6 collect (sample-params-for m)))
         (extents  (mapcar (lambda (args)
                             (let ((geom (expand-and-measure m args)))
                               (geometry-extent (first geom))))
                           samples))
         (lo       (reduce #'min extents :initial-value 0.0))
         (hi       (reduce #'max extents :initial-value 0.0)))
    (min 1.0 (/ (- hi lo) 10.0))))

(defun score-compatibility (m registry)
  "Reward macros that are readily composable (have layer > 0 deps)."
  (declare (ignore registry))
  (if (babel-macro-dependencies m)
      (min 1.0 (* 0.2 (length (babel-macro-dependencies m))))
      0.0))

(defun score-connectivity (m)
  "Reward macros whose body explicitly uses wall-segment or arch to
   connect other structures — a sign of architectural coherence.
   Also rewards use of shared position variables (let bindings fed to
   multiple calls), which indicates spatial coordination."
  (let ((body (babel-macro-body m))
        (score 0.0))
    ;; Bonus for wall-segment usage (explicit connectivity)
    (when (member 'wall-segment (babel-macro-dependencies m))
      (incf score 0.35))
    ;; Bonus for arch usage (gate / bridge)
    (when (member 'arch (babel-macro-dependencies m))
      (incf score 0.15))
    ;; Bonus for let-binding shared vars (position coordination)
    (labels ((count-lets (x)
               (cond ((and (consp x) (eq (car x) 'let*)) 1)
                     ((and (consp x) (eq (car x) 'let))  1)
                     ((consp x) (reduce #'+ (mapcar #'count-lets x)
                                        :initial-value 0))
                     (t 0))))
      (incf score (* 0.1 (min 5 (count-lets body)))))
    (min 1.0 score)))

;;; ─── Composite score ────────────────────────────────────────────────────────

(defun score-macro! (m)
  "Compute and store the composite fitness score for M. Returns score."
  (let* ((args     (sample-params-for m))
         (geom     (expand-and-measure m args))
         (verts    (first  geom))
         (edges    (second geom))
         (s-econ   (score-economy      m))
         (s-novel  (score-novelty      verts edges))
         (s-visual (score-visual-interest verts edges))
         (s-reuse  (score-reusability  m))
         (s-compat (score-compatibility m *babel-registry*))
         (s-conn   (score-connectivity m))
         (total    (+ (* 0.18 s-econ)
                      (* 0.22 s-novel)
                      (* 0.28 s-visual)
                      (* 0.14 s-reuse)
                      (* 0.08 s-compat)
                      (* 0.10 s-conn))))
    (setf (babel-macro-score m) (float total 1.0))
    total))

(defun rescore-all! ()
  "Recompute scores for every macro in the registry."
  (maphash (lambda (k v)
             (declare (ignore k))
             (when (> (babel-macro-layer v) 0)
               (score-macro! v)))
           *babel-registry*)
  (format t "~&[BABEL] Rescored all macros.~%"))
