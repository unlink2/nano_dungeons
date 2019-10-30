; handles all inputs
input_handler:
    ; reset latch
    lda #$01 
    sta $4016
    lda #$00 
    sta $4016 ; both controllers are latching now

    lda $4016 ; p1 - A
    and #%00000001 
    beq @no_a
    jsr a_input
@no_a:

    lda $4016 ; p1 - B
    and #%00000001
    beq @no_b
    jsr b_input
@no_b:

    lda $4016 ; p1 - select
    and #%00000001
    beq @no_select
    jsr select_input
@no_select:

    lda $4016 ; p1 - start
    and #%00000001
    beq @no_start 
    jsr start_input
@no_start:

    lda $4016 ; p1 - up
    and #%0000001
    beq @no_up
    jsr go_up
@no_up:

    lda $4016 ; p1 - down
    and #%00000001
    beq @no_down 
    jsr go_down
@no_down:

    lda $4016 ; p1 - left
    and #%00000001
    beq @no_left 
    jsr go_left
@no_left:

    lda $4016 ; p1 - right 
    and #%00000001
    beq @no_right 
    jsr go_right
@no_right:
    rts     

; make movement check
; uses move delay
; inputs:
;   none 
; returns:
;   a -> 0 if move can go ahead
;   a -> 1 if move cannot go ahead 
can_move:
    lda move_delay 
    rts 

; makse select check,
; uses select delay
; inputs:
;   none 
; returns:
; a-> 0 if select possible
; a-> 1 if select cannot go ahead
can_select:
    lda select_delay
    rts 

; a input
; places the player's current tile at the player's current
; location. only works in EDITOR_MODE
a_input:
    jsr can_select
    bne @done

    lda #MOVE_DELAY_FRAMES
    sta select_delay

    lda game_mode
    cmp #GAME_MODE_EDITOR 
    bne @not_editor

    jsr update_tile

    rts 
@not_editor:
    cmp #GAME_MODE_EDITOR_MENU
    bne @not_editor_menu
    jsr a_input_editor_menu
    rts 
@not_editor_menu:
    cmp #GAME_MODE_MENU
    bne @done 
    jsr a_input_main_menu
@done:
    rts 

; editor menu code for a input
a_input_editor_menu:
    lda #MOVE_DELAY_FRAMES*2
    sta select_delay

    ; set up the right pointers for data write
    ; save slot is based on menu select
    lda menu_select
    cmp #EDITOR_MENU_SAVE3
    bne @not_slot3
    lda #<save_3
    sta level_data_ptr
    lda #>save_3
    sta level_data_ptr+1

    lda #<attr_3
    sta attr_ptr
    lda #>attr_3 
    sta attr_ptr+1

    lda #<palette_3 
    sta dest_ptr
    lda #>palette_3 
    sta dest_ptr+1

    jmp @slot_slected
@not_slot3:

    cmp #EDITOR_MENU_SAVE2
    bne @not_slot2

    lda #<save_2
    sta level_data_ptr
    lda #>save_2
    sta level_data_ptr+1

    lda #<attr_2
    sta attr_ptr
    lda #>attr_2 
    sta attr_ptr+1

    lda #<palette_2 
    sta dest_ptr
    lda #>palette_2
    sta dest_ptr+1 

    jmp @slot_slected
@not_slot2:
    ; new slot should not save, but instead is a debug feature that loads a map based on the selected tile id
    cmp #EDITOR_MENU_NEW
    beq @load_debug_map

    cmp #EDITOR_MENU_SAVE1
    beq @slot_1 
    jmp @no_slot: 

@slot_1:
    ; always pick slot 1 as default option
    lda #<save_1
    sta level_data_ptr
    lda #>save_1
    sta level_data_ptr+1

    lda #<attr_1
    sta attr_ptr
    lda #>attr_1 
    sta attr_ptr+1

    lda #<palette_1 
    sta dest_ptr
    lda #>palette_1 
    sta dest_ptr+1 

@slot_slected:
    lda #$00
    sta $2001 ; disable rendering

    lda #<level_data 
    sta level_ptr 
    lda #>level_data 
    sta level_ptr+1

    ; disable NMI, don't change other flags
    ; NMI needs to be disabled 
    ; to prevent it being called again
    ; while compression is ongoing
    lda $2000
    and #%01111111
    ora nametable ; display the correct nametable to avoid flickering
    sta $2000
    jsr compress_level

    ldx #$00
    jsr write_attr
    ;lda $2000
    ;ora #%10000000
    ;sta $2000 ; enable NMI again 
    ; copy palette
    lda #<level_palette 
    sta src_ptr
    lda #>level_palette
    sta src_ptr+1
    ldy #PALETTE_SIZE 
    jsr memcpy

    rts 
