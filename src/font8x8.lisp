;;;; src/font8x8.lisp — BABEL system bitmap font
;;;;
;;;; Adapted from the user-provided font8x8.lisp asset.  It is kept inside the
;;;; BABEL package so the SDL/OpenGL UI can use it without extra font libraries.

(in-package #:babel)

(defconstant +ui-font-first-char+  #x20)
(defconstant +ui-font-last-char+   #x7E)
(defconstant +ui-font-glyph-count+ 95)   ; #x7E - #x20 + 1
(defconstant +ui-font-width+       8)
(defconstant +ui-font-height+      8)

;;; Helper macro so each glyph entry stays readable.
(defmacro ui-font-glyph-bytes (&rest bytes)
  `(make-array 8 :element-type '(unsigned-byte 8)
                 :initial-contents (list ,@bytes)))

(defparameter *ui-font8x8*
  (vector
   ;; 0x20 SPACE
   (ui-font-glyph-bytes #x00 #x00 #x00 #x00 #x00 #x00 #x00 #x00)
   ;; 0x21 !
   (ui-font-glyph-bytes #x18 #x3C #x3C #x18 #x18 #x00 #x18 #x00)
   ;; 0x22 "
   (ui-font-glyph-bytes #x36 #x36 #x00 #x00 #x00 #x00 #x00 #x00)
   ;; 0x23 #
   (ui-font-glyph-bytes #x36 #x36 #x7F #x36 #x7F #x36 #x36 #x00)
   ;; 0x24 $
   (ui-font-glyph-bytes #x0C #x3E #x03 #x1E #x30 #x1F #x0C #x00)
   ;; 0x25 %
   (ui-font-glyph-bytes #x00 #x63 #x33 #x18 #x0C #x66 #x63 #x00)
   ;; 0x26 &
   (ui-font-glyph-bytes #x1C #x36 #x1C #x6E #x3B #x33 #x6E #x00)
   ;; 0x27 '
   (ui-font-glyph-bytes #x06 #x06 #x03 #x00 #x00 #x00 #x00 #x00)
   ;; 0x28 (
   (ui-font-glyph-bytes #x18 #x0C #x06 #x06 #x06 #x0C #x18 #x00)
   ;; 0x29 )
   (ui-font-glyph-bytes #x06 #x0C #x18 #x18 #x18 #x0C #x06 #x00)
   ;; 0x2A *
   (ui-font-glyph-bytes #x00 #x66 #x3C #xFF #x3C #x66 #x00 #x00)
   ;; 0x2B +
   (ui-font-glyph-bytes #x00 #x0C #x0C #x3F #x0C #x0C #x00 #x00)
   ;; 0x2C ,
   (ui-font-glyph-bytes #x00 #x00 #x00 #x00 #x00 #x0C #x0C #x06)
   ;; 0x2D -
   (ui-font-glyph-bytes #x00 #x00 #x00 #x3F #x00 #x00 #x00 #x00)
   ;; 0x2E .
   (ui-font-glyph-bytes #x00 #x00 #x00 #x00 #x00 #x0C #x0C #x00)
   ;; 0x2F /
   (ui-font-glyph-bytes #x60 #x30 #x18 #x0C #x06 #x03 #x01 #x00)
   ;; 0x30 0
   (ui-font-glyph-bytes #x3E #x63 #x73 #x7B #x6F #x67 #x3E #x00)
   ;; 0x31 1
   (ui-font-glyph-bytes #x0C #x0E #x0C #x0C #x0C #x0C #x3F #x00)
   ;; 0x32 2
   (ui-font-glyph-bytes #x1E #x33 #x30 #x1C #x06 #x33 #x3F #x00)
   ;; 0x33 3
   (ui-font-glyph-bytes #x1E #x33 #x30 #x1C #x30 #x33 #x1E #x00)
   ;; 0x34 4
   (ui-font-glyph-bytes #x38 #x3C #x36 #x33 #x7F #x30 #x78 #x00)
   ;; 0x35 5
   (ui-font-glyph-bytes #x3F #x03 #x1F #x30 #x30 #x33 #x1E #x00)
   ;; 0x36 6
   (ui-font-glyph-bytes #x1C #x06 #x03 #x1F #x33 #x33 #x1E #x00)
   ;; 0x37 7
   (ui-font-glyph-bytes #x3F #x33 #x30 #x18 #x0C #x0C #x0C #x00)
   ;; 0x38 8
   (ui-font-glyph-bytes #x1E #x33 #x33 #x1E #x33 #x33 #x1E #x00)
   ;; 0x39 9
   (ui-font-glyph-bytes #x1E #x33 #x33 #x3E #x30 #x18 #x0E #x00)
   ;; 0x3A :
   (ui-font-glyph-bytes #x00 #x0C #x0C #x00 #x00 #x0C #x0C #x00)
   ;; 0x3B ;
   (ui-font-glyph-bytes #x00 #x0C #x0C #x00 #x00 #x0C #x0C #x06)
   ;; 0x3C <
   (ui-font-glyph-bytes #x18 #x0C #x06 #x03 #x06 #x0C #x18 #x00)
   ;; 0x3D =
   (ui-font-glyph-bytes #x00 #x00 #x3F #x00 #x00 #x3F #x00 #x00)
   ;; 0x3E >
   (ui-font-glyph-bytes #x06 #x0C #x18 #x30 #x18 #x0C #x06 #x00)
   ;; 0x3F ?
   (ui-font-glyph-bytes #x1E #x33 #x30 #x18 #x0C #x00 #x0C #x00)
   ;; 0x40 @
   (ui-font-glyph-bytes #x3E #x63 #x7B #x7B #x7B #x03 #x1E #x00)
   ;; 0x41 A
   (ui-font-glyph-bytes #x0C #x1E #x33 #x33 #x3F #x33 #x33 #x00)
   ;; 0x42 B
   (ui-font-glyph-bytes #x3F #x66 #x66 #x3E #x66 #x66 #x3F #x00)
   ;; 0x43 C
   (ui-font-glyph-bytes #x3C #x66 #x03 #x03 #x03 #x66 #x3C #x00)
   ;; 0x44 D
   (ui-font-glyph-bytes #x1F #x36 #x66 #x66 #x66 #x36 #x1F #x00)
   ;; 0x45 E
   (ui-font-glyph-bytes #x7F #x46 #x16 #x1E #x16 #x46 #x7F #x00)
   ;; 0x46 F
   (ui-font-glyph-bytes #x7F #x46 #x16 #x1E #x16 #x06 #x0F #x00)
   ;; 0x47 G
   (ui-font-glyph-bytes #x3C #x66 #x03 #x03 #x73 #x66 #x7C #x00)
   ;; 0x48 H
   (ui-font-glyph-bytes #x33 #x33 #x33 #x3F #x33 #x33 #x33 #x00)
   ;; 0x49 I
   (ui-font-glyph-bytes #x1E #x0C #x0C #x0C #x0C #x0C #x1E #x00)
   ;; 0x4A J
   (ui-font-glyph-bytes #x78 #x30 #x30 #x30 #x33 #x33 #x1E #x00)
   ;; 0x4B K
   (ui-font-glyph-bytes #x67 #x66 #x36 #x1E #x36 #x66 #x67 #x00)
   ;; 0x4C L
   (ui-font-glyph-bytes #x0F #x06 #x06 #x06 #x46 #x66 #x7F #x00)
   ;; 0x4D M
   (ui-font-glyph-bytes #x63 #x77 #x7F #x7F #x6B #x63 #x63 #x00)
   ;; 0x4E N
   (ui-font-glyph-bytes #x63 #x67 #x6F #x7B #x73 #x63 #x63 #x00)
   ;; 0x4F O
   (ui-font-glyph-bytes #x1C #x36 #x63 #x63 #x63 #x36 #x1C #x00)
   ;; 0x50 P
   (ui-font-glyph-bytes #x3F #x66 #x66 #x3E #x06 #x06 #x0F #x00)
   ;; 0x51 Q
   (ui-font-glyph-bytes #x1E #x33 #x33 #x33 #x3B #x1E #x38 #x00)
   ;; 0x52 R
   (ui-font-glyph-bytes #x3F #x66 #x66 #x3E #x36 #x66 #x67 #x00)
   ;; 0x53 S
   (ui-font-glyph-bytes #x1E #x33 #x07 #x0E #x38 #x33 #x1E #x00)
   ;; 0x54 T
   (ui-font-glyph-bytes #x3F #x2D #x0C #x0C #x0C #x0C #x1E #x00)
   ;; 0x55 U
   (ui-font-glyph-bytes #x33 #x33 #x33 #x33 #x33 #x33 #x3F #x00)
   ;; 0x56 V
   (ui-font-glyph-bytes #x33 #x33 #x33 #x33 #x33 #x1E #x0C #x00)
   ;; 0x57 W
   (ui-font-glyph-bytes #x63 #x63 #x63 #x6B #x7F #x77 #x63 #x00)
   ;; 0x58 X
   (ui-font-glyph-bytes #x63 #x63 #x36 #x1C #x1C #x36 #x63 #x00)
   ;; 0x59 Y
   (ui-font-glyph-bytes #x33 #x33 #x33 #x1E #x0C #x0C #x1E #x00)
   ;; 0x5A Z
   (ui-font-glyph-bytes #x7F #x63 #x31 #x18 #x4C #x66 #x7F #x00)
   ;; 0x5B [
   (ui-font-glyph-bytes #x1E #x06 #x06 #x06 #x06 #x06 #x1E #x00)
   ;; 0x5C backslash
   (ui-font-glyph-bytes #x03 #x06 #x0C #x18 #x30 #x60 #x40 #x00)
   ;; 0x5D ]
   (ui-font-glyph-bytes #x1E #x18 #x18 #x18 #x18 #x18 #x1E #x00)
   ;; 0x5E ^
   (ui-font-glyph-bytes #x08 #x1C #x36 #x63 #x00 #x00 #x00 #x00)
   ;; 0x5F _
   (ui-font-glyph-bytes #x00 #x00 #x00 #x00 #x00 #x00 #x00 #xFF)
   ;; 0x60 `
   (ui-font-glyph-bytes #x0C #x0C #x18 #x00 #x00 #x00 #x00 #x00)
   ;; 0x61 a
   (ui-font-glyph-bytes #x00 #x00 #x1E #x30 #x3E #x33 #x6E #x00)
   ;; 0x62 b
   (ui-font-glyph-bytes #x07 #x06 #x06 #x3E #x66 #x66 #x3B #x00)
   ;; 0x63 c
   (ui-font-glyph-bytes #x00 #x00 #x1E #x33 #x03 #x33 #x1E #x00)
   ;; 0x64 d
   (ui-font-glyph-bytes #x38 #x30 #x30 #x3E #x33 #x33 #x6E #x00)
   ;; 0x65 e
   (ui-font-glyph-bytes #x00 #x00 #x1E #x33 #x3F #x03 #x1E #x00)
   ;; 0x66 f
   (ui-font-glyph-bytes #x1C #x36 #x06 #x0F #x06 #x06 #x0F #x00)
   ;; 0x67 g
   (ui-font-glyph-bytes #x00 #x00 #x6E #x33 #x33 #x3E #x30 #x1F)
   ;; 0x68 h
   (ui-font-glyph-bytes #x07 #x06 #x36 #x6E #x66 #x66 #x67 #x00)
   ;; 0x69 i
   (ui-font-glyph-bytes #x0C #x00 #x0E #x0C #x0C #x0C #x1E #x00)
   ;; 0x6A j
   (ui-font-glyph-bytes #x30 #x00 #x30 #x30 #x30 #x33 #x33 #x1E)
   ;; 0x6B k
   (ui-font-glyph-bytes #x07 #x06 #x66 #x36 #x1E #x36 #x67 #x00)
   ;; 0x6C l
   (ui-font-glyph-bytes #x0E #x0C #x0C #x0C #x0C #x0C #x1E #x00)
   ;; 0x6D m
   (ui-font-glyph-bytes #x00 #x00 #x33 #x7F #x7F #x6B #x63 #x00)
   ;; 0x6E n
   (ui-font-glyph-bytes #x00 #x00 #x1F #x33 #x33 #x33 #x33 #x00)
   ;; 0x6F o
   (ui-font-glyph-bytes #x00 #x00 #x1E #x33 #x33 #x33 #x1E #x00)
   ;; 0x70 p
   (ui-font-glyph-bytes #x00 #x00 #x3B #x66 #x66 #x3E #x06 #x0F)
   ;; 0x71 q
   (ui-font-glyph-bytes #x00 #x00 #x6E #x33 #x33 #x3E #x30 #x78)
   ;; 0x72 r
   (ui-font-glyph-bytes #x00 #x00 #x3B #x6E #x66 #x06 #x0F #x00)
   ;; 0x73 s
   (ui-font-glyph-bytes #x00 #x00 #x3E #x03 #x1E #x30 #x1F #x00)
   ;; 0x74 t
   (ui-font-glyph-bytes #x08 #x0C #x3E #x0C #x0C #x2C #x18 #x00)
   ;; 0x75 u
   (ui-font-glyph-bytes #x00 #x00 #x33 #x33 #x33 #x33 #x6E #x00)
   ;; 0x76 v
   (ui-font-glyph-bytes #x00 #x00 #x33 #x33 #x33 #x1E #x0C #x00)
   ;; 0x77 w
   (ui-font-glyph-bytes #x00 #x00 #x63 #x6B #x7F #x7F #x36 #x00)
   ;; 0x78 x
   (ui-font-glyph-bytes #x00 #x00 #x63 #x36 #x1C #x36 #x63 #x00)
   ;; 0x79 y
   (ui-font-glyph-bytes #x00 #x00 #x33 #x33 #x33 #x3E #x30 #x1F)
   ;; 0x7A z
   (ui-font-glyph-bytes #x00 #x00 #x3F #x19 #x0C #x26 #x3F #x00)
   ;; 0x7B {
   (ui-font-glyph-bytes #x38 #x0C #x0C #x07 #x0C #x0C #x38 #x00)
   ;; 0x7C |
   (ui-font-glyph-bytes #x18 #x18 #x18 #x00 #x18 #x18 #x18 #x00)
   ;; 0x7D }
   (ui-font-glyph-bytes #x07 #x0C #x0C #x38 #x0C #x0C #x07 #x00)
   ;; 0x7E ~
   (ui-font-glyph-bytes #x6E #x3B #x00 #x00 #x00 #x00 #x00 #x00)))

;;; -----------------------------------------------------------------------
;;; Public API
;;; -----------------------------------------------------------------------

(defun ui-font8x8-glyph (char)
  "Return the 8-byte bitmap array for CHAR.
   Falls back to the SPACE glyph for out-of-range characters."
  (let ((idx (char-code char)))
    (when (or (< idx +ui-font-first-char+) (> idx +ui-font-last-char+))
      (setf idx +ui-font-first-char+))
    (aref *ui-font8x8* (- idx +ui-font-first-char+))))

(defun ui-font-pixel (char col row)
  "Return 1 if pixel (COL, ROW) of CHAR is lit, 0 otherwise.
   COL 0 = leftmost, ROW 0 = topmost.  Out-of-range coords return 0."
  (if (or (< col 0) (>= col +ui-font-width+)
          (< row 0) (>= row +ui-font-height+))
      0
      (if (logbitp col (aref (ui-font8x8-glyph char) row)) 1 0)))
