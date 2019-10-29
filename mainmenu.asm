
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
    lda #<update_main_menu
    sta update_sub
    lda #>update_main_menu
    sta update_sub+1

    lda #GAME_MODE_MENU
    sta game_mode

    ; move unsued sprites off-screen
    lda #$00
    sta sprite_data_1
    sta sprite_data_1+3
    sta sprite_data_2
    sta sprite_data_2+3
    sta sprite_data_3
    sta sprite_data_3+3
    sta sprite_data_4 
    sta sprite_data_4+3
    sta sprite_data_5 
    sta sprite_data_5+3

    ; cursor sprite
    lda #$31 
    sta sprite_data+1

    rts 

; update sub routine for main menu
; inputs:
;   none
; side effects:
;   regsiters and flags are changed
update_main_menu:
    lda menu_select
    and #MAIN_MENU_MAX_SELECT ; only 3 possible options
@no_overflow
    sta menu_select

    ; set sprite at correct position 
    tax 
    lda main_menu_cursor_x, x 
    sta player_x

    lda main_menu_cursor_y, x 
    sta player_y

    lda main_menu_cursor_attr, x
    sta sprite_data+2
@done:
    jmp update_done