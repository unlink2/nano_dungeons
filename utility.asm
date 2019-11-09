
; sub routine that converts the sprite's 
; tile position to an actual 
; location on  the screen
convert_tile_location:
    ldx player_y
    lda tile_convert_table, x 
    sec 
    sbc #$01
    cmp #$FF ; if y location is FF we set it to 0
    bne @not_ff
    lda #$00
@not_ff:
    sta sprite_data

    ldx player_x
    lda tile_convert_table, x 
    clc 
    adc #$00
    sta sprite_data+3

    ; check game mode
    lda game_mode
    cmp #GAME_MODE_EDITOR
    bne @done

    ; if editor mode also update sprites 1-5
    ldx player_y
    lda attr_convert_table, x
    tax 
    lda tile_convert_table, x
    sec 
    sbc #$01 
    cmp #$FF 
    bne @not_ff_editor
    lda #$00
@not_ff_editor:

    sta sprite_data_1
    sta sprite_data_2

    clc 
    adc #$8*3
    sta sprite_data_3
    sta sprite_data_4

    ldx player_x
    lda attr_convert_table, x
    tax 
    lda tile_convert_table, x
    sta sprite_data_1+3
    sta sprite_data_3+3

    clc 
    adc #$8*3
    sta sprite_data_2+3 
    sta sprite_data_4+3

@done:
    rts

; this sub routine applies smooth scrolling
; to sprite 0
; inputs:
;   smooth_up,_down,_left,_right
; side effects:
;   changes position of sprite 0
;   overwirtes a and carry flag
apply_smooth:
    lda sprite_data  
    sec 
    sbc smooth_down
    clc 
    adc smooth_up
    sta sprite_data

    lda sprite_data+3
    sec 
    sbc smooth_right
    clc 
    adc smooth_left 
    sta sprite_data+3
    rts 

; this sub routine decrements all
; smooth movement values if they are greater than 0
; inputs:
;   smooth up, down, left, right
; side effects:
;   a register and carry flag are modified
;   smooth_x values may be decremented
adjust_smooth:
    ; dec smooht values
    lda #$00 
    cmp smooth_left 
    beq @no_dec_left
    dec smooth_left
@no_dec_left

    cmp smooth_right 
    beq @no_dec_right 
    dec smooth_right
@no_dec_right:

    cmp smooth_up 
    beq @no_dec_up 
    dec smooth_up
@no_dec_up:

    cmp smooth_down 
    beq @no_dec_down
    dec smooth_down
@no_dec_down:
    rts 

; this sub routine copies memory from one 
; location to another
; inputs:
;   y -> size
;   src_ptr -> original data
;   dest_ptr -> destination 
; side effects:
;   y is changed, data is written at dest_ptr
memcpy:
    dey 
@loop:
    lda (src_ptr), y 
    sta (dest_ptr), y
    dey
    cpy #$FF ; if underflow stop
    bne @loop
    rts 

; this sub routine converts a number to hex values
; that are ready to be pritned to the screen
; inputs:
;   a -> the number
; side effects:
;   hex_buffer if overwritten
;   a is changed
convert_hex:
    pha ; save value of a

    and #$0F ; first nibble
    sta hex_buffer

    pla 
    and #$F0 ; second nibble
    lsr 
    lsr 
    lsr 
    lsr ; shift to get right value
    sta hex_buffer+1
    
    rts 

; this sub routine 
; makes an indirect jsr 
; based on src_ptr
; inputs
;   src_ptr -> the rotuine to jump to
; side effects:
;   depends on indirect routine called
jsr_indirect:
    jmp (src_ptr)

; this sub routine is a no-op update routine
update_none:
    jmp update_done

; this is an empty sub routine 
; useful for function pointers that
; require an input
empty_sub:
    rts 

; this sub routine hides objects
; at 0/0
; side effects:
;   moves obejcts
hide_objs:
    lda #$00
    ldx #$00
@loop:
    sta sprite_data, x 
    inx
    cpx #$FF
    bne @loop 
    rts 