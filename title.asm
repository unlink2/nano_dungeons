; this file contains the title screen

; inits title mode
init_title:
    lda #%00010000 ; pattern table 1
    sta gfx_flags

    lda #GAME_MODE_TITLE
    sta game_mode

    lda #<update_title
    sta update_sub
    lda #>update_title
    sta update_sub+1

    lda #<update_title_crit
    sta update_sub_crit
    lda #>update_title_crit
    sta update_sub_crit+1

    ; load palette
    lda #<palette_data
    sta palette_ptr
    lda #>palette_data
    sta palette_ptr+1
    jsr load_palette

    rts

; critical updates for title screen
update_title_crit:
    jmp update_crit_done

; update for title
update_title:
    jmp update_done
