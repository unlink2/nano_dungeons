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
;   changed delay_update, timer, and done
init_jump_animation:
    lda smooth_down
    ora smooth_left
    ora smooth_right
    ora smooth_up
    sta delay_timer

    lda #$00 
    sta delay_timer+1 ; second byte

    lda #<jump_update
    sta delay_update 
    lda #>jump_update
    sta delay_update+1

    lda #$38
    sta sprite_data+1
    sta sprite_data_1+1
    sta sprite_data_2+1 
    sta sprite_data_3+1

    ; set up attributes
    lda #$00 
    sta sprite_data+21
    lda #%10000000
    sta sprite_data_1+2
    lda #%01000000
    sta sprite_data_2+2
    lda #%11000000
    sta sprite_data_3+2

    rts 

; this sub routine inits the pre-jump state
; of the jump animation
; inputs:
;   none
; side effects:
;   changes delay_update, timer and done
;   changes player tile index
;   changes sprite_1-4
init_pre_jump:
    lda smooth_down
    ora smooth_left
    ora smooth_right
    ora smooth_up
    sta delay_timer

    lda #$00 
    sta delay_timer+1 ; second byte

    lda #<empty_sub 
    sta delay_update 
    lda #>empty_sub
    sta delay_update+1

    rts 

; this sub routine updates the jump routines
; inputs:
;   none
; side effects:
;   moves sprites_1-3 relative to player
;   x and a registers are used
;   uses temp to store original location
jump_update:
    lda sprite_data+3 
    sta temp 
    lda sprite_data
    sta temp+1

    ; first move x positions
    lda temp
    clc 
    adc #$04
    sta sprite_data_2+3
    sta sprite_data_3+3

    lda temp
    sec 
    sbc #$04
    sta sprite_data+3
    sta sprite_data_1+3

    ; y position
    lda  temp+1
    clc 
    adc #$04
    sta sprite_data_1 
    sta sprite_data_3

    lda temp+1
    sec 
    sbc #$04
    sta sprite_data
    sta sprite_data_2 

.rep 20 nop

    rts 

; this sub routine restore
; the original player tile at the end of a jump
; inputs:
;   none
; side effects:
;   changes player tile index
;   changes sprite_1-3
finish_jump:
    lda #$00
    sta sprite_data+2
    sta sprite_data_1+2 
    sta sprite_data_2+2 
    sta sprite_data_3+2

    sta sprite_data_1 
    sta sprite_data_1+3 
    sta sprite_data_2
    sta sprite_data_2+3 
    sta sprite_data_3
    sta sprite_data_3+3

    lda #$31 
    sta sprite_data+1
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
    jsr init_pre_jump
    lda #<@animation  
    sta delay_done 
    lda #>@animation
    sta delay_done+1
    lda #$00 ; allow animation
    rts
@animation:
    ; set up correct smooth value
    lda #$10 
    sta smooth_left 

    ; set up animation pointers
    jsr init_jump_animation
    lda #<finish_jump 
    sta delay_done 
    lda #>finish_jump
    sta delay_done+1

    lda player_x 
    sec 
    sbc #$02
    bcs @no_carry 
    lda #$00 ; if carry is set we go to 0
@no_carry:

    sta player_x 

    ; do not flag the jump tile as passed
    lda player_x 
    sta player_x_bac 
    lda player_y
    sta player_y_bac

    lda #$00 
@left:
    rts 

jump_right:
    ; set up animation pointers
    jsr init_pre_jump
    lda #<@animation  
    sta delay_done 
    lda #>@animation
    sta delay_done+1
    lda #$00 ; allow animation
    rts
@animation:
    ; set up correct smooth value
    lda #$10 
    sta smooth_right

    ; set up animation pointers
    jsr init_jump_animation
    lda #<finish_jump 
    sta delay_done 
    lda #>finish_jump
    sta delay_done+1

    lda player_x
    clc 
    adc #$02
    bcc @no_carry 
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
    jsr init_pre_jump
    lda #<@animation  
    sta delay_done 
    lda #>@animation
    sta delay_done+1
    lda #$00 ; allow animation
    rts
@animation:
    ; set up correct smooth value
    lda #$10 
    sta smooth_up

    ; set up animation pointers
    jsr init_jump_animation
    lda #<finish_jump 
    sta delay_done 
    lda #>finish_jump
    sta delay_done+1

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
    jsr init_pre_jump
    lda #<@animation  
    sta delay_done 
    lda #>@animation
    sta delay_done+1
    lda #$00 ; allow animation
    rts
@animation:
    ; set up correct smooth value
    lda #$10 
    sta smooth_down

    ; set up animation pointers
    jsr init_jump_animation
    lda #<finish_jump 
    sta delay_done 
    lda #>finish_jump
    sta delay_done+1

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