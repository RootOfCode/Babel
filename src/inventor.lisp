;;;; src/inventor.lisp
;;;; The BABEL macro invention engine.
;;;; Selects a composition template, fills its holes with compatible macro
;;;; calls and expressions, validates the result, then returns a candidate
;;;; babel-macro struct ready for registration.

(in-package #:babel)

;;; ─── Composition templates ──────────────────────────────────────────────────

(defparameter *composition-templates*
  '(;; REPETITION: repeat a macro call N times with linear parameter variation
    (repeat-pattern
     :skeleton (loop for STEP-VAR from 0 below COUNT-EXPR
                     do MACRO-CALL-HOLE)
     :holes (:STEP-VAR :COUNT-EXPR :MACRO-CALL-HOLE))

    ;; SEQUENCING: call two macros one after the other
    (sequential
     :skeleton (progn CALL-1 CALL-2)
     :holes (:CALL-1 :CALL-2))

    ;; LOCAL-BINDING: bind a computed value for reuse
    (with-binding
     :skeleton (let ((BIND-VAR BIND-EXPR)) BODY-CALL)
     :holes (:BIND-VAR :BIND-EXPR :BODY-CALL))

    ;; RADIAL: arrange macro calls around a centre
    (radial-arrangement
     :skeleton (loop for ANGLE-VAR from 0 below RADIAL-N
                     do (let ((DX-VAR (* RADIUS-EXPR
                                         (cos (* 2.0 pi (/ ANGLE-VAR RADIAL-N)))))
                              (DZ-VAR (* RADIUS-EXPR
                                         (sin (* 2.0 pi (/ ANGLE-VAR RADIAL-N))))))
                          MACRO-CALL-HOLE))
     :holes (:ANGLE-VAR :RADIAL-N :RADIUS-EXPR :DX-VAR :DZ-VAR :MACRO-CALL-HOLE))

    ;; VERTICAL STACK: repeat a call at increasing Y offsets
    (vertical-stack
     :skeleton (loop for STACK-STEP from 0 below STACK-COUNT
                     do (let ((STACK-Y (+ Y-BASE-EXPR (* STACK-STEP Y-INC-EXPR))))
                          MACRO-CALL-HOLE))
     :holes (:STACK-STEP :STACK-COUNT :Y-BASE-EXPR :Y-INC-EXPR :STACK-Y :MACRO-CALL-HOLE))

    ;; GRID: arrange macro calls on a 2D XZ grid
    (grid-arrangement
     :skeleton (loop for GX from 0 below GRID-N
                     do (loop for GZ from 0 below GRID-N
                              do (let ((GXP (* GX GRID-SPACING))
                                       (GZP (* GZ GRID-SPACING)))
                                   MACRO-CALL-HOLE)))
     :holes (:GX :GZ :GRID-N :GRID-SPACING :GXP :GZP :MACRO-CALL-HOLE))

    ;; PAIRED-SYMMETRIC: same call twice, mirrored on the X axis
    (paired-symmetric
     :skeleton (progn CALL-1
                      (let ((SYM-X (- 0.0 SX-VAR)))
                        CALL-2))
     :holes (:CALL-1 :SX-VAR :SYM-X :CALL-2))

    ;; BRIDGED: two macro calls with an explicit wall-segment connecting them.
    ;; All positions are inline float literals — no shared variables needed.
    (bridged
     :skeleton (progn
                 MACRO-CALL-A
                 MACRO-CALL-B
                 (wall-segment BRIDGE-X0 BRIDGE-Z0 BRIDGE-X1 BRIDGE-Z1
                               0.0 BRIDGE-H BRIDGE-W))
     :holes (:BRIDGE-X0 :BRIDGE-Z0 :BRIDGE-X1 :BRIDGE-Z1
             :BRIDGE-H :BRIDGE-W :MACRO-CALL-A :MACRO-CALL-B))

    ;; FOUR-CORNERS: four independent macro calls at symmetric corner positions.
    ;; Each call gets its own independently generated arguments.
    (four-corners
     :skeleton (progn
                 CORNER-CALL-A
                 CORNER-CALL-B
                 CORNER-CALL-C
                 CORNER-CALL-D)
     :holes (:CORNER-CALL-A :CORNER-CALL-B :CORNER-CALL-C :CORNER-CALL-D))))

