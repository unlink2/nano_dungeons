; this file defines a character map for ascii -> game font
; 0 - 9
.mrep 10
.map '0'+.ri., 0+.ri.
.endrep

; A-Z
.mrep 26
.map 'A'+.ri., 10+.ri.
.endrep

; space
.map $20, $24

