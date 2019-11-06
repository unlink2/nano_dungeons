; this file contains all collision sub routines 
; for each possible tile
; all tile routines return 
; a = 0 -> no collision
; a = 1 -> collision

; this sub routine simply 
; returns with a = 0
; returns:
;    a = 0 always
no_collision:
    lda #$00
    rts