@no_slot:
    cmp #EDITOR_MENU_BACK
    bne @done
    ; load nametable
    lda #$00
    sta $2001 ; no rendering

    lda $2000
    and #%01111111
    ora nametable ; display the correct nametable to avoid flickering
    sta $2000

    ldx #$00
    stx menu_select
    jsr load_menu
    jsr init_main_menu
@done:
    rts

@load_debug_map:
    ldx #$00
    stx $2001 ; disable rendering

    ; select the map to load
    ldx sprite_data_1+1 ; based on tile
    lda map_table_lo, x
    sta level_data_ptr
    lda map_table_hi, x
    sta level_data_ptr+1

    lda attr_table_lo, x
    sta attr_ptr
    lda attr_table_hi, x
    sta attr_ptr+1

    ; for memcpy, copy palette
    lda palette_table_lo, x 
    sta src_ptr 
    lda palette_table_hi, x 
    sta src_ptr+1
    lda #<level_palette 
    sta dest_ptr 
    lda #>level_palette
    sta dest_ptr+1

    lda #<level_data 
    sta level_ptr 
    lda #>level_data 
    sta level_ptr+1

    ; disable NMI until load is complete
    lda $2000
    and #%01111111
    ora nametable ; display the correct nametable to avoid flickering
    sta $2000

    jsr decompress_level

    ; copy palette we set up earlier
    ldy #PALETTE_SIZE ; size to copy
    jsr memcpy

    ldx $00 ; nametable 0
    jsr load_level
    jsr load_attr
    jsr load_palette

    lda #GAME_MODE_EDITOR
    sta game_mode
    jsr init_editor
    lda #$00
    sta nametable
    rts 


; main menu code for A
a_input_main_menu:
    ldx #$00
    stx $2001 ; disable rendering
    ; disable NMI until load is complete
    lda $2000
    and #%01111111
    ora nametable ; display the correct nametable to avoid flickering
    sta $2000

    lda menu_select
    cmp #MAIN_MENU_EDITOR
    bne @done 
    ; init editor
    lda #GAME_MODE_EDITOR_MENU
    sta game_mode
    tax 
    jsr load_menu

    lda #$00
    sta menu_select
    sta sprite_data+1

    jsr init_editor_menu
@done:
    rts 

; b button input 
; b loads a map in editor menu
b_input:
    lda game_mode
    cmp #GAME_MODE_EDITOR_MENU
    beq @editor_menu
    jmp @not_editor_menu ; branch was out of range qq
@editor_menu:

    jsr b_input_editor_menu
    rts 
@not_editor_menu:
    cmp #GAME_MODE_EDITOR   
    bne @done

    ; editor mode
    jsr update_attr
@done:
    rts 

; b input for editor menu
b_input_editor_menu:
    lda #MOVE_DELAY_FRAMES*2
    sta select_delay

    lda menu_select
    cmp #EDITOR_MENU_NEW
    bne @not_new_map


    lda #<empty_map
    sta level_data_ptr
    lda #>empty_map
    sta level_data_ptr+1

    lda #<test_attr
    sta attr_ptr
    lda #>test_attr
    sta attr_ptr+1

    lda #<palette_data 
    sta src_ptr
    lda #>palette_data 
    sta src_ptr+1

    jmp @slot_selected
@not_new_map:    

    cmp #EDITOR_MENU_SAVE2
    bne @not_slot2

    lda #<save_2
    sta level_data_ptr
    lda #>save_2
    sta level_data_ptr+1

    lda #<attr_2
    sta attr_ptr
    lda #>attr_2 
    sta attr_ptr+1

    lda #<palette_2 
    sta src_ptr
    lda #>palette_2
    sta src_ptr+1

    jmp @slot_selected
@not_slot2:

    cmp #EDITOR_MENU_SAVE3
    bne @not_slot3

    lda #<save_3
    sta level_data_ptr
    lda #>save_3
    sta level_data_ptr+1

    lda #<attr_3
    sta attr_ptr
    lda #>attr_3 
    sta attr_ptr+1

    lda #<palette_3 
    sta src_ptr
    lda #>palette_3
    sta src_ptr+1

    jmp @slot_selected
    ; set up for load
