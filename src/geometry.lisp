;;;; src/geometry.lisp
;;;; Low-level geometry accumulation.
;;;;
;;;; All Layer-0 macros ultimately call EMIT-EDGES which appends vertices and
;;;; edge indices into thread-local dynamic buffers. The renderer drains these
;;;; buffers every frame via gl:begin/:lines.

(in-package #:babel)

;;; ─── Global geometry buffers ────────────────────────────────────────────────
;;; Each entry in *vertex-buffer* is a list (x y z).
;;; Each entry in *edge-buffer*  is a list (i j) — absolute indices into the
;;; vertex buffer at the time the pair was appended.

(defvar *vertex-buffer* nil "Accumulated vertices for the current scene.")
(defvar *edge-buffer*   nil "Accumulated edge pairs (absolute indices).")

(defun clear-geometry! ()
  "Wipe the geometry buffers before a new frame / evaluation."
  (setf *vertex-buffer* nil
        *edge-buffer*   nil))

(defun emit-edges (vertices edge-pairs)
  "Add VERTICES (list of (x y z)) and EDGE-PAIRS (list of (i j)) into the
global buffers. Edge indices in EDGE-PAIRS are relative to this VERTICES list
and are offset by the current buffer size before insertion."
  (let ((offset (length *vertex-buffer*)))
    (setf *vertex-buffer*
          (nconc *vertex-buffer* (mapcar (lambda (v)
                                           (list (float (first  v))
                                                 (float (second v))
                                                 (float (third  v))))
                                         vertices)))
    (dolist (pair edge-pairs)
      (push (list (+ offset (first pair))
                  (+ offset (second pair)))
            *edge-buffer*))))

(defun collect-geometry ()
  "Return (values vertices edges) as simple vectors for the renderer."
  (values (coerce *vertex-buffer* 'vector)
          (coerce (nreverse *edge-buffer*) 'vector)))

;;; ─── Low-level sphere / cone / torus / plane primitives ────────────────────
;;; These are called by the Layer-0 macros that expand to EMIT-EDGES.

(defun emit-sphere-edges (x y z r steps)
  "Emit a wireframe sphere as latitude / longitude rings."
  (let* ((lat-steps  steps)
         (lon-steps  (* 2 steps))
         (vertices   '())
         (edges      '()))
    ;; Build vertex grid
    (dotimes (i (1+ lat-steps))
      (let ((phi (* pi (/ i lat-steps))))
        (dotimes (j lon-steps)
          (let ((theta (* 2.0 pi (/ j lon-steps))))
            (push (list (+ x (* r (sin phi) (cos theta)))
                        (+ y (* r (cos phi)))
                        (+ z (* r (sin phi) (sin theta))))
                  vertices)))))
    (setf vertices (nreverse (coerce vertices 'vector)))
    ;; Latitude rings
    (dotimes (i (1+ lat-steps))
      (dotimes (j lon-steps)
        (let* ((a (+ (* i lon-steps) j))
               (b (+ (* i lon-steps) (mod (1+ j) lon-steps))))
          (push (list a b) edges))))
    ;; Longitude lines
    (dotimes (j lon-steps)
      (dotimes (i lat-steps)
        (let* ((a (+ (* i lon-steps) j))
               (b (+ (* (1+ i) lon-steps) j)))
          (push (list a b) edges))))
    (emit-edges (coerce vertices 'list) (nreverse edges))))

(defun emit-arch-edges (x y z span rise width style)
  "Emit a single arch. STYLE is :roman (semicircle) or :gothic (pointed)."
  (declare (ignore style))                      ; same shape, different feel
  (let* ((steps 12)
         (hw    (/ span 2.0))
         (verts '())
         (edges '()))
    ;; Left column
    (push (list (- x hw) y z) verts)
    (push (list (- x hw) (+ y rise) z) verts)
    ;; Right column
    (push (list (+ x hw) y z) verts)
    (push (list (+ x hw) (+ y rise) z) verts)
    ;; Arch curve (semicircle)
    (dotimes (i (1+ steps))
      (let ((theta (+ pi (* pi (/ i steps)))))  ; π → 2π = left→right
        (push (list (+ x (* hw (cos theta)))
                    (+ y rise (* (/ rise 1.5) (sin (- theta pi))))
                    z)
              verts)))
    (setf verts (nreverse verts))
    ;; Column edges
    (push '(0 1) edges)
    (push '(2 3) edges)
    ;; Arch curve edges
    (let ((base 4))
      (dotimes (i steps)
        (push (list (+ base i) (+ base i 1)) edges)))
    ;; Connect columns to arch ends
    (push (list 1 4) edges)
    (push (list 3 (+ 4 steps)) edges)
    ;; Width duplication (back face)
    (let* ((n (length verts))
           (bverts (mapcar (lambda (v)
                             (list (first v) (second v) (+ (third v) width)))
                           verts))
           (bedges (mapcar (lambda (e) (list (+ n (first e)) (+ n (second e)))) edges))
           (xedges (loop for i below n collect (list i (+ n i)))))
      (emit-edges (append verts bverts) (append edges bedges xedges)))))

(defun emit-plane-edges (cx cz w d y divisions)
  "Emit a flat wireframe grid W × D centred on (CX, Y, CZ)."
  (let* ((verts '())
         (edges '())
         (hw    (/ w 2.0))
         (hd    (/ d 2.0))
         (nx    (1+ divisions))
         (nz    (1+ divisions)))
    ;; Vertices
    (dotimes (iz nz)
      (dotimes (ix nx)
        (let ((px (+ (- cx hw) (* w (/ ix divisions))))
              (pz (+ (- cz hd) (* d (/ iz divisions)))))
          (push (list px (float y) pz) verts))))
    (setf verts (nreverse verts))
    ;; X-axis lines
    (dotimes (iz nz)
      (dotimes (ix (1- nx))
        (push (list (+ (* iz nx) ix) (+ (* iz nx) ix 1)) edges)))
    ;; Z-axis lines
    (dotimes (ix nx)
      (dotimes (iz (1- nz))
        (push (list (+ (* iz nx) ix) (+ (* (1+ iz) nx) ix)) edges)))
    ;; verts already in forward order after nreverse above; don't reverse again
    (emit-edges verts (nreverse edges))))

(defun emit-cone-edges (x y z r h steps)
  "Emit a wireframe cone with STEPS facets."
  (let* ((verts (list (list (float x) (+ (float y) (float h)) (float z)))) ; apex
         (edges '()))
    (dotimes (i steps)
      (let ((theta (* 2.0 pi (/ i steps))))
        (push (list (+ x (* r (cos theta)))
                    (float y)
                    (+ z (* r (sin theta))))
              verts)))
    ;; After nreverse: base ring = indices 0..(steps-1), apex = index steps
    (setf verts (nreverse verts))
    ;; Base ring: 0→1, 1→2, …, (steps-1)→0
    (loop for i from 0 below steps do
      (push (list i (mod (1+ i) steps)) edges))
    ;; Lateral: each base vertex → apex (apex is at index STEPS, not 0)
    (let ((apex steps))
      (loop for i from 0 below steps do
        (push (list i apex) edges)))
    ;; verts already in correct order — do NOT nreverse again
    (emit-edges verts (nreverse edges))))

(defun emit-torus-edges (x y z r tube steps)
  "Emit a wireframe torus with STEPS major × STEPS minor segments."
  (let* ((verts '())
         (edges '())
         (ms    steps)
         (ns    steps))
    (dotimes (i ms)
      (let ((u (* 2.0 pi (/ i ms))))
        (dotimes (j ns)
          (let* ((v     (* 2.0 pi (/ j ns)))
                 (px    (+ x (* (cos u) (+ r (* tube (cos v))))))
                 (py    (+ y (* tube (sin v))))
                 (pz    (+ z (* (sin u) (+ r (* tube (cos v)))))))
            (push (list px py pz) verts)))))
    (setf verts (nreverse (coerce verts 'vector)))
    ;; Major circles
    (dotimes (i ms)
      (dotimes (j ns)
        (let ((a (+ (* i ns) j))
              (b (+ (* i ns) (mod (1+ j) ns))))
          (push (list a b) edges))))
    ;; Minor circles
    (dotimes (i ms)
      (dotimes (j ns)
        (let ((a (+ (* i ns) j))
              (b (+ (* (mod (1+ i) ms) ns) j)))
          (push (list a b) edges))))
    (emit-edges (coerce verts 'list) (nreverse edges))))
