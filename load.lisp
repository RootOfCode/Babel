;;;; load.lisp — One-shot loader for development without ASDF
;;;;
;;;; Usage from shell:
;;;;   sbcl --load ~/quicklisp/setup.lisp --load /path/to/babel/load.lisp
;;;;
;;;; Usage from REPL (after loading Quicklisp):
;;;;   (load "/path/to/babel/load.lisp")
;;;;
;;;; NOTE: The ASDF system is named :babel-world (not :babel) to avoid
;;;;       collision with the cl 'babel' character-encoding library.

(let ((base (or *load-truename*
                (error "Run via --load or LOAD, not compiled."))))
  (let ((dir (make-pathname :directory (pathname-directory base))))
    (flet ((src (name)
             (merge-pathnames (make-pathname :directory '(:relative "src")
                                             :name name :type "lisp")
                              dir)))
      ;; Dependencies first
      (ql:quickload '(:sdl2 :cl-opengl :cl-glu :alexandria :bordeaux-threads) :silent t)
      ;; Load source files in order
      (dolist (file '("package" "geometry" "registry" "layer0"
                      "inventor" "scoring" "evolution"
                      "camera" "gizmo" "colour" "terrain"
                      "renderer" "persistence" "worlds" "export"
                      "inspector" "main"))
        (format t "~&; Loading ~A…~%" file)
        (load (src file)))))
  (format t "~&; BABEL loaded. Call (babel:initialize) then (babel:run).~%"))