;;; ─── Helper: weighted random sampling ──────────────────────────────────────

(defun weighted-sample (items &key (key #'identity))
  "Sample from ITEMS with probability proportional to (KEY item).
   Falls back to uniform sampling when all weights are zero."
  (when (null items) (return-from weighted-sample nil))
  (let* ((weights (mapcar key items))
         (total   (reduce #'+ weights :initial-value 0.0)))
    (if (zerop total)
        (nth (random (length items)) items)
        (let ((r (* (random 1.0) total)))
          (loop for item in items
                for w    in weights
                do (decf r w)
                when (<= r 0) return item
                finally (return (car (last items))))))))

;;; ─── Hole filling ───────────────────────────────────────────────────────────

(defun random-int-in (lo hi)
  (+ lo (random (max 1 (- hi lo)))))

(defun random-float-in (lo hi)
  (+ lo (* (random 1.0) (- hi lo))))

(defun generate-macro-args (m outer-params)
  "Generate plausible runtime arguments for function M.
   Uses param name heuristics to produce architecturally meaningful values."
  (mapcar (lambda (param)
            (let ((pname (string-downcase (symbol-name param))))
              (cond
                ;; Reuse a caller param 30% of the time
                ((and outer-params (< (random 10) 3))
                 (nth (random (length outer-params)) outer-params))
                ;; Name-based heuristics
                ((or (search "floor" pname) (search "step" pname)
                     (search "count" pname) (search "n-" pname))
                 (float (+ 2 (random 8)) 1.0))
                ((or (search "radius" pname) (search "tube" pname))
                 (random-float-in 1.0 8.0))
                ((or (search "height" pname) (search "rise" pname)
                     (search "h" pname))
                 (random-float-in 2.0 15.0))
                ((or (search "width" pname) (search "len" pname)
                     (search "span" pname) (search "size" pname)
                     (search "w" pname) (search "d" pname))
                 (random-float-in 5.0 40.0))
                ((or (search "amp" pname) (search "scale" pname))
                 (random-float-in 5.0 25.0))
                ((or (search "density" pname) (search "taper" pname))
                 (random-float-in 0.1 0.5))
                ;; wall-segment specific — x0/z0 and x1/z1 should form a span
                ((or (search "x0" pname) (search "z0" pname))
                 (random-float-in -25.0 -5.0))
                ((or (search "x1" pname) (search "z1" pname))
                 (random-float-in 5.0 25.0))
                ((or (search "y-base" pname) (search "ybase" pname))
                 0.0)
                ((search "thickness" pname)
                 (random-float-in 0.5 2.5))
                ;; New primitives
                ((or (search "n-steps" pname) (search "sides" pname))
                 (float (+ 4 (random 10)) 1.0))
                ((search "step-h" pname)
                 (random-float-in 0.3 1.2))
                ((search "step-d" pname)
                 (random-float-in 0.5 1.5))
                ((search "base-r" pname)
                 (random-float-in 1.5 8.0))
                ((or (search "span" pname) (search "base-w" pname)
                     (search "base-d" pname))
                 (random-float-in 5.0 20.0))
                ((search "pier" pname)
                 (random-float-in -20.0 20.0))
                ((or (search "x" pname) (search "z" pname)
                     (search "cx" pname) (search "cz" pname))
                 (random-float-in -20.0 20.0))
                ((or (search "y" pname) (search "cy" pname))
                 (random-float-in 0.0 10.0))
                (t (random-float-in 1.0 12.0)))))
          (babel-macro-params m)))

(defun make-unique-var (prefix)
  (intern (format nil "~A~A" prefix (random 10000)) (find-package :babel)))

(defun fill-template-holes (skeleton holes layer params available-macros)
  "Return a new s-expression with every symbol in HOLES replaced by a
   suitable generated sub-form."
  (let ((form (copy-tree skeleton))
        (bindings (make-hash-table :test 'eq)))
    ;; Pre-generate stable gensym-like variable names
    (dolist (h holes)
      (case h
        ((:STEP-VAR :ANGLE-VAR :STACK-STEP :BIND-VAR :GX :GZ)
         (setf (gethash h bindings) (make-unique-var h)))
        ((:DX-VAR :DZ-VAR :STACK-Y :GXP :GZP)
         (setf (gethash h bindings) (make-unique-var h)))
        ((:COUNT-EXPR :RADIAL-N :STACK-COUNT :GRID-N)
         (setf (gethash h bindings) (random-int-in 2 8)))
        ((:RADIUS-EXPR :Y-INC-EXPR :GRID-SPACING)
         (setf (gethash h bindings) (random-float-in 1.0 12.0)))
        ((:Y-BASE-EXPR :BIND-EXPR)
         (setf (gethash h bindings) (random-float-in 0.0 5.0)))
        ;; Bridged template holes
        ((:B-X0-EXPR :B-Z0-EXPR)
         (setf (gethash h bindings) (random-float-in -30.0 -5.0)))
        ((:B-X1-EXPR :B-Z1-EXPR)
         (setf (gethash h bindings) (random-float-in 5.0 30.0)))
        ((:B-WALL-H)
         (setf (gethash h bindings) (random-float-in 4.0 12.0)))
        ((:B-WALL-W)
         (setf (gethash h bindings) (random-float-in 0.8 2.5)))
        ;; Paired-symmetric holes
        ((:SX-VAR)
         (setf (gethash h bindings) (random-float-in 5.0 25.0)))
        ;; Four-corners holes
        ((:FC-SIZE-EXPR)
         (setf (gethash h bindings) (random-float-in 8.0 30.0)))
        ;; Unique variable names for paired-symmetric
        ((:SYM-X)
         (setf (gethash h bindings) (make-unique-var h)))
        ;; Bridged template: inline float endpoints for wall-segment
        ((:BRIDGE-X0 :BRIDGE-Z0)
         (setf (gethash h bindings) (random-float-in -30.0 -5.0)))
        ((:BRIDGE-X1 :BRIDGE-Z1)
         (setf (gethash h bindings) (random-float-in 5.0 30.0)))
        ((:BRIDGE-H)
         (setf (gethash h bindings) (random-float-in 4.0 12.0)))
        ((:BRIDGE-W)
         (setf (gethash h bindings) (random-float-in 0.8 2.5)))
        ;; All hole types that generate a macro call
        ((:MACRO-CALL-HOLE :CALL-1 :CALL-2 :BODY-CALL
          :MACRO-CALL-A :MACRO-CALL-B
          :CORNER-CALL-A :CORNER-CALL-B :CORNER-CALL-C :CORNER-CALL-D)
         (let* ((candidates (or available-macros
                                 (macros-up-to-layer layer)))
                (m          (weighted-sample candidates
                                             :key #'babel-macro-score))
                (args       (when m (generate-macro-args m params))))
           (setf (gethash h bindings)
                 (if m
                     `(,(babel-macro-name m) ,@args)
                     '(values)))))))
    ;; Walk the skeleton and substitute every hole symbol.
    ;; Holes in the skeleton are uninterned/babel-package symbols like MACRO-CALL-HOLE.
    ;; Bindings are keyed by keywords like :MACRO-CALL-HOLE.
    ;; Normalise by converting any symbol to its keyword equivalent for lookup.
    (labels ((subst-holes (x)
               (cond
                 ((symbolp x)
                  (let ((key (intern (symbol-name x) :keyword)))
                    (or (gethash key bindings) x)))
                 ((consp x)
                  (mapcar #'subst-holes x))
                 (t x))))
      (subst-holes form))))

;;; ─── Validation ─────────────────────────────────────────────────────────────

(defun circular-dep? (m registry)
  "Return T if adding M would create a circular dependency in REGISTRY."
  (let ((visited (make-hash-table :test 'eq)))
    (labels ((visit (name)
               (when (eq name (babel-macro-name m)) (return-from circular-dep? t))
               (unless (gethash name visited)
                 (setf (gethash name visited) t)
                 (let ((entry (gethash name registry)))
                   (when entry
                     (dolist (dep (babel-macro-dependencies entry))
                       (visit dep)))))))
      (dolist (dep (babel-macro-dependencies m))
        (visit dep)))
    nil))

(defun terminates? (m)
  "Heuristic termination check: tree depth must be ≤ 20."
  (< (babel-macro-complexity m) 20))

(defun emits-geometry? (m sample-params)
  "Return T if M's body produces at least one edge when called with SAMPLE-PARAMS.
   Compiles an anonymous lambda with the params as formals, then applies it.
   This never calls the new function by name (which doesn't exist yet), so
   SBCL emits no 'undefined function' warnings."
  (let ((*vertex-buffer* nil) (*edge-buffer* nil))
    (handler-case
        (let ((fn (handler-bind ((warning #'muffle-warning))
                    (compile nil
                             `(lambda (,@(babel-macro-params m))
                                ,(babel-macro-body m))))))
          (when fn
            (apply fn sample-params))
          (not (null *edge-buffer*)))
      (error () nil))))

(defun body-duplicate? (m registry)
  "Return T if the body s-expression of M already exists in REGISTRY."
  (let ((body (babel-macro-body m)))
    (block found
      (maphash (lambda (k v)
                 (declare (ignore k))
                 (when (equalp body (babel-macro-body v))
                   (return-from found t)))
               registry)
      nil)))

(defun sample-params-for (m)
  "Generate a list of sample numeric arguments for macro M."
  (mapcar (lambda (p) (declare (ignore p)) (+ 1.0 (random 8.0)))
          (babel-macro-params m)))

(defvar *max-edges-per-macro* 4000
  "Budget: reject macros that would emit more than this many edges.")

(defun validate-macro (m)
  "Run all validation checks. Returns T if macro is safe to register."
  (and (not (circular-dep? m *babel-registry*))
       (terminates? m)
       (not (body-duplicate? m *babel-registry*))
       (emits-geometry? m (sample-params-for m))))

;;; ─── Invention ───────────────────────────────────────────────────────────────

(defparameter *layer-names*
  '((1 . ("tower" "dome" "pillar" "colonnade" "spire" "ramp" "crown"))
    (2 . ("keep"  "battlement" "cloister" "aqueduct" "bridge"))
    (3 . ("fortress" "monastery" "harbor" "citadel" "arena"))
    (4 . ("walled-city" "island-settlement" "sky-fortress" "acropolis")))
  "Suggested names for each invention layer.")

(defun candidate-name (layer)
  "Pick an unused name for a macro at LAYER, or generate a fresh gensym."
  (let ((pool (cdr (assoc layer *layer-names*))))
    (loop for name in (when pool (shuffle (copy-list pool)))
          for sym = (intern (string-upcase name) (find-package :babel))
          unless (gethash sym *babel-registry*)
            return sym
          finally
             (return (intern (format nil "MACRO-~A-~A" layer (random 9999))
                             (find-package :babel))))))

(defun try-invent-macro (layer &optional target-name outer-params)
  "Attempt to invent one new macro at LAYER. Returns the babel-macro or NIL."
  (let* ((name         (or target-name (candidate-name layer)))
         (params       (or outer-params
                           (loop repeat (+ 2 (random 4))
                                 for i from 0
                                 collect (intern (format nil "P~A" i)
                                                 (find-package :babel)))))
         (available    (macros-up-to-layer (1- layer)))
         (tmpl-entry   (nth (random (length *composition-templates*))
                            *composition-templates*))
         (tmpl-name    (first tmpl-entry))
         (skeleton     (getf (rest tmpl-entry) :skeleton))
         (holes        (getf (rest tmpl-entry) :holes))
         (body         (fill-template-holes skeleton holes layer params available))
         (deps         (extract-macro-calls body))
         (candidate    (make-babel-macro
                        :name        name
                        :layer       layer
                        :params      params
                        :body        body
                        :dependencies deps
                        :complexity  (tree-depth body)
                        :score       0.5
                        :usage-count 0
                        :invented-at *generation*
                        :doc         (format nil "AI-invented at layer ~D using ~A template."
                                             layer tmpl-name))))
    (when (validate-macro candidate)
      candidate)))

;;; ─── Layer growth ────────────────────────────────────────────────────────────

(defun invent-layer! (layer &optional (attempts-per-macro 10) (target-count 3))
  "Try to invent TARGET-COUNT new macros at LAYER, each with up to
   ATTEMPTS-PER-MACRO invention attempts. Returns the list of registered macros."
  (incf *generation*)
  (format t "~&[BABEL] Growing layer ~D…~%" layer)
  (let ((registered '()))
    (loop repeat target-count do
      (loop repeat attempts-per-macro
            for m = (try-invent-macro layer)
            when (and m (validate-macro m))
              do (register-macro! m)
                 (push m registered)
                 (loop-finish)))
    (format t "~&[BABEL] Layer ~D: ~D macros added (~D total)~%"
            layer (length registered) (hash-table-count *babel-registry*))
    registered))

;;; ─── Bootstrap: hand-craft Layer 1–3 macros to seed the vocabulary ──────────

(defun install-handcrafted-layer1! ()
  "Install the Layer-1 macros from the spec document verbatim."

  ;; TOWER
  (let* ((body '(loop for f from 0 below floors
                      for r = (* radius (- 1.0 (* f (/ taper floors))))
                      for yy = (* f 3.5)
                      do (box x yy z (* r 2) 3.5 (* r 2))))
         (m (make-babel-macro
             :name 'tower :layer 1
             :params '(x z floors radius taper)
             :body body
             :dependencies '(box)
             :complexity (tree-depth body)
             :score 0.75 :usage-count 0 :invented-at 0
             :doc "Tapering tower of stacked box floors.")))
    (register-macro! m))

  ;; DOME
  (let* ((body '(progn (sphere x y z radius steps)
                       (plane  x z (* radius 2) (* radius 2) y)))
         (m (make-babel-macro
             :name 'dome :layer 1
             :params '(x y z radius steps)
             :body body
             :dependencies '(sphere plane)
             :complexity (tree-depth body)
             :score 0.80 :usage-count 0 :invented-at 0
             :doc "Sphere resting on a flat plane — a dome.")))
    (register-macro! m))

  ;; COLONNADE
  (let* ((body '(let ((spacing (/ length (max 1 (1- n-pillars)))))
                  (loop for i from 0 below n-pillars
                        for px = (+ x (* i spacing))
                        do (box px (/ pillar-h 2) z
                                (* pillar-r 2) pillar-h (* pillar-r 2)))))
         (m (make-babel-macro
             :name 'colonnade :layer 1
             :params '(x z length n-pillars pillar-r pillar-h)
             :body body
             :dependencies '(box)
             :complexity (tree-depth body)
             :score 0.70 :usage-count 0 :invented-at 0
             :doc "Row of box pillars.")))
    (register-macro! m))

  (format t "~&[BABEL] Layer 1 (hand-crafted) complete.~%"))

(defun install-handcrafted-layer2! ()
  "Install Layer-2 macros."

  ;; BATTLEMENT — a solid wall with merlons on top.
  ;; X Y Z = centre of wall base (Y is ground level, not offset).
  ;; wall-len = length along the wall's primary axis (interpret as X for
  ;;   N/S walls, or flip W/D for E/W walls — see FORTRESS).
  ;; wall-w = wall thickness.  wall-h = total height incl. merlons.
  ;; crenels = number of merlons along the parapet.
  (let* ((body '(let* ((base-h  (* wall-h 0.72))
                       (m-h     (* wall-h 0.28))
                       (m-w     (/ wall-len (float (* 2 crenels))))
                       (spacing (/ wall-len (float crenels))))
                  ;; Solid wall base from y to y+base-h
                  (box x (+ y (/ base-h 2.0)) z wall-len base-h wall-w)
                  ;; Merlons (every other gap)
                  (loop for i from 0 below crenels
                        for mx = (+ (- x (/ wall-len 2.0))
                                    (* (+ i 0.5) spacing))
                        do (box mx
                                (+ y base-h (/ m-h 2.0))
                                z m-w m-h wall-w))))
         (m (make-babel-macro
             :name 'battlement :layer 2
             :params '(x y z wall-len wall-w wall-h crenels)
             :body body
             :dependencies '(box)
             :complexity (tree-depth body)
             :score 0.82 :usage-count 0 :invented-at 0
             :doc "Solid wall with merlons (crenellated parapet).")))
    (register-macro! m))

  ;; KEEP
  (let* ((body '(let ((h (* floors 3.5)))
                  (progn
                    (tower x z floors base-r 0.1)
                    (battlement x h z (* base-r 2.2) 0.8 1.2 8))))
         (m (make-babel-macro
             :name 'keep :layer 2
             :params '(x z base-r floors)
             :body body
             :dependencies '(tower battlement)
             :complexity (tree-depth body)
             :score 0.85 :usage-count 0 :invented-at 0
             :doc "Castle keep: tower topped with battlements.")))
    (register-macro! m))

  (format t "~&[BABEL] Layer 2 (hand-crafted) complete.~%"))

(defun install-handcrafted-layer3! ()
  "Install Layer-3 macros."

  ;; FORTRESS — four corner keeps with full-height connected walls.
  ;; wall-segment is used for E/W walls so they run along Z correctly.
  ;; battlement is used for N/S walls (runs along X by convention).
  (let* ((body '(let* ((half    (/ size 2.0))
                       (keep-r  2.5)
                       (keep-fl 6)
                       (wall-h  (* keep-fl 3.5 0.55))   ; ~55% keep height
                       (wall-w  1.5))
                  ;; ── Corner keeps ────────────────────────────────────
                  (keep (- cx half) (- cz half) keep-r keep-fl)
                  (keep (+ cx half) (- cz half) keep-r keep-fl)
                  (keep (- cx half) (+ cz half) keep-r keep-fl)
                  (keep (+ cx half) (+ cz half) keep-r keep-fl)
                  ;; ── N/S walls — run along X, use battlement ─────────
                  ;; South wall (z = cz-half), crenels face outward
                  (battlement cx 0.0 (- cz half) size wall-w wall-h 10)
                  ;; North wall
                  (battlement cx 0.0 (+ cz half) size wall-w wall-h 10)
                  ;; ── E/W walls — run along Z, use wall-segment ────────
                  ;; West wall
                  (wall-segment (- cx half) (- cz half)
                                (- cx half) (+ cz half)
                                0.0 wall-h wall-w)
                  ;; East wall
                  (wall-segment (+ cx half) (- cz half)
                                (+ cx half) (+ cz half)
                                0.0 wall-h wall-w)
                  ;; ── Gate arch in south wall ──────────────────────────
                  (arch cx 0.0 (- cz half) 4.5 4.0 wall-w :gothic)))
         (m (make-babel-macro
             :name 'fortress :layer 3
             :params '(cx cz size)
             :body body
             :dependencies '(keep battlement wall-segment arch)
             :complexity (tree-depth body)
             :score 0.92 :usage-count 0 :invented-at 0
             :doc "Four corner keeps with full-height connected walls and gate arch.")))
    (register-macro! m))

  (format t "~&[BABEL] Layer 3 (hand-crafted) complete.~%"))

(defun install-handcrafted-layer4! ()
  "Install Layer-4 macros."

  ;; WALLED-CITY
  (let* ((body '(progn
                  (fortress cx cz size)
                  (loop repeat (max 1 (round (* density size size 0.005)))
                        for ix = (+ cx (- (random (floor size))
                                          (floor (/ size 2))))
                        for iz = (+ cz (- (random (floor size))
                                          (floor (/ size 2))))
                        for flrs = (+ 1 (random 4))
                        do (keep (float ix) (float iz) 1.0 flrs))))
         (m (make-babel-macro
             :name 'walled-city :layer 4
             :params '(cx cz size density)
             :body body
             :dependencies '(fortress keep)
             :complexity (tree-depth body)
             :score 0.92 :usage-count 0 :invented-at 0
             :doc "A walled city with a fortress perimeter and interior keeps.")))
    (register-macro! m))

  (format t "~&[BABEL] Layer 4 (hand-crafted) complete.~%"))

(defun install-handcrafted-layer5! ()
  "Install Layer-5 macros built from Layer 3-4 vocabulary."

  ;; CITADEL — fortress on a plateau
  (let* ((body '(progn
                  (plateau cx cz (* size 1.4) (* size 1.4) platform-h 8.0)
                  (fortress cx cz size)))
         (m (make-babel-macro
             :name 'citadel :layer 5
             :params '(cx cz size platform-h)
             :body body
             :dependencies '(plateau fortress)
             :complexity (tree-depth body)
             :score 0.88 :usage-count 0 :invented-at 0
             :doc "Fortress raised on a stone plateau.")))
    (register-macro! m))

  ;; TWIN-CITIES — two walled cities flanking a central fortress
  (let* ((body '(progn
                  (walled-city (- cx spacing) cz city-size 0.2)
                  (walled-city (+ cx spacing) cz city-size 0.2)
                  (fortress cx cz (* city-size 0.5))
                  ;; Connecting road colonnades
                  (colonnade cx cz (* spacing 2.0) 8 0.5 10.0)))
         (m (make-babel-macro
             :name 'twin-cities :layer 5
             :params '(cx cz city-size spacing)
             :body body
             :dependencies '(walled-city fortress colonnade)
             :complexity (tree-depth body)
             :score 0.91 :usage-count 0 :invented-at 0
             :doc "Two walled cities flanking a central fortress.")))
    (register-macro! m))

  ;; MONASTERY — cloister + keep + dome chapel
  (let* ((body '(progn
                  ;; Cloister — four colonnades forming a courtyard
                  (colonnade cx              cz             size 7 0.5 9.0)
                  (colonnade cx              (+ cz size)    size 7 0.5 9.0)
                  (colonnade (- cx (* size 0.5)) (+ cz (* size 0.5)) size 7 0.5 9.0)
                  (colonnade (+ cx (* size 0.5)) (+ cz (* size 0.5)) size 7 0.5 9.0)
                  ;; Bell tower
                  (keep cx (+ cz (* size 1.2)) 1.5 8)
                  ;; Chapel dome
                  (dome cx 0.0 cz (* size 0.6) 10)))
         (m (make-babel-macro
             :name 'monastery :layer 5
             :params '(cx cz size)
             :body body
             :dependencies '(colonnade keep dome)
             :complexity (tree-depth body)
             :score 0.87 :usage-count 0 :invented-at 0
             :doc "Cloister, bell tower, and dome chapel.")))
    (register-macro! m))

  (format t "~&[BABEL] Layer 5 (hand-crafted) complete.~%"))

(defun bootstrap-vocabulary! ()
  "Install all hand-crafted layers 0–5."
  (register-layer-0!)
  (install-handcrafted-layer1!)
  ;; Register terrain/plateau as additional layer-1 primitives
  (register-terrain-macro!)
  (register-macro!
   (make-babel-macro
    :name 'plateau :layer 1
    :params '(cx cz width depth y-base wall-height)
    :body '(emit-plateau-edges cx cz width depth y-base wall-height)
    :dependencies '() :complexity 2 :score 0.75
    :usage-count 0 :invented-at 0
    :doc "Flat raised platform with vertical walls."))
  (install-handcrafted-layer2!)
  (install-handcrafted-layer3!)
  (install-handcrafted-layer4!)
  (install-handcrafted-layer5!)
  (format t "~&[BABEL] Vocabulary bootstrapped with ~D macros.~%"
          (hash-table-count *babel-registry*)))
