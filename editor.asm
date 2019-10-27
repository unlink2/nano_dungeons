
; inits editor menu
init_editor_menu:
    ; backup player's location and
    ; move to cursor position
    lda player_x 
    sta player_x_bac
    lda player_y
    sta player_y_bac

    lda #$01 
    sta player_x
    lda #$09 
    sta player_y

    ; move sprite 1 to tile select location
    lda #$77
    sta sprite_data_1
    lda #$38
    sta sprite_data_1+3

    lda #$00
    sta sprite_data_1+1
    sta sprite_data_1+2

    ; set other spirtes to 0/0
    sta sprite_data_2
    sta sprite_data_2+3 
    sta sprite_data_3
    sta sprite_data_3+3
    sta sprite_data_4
    sta sprite_data_4+3

    ; set the tile select's tile index
    lda sprite_data+1 
    sta sprite_data_1+1

    lda #<update_editor_menu
    sta update_sub
    lda #>update_editor_menu
    sta update_sub+1

    rts 

; init editor
init_editor:
    ; restore player's location
    lda player_x_bac
    sta player_x
    lda player_y_bac
    sta player_y

    ; set the tile select's tile index
    lda sprite_data_1+1 
    sta sprite_data+1

    ; hide other sprite offscreen
    lda #$00 
    sta sprite_data_1
    sta sprite_data_1+3

    lda #<update_editor
    sta update_sub
    lda #>update_editor
    sta update_sub+1

    ; set up other sprites used to attribute drawing
    lda #$30 ; corner tile
    sta sprite_data_1+1 
    sta sprite_data_2+1
    sta sprite_data_3+1 
    sta sprite_data_4+1

    ; set up rotation
    lda #%01000000
    sta sprite_data_2+2

    lda #%10000000
    sta sprite_data_3+2

    lda #%11000000
    sta sprite_data_4+2

    rts 

; update sub routine for editor menu
update_editor_menu:
    lda menu_select
    and #EDITOR_MENU_MAX_SELECT ; only 3 possible options
    sta menu_select

    ; set sprite at correct position 
    tax 
    lda editor_menu_cursor_x, x 
    sta player_x

    lda editor_menu_cursor_y, x 
    sta player_y
@done:
    jmp update_done

; update sub routne for editor
update_editor:
    jmp update_done