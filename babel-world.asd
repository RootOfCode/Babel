;;;; babel-world.asd — BABEL: The Lisp Macro World Compiler
;;;; ASDF system definition
;;;;
;;;; NOTE: File is named babel-world.asd (not babel.asd) to avoid shadowing
;;;;       the cl 'babel' character-encoding library that sdl2 depends on.
;;;; NOTE: System is named :babel-world (not :babel) for the same reason.
;;;;
;;;; Load with: (ql:quickload :babel-world)
;;;; Run  with: (babel:run)

(asdf:defsystem :babel-world
  :description "BABEL — 3D Wireframe World Compiler driven by layered Lisp macros"
  :version "0.1.0"
  :author "Bruno
  :license "MIT"
  :depends-on (:sdl2 :cl-opengl :cl-glu :alexandria :bordeaux-threads)
  :serial t
  :components
  ((:module "src"
    :serial t
    :components
    ((:file "package")
     (:file "geometry")
     (:file "registry")
     (:file "layer0")
     (:file "inventor")
     (:file "scoring")
     (:file "evolution")
     (:file "camera")
     (:file "gizmo")
     (:file "colour")
     (:file "terrain")
     (:file "renderer")
     (:file "persistence")
     (:file "worlds")
     (:file "export")
     (:file "inspector")
     (:file "main")))))