@not_slot3:
    ; otherwise it is slot 1
    cmp #EDITOR_MENU_SAVE1
    beq @slot_1
    rts 
@slot_1:    
    lda #<save_1
    sta level_data_ptr
    lda #>save_1
    sta level_data_ptr+1

    lda #<attr_1
    sta attr_ptr
    lda #>attr_1 
    sta attr_ptr+1

    lda #<palette_1 
    sta src_ptr
    lda #>palette_1 
    sta src_ptr+1
@slot_selected:
    ldx #$00
    stx $2001 ; disable rendering

    lda #<level_data 
    sta level_ptr 
    lda #>level_data 
    sta level_ptr+1

    ; disable NMI until load is complete
    lda $2000
    and #%01111111
    ora nametable ; display the correct nametable to avoid flickering
    sta $2000

    jsr decompress_level


    ldx $00 ; nametable 0
    jsr load_level
    jsr load_attr

    ; copy palette
    lda #<level_palette
    sta dest_ptr 
    lda #>level_palette 
    sta dest_ptr+1
    ldy #PALETTE_SIZE
    jsr memcpy

    lda #GAME_MODE_EDITOR
    sta game_mode
    jsr init_editor
    lda #$00
    sta nametable
    rts     

; select button input
; select changes the players sprite index 
; this is only temporary
select_input:
    jsr can_select
    bne @done

    lda #MOVE_DELAY_FRAMES
    sta select_delay

    lda game_mode
    cmp #GAME_MODE_EDITOR 
    bne @not_editor

    ; change sprite 0s sprite index
    inc sprite_data+1
@not_editor:
    cmp #GAME_MODE_EDITOR_MENU
    bne @done
    jsr select_input_editor_menu
@done: 
    rts 

; select input editor menu
select_input_editor_menu:
    ldx #$00
    stx $2001 ; disable rendering

    ; disable NMI until load is complete
    lda $2000
    and #%01111111
    ora nametable ; display the correct nametable to avoid flickering
    sta $2000

    ldx palette
    inx 
    txa 
    and #PALETTES
    sta palette
    tax 

    lda palette_table_lo, x 
    sta palette_ptr
    lda palette_table_hi, x
    sta palette_ptr+1

    jsr load_palette
    rts 

; start button input
; start button saves the 
; current level to save_1 for now
; this is only temporary
start_input:
    jsr can_select
    bne @done

    lda #MOVE_DELAY_FRAMES
    sta select_delay

    ; decide what action to take
    lda game_mode
    cmp #GAME_MODE_MENU
    bne @not_menu
    ; TODO start puzzle
    rts 
@not_menu:
    cmp #GAME_MODE_EDITOR
    bne @not_editor
    jsr start_input_editor

    rts 
@not_editor:
    cmp #GAME_MODE_EDITOR_MENU
    bne @not_editor_menu
    jsr start_input_editor_menu

    rts 
@not_editor_menu:
    cmp GAME_MODE_PUZZLE
    bne @not_puzzle
@not_puzzle:
@done:
    rts 

; editor menu start input
start_input_editor_menu:
    ; sawp to editor mode and nt 0
    lda #GAME_MODE_EDITOR
    sta game_mode
    lda #$00 
    sta nametable

    jsr init_editor
    rts 

; start input editor
start_input_editor:
    ; swap to menu and nametable 1
    lda #GAME_MODE_EDITOR_MENU
    sta game_mode
    lda #$01
    sta nametable

    jsr init_editor_menu
    rts 

; left input
go_left:
    jsr can_move
    bne @done

    lda #MOVE_DELAY_FRAMES
    sta move_delay

    ; check gamemode
    lda game_mode
    cmp #GAME_MODE_EDITOR
    bne @not_editor

    jsr go_left_editor

    rts 
@not_editor:
    cmp #GAME_MODE_EDITOR_MENU
    bne @not_editor_menu

    jsr go_left_editor_menu
@not_editor_menu
@done:
    rts 

; editor code
go_left_editor:
    lda #$00
    cmp player_x ; dont allow underflow 
    beq @no_dec

    dec player_x
@no_dec:
    rts 

