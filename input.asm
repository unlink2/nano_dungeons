; handles all inputs
input_handler:
    ; reset latch
    lda #$01
    sta $4016
    lda #$00
    sta $4016 ; both controllers are latching now

    lda nmi_flags
    and #%00100000 ; check disable input flag
    beq @not_disabled

    ; latch buttons anyway
    lda $4016
    rts
@not_disabled:
    lda last_inputs
    sta prev_inputs

    lda #$00
    sta last_inputs

    ; latch all inputs and place them in last input register
    ldx #$08
@read_loop:
    asl
    sta last_inputs
    lda $4016 ; read each input in order A, B, select, start, u, d, l, r
    and #$01
    ora last_inputs
    dex
    bne @read_loop
    sta last_inputs
    ; all inputs are now read

    lda last_inputs ; p1 - A
    and #%10000000
    beq @no_a
    lda prev_inputs
    and #%10000000
    bne @skip_a ; don't allow held inputs

    jsr a_input

@skip_a:

@no_a:

    lda last_inputs ; p1 - B
    and #%01000000
    beq @no_b
    lda prev_inputs
    and #%01000000
    bne @skip_b ; don't allow held input

    jsr b_input
@skip_b:
@no_b:

    lda last_inputs ; p1 - select
    and #%00100000
    beq @no_select
    jsr select_input
@no_select:

    lda last_inputs ; p1 - start
    and #%00010000
    beq @no_start
    jsr start_input
@no_start:

    lda last_inputs ; p1 - up
    and #%00001000
    beq @no_up
    jsr go_up
@no_up:

    lda last_inputs ; p1 - down
    and #%00000100
    beq @no_down
    jsr go_down
@no_down:

    lda last_inputs ; p1 - left
    and #%00000010
    beq @no_left
    jsr go_left
@no_left:

    lda last_inputs ; p1 - right
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
    bne @not_main_menu
    jsr a_input_main_menu
    rts
@not_main_menu:
    cmp #GAME_MODE_GAME
    bne @not_game
    jsr a_input_game
    rts
@not_game:
    cmp #GAME_MODE_PAUSE
    bne @done
    jsr a_input_pause
@done:
    rts

; in-game a input
a_input_game:
    ldy weapon_type
    ; no weapon if 0
    bne @init
    rts
@init:

    ; disable blinking animation
    lda sprite_data+1
    and #%01111111
    sta sprite_data+1

    jsr init_sword_noise

    lda weapon_update_lo, y
    sta delay_update
    lda weapon_update_hi, y
    sta delay_update+1

    lda weapon_done_lo, y
    sta delay_done
    lda weapon_done_hi, y
    sta delay_done+1

    lda weapon_timer_16, y
    sta delay_timer+1
    lda weapon_timer, y
    sta delay_timer

    ; disable inputs
    lda nmi_flags
    ora #%00100000
    sta nmi_flags

    ; move weapon x and y based on last inputs
    lda player_x
    sta weapon_x
    lda player_y
    sta weapon_y

    lda weapon_sprite, y ; tile
    sta sprite_data_1+1

    lda last_move
    cmp #UP
    bne @no_up
    dec weapon_y
    lda #%10000000 ; flip
    sta sprite_data_1+2
    rts
@no_up:
    cmp #DOWN
    bne @no_down
    inc weapon_y
    lda #%00000000 ; no flip
    sta sprite_data_1+2
    rts
@no_down:

    lda weapon_sprite, y ; tile
    ora #%10000000 ; get horizontal version
    sta sprite_data_1+1

    lda last_move
    cmp #LEFT
    bne @no_left
    dec weapon_x
    lda #%01000000 ; flip
    sta sprite_data_1+2
    rts
@no_left:
    cmp #RIGHT
    bne @no_right
    inc weapon_x
    lda #%00000000 ; flip
    sta sprite_data_1+2
    rts
@no_right:

    rts

; editor menu code for a input
a_input_editor_menu:
    lda editor_flags
    and #%10000000
    beq @not_tile_select_mode
    ldx #$01 ; get current tile from nt 1

    lda player_x
    sta get_tile_x
    lda player_y
    sta get_tile_y
    jsr get_tile_nametable
    sta sprite_data_1+1
    rts
@not_tile_select_mode:

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
    bne @dont_load_debug_map
    jmp @load_debug_map
@dont_load_debug_map:

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
    set_nmi_flag

    jsr compress_level

    vblank_wait
    ldx #$00
    ; stx $2005
    ; stx $2005 ; no scrolling
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

    vblank_wait

    rts
