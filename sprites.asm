; all sprite routines need 
; an input of x pointing to the sprite to use


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
@loop:
    ldx sprite_tile_ai, y
    lda sprite_ai_lo, x 
    sta src_ptr
    lda sprite_ai_hi, x 
    sta src_ptr+1

    jsr jsr_indirect

    dey 
    cmp #$FF
    bne @loop
@done:
    rts 