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

; this routine handles jumping, jumps over 1 tile
; does not go out of bounds
; returns
;   a = 0 when jump tile is hit
; side effects:
;   removes smooth scrolling
;   sets registers 
;   changes player location
jump_left:
    lda player_x 
    clc 
    adc #$02
    bcc @no_carry 
    lda #$00 ; if carry is set we go to 0
@no_carry:

    sta player_x 

    lda #$00 
    sta smooth_down
    sta smooth_left
    sta smooth_right
    sta smooth_up
    rts 

jump_right:
    lda player_x
    sec
    sbc #$02
    bcs @no_carry 
    lda #31 ; if carry is set we go to 29
@no_carry:

    sta player_x

    lda #$00
    sta smooth_down
    sta smooth_left
    sta smooth_right
    sta smooth_up
    rts 

jump_up:
    lda player_y
    sec
    sbc #$02
    bcs @no_carry 
    lda #$00 ; if carry is set we go to 0
@no_carry:

    sta player_y 

    lda #$00 
    sta smooth_down
    sta smooth_left
    sta smooth_right
    sta smooth_up
    rts 

jump_down:
    lda player_y
    clc  
    adc #$02
    bcc @no_carry 
    lda #29 ; if carry is set we go to 29
@no_carry:

    sta player_y 

    lda #$00
    sta smooth_down
    sta smooth_left
    sta smooth_right
    sta smooth_up
    rts 