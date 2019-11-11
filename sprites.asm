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
