
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