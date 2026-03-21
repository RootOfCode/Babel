;;;; src/registry.lisp
;;;; The BABEL macro registry — every macro at every layer is recorded here.
;;;; Registering a macro also installs it as a real Common Lisp macro via EVAL,
;;;; so BABEL macro programs are executable Lisp source code.

(in-package #:babel)

;;; ─── Registry entry ─────────────────────────────────────────────────────────

(defstruct babel-macro
  (name         nil  :type symbol)
  (layer        0    :type integer)
  (params       nil  :type list)
  (defaults     nil  :type list)          ; alist param → default
  (body         nil)                       ; quoted s-expression
  (dependencies nil  :type list)           ; list of macro-name symbols called
  (complexity   0    :type integer)        ; tree depth
  (score        0.0  :type single-float)
  (usage-count  0    :type integer)
  (invented-at  0    :type integer)        ; generation counter
  (doc          ""   :type string))

;;; ─── The registry table ─────────────────────────────────────────────────────

(defvar *babel-registry* (make-hash-table :test 'eq)
  "Central hash table: symbol → babel-macro.")

(defvar *generation* 0
  "Monotonically increasing generation counter.")

;;; ─── Registration ───────────────────────────────────────────────────────────

(defun register-macro! (m)
  "Record M in *babel-registry* and install it as a regular CL function.
   Using DEFUN avoids macroexpansion-time type errors in composed builders."
  (setf (gethash (babel-macro-name m) *babel-registry*) m)
  ;; Suppress style-warnings about forward references to other babel functions.
  (handler-bind ((style-warning #'muffle-warning))
    (eval `(defun ,(babel-macro-name m) ,(babel-macro-params m)
             ,(babel-macro-body m))))
  (format t "~&[BABEL] Registered ~A (layer ~D, score ~,2f)~%"
          (babel-macro-name m)
          (babel-macro-layer m)
          (babel-macro-score m))
  m)

;;; ─── Queries ────────────────────────────────────────────────────────────────

(defun macros-up-to-layer (layer)
  "Return a list of babel-macro structs whose layer ≤ LAYER."
  (let ((result '()))
    (maphash (lambda (k v)
               (declare (ignore k))
               (when (<= (babel-macro-layer v) layer)
                 (push v result)))
             *babel-registry*)
    result))

(defun find-babel-macro (name)
  "Lookup macro by symbol, returning the babel-macro struct or NIL."
  (gethash name *babel-registry*))

(defun babel-macro-names ()
  "Return a list of all registered macro names."
  (let ((names '()))
    (maphash (lambda (k v) (declare (ignore v)) (push k names))
             *babel-registry*)
    names))

;;; ─── Tree utilities used by invention / scoring ─────────────────────────────

(defun tree-depth (form)
  "Return the maximum nesting depth of s-expression FORM."
  (if (consp form)
      (1+ (reduce #'max (mapcar #'tree-depth form) :initial-value 0))
      0))

(defun extract-macro-calls (form)
  "Walk FORM and collect all symbols that name a registered BABEL macro."
  (let ((calls '()))
    (labels ((walk (x)
               (cond
                 ((and (symbolp x) (gethash x *babel-registry*))
                  (pushnew x calls))
                 ((consp x)
                  (mapc #'walk x)))))
      (walk form))
    calls))

;;; ─── Export the entire library ───────────────────────────────────────────────

(defun export-library (path)
  "Write the entire BABEL macro library to a .lisp source file at PATH.
   The resulting file is loadable in any Common Lisp environment."
  (with-open-file (f path :direction :output :if-exists :supersede)
    (format f ";;;; BABEL Macro Library~%")
    (format f ";;;; Generated at universal-time ~A~%~%" (get-universal-time))
    (format f "(in-package #:cl-user)~%~%")
    (let ((sorted (sort (loop for v being the hash-values of *babel-registry*
                              collect v)
                        #'< :key #'babel-macro-layer)))
      (dolist (m sorted)
        (format f ";; Layer ~D | Score ~,2f | Uses ~D~%"
                (babel-macro-layer m)
                (babel-macro-score m)
                (babel-macro-usage-count m))
        (format f "(defun ~A ~A~%  ~S)~%~%"
                (babel-macro-name m)
                (babel-macro-params m)
                (babel-macro-body m)))))
  (format t "~&[BABEL] Library exported to ~A~%" path))