; ediotr menu code
go_left_editor_menu:
    ; if in editor menu we decrement tile id
    lda menu_select
    cmp #EDITOR_MENU_TILE
    bne @not_tile_select

    ldx sprite_data_1+1
    dex 
    ;check for invalid values
    cpx #$FF 
    bne @not_invalid
    ldx #$FE 
@not_invalid:
    stx sprite_data_1+1
    rts 
    
@not_tile_select:
    cmp #EDITOR_MENU_ATTR_1
    bcc @not_attr
    cmp #EDITOR_MENU_ATTR_1+4
    bcs @not_attr

    sec 
    sbc #EDITOR_MENU_ATTR_1
    tay 
    ldx #$00 ; dec
    jsr inc_dec_attr
    ; dec attr_value
    rts 
@not_attr
    cmp #EDITOR_MENU_COLOR
    bne @not_color
    dec color_select
    jsr init_color_display
    jsr init_value_display
    rts 
@not_color
    cmp #EDITOR_MENU_VALUE 
    bne @done
    ldy color_select 
    lda level_palette, y
    tax 
    dex
    txa  
    sta level_palette, y
    jsr init_value_display
@done:
    rts 

; right input
go_right:
    jsr can_move
    bne @done

    lda #MOVE_DELAY_FRAMES
    sta move_delay

    ; check gamemode
    lda game_mode
    cmp #GAME_MODE_EDITOR
    bne @not_editor

    jsr go_right_editor

    rts 
@not_editor:
    cmp #GAME_MODE_EDITOR_MENU
    bne @not_editor_menu
    jsr go_right_editor_menu
@not_editor_menu:
@done:
    rts 

; editor code
go_right_editor:
    lda #$1F
    cmp player_x ; dont allow overflow 
    beq @no_inc

    inc player_x
@no_inc:
    rts 

; editor menu code
go_right_editor_menu:
    ; if in editor menu we increment tile id
    ; check cursor positon
    lda menu_select
    cmp #EDITOR_MENU_TILE
    bne @not_tile_select
    ; increment sprite location
    ldx sprite_data_1+1
    inx 
    ; check for invalid value
    cpx #$FF 
    bne @not_invalid
    ldx #$00
@not_invalid:
    stx sprite_data_1+1
    rts 
@not_tile_select:
    cmp #EDITOR_MENU_ATTR_1
    bcc @not_attr
    cmp #EDITOR_MENU_ATTR_1+4
    bcs @not_attr
    ; increment attr value
    ; inc attr_value
    sec 
    sbc #EDITOR_MENU_ATTR_1
    tay 
    ldx #$01 ; inc
    jsr inc_dec_attr
    rts 
@not_attr
    cmp #EDITOR_MENU_COLOR
    bne @not_color
    inc color_select
    jsr init_color_display
    jsr init_value_display
    rts 
@not_color
    cmp #EDITOR_MENU_VALUE 
    bne @done
    ldy color_select 
    lda level_palette, y 
    tax 
    inx 
    txa
    sta level_palette, y
    jsr init_value_display
@done:
    rts 

; up input
go_up:
    jsr can_move
    bne @done 

    lda #MOVE_DELAY_FRAMES
    sta move_delay

    ; check gamemode
    lda game_mode
    cmp #GAME_MODE_EDITOR
    bne @not_editor

    jsr go_up_editor

    rts 

@not_editor:
    cmp #GAME_MODE_EDITOR_MENU
    bne @not_editor_menu

    dec menu_select
@not_editor_menu:
    cmp #GAME_MODE_MENU
    bne @not_main_menu
    dec menu_select
@not_main_menu:
@done:
    rts 

; editor code
go_up_editor:
    lda #$00
    cmp player_y ; dont allow underflow 
    beq @no_dec

    dec player_y
@no_dec:
    rts 

; down input
go_down:
    jsr can_move
    bne @done

    lda #MOVE_DELAY_FRAMES
    sta move_delay

    ; check gamemode
    lda game_mode
    cmp #GAME_MODE_EDITOR
    bne @not_editor
    jsr go_down_editor
    rts 
@not_editor:
    cmp #GAME_MODE_EDITOR_MENU
    bne @not_editor_menu

    inc menu_select
@not_editor_menu:
    cmp #GAME_MODE_MENU
    bne @not_main_menu
    inc menu_select
@not_main_menu
@done: 
    rts 

; editor code
go_down_editor:
    lda #$1D
    cmp player_y ; dont allow overflow 
    beq @no_inc 

    inc player_y
@no_inc:
    rts 