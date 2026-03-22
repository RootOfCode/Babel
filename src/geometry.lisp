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

;;; ─── Wall-segment emitter ────────────────────────────────────────────────────

(defun emit-wall-segment-edges (x0 z0 x1 z1 y-base height thickness)
  "Emit a rectangular wall panel whose base runs from (X0,Z0) to (X1,Z1),
   rising from Y-BASE to Y-BASE+HEIGHT with the given THICKNESS.
   The thickness is extruded perpendicular to the wall direction in the XZ plane."
  (let* ((dx  (- (float x1) (float x0)))
         (dz  (- (float z1) (float z0)))
         (len (max 0.001 (sqrt (+ (* dx dx) (* dz dz)))))
         ;; Inward-perpendicular unit vector
         (px  (/ (- dz) len))
         (pz  (/ dx  len))
         (ht  (/ (float thickness) 2.0))
         (y0  (float y-base))
         (y1  (+ y0 (float height)))
         (ax0 (float x0)) (az0 (float z0))
         (ax1 (float x1)) (az1 (float z1)))
    (emit-edges
     (list
      ;; Bottom face — 4 corners
      (list (+ ax0 (* px ht)) y0 (+ az0 (* pz ht)))   ; 0 near-start-bottom
      (list (+ ax1 (* px ht)) y0 (+ az1 (* pz ht)))   ; 1 near-end-bottom
      (list (- ax1 (* px ht)) y0 (- az1 (* pz ht)))   ; 2 far-end-bottom
      (list (- ax0 (* px ht)) y0 (- az0 (* pz ht)))   ; 3 far-start-bottom
      ;; Top face — 4 corners
      (list (+ ax0 (* px ht)) y1 (+ az0 (* pz ht)))   ; 4 near-start-top
      (list (+ ax1 (* px ht)) y1 (+ az1 (* pz ht)))   ; 5 near-end-top
      (list (- ax1 (* px ht)) y1 (- az1 (* pz ht)))   ; 6 far-end-top
      (list (- ax0 (* px ht)) y1 (- az0 (* pz ht))))  ; 7 far-start-top
     '((0 1)(1 2)(2 3)(3 0)                            ; bottom ring
       (4 5)(5 6)(6 7)(7 4)                            ; top ring
       (0 4)(1 5)(2 6)(3 7)                            ; verticals
       (0 2)(1 3)))))                                  ; bottom diagonals (cross-bracing)

;;; ─── Hemisphere emitter ──────────────────────────────────────────────────────

