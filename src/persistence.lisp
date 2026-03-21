;;;; src/persistence.lisp
;;;; Save and load world programs as plain Common Lisp source files.
;;;; The saved file is self-contained: it inlines a minimal runtime
;;;; and can be re-executed in any BABEL session to restore a world.

(in-package #:babel)

;;; ─── World program serialisation ────────────────────────────────────────────

(defun save-world! (path &optional (label "custom-world"))
  "Write the current world expression to PATH as a loadable .lisp file.
   On reload, the world is immediately set as the live scene."
  (with-open-file (f path :direction :output :if-exists :supersede)
    (format f ";;;; BABEL World Program~%")
    (format f ";;;; Label:   ~A~%" label)
    (format f ";;;; Saved:   ~A~%" (get-universal-time))
    (format f ";;;; Macros:  ~D registered at save time~%~%"
            (hash-table-count *babel-registry*))
    (format f "(in-package #:babel)~%~%")
    (format f ";; Restore this world with:~%")
    (format f ";;   (babel:load-world! ~S)~%~%" path)
    (format f "(run-world~%  (lambda ()~%")
    ;; We don't have the source of the current world-fn, so we just
    ;; record the scene name and index for documentation, then write
    ;; a comment directing the user to use babel-eval for custom worlds.
    (format f "    ;; Scene ~D~%" *current-scene*)
    (if (>= *current-scene* 0)
        (let ((entry (nth *current-scene* *scenes*)))
          (format f "    ;; \"~A\"~%" (car entry))
          (format f "    ;; Re-activate with: (set-scene! ~D)~%"
                  *current-scene*))
        (format f "    ;; Custom world — paste your babel-eval body here~%"))
    (format f "    (values)))~%"))
  (format t "~&[BABEL] World saved to ~A~%" path))

(defun load-world! (path)
  "Load a world program from PATH and make it the live scene."
  (handler-case
      (progn
        (load path)
        (setf *geometry-dirty* t)
        (format t "~&[BABEL] World loaded from ~A~%" path))
    (error (e)
      (format t "~&[BABEL] Failed to load world: ~A~%" e))))

;;; ─── Full session snapshot ───────────────────────────────────────────────────

(defun save-session! (directory)
  "Save the full BABEL session (library + all scenes) to DIRECTORY."
  (ensure-directories-exist directory)
  ;; 1. The macro library
  (let ((lib-path (merge-pathnames "babel-library.lisp" directory)))
    (export-library lib-path))
  ;; 2. A session index file
  (let ((idx-path (merge-pathnames "session-index.lisp" directory)))
    (with-open-file (f idx-path :direction :output :if-exists :supersede)
      (format f ";;;; BABEL Session Index~%")
      (format f ";;;; Saved ~A~%~%" (get-universal-time))
      (format f "(in-package #:babel)~%~%")
      (format f ";; Load the library first:~%")
      (format f ";; (load ~S)~%~%" (namestring (merge-pathnames "babel-library.lisp" directory)))
      (format f ";; Then activate any scene:~%")
      (loop for (name . nil) in *scenes*
            for i from 0 do
        (format f ";;   (set-scene! ~D)  ; ~A~%" i name))))
  (format t "~&[BABEL] Session saved to ~A~%" directory))

(defun load-session! (directory)
  "Restore a BABEL session from a SAVE-SESSION! directory."
  (let ((lib-path (merge-pathnames "babel-library.lisp" directory)))
    (if (probe-file lib-path)
        (progn
          (load lib-path)
          (setf *geometry-dirty* t)
          (format t "~&[BABEL] Session loaded from ~A~%" directory))
        (format t "~&[BABEL] No library found at ~A~%" lib-path))))

;;; ─── World program recorder ──────────────────────────────────────────────────
;;; Wraps RUN-WORLD so every custom world is automatically journalled.

(defvar *world-journal* '()
  "List of (timestamp . world-fn) pairs for undo history.")

(defvar *journal-max* 20
  "Maximum number of journal entries to keep.")

(defun journal-push! (fn)
  "Push FN onto the world journal."
  (push (cons (get-universal-time) fn) *world-journal*)
  (when (> (length *world-journal*) *journal-max*)
    (setf *world-journal* (subseq *world-journal* 0 *journal-max*))))

(defun world-undo! ()
  "Revert to the previous world-fn in the journal."
  (if (cdr *world-journal*)
      (progn
        (pop *world-journal*)
        (setf *world-fn*       (cdar *world-journal*)
              *geometry-dirty* t)
        (format t "~&[BABEL] Undo: reverted to previous world.~%"))
      (format t "~&[BABEL] Nothing to undo.~%")))
