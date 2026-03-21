;;;; src/export.lisp
;;;; Export the current scene geometry to external file formats.
;;;;
;;;;  Wavefront OBJ  — vertices + edges as line elements
;;;;  SVG            — orthographic top-down and side projections
;;;;  EDN            — Clojure-compatible data (vertices + edges as vectors)

(in-package #:babel)

;;; ─── Wavefront OBJ ───────────────────────────────────────────────────────────

(defun export-obj! (&optional (path "/tmp/babel-world.obj"))
  "Export the current scene as a Wavefront OBJ file.
   Edges are written as 'l' (line) elements.
   Load in Blender with: File → Import → Wavefront (.obj)"
  (let ((verts *cached-verts*)
        (edges *cached-edges*))
    (if (zerop (length verts))
        (format t "~&[BABEL] No geometry to export.~%")
        (progn
          (with-open-file (f path :direction :output :if-exists :supersede)
            (format f "# BABEL World Export~%")
            (format f "# ~D vertices, ~D edges~%~%"
                    (length verts) (length edges))
            ;; Vertices: OBJ is Y-up, we use Y-up, so coords map directly
            (loop for v across verts do
              (format f "v ~,6f ~,6f ~,6f~%"
                      (float (first v))
                      (float (second v))
                      (float (third v))))
            (format f "~%")
            ;; Line elements: OBJ indices are 1-based
            (loop for e across edges do
              (format f "l ~D ~D~%"
                      (1+ (first  e))
                      (1+ (second e)))))
          (format t "~&[BABEL] OBJ exported → ~A  (~D verts, ~D edges)~%"
                  path (length verts) (length edges))))))

;;; ─── SVG projection export ───────────────────────────────────────────────────

(defun project-vertex (v mode scale offset-x offset-y)
  "Project 3D vertex V to 2D for SVG export.
   MODE is :top (XZ plane), :front (XY plane), :side (ZY plane), or :iso."
  (let ((x (float (first  v)))
        (y (float (second v)))
        (z (float (third  v))))
    (ecase mode
      (:top   (list (+ offset-x (* scale x))
                    (+ offset-y (* scale z))))
      (:front (list (+ offset-x (* scale x))
                    (+ offset-y (* scale (- y)))))
      (:side  (list (+ offset-x (* scale z))
                    (+ offset-y (* scale (- y)))))
      (:iso   ;; simple isometric
       (list (+ offset-x (* scale (- x z)))
             (+ offset-y (* scale (+ (* 0.5 (- x z)) (- y)))))))))

(defun export-svg! (&optional (path "/tmp/babel-world.svg")
                    &key (mode :iso) (scale 2.0) (width 1200) (height 800))
  "Export the current scene as an SVG wireframe.
   MODE: :top :front :side :iso (default)."
  (let ((verts *cached-verts*)
        (edges *cached-edges*))
    (if (zerop (length verts))
        (format t "~&[BABEL] No geometry to export.~%")
        (progn
          (let ((ox (/ width  2.0))
                (oy (/ height 2.0)))
            (with-open-file (f path :direction :output :if-exists :supersede)
              (format f "<?xml version=\"1.0\" encoding=\"UTF-8\"?>~%")
              (format f "<svg width=\"~D\" height=\"~D\" " width height)
              (format f "xmlns=\"http://www.w3.org/2000/svg\">~%")
              (format f "<rect width=\"100%\" height=\"100%\" fill=\"#0d0d14\"/>~%")
              (format f "<g stroke=\"#2adfd0\" stroke-width=\"0.8\" opacity=\"0.85\">~%")
              (loop for e across edges do
                (let* ((v0 (aref verts (first  e)))
                       (v1 (aref verts (second e)))
                       (p0 (project-vertex v0 mode scale ox oy))
                       (p1 (project-vertex v1 mode scale ox oy)))
                  (format f "  <line x1=\"~,2f\" y1=\"~,2f\" x2=\"~,2f\" y2=\"~,2f\"/>~%"
                          (first p0) (second p0)
                          (first p1) (second p1))))
              (format f "</g>~%")
              ;; Label
              (format f "<text x=\"10\" y=\"20\" fill=\"#3a9\" ")
              (format f "font-family=\"monospace\" font-size=\"12\">")
              (format f "BABEL ~A | ~D edges</text>~%" mode (length edges))
              (format f "</svg>~%")))
          (format t "~&[BABEL] SVG exported → ~A  (~A projection)~%"
                  path mode)))))

(defun export-svg-quad! (&optional (path "/tmp/babel-quad.svg"))
  "Export four-view SVG: top, front, side, and isometric."
  (let ((verts *cached-verts*)
        (edges *cached-edges*))
    (if (zerop (length verts))
        (format t "~&[BABEL] No geometry to export.~%")
        (let* ((w 1600) (h 1200)
               (qw (/ w 2)) (qh (/ h 2))
               (s  1.2)
               (views `((:top   ,(/ qw 2) ,(/ qh 2))
                        (:front ,(+ qw (/ qw 2)) ,(/ qh 2))
                        (:side  ,(/ qw 2) ,(+ qh (/ qh 2)))
                        (:iso   ,(+ qw (/ qw 2)) ,(+ qh (/ qh 2))))))
          (with-open-file (f path :direction :output :if-exists :supersede)
            (format f "<?xml version=\"1.0\" encoding=\"UTF-8\"?>~%")
            (format f "<svg width=\"~D\" height=\"~D\" " w h)
            (format f "xmlns=\"http://www.w3.org/2000/svg\">~%")
            (format f "<rect width=\"100%\" height=\"100%\" fill=\"#09090f\"/>~%")
            ;; Grid lines dividing four quadrants
            (format f "<line x1=\"~D\" y1=\"0\" x2=\"~D\" y2=\"~D\" " qw qw h)
            (format f "stroke=\"#222\" stroke-width=\"1\"/>~%")
            (format f "<line x1=\"0\" y1=\"~D\" x2=\"~D\" y2=\"~D\" " qh w qh)
            (format f "stroke=\"#222\" stroke-width=\"1\"/>~%")
            (dolist (view views)
              (let ((mode (first view))
                    (ox   (second view))
                    (oy   (third  view)))
                (format f "<g stroke=\"#2adfd0\" stroke-width=\"0.7\" opacity=\"0.9\">~%")
                (loop for e across edges do
                  (let* ((v0 (aref verts (first  e)))
                         (v1 (aref verts (second e)))
                         (p0 (project-vertex v0 mode s ox oy))
                         (p1 (project-vertex v1 mode s ox oy)))
                    (format f "  <line x1=\"~,1f\" y1=\"~,1f\" x2=\"~,1f\" y2=\"~,1f\"/>~%"
                            (first p0) (second p0)
                            (first p1) (second p1))))
                (format f "</g>~%")
                (format f "<text x=\"~,0f\" y=\"~,0f\" fill=\"#47b\" "
                        (- ox (/ qw 2.2)) (- oy (/ qh 2.2)))
                (format f "font-family=\"monospace\" font-size=\"11\">~A</text>~%"
                        (string-downcase (symbol-name mode)))))
            (format f "</svg>~%"))
          (format t "~&[BABEL] Quad-SVG exported → ~A~%" path)))))

;;; ─── EDN export (Clojure-compatible data) ────────────────────────────────────

(defun export-edn! (&optional (path "/tmp/babel-world.edn"))
  "Export geometry as EDN — readable by Clojure, babashka, and many tools."
  (let ((verts *cached-verts*)
        (edges *cached-edges*))
    (if (zerop (length verts))
        (format t "~&[BABEL] No geometry to export.~%")
        (with-open-file (f path :direction :output :if-exists :supersede)
          (format f "{:babel/version 1~%")
          (format f " :scene ~D~%" *current-scene*)
          (format f " :vertices [~%")
          (loop for v across verts do
            (format f "   [~,6f ~,6f ~,6f]~%"
                    (float (first v)) (float (second v)) (float (third v))))
          (format f " ]~% :edges [~%")
          (loop for e across edges do
            (format f "   [~D ~D]~%" (first e) (second e)))
          (format f " ]}~%")
          (format t "~&[BABEL] EDN exported → ~A~%" path)))))

;;; ─── Combined export shortcut ────────────────────────────────────────────────

(defun export-all! (&optional (dir "/tmp/babel-export/"))
  "Export the current scene to OBJ + SVG (quad) + EDN in DIR."
  (ensure-directories-exist dir)
  (export-obj!       (merge-pathnames "world.obj"      dir))
  (export-svg-quad!  (merge-pathnames "world-quad.svg" dir))
  (export-edn!       (merge-pathnames "world.edn"      dir))
  (format t "~&[BABEL] Full export written to ~A~%" dir))