(defun emit-hemisphere-edges (x y z r steps)
  "Emit a wireframe hemisphere (upper half-sphere) sitting ON the plane y=Y.
   Phi runs from 0 (top/north-pole) to pi/2 (equator) only.
   The equator ring at y is the base — no bottom cap is drawn."
  (let* ((lat-steps  steps)
         (lon-steps  (* 2 steps))
         (vertices   '())
         (edges      '()))
    ;; Build vertex grid: phi 0 → pi/2  (top pole → equator)
    (dotimes (i (1+ lat-steps))
      (let ((phi (* (/ pi 2.0) (/ i lat-steps))))   ; 0 … π/2
        (dotimes (j lon-steps)
          (let ((theta (* 2.0 pi (/ j lon-steps))))
            (push (list (+ x (* r (sin phi) (cos theta)))
                        (+ y (* r (cos phi)))        ; y=y+r at pole, y=y at equator
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

;;; ─── Cylinder ────────────────────────────────────────────────────────────────

(defun emit-cylinder-edges (x y z r h steps)
  "Vertical cylinder centred at X Y Z, radius R, height H, STEPS facets.
   Emits bottom ring, top ring, and vertical lines. No caps."
  (let ((verts '()) (edges '()) (n steps))
    (dotimes (i n)
      (let* ((theta (* 2.0 pi (/ i n)))
             (px (+ x (* r (cos theta))))
             (pz (+ z (* r (sin theta)))))
        (push (list px (float y)       pz) verts)   ; bottom ring: 0..n-1
        (push (list px (+ y (float h)) pz) verts))) ; top ring:    n..2n-1
    (setf verts (nreverse verts))
    ;; Bottom ring
    (dotimes (i n)
      (push (list (* 2 i) (* 2 (mod (1+ i) n))) edges))
    ;; Top ring
    (dotimes (i n)
      (push (list (1+ (* 2 i)) (1+ (* 2 (mod (1+ i) n)))) edges))
    ;; Verticals
    (dotimes (i n)
      (push (list (* 2 i) (1+ (* 2 i))) edges))
    (emit-edges verts (nreverse edges))))

;;; ─── Pyramid ─────────────────────────────────────────────────────────────────

(defun emit-pyramid-edges (x y z base-w base-d height)
  "Square-base pyramid. Base centred at X Y Z, apex at X Y+HEIGHT Z."
  (let* ((hw (/ (float base-w) 2.0))
         (hd (/ (float base-d) 2.0))
         (by (float y))
         (ty (+ by (float height))))
    (emit-edges
     (list (list (- x hw) by (- z hd))   ; 0 base SW
           (list (+ x hw) by (- z hd))   ; 1 base SE
           (list (+ x hw) by (+ z hd))   ; 2 base NE
           (list (- x hw) by (+ z hd))   ; 3 base NW
           (list (float x) ty (float z))) ; 4 apex
     '((0 1)(1 2)(2 3)(3 0)              ; base ring
       (0 4)(1 4)(2 4)(3 4)))))          ; lateral edges

;;; ─── Barrel vault ────────────────────────────────────────────────────────────

(defun emit-vault-edges (x y z span length steps)
  "Barrel vault: a semicircular arch extruded LENGTH along Z.
   Centre of the vault runs from (X Y Z) to (X Y Z+LENGTH).
   SPAN is the total width (chord), rise = span/2."
  (let* ((r     (/ (float span) 2.0))
         (verts '())
         (edges '())
         (n     steps)
         (nz    (max 2 (round (/ (float length) r)))))  ; arch count along length
    ;; Build vertex grid: n+1 points per arch × nz+1 arches
    (dotimes (iz (1+ nz))
      (let ((pz (+ z (* (float length) (/ iz nz)))))
        (dotimes (ia (1+ n))
          (let* ((theta (+ (* pi (/ ia n))))      ; π → 2π : left→right overhead
                 (px    (+ x (* r (cos theta))))
                 (py    (+ y r (* r (sin (- theta pi))))))
            (push (list px py pz) verts)))))
    (setf verts (nreverse verts))
    (let ((row (1+ n)))
      ;; Arch ribs (along theta)
      (dotimes (iz (1+ nz))
        (dotimes (ia n)
          (push (list (+ (* iz row) ia)
                      (+ (* iz row) ia 1)) edges)))
      ;; Longitudinal lines (along Z)
      (dotimes (ia (1+ n))
        (dotimes (iz nz)
          (push (list (+ (* iz row) ia)
                      (+ (* (1+ iz) row) ia)) edges))))
    (emit-edges verts (nreverse edges))))

;;; ─── Staircase ───────────────────────────────────────────────────────────────

(defun emit-staircase-edges (x y z width n-steps step-h step-d)
  "Staircase rising along +Z. N-STEPS steps, each STEP-H high and STEP-D deep.
   Width runs along X, centred on X. Bottom-front corner at X Y Z."
  (let ((hw  (/ (float width) 2.0))
        (verts '()) (edges '()))
    (dotimes (i (1+ n-steps))
      (let ((sy (+ y (* i (float step-h))))
            (sz (+ z (* i (float step-d)))))
        ;; Left and right corners of this step's front edge
        (push (list (- x hw) sy sz) verts)   ; 2i   left
        (push (list (+ x hw) sy sz) verts))) ; 2i+1 right
    (setf verts (nreverse verts))
    ;; Horizontal treads (front edge of each step)
    (dotimes (i (1+ n-steps))
      (push (list (* 2 i) (1+ (* 2 i))) edges))
    ;; Left and right side risers + nosing lines
    (dotimes (i n-steps)
      ;; Riser left
      (push (list (* 2 i) (* 2 (1+ i))) edges)
      ;; Riser right
      (push (list (1+ (* 2 i)) (1+ (* 2 (1+ i)))) edges))
    ;; Top landing edge
    (push (list (* 2 n-steps) (1+ (* 2 n-steps))) edges)
    (emit-edges verts (nreverse edges))))

;;; ─── Spire ───────────────────────────────────────────────────────────────────

(defun emit-spire-edges (x y z height base-r sides)
  "Polygonal spire. Base polygon (SIDES faces, radius BASE-R) at Y,
   apex at Y+HEIGHT. Base ring + lateral edges only — looks best with
   sides 4 (square) or 8 (octagonal)."
  (let ((verts '()) (edges '()) (n (max 3 sides)))
    (dotimes (i n)
      (let* ((theta (* 2.0 pi (/ i n)))
             (px    (+ x (* (float base-r) (cos theta))))
             (pz    (+ z (* (float base-r) (sin theta)))))
        (push (list px (float y) pz) verts)))
    ;; Apex
    (push (list (float x) (+ y (float height)) (float z)) verts)
    (setf verts (nreverse verts))
    ;; Base ring
    (dotimes (i n)
      (push (list i (mod (1+ i) n)) edges))
    ;; Lateral edges to apex (index n)
    (dotimes (i n)
      (push (list i n) edges))
    (emit-edges verts (nreverse edges))))

;;; ─── Flying buttress ─────────────────────────────────────────────────────────

(defun emit-flying-buttress-edges (wall-x wall-y wall-z
                                   pier-x pier-y pier-z
                                   thickness)
  "A flying buttress: a shallow arch leaping from (WALL-X WALL-Y WALL-Z)
   to a free-standing pier at (PIER-X PIER-Y PIER-Z). THICKNESS is the
   depth of the arch (extruded along the wall face)."
  (let* ((steps 8)
         (dx    (- (float pier-x) (float wall-x)))
         (dy    (- (float pier-y) (float wall-y)))
         (dz    (- (float pier-z) (float wall-z)))
         ;; Rise: midpoint lifted by half the horizontal distance
         (hdist (sqrt (+ (* dx dx) (* dz dz))))
         (rise  (* 0.55 hdist))
         (verts '()) (edges '()))
    ;; Front arc
    (dotimes (i (1+ steps))
      (let* ((t1  (/ i steps))
             ;; Quadratic Bezier: start → lifted midpoint → end
             (mt  (- 1.0 t1))
             (mx  (+ (float wall-x) (* 0.5 dx)))
             (my  (+ (float wall-y) (* 0.5 dy) rise))
             (mz  (+ (float wall-z) (* 0.5 dz)))
             (px  (+ (* mt mt (float wall-x)) (* 2.0 mt t1 mx) (* t1 t1 (float pier-x))))
             (py  (+ (* mt mt (float wall-y)) (* 2.0 mt t1 my) (* t1 t1 (float pier-y))))
             (pz  (+ (* mt mt (float wall-z)) (* 2.0 mt t1 mz) (* t1 t1 (float pier-z)))))
        (push (list px py pz) verts)))
    ;; Back arc — offset by THICKNESS along the perpendicular
    ;; Perpendicular direction: rotate (dx,dz) by 90°, normalise
    (let* ((perp-len (max 0.001 hdist))
           (ox  (/ (- dz) perp-len))
           (oz  (/ dx     perp-len)))
      (dotimes (i (1+ steps))
        (let* ((t1 (/ i steps))
               (mt (- 1.0 t1))
               (mx  (+ (float wall-x) (* 0.5 dx)))
               (my  (+ (float wall-y) (* 0.5 dy) rise))
               (mz  (+ (float wall-z) (* 0.5 dz)))
               (px  (+ (* mt mt (float wall-x)) (* 2.0 mt t1 mx) (* t1 t1 (float pier-x))))
               (py  (+ (* mt mt (float wall-y)) (* 2.0 mt t1 my) (* t1 t1 (float pier-y))))
               (pz  (+ (* mt mt (float wall-z)) (* 2.0 mt t1 mz) (* t1 t1 (float pier-z)))))
          (push (list (+ px (* ox (float thickness)))
                      py
                      (+ pz (* oz (float thickness))))
                verts))))
    (setf verts (nreverse verts))
    (let ((row (1+ steps)))
      ;; Front arc edges
      (dotimes (i steps)
        (push (list i (1+ i)) edges))
      ;; Back arc edges
      (dotimes (i steps)
        (push (list (+ row i) (+ row i 1)) edges))
      ;; Cross ribs connecting front to back
      (dotimes (i (1+ steps))
        (push (list i (+ row i)) edges)))
    (emit-edges verts (nreverse edges))))
