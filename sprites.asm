; this sub routine calls all sprite 
; routines that are needed
; if sprtie_disable flag is set no updates will occur
; inputs:
;   sprite_tile_size -> amount of sprites in use on current map
; side effects:
;   updates all sprites
update_sprites:
    lda game_flags
    and #%01000000 ; sprite enable flag
    beq @done

    ldy sprite_tile_size
    cpy #$FF
    beq @done
@loop:
    ldx sprite_tile_ai, y
    lda sprite_ai_lo, x
    sta src_ptr
    lda sprite_ai_hi, x
    sta src_ptr+1

    jsr jsr_indirect

    dey
    cpy #$FF
    bne @loop
@done:
    rts


; this sub routine loops through all sprite tiles
; inputs:
;   player_x, _y
; returns:
;   a = 1 if collision occured
;   a = 0 if no collision
sprite_collision:
    ldx #$00

@loop:
    lda sprite_tile_flags, x
    and #%10000000 ; enable flag,
    beq @no_collision

    lda sprite_tile_x, x
    cmp player_x
    bne @no_collision

    lda sprite_tile_y, x
    cmp player_y
    beq @collision ; if both passed collision occured

@no_collision:
    inx
    cpx #SPRITE_TILES
    bne @loop


    lda #$00
    rts
@collision:
    lda sprite_tile_ai, x
    tay

    ; call collision routine
    lda sprite_collision_lo, y
    sta src_ptr
    lda sprite_collision_hi, y
    sta src_ptr+1

    txa
    tay ; put data offset into y

    jsr jsr_indirect

    ; lda #$01
    rts

; default sprite init, no special stuff
; inits the sprite as a barrier
; this routine should not destroy any registers
; inputs:
;   y -> pointing to sprite data offset
sprite_init_default:
    pha
    tya
    pha
    txa
    pha

    ; reset sprite flags and data
    lda #$00
    sta sprite_tile_data, y

    lda #%00000000 ; turn off because collision is handeled by tile in this case
    sta sprite_tile_flags, y

    ; set up location
    lda sprite_tile_obj, y
    tax
    lda obj_index_to_addr, x
    sta sprite_ptr

    tya
    tax ; need y value, but need y for indirect,y

    lda sprite_tile_x, x
    sta temp
    lda sprite_tile_y, x
    sta temp+1

    ldx temp+1
    lda tile_convert_table, x ; y position
    ldy #$00 ; for indirect, y
    sta (sprite_ptr), y

    ldx temp
    lda tile_convert_table, x ; x position
    ldy #$03
    sta (sprite_ptr), y

    pla
    tax
    pla
    tay
    pla
    rts

; default sprite update routine
; this routine should not destry any registers
; updates a barrier sprite
; inputs:
;   y -> pointing to sprite data offset
sprite_update_default:
    pha
    tya
    pha
    txa
    pha

    ; set up pointer
    lda sprite_tile_obj, y
    tax
    lda obj_index_to_addr, x
    sta sprite_ptr

    ; check if barrier flag is set, if so make
    ; tile appear as barrier
    lda map_flags
    and #%10000000
    bne @barrier_clear

    ; barrier is not clear
    lda #$50
    bne @done

    ; barrier is clear
@barrier_clear:
    lda #$24 ; empty
@done:
    ; store in sprite
    ldy #$01
    sta (sprite_ptr), y

    pla
    tax
    pla
    tay
    pla
    rts

; same routine as above, but it inverts the barrier behaviour
sprite_update_barrier_invert:
    pha
    tya
    pha
    txa
    pha

    ; set up pointer
    lda sprite_tile_obj, y
    tax
    lda obj_index_to_addr, x
    sta sprite_ptr

    ; check if barrier flag is set, if so make
    ; tile appear as barrier
    lda map_flags
    and #%10000000
    beq @barrier_clear

    ; barrier is not clear
    lda #$50
    bne @done

    ; barrier is clear
@barrier_clear:
    lda #$24 ; empty
@done:
    ; store in sprite
    ldy #$01
    sta (sprite_ptr), y

    pla
    tax
    pla
    tay
    pla
    rts

; default sprite on collision handler
; inputs:
;   y -> pointing to sprite data offset
; returns:
;   a = 1 if collision was valid
;   a = 0 when collision was invalid
sprite_on_collision:
    lda #$01
    rts


; inits the push tile
; inputs:
;   y -> sprite data offset
sprite_init_push:
    pha
    tya
    pha
    txa
    pha

    jsr sprite_init_default

    lda #$80 ; enable flag
    sta sprite_tile_flags, y

    pla
    tax
    pla
    tay
    pla
    rts

    rts

