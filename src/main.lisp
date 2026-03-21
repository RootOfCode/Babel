;;;; src/main.lisp
;;;; Entry point, REPL helpers, and startup message.

(in-package #:babel)

;;; ─── Banner ──────────────────────────────────────────────────────────────────

(defun print-banner ()
  (format t "~%")
  (format t "  ╔══════════════════════════════════════════════════════╗~%")
  (format t "  ║        B  A  B  E  L                                 ║~%")
  (format t "  ║   The Lisp Macro World Compiler                      ║~%")
  (format t "  ║                                                       ║~%")
  (format t "  ║  \"In the beginning was the Word.                      ║~%")
  (format t "  ║   Then the Word wrote more Words.\"                   ║~%")
  (format t "  ╠══════════════════════════════════════════════════════╣~%")
  (format t "  ║  MOUSE   LMB=orbit  RMB=pan  scroll=zoom             ║~%")
  (format t "  ║  CAMERA  R=reset  IJKL=pan  ←→=scene cycle          ║~%")
  (format t "  ║  SCENES  1-9 direct                                  ║~%")
  (format t "  ║  DISPLAY C=colour  X=gizmo  O=rings                  ║~%")
  (format t "  ║  GROW    G=invent-layer  E=evolve                    ║~%")
  (format t "  ║  SAVE    S=lib  W=OBJ  V=SVG  F12=screenshot         ║~%")
  (format t "  ║  OTHER   Z=undo  H=hud  ESC=quit                     ║~%")
  (format t "  ╚══════════════════════════════════════════════════════╝~%")
  (format t "~%"))

;;; ─── REPL convenience macros ────────────────────────────────────────────────

(defmacro babel-eval (&body forms)
  "Evaluate FORMS as a world program and make it the live scene.
   Example: (babel-eval (fortress 0.0 0.0 30.0) (dome 0.0 0.0 0.0 8 8))"
  `(run-world (lambda () ,@forms)))

(defmacro show-macro (name &rest args)
  "Preview a single macro call as the live scene.
   Example: (show-macro keep 0.0 0.0 3.0 6) -- keep is now a function"
  `(run-world (lambda () (,name ,@args))))

;;; ─── list-macros-by-layer ────────────────────────────────────────────────────
;;; (print-macro-tree is defined with full cycle detection in inspector.lisp)

(defun list-macros-by-layer ()
  "Print all registered macros grouped by layer."
  (let ((by-layer (make-hash-table))
        (max-layer 0))
    (maphash (lambda (k v)
               (push k (gethash (babel-macro-layer v) by-layer))
               (setf max-layer (max max-layer (babel-macro-layer v))))
             *babel-registry*)
    (loop for layer from 0 to max-layer do
      (let ((names (sort (copy-list (gethash layer by-layer)) #'string< :key #'symbol-name)))
        (when names
          (format t "~&  Layer ~D: ~{~A~^ ~}~%" layer names))))))

;;; ─── Startup ─────────────────────────────────────────────────────────────────

(defun validate-all-scenes! ()
  "Run every scene thunk with a dry run to catch errors before opening window."
  (format t "~&[BABEL] Validating ~D scenes…~%" (length *scenes*))
  (let ((ok 0) (fail 0))
    (loop for (name . fn) in *scenes*
          for i from 0 do
      (let ((*vertex-buffer* nil) (*edge-buffer* nil))
        (handler-case
            (progn (funcall fn)
                   (incf ok)
                   (format t "  [OK] scene ~D: ~A (~D verts)~%"
                           i name (length *vertex-buffer*)))
          (error (e)
            (incf fail)
            (format t "  [FAIL] scene ~D: ~A — ~A~%" i name e)))))
    (format t "[BABEL] ~D OK, ~D FAILED.~%" ok fail)
    (zerop fail)))

;;; Called at load-time to bootstrap the vocabulary.
;;; The window is NOT opened here — call (babel:run) for that.
(defun initialize (&key (validate t))
  (print-banner)
  (unless (> (hash-table-count *babel-registry*) 0)
    (bootstrap-vocabulary!))
  (when validate
    (validate-all-scenes!))
  (format t "~%  Vocabulary ready. Call (babel:run) to open the window.~%~%")
  (list-macros-by-layer))
