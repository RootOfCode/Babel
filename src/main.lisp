;;;; src/main.lisp
;;;; Entry point, REPL helpers, and startup message.

(in-package #:babel)

;;; ─── Output directory ────────────────────────────────────────────────────────

(defvar *output-dir* nil
  "Absolute pathname of the output/ directory next to the system root.
   Set by SET-OUTPUT-DIR! at load time; can be overridden at the REPL.")

(defun set-output-dir! (system-root)
  "Derive and create the output/ directory from SYSTEM-ROOT pathname."
  (let ((dir (merge-pathnames "output/"
                              (make-pathname :directory
                                             (pathname-directory system-root)))))
    (ensure-directories-exist dir)
    (setf *output-dir* dir)
    (format t "~&[BABEL] Output directory: ~A~%" dir)
    dir))

(defun babel-out (filename)
  "Return an absolute pathname for FILENAME inside *output-dir*.
   Falls back to /tmp/ if *output-dir* is not yet set."
  (if *output-dir*
      (merge-pathnames filename *output-dir*)
      (merge-pathnames filename "/tmp/")))

;;; ─── Banner ──────────────────────────────────────────────────────────────────

(defun print-banner ()
  (format t "~%")
  (format t "  ╔══════════════════════════════════════════════════════╗~%")
  (format t "  ║        B  A  B  E  L                                 ║~%")
  (format t "  ║   The Lisp Macro World Compiler                      ║~%")
  (format t "  ╠══════════════════════════════════════════════════════╣~%")
  (format t "  ║  GUI     Click scenes, camera/display, generation,   ║~%")
  (format t "  ║          save, screenshot, export, and live editable ║~%")
  (format t "  ║          structure source. No terminal HUD.          ║~%")
  (format t "  ║  MOUSE   Left-drag orbit, right-drag pan, wheel zoom ║~%")
  (format t "  ║  KEYS    F2 GUI, F3 code, F4 stats, F5 apply       ║~%")
  (format t "  ║          F10 theme, F11 fit, H help                ║~%")
  (format t "  ║          F6/Ctrl/Cmd+C copy, F7/Ctrl/Cmd+V paste  ║~%")
  (format t "  ║          F8 import, F9 hot reload, ESC unfocus     ║~%")
  (format t "  ╠══════════════════════════════════════════════════════╣~%")
  (format t "  ║  START   (babel:initialize)                          ║~%")
  (format t "  ║          (babel:run-threaded)                        ║~%")
  (format t "  ╚══════════════════════════════════════════════════════╝~%")
  (format t "~%"))

;;; ─── Window launch helpers ──────────────────────────────────────────────────

(defun run-threaded ()
  "Start the BABEL window in a background thread, leaving the REPL free.

   This is the recommended way to open BABEL interactively.  Calling
   (babel:run) directly blocks the current thread because SDL2 takes over
   the event loop.  Use run-threaded instead:

     (babel:initialize)
     (babel:run-threaded)
     ;; REPL is now free — evaluate worlds live:
     (babel:babel-eval (fortress 0.0 0.0 40.0))
     (babel:babel-eval (walled-city 0.0 0.0 70.0 0.3))"
  (bt:make-thread #'run :name "babel-window")
  (format t "~&[BABEL] Window thread started. REPL is free.~%")
  (format t "~&[BABEL] Try: (babel:babel-eval (fortress 0.0 0.0 40.0))~%"))

;;; ─── Package-aware symbol resolution ───────────────────────────────────────

(defun babel-resolve-sym (sym)
  "If SYM names a function exported from the :babel package, return that
   symbol.  Otherwise return SYM unchanged.  This lets callers in any package
   write unqualified names like FORTRESS and have them resolve correctly."
  (if (and (symbolp sym) (not (keywordp sym)))
      (let ((found (find-symbol (symbol-name sym) (find-package :babel))))
        (if (and found (fboundp found))
            found
            sym))
      sym))

(defun babel-rewrite-forms (tree)
  "Walk TREE depth-first, re-interning every symbol that names a babel
   function into the :babel package.  Leaves literals, keywords, and
   unknown symbols alone."
  (cond
    ((symbolp tree) (babel-resolve-sym tree))
    ((consp tree)
     (cons (babel-rewrite-forms (car tree))
           (babel-rewrite-forms (cdr tree))))
    (t tree)))

;;; ─── REPL convenience macros ────────────────────────────────────────────────

(defmacro babel-eval (&body forms)
  "Evaluate FORMS as a world program and make it the live scene.
   Unqualified names (FORTRESS, DOME, etc.) are resolved to the :babel
   package automatically, so this works from any package.
   The source forms are stored in *current-world-source* for save-world-file!.
   Example: (babel:babel-eval (fortress 0.0 0.0 30.0) (dome 0.0 0.0 0.0 8 8))"
  (let ((rewritten (babel-rewrite-forms forms)))
    `(progn
       (setf *current-world-source* ',forms)
       (run-world (lambda () ,@rewritten)))))

(defmacro show-macro (name &rest args)
  "Preview a single macro call as the live scene.
   Example: (babel:show-macro keep 0.0 0.0 3.0 6)"
  (let ((resolved (babel-resolve-sym name)))
    `(run-world (lambda () (,resolved ,@args)))))

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
(defun initialize (&key (validate t) (system-root nil))
  "Bootstrap the vocabulary and open the output directory.
   SYSTEM-ROOT should be the directory containing babel-world.asd.
   If not supplied, it is inferred from the ASDF source registry."
  (print-banner)
  ;; Resolve output directory
  (let ((root (or system-root
                  ;; Ask ASDF where it loaded the system from
                  (handler-case
                      (asdf:system-source-directory :babel-world)
                    (error () nil))
                  ;; Last resort: current directory
                  *default-pathname-defaults*)))
    (set-output-dir! root))
  (unless (> (hash-table-count *babel-registry*) 0)
    (bootstrap-vocabulary!))
  (when validate
    (validate-all-scenes!))
  (format t "~%  Vocabulary ready. Call (babel:run-threaded) to open the window.~%~%")
  (list-macros-by-layer))
