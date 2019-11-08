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

; this sub routine sets up common
; animation pointers to be used before a jump
; inputs:
;   none
; side effects:
;   changed animation_update, timer, and done
init_jump_animation:
    lda smooth_down
    ora smooth_left
    ora smooth_right
    ora smooth_up
    sta animation_timer

    lda #$00 
    sta animation_timer+1 ; second byte

    lda #<empty_sub 
    sta animation_update 
    lda #>empty_sub
    sta animation_update+1

    rts 

; this routine handles jumping, jumps over 1 tile
; does not go out of bounds
; returns
;   a = 0 when jump tile is hit
; side effects:
;   removes smooth scrolling
;   sets registers 
;   changes player location
jump_left:
    ; set up animation pointers
    jsr init_jump_animation
    lda #<@left  
    sta animation_done 
    lda #>@left
    sta animation_done+1
    lda #$00 ; allow animation
    rts
@left:
    lda player_x 
    clc 
    adc #$02
    bcc @no_carry 
    lda #$00 ; if carry is set we go to 0
@no_carry:

    sta player_x 

    ; do not flag the jump tile as passed
    lda player_x 
    sta player_x_bac 
    lda player_y
    sta player_y_bac

    lda #$00 
    rts 

jump_right:
    ; set up animation pointers
    jsr init_jump_animation
    lda #<@right  
    sta animation_done 
    lda #>@right
    sta animation_done+1
    lda #$00 ; allow animation
    rts 
@right:
    lda player_x
    sec
    sbc #$02
    bcs @no_carry 
    lda #31 ; if carry is set we go to 29
@no_carry:

    sta player_x

    ; do not flag the jump tile as passed
    lda player_x 
    sta player_x_bac 
    lda player_y
    sta player_y_bac

    lda #$00 
    rts 

jump_up:
    ; set up animation pointers
    jsr init_jump_animation
    lda #<@up 
    sta animation_done 
    lda #>@up 
    sta animation_done+1
    lda #$00 ; allow animation
    rts 
@up:
    lda player_y
    sec
    sbc #$02
    bcs @no_carry 
    lda #$00 ; if carry is set we go to 0
@no_carry:

    sta player_y 

    ; do not flag the jump tile as passed
    lda player_x 
    sta player_x_bac 
    lda player_y
    sta player_y_bac

    lda #$00 
    rts 

jump_down:
    ; set up animation pointers
    jsr init_jump_animation
    lda #<@down 
    sta animation_done 
    lda #>@down 
    sta animation_done+1
    lda #$00 ; allow animation
    rts 
@down:
    lda player_y
    clc  
    adc #$02
    bcc @no_carry 
    lda #29 ; if carry is set we go to 29
@no_carry:

    sta player_y 

    ; do not flag the jump tile as passed
    lda player_x 
    sta player_x_bac 
    lda player_y
    sta player_y_bac

    lda #$00 ; do not skip update this frame
    rts 