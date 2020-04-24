
; the pause menu init tries to be as
; small as possible as to not disrupt gameplay states
; side effects:
;   disables sprites, disables sprite updating, switches to nt1
;   changes update routines from gameplay to menu
;   changes gamemode from game to pause
init_pause_menu:
    lda game_flags
    and #%10111111 ; disable sprite updates
    sta game_flags

    lda mask_flags
    and #%11101111 ; no sprites
    sta mask_flags

    lda #$01
    sta nametable

    lda #<update_none
    sta update_sub
    lda #>update_none
    sta update_sub+1

    lda #<update_crit_none
    sta update_sub_crit
    lda #>update_crit_none
    sta update_sub_crit+1

    lda #GAME_MODE_PAUSE
    sta game_mode

    rts

; reverts all changes made during pause
resume_game:
    lda game_flags
    ora #%01000000 ; enable sprite updates
    sta game_flags

    lda mask_flags
    ora #%00010000 ; sprites
    sta mask_flags

    lda #$00
    sta nametable

    lda #<update_game
    sta update_sub
    lda #>update_game
    sta update_sub+1

    lda #<update_game_crit
    sta update_sub_crit
    lda #>update_game_crit
    sta update_sub_crit+1

    lda #GAME_MODE_GAME
    sta game_mode

    rts 
