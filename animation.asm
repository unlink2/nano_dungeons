; this sub routine handles animation updates
; inputs:
;   animation_timer -> set how many frames an animation will take
;   animation_update -> function pointer
;   animation_done -> function pointer
; returns:
;   a = 1 if animation just finished AND update should be skipped
;       note that this has to be set by the update done handler
update_animation:
    ldx animation_timer
    beq @done ; if animation timer is 0 we are done

    dex ; -1
    stx animation_timer

    ; if it is 0 now we call done function
    cpx #$00
    bne @not_done

    lda animation_done
    sta src_ptr 
    lda animation_done+1
    sta src_ptr+1
    jsr jsr_indirect
    rts 
@not_done:
    ; otherwise call update routine
    lda animation_update
    sta src_ptr 
    lda animation_update+1
    sta src_ptr+1
    jsr jsr_indirect
@done:
    lda #$00
    rts 