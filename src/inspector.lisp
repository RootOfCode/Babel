;;;; src/inspector.lisp
;;;; Terminal-based macro inspector and vocabulary browser.
;;;; Provides formatted, human-readable reports about any macro in the registry:
;;;;   dependency trees, expansion previews, fitness breakdowns, layer summaries.

(in-package #:babel)

;;; ─── ANSI colour helpers (terminal only) ────────────────────────────────────

(defun ansi (code text)
  (format nil "~A[~Am~A~A[0m" #\Escape code text #\Escape))

(defun bold    (s) (ansi 1 s))
(defun dim     (s) (ansi 2 s))
(defun cyan    (s) (ansi 36 s))
(defun yellow  (s) (ansi 33 s))
(defun green   (s) (ansi 32 s))
(defun red     (s) (ansi 31 s))
(defun magenta (s) (ansi 35 s))

;;; ─── Single macro profile ────────────────────────────────────────────────────

(defun inspect-macro (name)
  "Print a full profile of the named BABEL macro."
  (let ((m (gethash name *babel-registry*)))
    (unless m
      (format t "~&No macro named ~A in registry.~%" name)
      (return-from inspect-macro nil))
    (format t "~%~A~%" (bold (cyan (format nil "══ BABEL Macro: ~A ══" name))))
    (format t "  Layer      : ~A~%"
            (case (babel-macro-layer m)
              (0 (bold "0 — Primitive"))
              (1 (green "1 — Layer 1"))
              (2 (yellow "2 — Layer 2"))
              (3 (magenta "3 — Layer 3"))
              (4 (cyan "4 — Layer 4"))
              (otherwise (format nil "~D — AI-invented" (babel-macro-layer m)))))
    (format t "  Params     : ~A~%" (babel-macro-params m))
    (format t "  Score      : ~,3f~%" (babel-macro-score m))
    (format t "  Complexity : ~D (tree depth)~%" (babel-macro-complexity m))
    (format t "  Uses       : ~D~%" (babel-macro-usage-count m))
    (format t "  Invented   : generation ~D~%" (babel-macro-invented-at m))
    (format t "  Deps       : ~{~A~^ ~}~%"
            (or (babel-macro-dependencies m) '(none)))
    (format t "  Doc        : ~A~%" (babel-macro-doc m))
    (format t "~%  ~A~%" (bold "Body:"))
    (let ((*print-pretty* t) (*print-right-margin* 72))
      (format t "  ~S~%~%" (babel-macro-body m)))
    ;; Score breakdown
    (format t "  ~A~%" (bold "Score breakdown:"))
    (let* ((s-econ   (score-economy m))
           (s-reuse  (score-reusability m))
           (s-compat (score-compatibility m *babel-registry*))
           (args     (sample-params-for m))
           (geom     (let ((*vertex-buffer* nil) (*edge-buffer* nil))
                       (handler-case (progn (eval `(,(babel-macro-name m) ,@args))
                                            (list (length *vertex-buffer*)
                                                  (length *edge-buffer*)))
                         (error () '(0 0)))))
           (verts    (first  geom))
           (edges    (second geom)))
      (format t "    economy      ~,3f~%" s-econ)
      (format t "    reusability  ~,3f~%" s-reuse)
      (format t "    compat       ~,3f~%" s-compat)
      (format t "    sample verts ~D  edges ~D~%" verts edges))
    (format t "~%")))

;;; ─── Dependency tree ────────────────────────────────────────────────────────

(defun print-macro-tree (name &optional (indent 0) (seen (make-hash-table)))
  "Print the dependency tree of NAME recursively."
  (when (gethash name seen) (return-from print-macro-tree))
  (setf (gethash name seen) t)
  (let ((m (gethash name *babel-registry*)))
    (if m
        (format t "~A~A ~A(layer ~D  score ~,2f)~%"
                (make-string (* indent 2) :initial-element #\Space)
                (bold (format nil "~A" name))
                (dim "")
                (babel-macro-layer m)
                (babel-macro-score m))
        (format t "~A~A ~A~%"
                (make-string (* indent 2) :initial-element #\Space)
                name
                (red "[not in registry]")))
    (when m
      (dolist (dep (babel-macro-dependencies m))
        (print-macro-tree dep (1+ indent) seen)))))

;;; ─── Layer summary table ────────────────────────────────────────────────────

(defun print-layer-summary ()
  "Print a formatted table of all macros grouped by layer."
  (format t "~%~A~%" (bold (cyan "══ BABEL Vocabulary Summary ══")))
  (let ((by-layer (make-hash-table)))
    (maphash (lambda (k v)
               (push (list k
                           (babel-macro-score v)
                           (babel-macro-usage-count v)
                           (babel-macro-complexity v))
                     (gethash (babel-macro-layer v) by-layer)))
             *babel-registry*)
    (loop for layer from 0 to 10 do
      (let ((entries (gethash layer by-layer)))
        (when entries
          (format t "~%  ~A  (~D macros)~%"
                  (bold (format nil "Layer ~D" layer))
                  (length entries))
          (let ((sorted (sort entries #'> :key #'second)))
            (dolist (e sorted)
              (format t "    ~A~20T score=~,2f  uses=~D  depth=~D~%"
                      (first e) (second e) (third e) (fourth e))))))))
  (format t "~%  Total: ~D macros~%~%"
          (hash-table-count *babel-registry*)))

;;; ─── Top-N scorers ──────────────────────────────────────────────────────────

(defun print-top-macros (&optional (n 10))
  "Print the top N macros by score."
  (format t "~%~A~%" (bold (cyan (format nil "══ Top ~D Macros by Score ══" n))))
  (let ((all (loop for v being the hash-values of *babel-registry* collect v)))
    (dolist (m (subseq (sort all #'> :key #'babel-macro-score) 0 (min n (length all))))
      (format t "  ~A~30T layer=~D  score=~,3f  uses=~D~%"
              (bold (format nil "~A" (babel-macro-name m)))
              (babel-macro-layer m)
              (babel-macro-score m)
              (babel-macro-usage-count m))))
  (format t "~%"))

;;; ─── Expansion preview ──────────────────────────────────────────────────────

(defun preview-expansion (name &rest args)
  "Show the first level of macroexpansion for a named macro call."
  (let ((form `(,name ,@args)))
    (format t "~%~A~%  " (bold (cyan (format nil "Macroexpand-1: ~S" form))))
    (let ((*print-pretty* t) (*print-right-margin* 72))
      (format t "~S~%~%" (macroexpand-1 form)))))

;;; ─── Geometry statistics for a macro ────────────────────────────────────────

(defun macro-geometry-stats (name &optional (samples 8))
  "Print min/max/mean vertex and edge counts across SAMPLES random param sets."
  (let ((m (gethash name *babel-registry*)))
    (unless m
      (format t "Macro ~A not found.~%" name)
      (return-from macro-geometry-stats))
    (format t "~%~A~%" (bold (cyan (format nil "══ Geometry stats: ~A ══" name))))
    (let ((vcounts '()) (ecounts '()))
      (loop repeat samples do
        (let ((*vertex-buffer* nil) (*edge-buffer* nil))
          (handler-case
              (progn
                (eval `(,name ,@(sample-params-for m)))
                (push (length *vertex-buffer*) vcounts)
                (push (length *edge-buffer*)   ecounts))
            (error ()))))
      (when vcounts
        (format t "  Vertices: min=~D  max=~D  mean=~,0f~%"
                (reduce #'min vcounts) (reduce #'max vcounts)
                (/ (reduce #'+ vcounts) (float (length vcounts))))
        (format t "  Edges:    min=~D  max=~D  mean=~,0f~%~%"
                (reduce #'min ecounts) (reduce #'max ecounts)
                (/ (reduce #'+ ecounts) (float (length ecounts))))))))

;;; ─── Convenience alias ───────────────────────────────────────────────────────

(defun ? (name)
  "Quick-inspect shorthand: (? 'fortress)"
  (inspect-macro name))