@no_slot:
    cmp #EDITOR_MENU_BACK
    bne @not_back
    ; load nametable
    lda #$00
    sta $2001 ; no rendering

    set_nmi_flag

    ldx #$00
    stx menu_select
    jsr load_menu

    vblank_wait
    ; lda #$00
    ; sta $2005
    ; sta $2005 ; no scrolling
    jsr init_main_menu
    vblank_wait
    rts
@not_back:
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
    set_nmi_flag

    jsr decompress_level

    ; copy palette we set up earlier
    ldy #PALETTE_SIZE ; size to copy
    jsr memcpy

    ldx #$00 ; nametable 0
    jsr load_level
    jsr load_attr
    vblank_wait
    ; lda #$00
    ; sta $2005
    ; sta $2005 ; no scrolling
    jsr load_palette

    lda #GAME_MODE_EDITOR
    sta game_mode

    vblank_wait
    ; lda #$00
    ; sta $2005
    ; sta $2005 ; no scrolling again
    jsr init_editor
    lda #$00
    sta nametable

    jsr init_ai_tiles
    jsr find_start

    vblank_wait

    rts


; main menu code for A
a_input_main_menu:
    ldx #$00
    stx $2001 ; disable rendering
    ; disable NMI until load is complete
    set_nmi_flag

    lda menu_select
    cmp #MAIN_MENU_EDITOR
    bne @not_editor
    ; init editor
    lda #GAME_MODE_EDITOR_MENU
    sta game_mode
    tax
    jsr load_menu

    lda #$00
    sta menu_select
    sta sprite_data+1

    vblank_wait
    ; lda #$00
    ; sta $2005
    ; sta $2005 ; no scrolling
    jsr init_editor_menu
    rts

@not_editor:
    ; at this point all choices will load a map
    ; load pause menu into nt1
    ldx #GAME_MODE_PAUSE
    jsr load_menu

    lda menu_select ; need to restore menu_select in A after load
    cmp #MAIN_MENU_LEVEL
    bne @not_level_select

@level_select:
    ; select the map to load
    ldx level_select ; based on tile
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

    ; load sub routine
    lda map_sub_lo, x
    sta map_sub_ptr
    lda map_sub_hi, x
    sta map_sub_ptr+1

    jmp @slot_selected
@not_level_select:

    cmp #MAIN_MENU_RANDOM
    bne @not_random
    lda #%10000000
    sta load_flags
    jmp @level_select
@not_random:

    cmp #MAIN_MENU_RESUME
    bne @no_resume

    lda #%10100000
    sta load_flags
    jmp @level_select

@no_resume:
    cmp #MAIN_MENU_SET_SEED
    bne @not_set_seed
    lda seed_input
    sta seed
    lda seed_input+1
    sta seed+1
    lda #%10000000
    sta load_flags
    jmp @level_select
@not_set_seed:

    ; check which slot is selected
    cmp #MAIN_MENU_SLOT_1
    bne @not_slot_1
    ; slot 1 selected, set up pointers
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

    ; load no update routine for custom levels
    lda #<save_sub_1
    sta map_sub_ptr
    lda #>save_sub_1
    sta map_sub_ptr+1

    jmp @slot_selected
@not_slot_1:

    cmp #MAIN_MENU_SLOT_2
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

    ; load no update routine for custom levels
    lda #<save_sub_2
    sta map_sub_ptr
    lda #>save_sub_2
    sta map_sub_ptr+1

    jmp @slot_selected
@not_slot2:

    cmp #MAIN_MENU_SLOT_3
    beq @slot3
    jmp @no_slot
@slot3:

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

    ; load no update routine for custom levels
    lda #<save_sub_3
    sta map_sub_ptr
    lda #>save_sub_3
    sta map_sub_ptr+1

