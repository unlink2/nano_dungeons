; this sub routine handles delayed updates
; inputs:
;   delay_timer -> set how many frames an animation will take
;   delay_update -> function pointer
;   delay_done -> function pointer
; returns:
;   a = 1 if animation just finished AND update should be skipped
;       note that this has to be set by the update done handler
update_delay:
    lda delay_timer
    ora delay_timer+1
    beq @done ; if animation timer is 0 we are done

    ; -1 16 bit sub
    sec 
    sbc #$01 
    sta delay_timer
    lda delay_timer+1 
    sbc #$00 
    sta delay_timer+1

    ; if it is 0 now we call done function
    lda delay_timer
    ora delay_timer+1
    bne @not_done

    lda delay_done
    sta src_ptr 
    lda delay_done+1
    sta src_ptr+1
    jsr jsr_indirect
    rts 
@not_done:
    ; otherwise call update routine
    lda delay_update
    sta src_ptr 
    lda delay_update+1
    sta src_ptr+1
    jsr jsr_indirect
@done:
    lda #$00
    rts 