; this sub routine updates a push block
; inputs:
;   y -> pointing to sprite data offset
; sprite data documentation:
;   this AI type uses sprite_data as an offset to its x or y position
;   the lower 4 bits are the actual offset value
;   7th bit = 1 -> sbc; = 0 -> adc
;   6th bit = 1 -> x position; = 0 -> y position
sprite_update_push:
    pha
    tya
    pha
    txa
    pha

    ; load x position
    ldx sprite_tile_x, y
    lda tile_convert_table, x
    sta temp

    ; load y position
    ldx sprite_tile_y, y
    lda tile_convert_table, x
    sta temp+1

    ; sett if we need fine tuning
    lda sprite_tile_data, y
    and #%00001111
    beq @no_adjust ; if the lower 4 bits are already 0 there is no need to adjust

    ; now test what value we need to use as a base
    lda sprite_tile_data, y
    sta temp+3 ; used for bit instruction

    bit temp+3 ; N flag = bit 7, V flag = bit 6

    bvs @y_position ; test bit 7

    ; x position adjust
    ; test if sbc or adc
    bpl @x_add

    ; x sub
    lda sprite_tile_data, y
    and #%00001111
    sta temp+3 ; store for sub
    lda temp
    sec
    sbc temp+3
    sta temp

    jmp @adjust_done 
@x_add:
    lda sprite_tile_data, y

    lda sprite_tile_data, y
    and #%00001111
    clc
    adc temp
    sta temp

    jmp @adjust_done
@y_position

    ; y position adjust
    ; test if sbc or adc
    bpl @y_add

    ; y sub
    lda sprite_tile_data, y
    and #%00001111
    sta temp+3 ; store for sub
    lda temp+1
    sec
    sbc temp+3
    sta temp+1

    jmp @adjust_done
@y_add:
    lda sprite_tile_data, y

    lda sprite_tile_data, y
    and #%00001111
    clc
    adc temp+1
    sta temp+1


@adjust_done:
    lda sprite_tile_data, y
    sec
    sbc #$01
    sta sprite_tile_data, y
@no_adjust:

    ; set up pointer
    lda sprite_tile_obj, y
    tax
    lda obj_index_to_addr, x
    sta sprite_ptr

    ldy #$00
    lda temp+1
    sta (sprite_ptr), y

    ldy #$03
    lda temp
    sta (sprite_ptr), y

    pla
    tax
    pla
    tay
    pla
    rts


    rts

; this sub routine handles collision with a push sprite
; inputs:
;   y -> pointing to sprite data offset
sprite_push_collision:
    ; check which direction the player is coming from
    lda player_y
    cmp player_y_bac
    beq @not_up_down ; if equal skip
    bcs @down ; if greater than player went down


@up:
    ldx sprite_tile_y, y
    dex
    stx get_tile_y
    ldx sprite_tile_x, y
    stx get_tile_x

    lda #%01000000
    sta sprite_tile_data, y

    jmp @tile_got

@down:
    ldx sprite_tile_y, y
    inx
    stx get_tile_y
    ldx sprite_tile_x, y
    stx get_tile_x

    lda #%11000000
    sta sprite_tile_data, y

    jmp @tile_got

@not_up_down:
    lda player_x
    cmp player_x_bac
    beq @not_left_right ; if equal skip
    bcs @right ; if greater player went right


@left:
    ldx sprite_tile_x, y
    dex
    stx get_tile_x
    ldx sprite_tile_y, y
    stx get_tile_y

    lda #%00000000
    sta sprite_tile_data, y

    jmp @tile_got
@right:
    ldx sprite_tile_x, y
    inx
    stx get_tile_x
    ldx sprite_tile_y, y
    stx get_tile_y

    lda #%10000000
    sta sprite_tile_data, y

    jmp @tile_got


@not_left_right:
@collision:
    lda #$01
    rts

@tile_got:
    sty temp ; need y value again

    ; verify that the move can go ahead
    jsr get_tile

    cmp #$24 ; empty tile
    beq @no_collision
    cmp #CLEARABLE_TILES_START
    bcc @collision
    cmp #CLEARABLE_TILES_END
    bcs @collision

@no_collision:
    ldy temp
    lda sprite_tile_data, y
    ora #$08 ; fine tuning offset for sprite to move
    sta sprite_tile_data, y

    lda get_tile_x
    sta sprite_tile_x, y
    lda get_tile_y
    sta sprite_tile_y, y

    lda #$00

    rts

