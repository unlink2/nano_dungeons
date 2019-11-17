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
sprite_update_push:
    rts

; this sub routine handles collision with a push sprite
; inputs:
;   y -> pointing to sprite data offset
sprite_push_collision:
    lda #$00
    rts