@slot_selected:
    ; store pointers in backup
    lda level_data_ptr
    sta level_data_ptr_bac
    lda level_data_ptr+1
    sta level_data_ptr_bac+1

    lda attr_ptr
    sta attr_ptr_bac
    lda attr_ptr+1
    sta attr_ptr_bac+1

    lda src_ptr
    sta palette_ptr_bac
    lda src_ptr+1
    sta palette_ptr_bac+1

    lda seed
    sta seed_bac
    lda seed+1
    sta seed_bac+1

    ; now all pointers are backed up

    ; load level $00 because init_game increments it
    lda #$00
    sta level

    ; enable low visiblity mode
    lda load_flags
    ora #%01000000
    sta load_flags

    jsr reload_room

    ;ldx #$00
    ;stx $2001 ; disable rendering


    ; load an empty map first
    ;lda #<empty_map
    ;sta level_data_ptr
    ;lda #>empty_map
    ;sta level_data_ptr+1

    ;lda #<level_data
    ;sta level_ptr
    ;lda #>level_data
    ;sta level_ptr+1

    ; disable NMI until load is complete
    ;set_nmi_flag

    ;jsr decompress_level
    ;ldx #$00 ; nt 0
    ;jsr load_level

    ; load actual map
    ;lda level_data_ptr_bac
    ;sta level_data_ptr
    ;lda level_data_ptr_bac+1
    ;sta level_data_ptr+1

    ;lda #<level_data
    ;sta level_ptr
    ;lda #>level_data
    ;sta level_ptr+1

    ;jsr decompress_level
    ;ldx #$00 ; nametable 0

    ; test which load needs to be done
    ;lda load_flags
    ;and #%01000000 ; flag for partial load
    ;bne @load_part
    ;jsr load_level
    ; partial load depends on start tile
    ; therefore it will happen after init_game is called
;@load_part:
    ;jsr load_attr


    ; copy palette
    ;lda #<level_palette
    ;sta dest_ptr
    ;lda #>level_palette
    ;sta dest_ptr+1
    ;ldy #PALETTE_SIZE
    ;jsr memcpy

    ;lda #$00
    ;sta nametable

    ;vblank_wait
    ; lda #$00
    ; sta $2005
    ; sta $2005 ; no scrolling
    ;jsr init_game

    ; test if partial load is needed now
    ; if so we have start location and can go ahead
    ;lda load_flags
    ;and #%01000000 ; flag for partial load
    ;beq @no_part_load
    ;lda player_x
    ;sta get_tile_x
    ;lda player_y
    ;sta get_tile_y
    ;ldx #$00 ; nametable 0
    ;jsr load_level_part
;@no_part_load:

    ;vblank_wait
@no_slot:
@done:
    rts

; a input pause menu
a_input_pause:
    lda menu_select
    cmp #PAUSE_MENU_RESUME
    bne @not_resume:
    jsr resume_game
    rts
@not_resume:
    cmp #PAUSE_MENU_QUIT
    bne @not_quit
    jsr resume_game
    jsr start_input_message ; back to main menu
    rts
@not_quit:
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
    bne @not_editor

    ; editor mode
    jsr update_attr
    rts
@not_editor:
    cmp #GAME_MODE_GAME
    bne @done

    ; debug decrease magic
    jsr b_input_game

    ; debug projectile spawn
    ; TODO remove
    ; lda player_x
    ; sta get_tile_x
    ; lda player_y
    ; sta get_tile_y
    ; lda last_move
    ; jsr spawn_projectile
@done:
    rts


; in-game a input
b_input_game:
    ldy spell_type
    ; no weapon if 0
    bne @init
    rts
@init:
    lda pmagic
    bne @magic
    rts ; if not enough magic
@magic:
    dec pmagic ; -1

    ; disable blinking animation
    lda sprite_data+1
    and #%01111111
    sta sprite_data+1

    jsr init_sword_noise

    lda weapon_update_lo, y
    sta delay_update
    lda weapon_update_hi, y
    sta delay_update+1

    lda weapon_done_lo, y
    sta delay_done
    lda weapon_done_hi, y
    sta delay_done+1

    lda weapon_timer_16, y
    sta delay_timer+1
    lda weapon_timer, y
    sta delay_timer

    ; store player damage and load
    ; spell damage
    lda player_damage
    sta seed_input ; unused area in ram, use it as temp storage
    lda spell_damage, y ; damage
    sta player_damage

    ; disable inputs
    lda nmi_flags
    ora #%00100000
    sta nmi_flags

    ; move weapon x and y based on last inputs
    lda player_x
    sta weapon_x
    lda player_y
    sta weapon_y

    lda weapon_sprite, y ; tile
    sta sprite_data_1+1

    rts

; b input for editor menu
b_input_editor_menu:
    lda editor_flags
    and #%10000000
    beq @not_tile_select_mode
    rts
@not_tile_select_mode:

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


    ; disable NMI until load is complete
    set_nmi_flag

    lda #<level_data
    sta level_ptr
    lda #>level_data
    sta level_ptr+1

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

    vblank_wait
    ; lda #$00
    ; sta $2005
    ; sta $2005 ; no scrolling
    jsr init_editor
    lda #$00
    sta nametable

    jsr init_ai_tiles
    jsr find_start

    vblank_wait

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
    ; inc sprite_data+1

    lda player_x
    sta get_tile_x
    lda player_y
    sta get_tile_y
    jsr get_tile
    sta sprite_data+1
    rts
