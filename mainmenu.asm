
; this sub routine sets up the main menu
; it will load the background into nametable 1
; and swap to that table
; also moves sprites around
; inputs:
;   none
; side effects:
;   nametables are updated, sprites changed
;   registers changed
init_main_menu:
    jsr stop_audio

    lda #$00
    sta gfx_flags

    sta load_flags

    lda #$01
    sta level_select

    lda #<update_main_menu
    sta update_sub
    lda #>update_main_menu
    sta update_sub+1

    lda #<update_crit_none
    sta update_sub_crit
    lda #>update_crit_none
    sta update_sub_crit+1

    ; load palette
    lda #<palette_data
    sta palette_ptr
    lda #>palette_data
    sta palette_ptr+1
    jsr load_palette

    lda #GAME_MODE_MENU
    sta game_mode

    jsr hide_objs

    ; move unsued sprites off-screen
    lda #$00
    sta sprite_data_3
    sta sprite_data_3+3
    sta sprite_data_4
    sta sprite_data_4+3
    sta sprite_data_5
    sta sprite_data_5+3
    sta sprite_data_6
    sta sprite_data_6+3
    sta sprite_data_7
    sta sprite_data_7+3
    sta sprite_data_8
    sta sprite_data_8+3
    sta sprite_data_9
    sta sprite_data_9+3
    sta sprite_data_A
    sta sprite_data_A+3

    ; no smooth scrolling outside of in-game mode
    sta smooth_left
    sta smooth_right
    sta smooth_up
    sta smooth_down

    ; level select display
    lda #$0B*08 ; x position
    sta sprite_data_1+3
    lda #$0A*08 ; x positon
    sta sprite_data_2+3

    lda #$08*08 ; y position
    sta sprite_data_1
    sta sprite_data_2

    ; cursor sprite
    lda #$31
    sta sprite_data+1

    ; seed input
    lda seed_bac
    sta seed_input
    lda seed_bac+1
    sta seed_input+1

    ; seed input display
    ldy #$97 ; y coordinate
    sty sprite_data_3
    sty sprite_data_4
    sty sprite_data_5
    sty sprite_data_6
    ldy #$48
    sty sprite_data_3+3
    ldy #$48+8
    sty sprite_data_4+3
    ldy #$48+8*2
    sty sprite_data_5+3
    ldy #$48+8*3
    sty sprite_data_6+3

    ; enable sprite rendering
    lda mask_flags
    ora #%00010000 ; sprites
    sta mask_flags

    rts

; update sub routine for main menu
; inputs:
;   none
; side effects:
;   regsiters and flags are changed
update_main_menu:
    lda menu_select
    and #MAIN_MENU_MAX_SELECT ; only 3 possible options
    cmp #$08
    bcc @no_overflow
    lda #$00
@no_overflow:
    sta menu_select

    ; set sprite at correct position 
    tax 
    lda main_menu_cursor_x, x 
    sta player_x

    lda main_menu_cursor_y, x 
    sta player_y

    lda main_menu_cursor_attr, x
    sta sprite_data+2

    ; use 2 sprites to display the currently selected level
    lda level_select 
    and #$0F 
    sta sprite_data_1+1
    lda level_select
    and #$F0 
    lsr 
    lsr 
    lsr 
    lsr 
    sta sprite_data_2+1

    ; display seed input
    lda seed_input
    jsr convert_hex
    lda hex_buffer+1
    sta sprite_data_3+1
    lda hex_buffer
    sta sprite_data_4+1
    lda seed_input+1
    jsr convert_hex
    lda hex_buffer+1
    sta sprite_data_5+1
    lda hex_buffer
    sta sprite_data_6+1

    ; seed = rand16 in main menu
    lda rand8
    sta seed
    lda rand16
    sta seed+1

@done:
    jmp update_done
