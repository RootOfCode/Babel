;;;; src/evolution.lisp — Macro mutation and crossover operators.

(in-package #:babel)

;;; ─── Call-site utilities ────────────────────────────────────────────────────

(defun macro-call-sites (body)
  "Return all sub-forms in BODY that are calls to registered BABEL functions."
  (let ((sites '()))
    (labels ((walk (x)
               (when (consp x)
                 (when (and (symbolp (car x))
                            (gethash (car x) *babel-registry*))
                   (push x sites))
                 (mapc #'walk (cdr x)))))
      (walk body))
    sites))

(defun random-macro-call (body)
  (let ((sites (macro-call-sites body)))
    (when sites (nth (random (length sites)) sites))))

(defun substitute-call (body old new)
  "Replace first occurrence of OLD in BODY with NEW."
  (let ((done nil))
    (labels ((walk (x)
               (cond ((and (not done) (equal x old)) (setf done t) new)
                     ((consp x) (mapcar #'walk x))
                     (t x))))
      (walk body))))

;;; ─── Variant registration ───────────────────────────────────────────────────

(defun try-register-variant (m new-body suffix)
  "Build and register a mutant of M with NEW-BODY if it scores well enough."
  (let* ((new-name (intern (format nil "~A-~A" (babel-macro-name m) suffix)
                           (find-package :babel)))
         (variant  (make-babel-macro
                    :name         new-name
                    :layer        (babel-macro-layer m)
                    :params       (babel-macro-params m)
                    :body         new-body
                    :dependencies (extract-macro-calls new-body)
                    :complexity   (tree-depth new-body)
                    :score        0.0
                    :usage-count  0
                    :invented-at  *generation*
                    :doc          (format nil "Mutation of ~A." (babel-macro-name m)))))
    (when (validate-macro variant)
      (score-macro! variant)
      (when (> (babel-macro-score variant) (* 0.75 (babel-macro-score m)))
        (register-macro! variant)
        variant))))

;;; ─── Mutation operators ─────────────────────────────────────────────────────

(defun mutate-substitute-call! (m)
  "Replace a random call-site in M's body with a different BABEL function."
  (let* ((body      (babel-macro-body m))
         (call-site (random-macro-call body)))
    (unless call-site (return-from mutate-substitute-call! nil))
    (let* ((candidates (macros-up-to-layer (babel-macro-layer m)))
           (alt        (nth (random (length candidates)) candidates))
           (alt-call   `(,(babel-macro-name alt)
                         ,@(generate-macro-args alt (babel-macro-params m))))
           (new-body   (substitute-call body call-site alt-call)))
      (try-register-variant m new-body "SUB"))))

(defun mutate-add-repetition! (m)
  "Wrap M's body in a small counted loop with a fresh loop variable."
  (let* ((body    (babel-macro-body m))
         (n-var   (make-unique-var "N"))
         (count   (+ 2 (random 4)))
         (new-body `(loop for ,n-var from 0 below ,count do ,body)))
    (try-register-variant m new-body "REP")))

(defun mutate-offset-args! (m)
  "Perturb numeric literals in M's body by ±20%, creating a geometric variant."
  (let ((new-body (labels ((perturb (x)
                             (cond
                               ((and (numberp x) (not (zerop x)))
                                (float (* x (+ 0.8 (random 0.4))) 1.0))
                               ((consp x) (mapcar #'perturb x))
                               (t x))))
                    (perturb (babel-macro-body m)))))
    (try-register-variant m new-body "OFF")))

;;; ─── Crossover operator ─────────────────────────────────────────────────────

(defun crossover! (m1 m2)
  "Splice a random call from M2's body into a random site in M1's body."
  (let* ((site1 (random-macro-call (babel-macro-body m1)))
         (site2 (random-macro-call (babel-macro-body m2))))
    (unless (and site1 site2) (return-from crossover! nil))
    (let* ((m2-fn  (gethash (car site2) *babel-registry*))
           (adapted (when m2-fn
                      `(,(babel-macro-name m2-fn)
                        ,@(generate-macro-args m2-fn (babel-macro-params m1)))))
           (new-body (when adapted
                       (substitute-call (babel-macro-body m1) site1 adapted))))
      (when new-body
        (try-register-variant m1 new-body
                              (format nil "X~A" (babel-macro-name m2)))))))

;;; ─── Evolution round ────────────────────────────────────────────────────────

(defun evolve! (&optional (rounds 3))
  "Run ROUNDS of mutation + crossover on the top-scoring macros."
  (incf *generation*)
  (let* ((all (loop for v being the hash-values of *babel-registry*
                    when (> (babel-macro-layer v) 0) collect v))
         (top (subseq (sort all #'> :key #'babel-macro-score)
                      0 (min 6 (length all)))))
    ;; Mutations
    (dolist (m top)
      (loop repeat rounds do
        (case (random 3)
          (0 (mutate-substitute-call! m))
          (1 (mutate-add-repetition!  m))
          (2 (mutate-offset-args!     m)))))
    ;; Crossover between random pairs
    (when (>= (length top) 2)
      (loop repeat rounds do
        (let ((a (nth (random (length top)) top))
              (b (nth (random (length top)) top)))
          (unless (eq a b) (crossover! a b))))))
  (format t "~&[BABEL] Evolution round ~D complete (~D total macros).~%"
          *generation* (hash-table-count *babel-registry*)))
