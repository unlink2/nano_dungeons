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
; this routine should not destroy any registers
; inputs:
;   y -> pointing to sprite data offset
sprite_init_default:
    pha 
    tya 
    pha
    txa 
    pha 

    ; test code
    lda sprite_tile_obj, y
    tax 
    lda obj_index_to_addr, x
    sta sprite_ptr

    tya
    tax ; need y value, but need y for indirect,y 

    lda #32
    ldy #$00 ; for indirect, y 
    sta (sprite_ptr), y

    lda #32
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
sprite_update_default:
    pha 
    tya 
    pha
    txa 
    pha 

    pla 
    tax 
    pla 
    tay 
    pla 
    rts 