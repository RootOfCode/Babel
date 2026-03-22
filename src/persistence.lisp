;;;; src/persistence.lisp
;;;; Save and load world programs as plain Common Lisp source files.
;;;; The saved file is self-contained: it inlines a minimal runtime
;;;; and can be re-executed in any BABEL session to restore a world.
;;;;
;;;; Also provides two dedicated binary-friendly formats:
;;;;   .world — stores a world expression so it can be re-evaluated exactly
;;;;   .voc   — stores the full macro vocabulary with all metadata

(in-package #:babel)

;;; ─── Current world source tracker ───────────────────────────────────────────

(defvar *current-world-source* nil
  "The last world source forms passed to babel-eval, kept for .world saving.")

;;; ─── .world file: save / load ────────────────────────────────────────────────

(defun save-world-file! (path &optional (label "my-world"))
  "Save the current world as a structured .world file at PATH.
   The file stores the exact babel-eval source so load-world-file! can
   re-evaluate it without needing the original REPL session.

   Example:
     (babel:save-world-file! (babel:babel-out "fortress-scene.world") "fortress")"
  (with-open-file (f path :direction :output :if-exists :supersede)
    (format f ";;;; BABEL .world file~%")
    (format f ";;;; Label:   ~A~%" label)
    (format f ";;;; Reload:  (babel:load-world-file! ~S)~%~%" path)
    (let ((data `(:babel-world-format t
                  :version        1
                  :label          ,label
                  :timestamp      ,(get-universal-time)
                  :scene-index    ,*current-scene*
                  :world-source   ,*current-world-source*
                  :macro-count    ,(hash-table-count *babel-registry*))))
      (with-standard-io-syntax
        (let ((*print-case*   :downcase)
              (*print-pretty* t))
          (print data f)))))
  (format t "~&[BABEL] World saved → ~A~%" path))

(defun load-world-file! (path)
  "Load a .world file from PATH and restore the scene.

   If the file contains a world-source expression it is re-evaluated live.
   If it contains only a scene-index the matching built-in scene is activated.

   Example:
     (babel:load-world-file! (babel:babel-out "fortress-scene.world"))"
  (handler-case
      (let* ((data   (with-open-file (f path) (read f)))
             (label  (getf data :label  "unknown"))
             (scene  (getf data :scene-index -1))
             (source (getf data :world-source nil)))
        (unless (getf data :babel-world-format)
          (error "File does not look like a BABEL .world file."))
        (format t "~&[BABEL] Loading world: ~A~%" label)
        (cond
          ;; Custom world — re-evaluate the stored source
          (source
           (setf *current-world-source* source)
           (run-world (compile nil `(lambda () ,@source)))
           (format t "~&[BABEL] World expression restored (~D form~:P).~%"
                   (length source)))
          ;; Built-in scene — just switch to it
          ((and (>= scene 0) (< scene (length *scenes*)))
           (set-scene! scene)
           (format t "~&[BABEL] Built-in scene ~D activated.~%" scene))
          (t
           (format t "~&[BABEL] Warning: world file has no restorable content.~%")))
        (setf *geometry-dirty* t)
        (format t "~&[BABEL] Loaded from ~A~%" path))
    (error (e)
      (format t "~&[BABEL] Failed to load world file: ~A~%" e))))

;;; ─── .voc file: save / load ──────────────────────────────────────────────────

(defun save-vocabulary! (path)
  "Save the entire macro vocabulary to PATH as a .voc file.

   Unlike export-library (which writes plain defun source), .voc files
   preserve the full babel-macro metadata: layer, score, usage-count,
   invented-at, dependencies, and doc strings.  Use load-vocabulary! to
   restore an exact snapshot of the registry.

   Example:
     (babel:save-vocabulary! (babel:babel-out "my-city-vocab.voc"))"
  (let ((all-macros (sort (loop for v being the hash-values of *babel-registry*
                                collect v)
                          #'< :key #'babel-macro-layer)))
    (with-open-file (f path :direction :output :if-exists :supersede)
      (format f ";;;; BABEL .voc vocabulary file~%")
      (format f ";;;; ~D macro~:P, layers ~D–~D~%"
              (length all-macros)
              (if all-macros (babel-macro-layer (first all-macros)) 0)
              (if all-macros (babel-macro-layer (car (last all-macros))) 0))
      (format f ";;;; Reload: (babel:load-vocabulary! ~S)~%~%" path)
      (let ((data `(:babel-voc-format t
                    :version     1
                    :timestamp   ,(get-universal-time)
                    :macro-count ,(length all-macros)
                    :macros
                    ,(mapcar
                      (lambda (m)
                        `(:name         ,(babel-macro-name m)
                          :layer        ,(babel-macro-layer m)
                          :params       ,(babel-macro-params m)
                          :body         ,(babel-macro-body m)
                          :dependencies ,(babel-macro-dependencies m)
                          :complexity   ,(babel-macro-complexity m)
                          :score        ,(babel-macro-score m)
                          :usage-count  ,(babel-macro-usage-count m)
                          :invented-at  ,(babel-macro-invented-at m)
                          :doc          ,(babel-macro-doc m)))
                      all-macros))))
        (with-standard-io-syntax
          (let ((*print-case*   :downcase)
                (*print-pretty* t))
            (print data f)))))
    (format t "~&[BABEL] Vocabulary saved → ~A  (~D macro~:P)~%"
            path (length all-macros))))

(defun load-vocabulary! (path &key (merge nil))
  "Load a .voc file from PATH and restore the macro vocabulary.

   By default (MERGE NIL) the registry is cleared first, giving you an
   exact restore of the saved state.  Pass :MERGE T to layer the loaded
   macros on top of the current registry — useful for combining two .voc
   files or adding a saved AI layer to the standard vocabulary.

   Any macro whose name already exists in the registry is overwritten.

   Examples:
     (babel:load-vocabulary! (babel:babel-out "my-city-vocab.voc"))
     (babel:load-vocabulary! (babel:babel-out "ai-layer6.voc") :merge t)"
  (handler-case
      (let* ((data   (with-open-file (f path) (read f)))
             (macros (getf data :macros)))
        (unless (getf data :babel-voc-format)
          (error "File does not look like a BABEL .voc vocabulary."))
        (unless merge
          (clrhash *babel-registry*))
        (let ((count 0))
          (dolist (entry macros)
            (let ((m (make-babel-macro
                      :name         (getf entry :name)
                      :layer        (getf entry :layer 0)
                      :params       (getf entry :params)
                      :body         (getf entry :body)
                      :dependencies (getf entry :dependencies)
                      :complexity   (getf entry :complexity 0)
                      :score        (float (getf entry :score 0.5))
                      :usage-count  (getf entry :usage-count 0)
                      :invented-at  (getf entry :invented-at 0)
                      :doc          (or (getf entry :doc) ""))))
              (register-macro! m)
              (incf count)))
          (setf *geometry-dirty* t)
          (format t "~&[BABEL] Vocabulary loaded → ~A (~D macro~:P, ~A)~%"
                  path count (if merge "merged" "replaced"))))
    (error (e)
      (format t "~&[BABEL] Failed to load vocabulary: ~A~%" e))))

;;; ─── World program serialisation (legacy .lisp format) ──────────────────────

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
