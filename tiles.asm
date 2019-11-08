; this file contains all collision sub routines 
; for each possible tile
; all tile routines return 
; a = 0 -> no collision
; a = 1 -> collision

; this sub routine simply 
; returns with a = 0 to flag no collision
; returns:
;    a = 0 always
no_collision:
    lda #$00
    rts

; this sub routine simply
; returns with a = 1 to flag collision
; returns:
;   a = 1 always
collision:
    lda #$01 
    rts 


; this routine only returns 
; 0 when the direction value is nonzero
; returns:
;   a = 0 when direction is nonzero
.macro one_way_n direction
    lda direction 
    beq @.mi.collision
    lda #$00 
    rts 
@.mi.collision 
    lda #$01 
    rts 
.endm

one_way_left:
    one_way_n smooth_left

one_way_right:
    one_way_n smooth_right 

one_way_up:
    one_way_n smooth_up 

one_way_down:
    one_way_n smooth_down