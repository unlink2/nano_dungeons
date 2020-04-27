
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

    lda #<update_pause_crit
    sta update_sub_crit
    lda #>update_pause_crit
    sta update_sub_crit+1

    lda #GAME_MODE_PAUSE
    sta game_mode

    lda #$00
    sta menu_select
    lda #$01
    sta menu_select_prev

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

update_pause_crit:
    ldx menu_select ; place cursor on screen
    ; oob check
    cpx #$02
    bcc @not_oob
    ldx #$00
    stx menu_select
@not_oob:

    ; see if previous matches with current select
    cpx menu_select_prev
    beq @done

    lda pause_menu_cursor_x, x
    sta get_tile_x
    lda pause_menu_cursor_y, x
    sta get_tile_y
    lda #$31 ; arrow tile
    ldx #$01 ; nt1
    jsr set_tile

    ; clear previous tile
    ldx menu_select_prev
    lda pause_menu_cursor_x, x
    sta get_tile_x
    lda pause_menu_cursor_y, x
    sta get_tile_y
    lda #$24 ; arrow tile
    ldx #$01 ; nt1
    jsr set_tile

    ; set previous menu select
    lda menu_select
    sta menu_select_prev
@done:
    jmp update_crit_done