@not_editor:
    cmp #GAME_MODE_EDITOR_MENU
    bne @not_editor_menu
    jsr select_input_editor_menu
    rts
@not_editor_menu:
    cmp #GAME_MODE_GAME
    bne @not_game
    dec level ; level -1 to not inc level during reload
    jsr reload_room
    rts
@not_game:
    cmp #GAME_MODE_PAUSE
    bne @done
    jsr resume_game
    jsr start_input_message ; back to main menu
@done:
    rts

; select input editor menu
select_input_editor_menu:
    ; cmp #EDITOR_MENU_TILE
    ; bne @done

    ; enable/disable tile select mode
    lda editor_flags
    eor #%10000000
    sta editor_flags
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
    cmp #GAME_MODE_GAME
    bne @not_puzzle

    ; jsr start_input_message
    jsr init_pause_menu

    rts
@not_puzzle:
    cmp #GAME_MODE_MESSAGE
    bne @not_win
    jsr start_input_message
    rts
@not_win:
    cmp #GAME_MODE_TITLE
    bne @not_title
    jsr start_input_message
@not_title:
    cmp #GAME_MODE_PAUSE
    bne @done
    jsr resume_game
@done:
    rts

; start input for win
start_input_message:
    ; load nametable
    lda #$00
    sta $2001 ; no rendering

    set_nmi_flag

    lda #$01
    sta nametable

    ldx #$00
    stx menu_select
    jsr load_menu

    vblank_wait
    ; lda #$00
    ; sta $2005
    ; sta $2005 ; no scrolling
    jsr init_main_menu

    vblank_wait
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
    lda #$08
    sta smooth_left

    rts
@not_editor:
    cmp #GAME_MODE_EDITOR_MENU
    bne @not_editor_menu

    jsr go_left_editor_menu
    rts
@not_editor_menu:
    cmp #GAME_MODE_MENU
    bne @not_main_menu
    jsr go_left_main_menu
    rts
@not_main_menu:
    cmp #GAME_MODE_GAME
    bne @done

    lda #LEFT
    jsr check_move_delay
    beq @done

    jsr go_left_editor
    lda #$08
    sta smooth_left
@done:
    rts

; editor code
go_left_editor:
    lda #$00
    cmp player_x ; dont allow underflow
    beq @no_dec

    lda #LEFT
    sta last_move

    dec player_x
@no_dec:
    rts

; ediotr menu code
go_left_editor_menu:
    ; check for bit 1 of flags
    lda editor_flags
    and #%10000000
    beq @not_tile_select_mode
    dec player_x
    rts
@not_tile_select_mode:

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
@not_attr:
    cmp #EDITOR_MENU_COLOR
    bne @not_color
    dec color_select
    jsr init_color_display
    jsr init_value_display
    rts
@not_color:
    cmp #EDITOR_MENU_VALUE
    bne @not_value
    ldy color_select
    lda level_palette, y
    tax
    dex
    txa
    sta level_palette, y
    jsr init_value_display
@not_value:
    cmp #EDITOR_MENU_BANK
    bne @not_bank
    ldy level_data_ptr_bac
    dey
    cpy #$3F
    bne @not_outside_ram
    ldy #$07
@not_outside_ram:
    sty level_data_ptr_bac
@not_bank:
    cmp #EDITOR_MENU_ADDR
    bne @not_addr
    dec level_data_ptr_bac+1
@not_addr:
    cmp #EDITOR_MENU_MEMVALUE
    bne @done
    lda level_data_ptr_bac
    sta src_ptr+1
    lda level_data_ptr_bac+1
    sta src_ptr
    ldy #$00
    lda (src_ptr), y
    sec
    sbc #$01
    sta (src_ptr), y
@done:
    rts

; main menu left input
go_left_main_menu:
    lda menu_select
    cmp #MAIN_MENU_LEVEL
    bne @not_level
    dec level_select
    rts
@not_level:
    cmp #MAIN_MENU_SET_SEED
    bne @not_seed
    lda seed_input+1
    sec
    sbc #$01
    sta seed_input+1
    bcs @no_underflow
    dec seed_input
@no_underflow:
@not_seed:
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
    lda #$08
    sta smooth_right

    rts
@not_editor:
    cmp #GAME_MODE_EDITOR_MENU
    bne @not_editor_menu
    jsr go_right_editor_menu
    rts
