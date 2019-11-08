; this sub routine handles animation updates
; inputs:
;   animation_timer -> set how many frames an animation will take
;   animation_update -> function pointer
;   animation_done -> function pointer
; returns:
;   a = 1 if animation just finished AND update should be skipped
;       note that this has to be set by the update done handler
update_animation:
    lda animation_timer
    ora animation_timer+1
    beq @done ; if animation timer is 0 we are done

    ; -1 16 bit sub
    sec 
    sbc #$01 
    sta animation_timer
    lda animation_timer+1 
    sbc #$00 
    sta animation_timer+1

    ; if it is 0 now we call done function
    lda animation_timer
    ora animation_timer+1
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