@not_editor_menu:
    cmp #GAME_MODE_MENU
    bne @not_main_menu
    jsr go_right_main_menu
    rts
@not_main_menu:
    cmp #GAME_MODE_GAME
    bne @done

    lda #RIGHT
    jsr check_move_delay
    beq @done

    jsr go_right_editor
    lda #$08
    sta smooth_right
@done:
    rts

; editor code
go_right_editor:
    lda #$1F
    cmp player_x ; dont allow overflow
    beq @no_inc

    lda #RIGHT
    sta last_move

    inc player_x
@no_inc:
    rts

; editor menu code
go_right_editor_menu:
    ; check for bit 1 of flags
    lda editor_flags
    and #%10000000
    beq @not_tile_select_mode
    inc player_x
    rts
@not_tile_select_mode:

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
    txa
    ; and #$7F ; only first 128 tiles are valid
    sta sprite_data_1+1
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
@not_attr:
    cmp #EDITOR_MENU_COLOR
    bne @not_color
    inc color_select
    jsr init_color_display
    jsr init_value_display
    rts
@not_color:
    cmp #EDITOR_MENU_VALUE
    bne @not_value
    ldy color_select
    lda level_palette, y
    tax
    inx
    txa
    sta level_palette, y
    jsr init_value_display
@not_value:
    cmp #EDITOR_MENU_BANK
    bne @not_bank
    ldy level_data_ptr_bac
    iny
    cpy #$08
    bne @not_outside_ram
    ldy #$40
@not_outside_ram:
    sty level_data_ptr_bac
@not_bank:
    cmp #EDITOR_MENU_ADDR
    bne @not_addr
    inc level_data_ptr_bac+1
@not_addr:
    cmp #EDITOR_MENU_MEMVALUE
    bne @done
    lda level_data_ptr_bac
    sta src_ptr+1
    lda level_data_ptr_bac+1
    sta src_ptr
    ldy #$00
    lda (src_ptr), y
    clc
    adc #$01
    sta (src_ptr), y
@done:
    rts

; main menu right input
go_right_main_menu:
    lda menu_select
    cmp #MAIN_MENU_LEVEL
    bne @not_level
    inc level_select
    rts
@not_level:
    cmp #MAIN_MENU_SET_SEED
    bne @not_seed
    lda seed_input+1
    clc
    adc #$01
    sta seed_input+1
    bcc @no_overflow
    inc seed_input
@no_overflow:
@not_seed:
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
    lda #$08
    sta smooth_up

    rts

@not_editor:
    cmp #GAME_MODE_EDITOR_MENU
    bne @not_editor_menu

    ; check for bit 1 of flags
    lda editor_flags
    and #%10000000
    beq @not_tile_select_mode
    dec player_y
    rts
@not_tile_select_mode:

    dec menu_select
    rts
@not_editor_menu:
    cmp #GAME_MODE_MENU
    bne @not_main_menu
    dec menu_select
    rts
@not_main_menu:
    cmp #GAME_MODE_GAME
    bne @not_game

    lda #UP
    jsr check_move_delay
    beq @done

    jsr go_up_editor
    lda #$08
    sta smooth_up
    rts
@not_game:
    cmp #GAME_MODE_PAUSE
    bne @done
    dec menu_select
@done:
    rts

; editor code
go_up_editor:
    lda #$00
    cmp player_y ; dont allow underflow
    beq @no_dec

    lda #UP
    sta last_move

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
    lda #$08
    sta smooth_down

    rts
@not_editor:
    cmp #GAME_MODE_EDITOR_MENU
    bne @not_editor_menu

    ; check for bit 1 of flags
    lda editor_flags
    and #%10000000
    beq @not_tile_select_mode
    inc player_y
    rts
@not_tile_select_mode:

    inc menu_select
    rts
@not_editor_menu:
    cmp #GAME_MODE_MENU
    bne @not_main_menu
    inc menu_select
    rts
@not_main_menu:
    cmp #GAME_MODE_GAME
    bne @not_game

    lda #DOWN
    jsr check_move_delay
    beq @done

    jsr go_down_editor
    lda #$08
    sta smooth_down
    rts
@not_game:
    cmp #GAME_MODE_PAUSE
    bne @done
    inc menu_select
@done:
    rts

; editor code
go_down_editor:
    lda #$1D
    cmp player_y ; dont allow overflow
    beq @no_inc

    lda #DOWN
    sta last_move

    inc player_y
@no_inc:
    rts
