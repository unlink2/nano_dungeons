; game related code

; inits game mode
; inputs:
;   level_data_ptr -> pointing to compressed level
;   attr_ptr -> pointing to attributes
;   palette_ptr -> pointing to palette
;   enables sprite updating
init_game:
    lda #$00
    sta gfx_flags

    lda #$FF
    sta last_player_damage
    sta last_player_armor
    sta last_keys
    sta last_coins

    ; tile update mode
    lda #%01000000
    sta editor_flags

    inc level

    ; re-enable input just in case player died
    ; during sword animation
    lda nmi_flags
    and #%11011111 ; enables input
    sta nmi_flags

    lda #GAME_MODE_GAME
    sta game_mode

    lda #MAX_HP ; hp
    sta player_hp

    lda #START_DAMAGE
    sta player_damage

    lda #START_WEAPON
    sta weapon_type

    lda #START_ARMOR ; base armor
    sta player_armor_base
    sta player_armor

    lda #$00
    sta map_flags ; reset all map flags
    sta key_count ; no keys when map begins
    sta player_timer ; no timer for player
    sta iframes ; no iframes
    sta move_timer ; reset move timer
    sta coins

    lda #<update_game
    sta update_sub
    lda #>update_game
    sta update_sub+1

    lda #<update_game_crit
    sta update_sub_crit
    lda #>update_game_crit
    sta update_sub_crit+1

    ; copy palette
    lda #<level_palette
    sta palette_ptr
    lda #>level_palette
    sta palette_ptr+1
    jsr load_palette

    jsr hide_objs
    jsr init_projectile_slots ; clear projectiles

    lda game_flags
    ora #%01000000
    sta game_flags ; enable sprite updating, disable tile updating

    jsr init_ai_tiles
    jsr find_start
    ; check if start was found
    cmp #$01
    beq @no_error
    ; error state
    lda #ERROR_NO_START_TILE
    sta errno
@no_error:

    lda player_x
    sta player_x_bac
    lda player_y
    sta player_y_bac

    ; player sprite
    lda #$32
    sta sprite_data+1

    ; move other sprites offscreen
    lda #$00
    sta sprite_data_1
    sta sprite_data_1+3
    sta sprite_data_2
    sta sprite_data_2+3

    ; move hp sprites to correct
    ; location and init them
    lda #2 * 8 ; x positions
    sta sprite_data_8+3
    sta sprite_data_C+3 ; sword
    lda #3 * 8
    sta sprite_data_9+3
    lda #4 * 8
    sta sprite_data_A+3

    lda #25 * 8 ; y position
    sta sprite_data_8
    sta sprite_data_9
    sta sprite_data_A

    lda #$02 ; palette
    sta sprite_data_8+2
    sta sprite_data_9+2
    sta sprite_data_A+2

    lda #$5 * 8
    sta sprite_data_D+3 ; armor

    lda #$8 * 8
    sta sprite_data_B+3 ; key

    lda #$5 * 8
    sta sprite_data_E+3 ; coin
    lda #$3F
    sta sprite_data_E+1 ; coin sprite

    ; move other UI sprites onscreen
    lda #26 * 8 ; y position
    sta sprite_data_B ; key 
    sta sprite_data_C ; sword 
    sta sprite_data_D ; armor 
    lda #25 * 8
    sta sprite_data_E ; coin

    lda #$3C ; armor spirte
    sta sprite_data_D+1


    ; jsr init_test_song

    ; reload game state if flag is set
    lda load_flags
    and #%00100000
    beq @no_load
    jsr load_save
@no_load

    rts

; this routine is called every frame
; it updates the game state
; critical game update
update_game_crit:
    jsr render_tile_updates
    jsr update_ui

    ; test if actions are to become 0
    ; this flag may be used by some routines that
    ; update during non-critical code, but want to waste a turn
    ; like a trap
    lda map_flags
    and #%00010000
    beq @not_actions_zero
    lda map_flags
    and #%11101111 ; unset flag
    sta map_flags
    lda #$00
    sta actions
@not_actions_zero:

    jsr check_player_move
    cmp #$01
    bne @player_not_moved

    ; test collision
    ; jsr collision_check
    ; load collision result from previous frame
    lda game_flags
    and #%00000001
    ; if a = 1 collision occured
    cmp #$01
    beq @player_not_moved

    ; if player did move set remaining actions
    ; to 0. a move ends the turn
    lda #$00
    sta actions

    ; skip tile update if flag is not set
    lda game_flags
    and #%00000010
    beq @skip_tile_update

    ; test if the current tile
    ; is already marked if so, do not update the previous tile but rather unmark the current
    lda player_x
    sta get_tile_x
    lda player_y
    sta get_tile_y

    jsr get_tile
    and #%10000000
    beq @tile_update_not_marked
    jsr update_tile
    jmp @skip_tile_update
@tile_update_not_marked:
    ; update current tile if player did move
    ; game mode is puzzle
    ; therefore a tile update will update the tile to become
    ; a passed over tile by setting bit 7 to 1
    ; for that however we use the previous location rather than the current one
    ; to update the tile behind the player
    lda player_x
    pha
    lda player_y
    pha

    lda player_x_bac
    sta player_x
    lda player_y_bac
    sta player_y

    jsr update_tile

    ; restore position
    pla
    sta player_y
    pla
    sta player_x
@skip_tile_update:
@player_not_moved:
    jsr update_player_animation

    ; store previous position
    lda player_x
    sta player_x_bac
    lda player_y
    sta player_y_bac
    jmp update_crit_done

; updates UI for key, armor and damage count
; performs nametable update required to display numbers
update_ui:
    lda last_player_damage
    cmp player_damage
    beq @no_update_damage

    ; UI is always at same location so it is easy to update
    lda player_damage
    sta last_player_damage ; update completed store for next frame
    jsr convert_hex

    ; update nametable
    lda #03
    sta get_tile_x
    lda #26
    sta get_tile_y
    jsr draw_hex_buffer

@no_update_damage:

    lda last_player_armor
    cmp player_armor
    beq @no_update_armor

    ; UI is always at same location so it is easy to update
    lda player_armor
    sta last_player_armor ; update completed store for next frame
    jsr convert_hex

    ; update nametable
    lda #06
    sta get_tile_x
    lda #26
    sta get_tile_y
    jsr draw_hex_buffer

@no_update_armor:

    lda last_coins
    cmp coins
    beq @no_update_coins

    ; UI is always at same location so it is easy to update
    lda coins
    sta last_coins ; update completed store for next frame
    jsr convert_hex

    ; update nametable
    lda #06
    sta get_tile_x
    lda #25
    sta get_tile_y
    jsr draw_hex_buffer

@no_update_coins:
    rts

; non-critical game updates
update_game:
    jsr check_player_move
    cmp #$01
    bne @player_not_moved

    ; test trap flag, if trapped rng roll to become free
    ; if bad roll skip move by failing collision check
    ; but consume action
    lda map_flags
    and #%00100000
    beq @not_trapped
    jsr random
    lda rand8
    cmp #$7F
    bcc @free ; free
    ; if not free skip move and consume action
    ; restore position and remove smooth movement
    lda #$00
    sta smooth_down
    sta smooth_up
    sta smooth_right
    sta smooth_left
    lda player_x_bac
    sta player_x
    lda player_y_bac
    sta player_y
    ; set flag to set actions to 0 on crit update
    lda map_flags
    ora #%00010000
    sta map_flags
    jmp @player_not_moved
@free:
    lda map_flags
    and #%11011111
    sta map_flags ; unset trap flag
@not_trapped:

    jsr collision_check
    sta temp
    lda game_flags
    and #%11111110
    ora temp
    sta game_flags ; store this frames collision result in game_flags

    jsr setup_tile_updates
@player_not_moved:

    ; run custom update routine unless ptr is FF FF
    lda map_sub_ptr
    and map_sub_ptr+1 ; FF and FF = FF
    cmp #$FF
    beq @no_sub

    lda map_sub_ptr
    sta src_ptr
    lda map_sub_ptr+1
    sta src_ptr+1
    jsr jsr_indirect
@no_sub:

    ; see if song finished by testing square wave 1
    ldy #$00
    lda (pulse_ptr_1), y
    cmp #$FF
    bne @no_audio_reset
    ; jsr init_test_song
@no_audio_reset:

    ; test for movement inputs, if non occured reset
    ; timer
    lda last_inputs
    and #%11110000
    bne @no_move_timer_reset
    sta move_timer
@no_move_timer_reset:

    ; update hp display
    lda #$3A ; heart sprite
    sta sprite_data_8+1
    sta sprite_data_9+1
    sta sprite_data_A+1

    ldx player_hp
    cpx #MAX_HP
    beq @no_damage
    ldy #$0A
@damage_display_loop:
    lda obj_index_to_addr, y
    sta sprite_ptr
    tya
    pha

    ldy #$01
    lda #$24 ; empty tile
    sta (sprite_ptr), y

    pla
    tay

    inx
    dey
    cpx #MAX_HP
    bne @damage_display_loop
@no_damage

    ; update other UI elements
    ldy #$24 ; empty sprite
    lda key_count
    beq @no_keys
    ldy #$59 ; key sprite
@no_keys:
    sty sprite_data_B+1

    ldy weapon_type
    lda weapon_sprite, y
    sta sprite_data_C+1

    ; ldy #$24 ; empty sprite
    ; lda player_armor_base
    ; beq @no_armor
    ; ldy #$3C
; @no_armor:
    ; sty sprite_data_D+1

    ; update damage animation
    jsr update_damage_animation

    jsr test_victory_condition
    bne @done

    ; if animation timer is already going do not porceed
    lda delay_timer
    ora delay_timer+1
    bne @done

    ; only finish if movment finished as well
    lda smooth_up
    ora smooth_down
    ora smooth_left
    ora smooth_right
    ; bne @done

    ; set up win condition pointers
    sta delay_timer
    lda #$00
    sta delay_timer+1 ; second byte, we only need first byte
    lda #<empty_sub
    sta delay_update
    lda #>empty_sub
    sta delay_update+1

    lda #<update_none
    sta update_sub
    lda #>update_none
    sta update_sub+1

    lda #<update_crit_none
    sta update_sub_crit
    lda #>update_crit_none
    sta update_sub_crit+1

    lda #<init_win_condition
    sta delay_done
    lda #>init_win_condition
    sta delay_done+1
@done:
    jmp update_done

; this sub rout01e is called when win condition
; animation finishes
init_win_condition:
    lda #$00
    sta $2001 ; no rendering

    ; advance seed
    lda seed
    jsr random_reg
    sta seed
    lda seed+1
    jsr random_reg
    sta seed+1

    inc level

    ; store gamestate
    jsr store_save

    ; if random flag is set load next map
    lda #%10000000
    and load_flags
    bne @next_map

    ; set flag to reload values from sram
    lda load_flags
    ora #%00100000
    sta load_flags

    lda #$01
    sta nametable

    set_nmi_flag

    ldx #GAME_MODE_MESSAGE
    stx game_mode
    jsr load_menu
    jsr init_message

    lda #$01 ; set flag to skip update

    vblank_wait

    rts
@next_map:
    ; lda #MAIN_MENU_RANDOM
    ; sta menu_select
    ; load next map
    ; make it load the next seed
    lda seed
    sta seed_bac
    lda seed+1
    sta seed_bac+1

    ; load from savegame
    lda load_flags
    ora #%00100000
    sta load_flags

    jsr reload_room
    ; jsr a_input_main_menu
    rts

; loads the game over message as a menu
init_game_over:
    lda #$00
    sta $2001 ; no rendering

    lda #$01
    sta nametable
    set_nmi_flag

    vblank_wait

    ldx #GAME_MODE_GAME_OVER
    lda #GAME_MODE_MESSAGE
    sta game_mode
    jsr load_menu
    jsr init_message

    ; write level to correct position
    lda level
    jsr convert_hex

    ; update nametable
    lda #16
    sta get_tile_x
    lda #10
    sta get_tile_y
    jsr draw_hex_buffer

    ; hide all sprites
    jsr hide_objs

    lda #$01 ; set flag to skip update

    vblank_wait

    rts

; this sub routine updates the player's animation based on
; the movement offset
; inputs:
;   smooth up, down, left, right
; side effects:
;   modifies registers, flags
;   modifies player sprite and attributes
update_player_animation:
    lda delay_timer ; do not update during delay timer
    bne @done

    lda iframes
    beq @no_iframes

    ; if iframes flash player
    lda sprite_data+1
    cmp #$24
    bne @swap_invisible

    lda #$32
    sta sprite_data+1
    rts
@swap_invisible:
    lda #$24
    sta sprite_data+1
    rts 

@no_iframes:
    ; see if player is invisible if so swap back to normal sprite
    lda sprite_data+1
    cmp #$24
    bne @not_invisible
    lda #$32
    sta sprite_data+1
@not_invisible:

    ; update player animation
    ; every 128 frames blink
    lda player_timer
    bne @done

    lda sprite_data+1
    eor #%10000000
    sta sprite_data+1
    and #%10000000
    bne @short_timer ; blink for 8 frames

    ; long timer wait 128 frames
    jsr random
    lda rand8
    ora #%10000000
    sta player_timer ; at least 128 frames, but maybe more
    rts
@short_timer:
    lda #08
    sta player_timer
    rts
@done:
    dec player_timer
    rts

; checks for player collision based on the currently occupied tile
; inputs:
;   player_x, y and respective _bac
; side effects:
;   if tile does collide, player position is restored
;   to values in _bac
;   overwrites src_ptr
; returns:
;   a = 0 -> if collision did not occur
;   a = 1 -> if collision occured
collision_check:
    lda map_flags
    and #%01000000 ; collision off flag
    beq @collision_enabled
    lda #$00
    rts
@collision_enabled

    lda player_x
    sta get_tile_x
    lda player_y
    sta get_tile_y
    jsr get_tile
    tax
    ; get routine for current tile
    lda tile_sub_lo, x
    sta src_ptr
    lda tile_sub_hi, x
    sta src_ptr+1

    jsr jsr_indirect
    cmp #$01
    bne @no_collision_tile
    beq @collision_tile
@no_collision_tile:

    ; after we have checked tile collision also verify sprite collision
    jsr sprite_collision
    cmp #$01
    bne @no_collision
@collision_tile:
    ; if collision, restore previous location
    ; and remove smooth movement
    ldx #$00
    stx smooth_left
    stx smooth_right
    stx smooth_up
    stx smooth_down

    ldx player_x_bac
    stx player_x
    ldx player_y_bac
    stx player_y

    jsr convert_tile_location
    rts
@no_collision:

    rts

; this sub routine updates the tiles to clear counter
; it does this based on the negative flag
; inputs:
;   N flag = 0 -> dec
;   N flag = 1 -> inc
; side effects:
;   tiles_to_clear is changed
;   flags may be changed
;   registers are preserved
update_tiles_to_clear:
    pha
    ; eor sets the negative flag when bit 7 is set
    ; since that is exactly the bit we set we can use it to
    ; decide wheter to inc or dec
    bmi @negative_flag
    lda tiles_to_clear
    clc
    adc #$01
    sta tiles_to_clear
    lda tiles_to_clear+1
    adc #$00
    sta tiles_to_clear+1
    jmp @done
@negative_flag:
    lda tiles_to_clear
    sec
    sbc #$01
    sta tiles_to_clear
    lda tiles_to_clear+1
    sbc #$00
    sta tiles_to_clear+1
@done:
    pla
    rts


; this sub rotuine checks win condition
; returns:
;   a == 0 if won
;   a == 1 if not won
test_victory_condition:
    ; test victory condition
    ; if only one tile is left to clear the player must be on it
    lda tiles_to_clear+1
    cmp #$00
    bne @done
    lda tiles_to_clear
    cmp #$01
    bne @done
    lda #$00
    rts
@done:
    lda #$01
    rts

; this sub routine loads the win screen
; inputs:
;   none
; side effects:
;   inits a new game mode
init_message:
    lda #$00 ; move player offscreen
    sta sprite_data
    sta sprite_data+3
    sta player_x
    sta player_y
    sta player_x_bac
    sta player_y_bac

    lda #<update_message
    sta update_sub
    lda #>update_message
    sta update_sub+1

    lda #<update_crit_none
    sta update_sub_crit
    lda #>update_crit_none
    sta update_sub_crit+1

    rts

; update routine for the win screen
update_message:
    jmp update_done

; this sub routine checks if player has moved
; compared to its previous position
; inputs:
;   player_x, y,
;   player_x_bac, y_bac
; returns:
;   a = 0 -> no move
;   a = 1 -> move
check_player_move:
    ; check if player moved
    lda #$00 ; move flag
    ldx player_x
    cpx player_x_bac
    beq @player_not_moved_x

    lda #$01 ; did move
@player_not_moved_x:
    ldx player_y
    cpx player_y_bac
    beq @player_not_moved_y
    lda #$01 ; did move
@player_not_moved_y:
    rts


; updates the sword sprite (sprite 1)
; based on the delay timer
sword_update:
    ; lda #$33 ; tile
    ; sta sprite_data_1+1

    ldy weapon_x
    lda tile_convert_table, y
    sta sprite_data_1+3

    ldy weapon_y
    lda tile_convert_table, y
    sta sprite_data_1

    rts

; moves sword to 0/0
; enables player inputs
sword_done:
    lda nmi_flags
    and #%11011111 ; enables input
    sta nmi_flags

    lda #$00
    sta weapon_x
    sta weapon_y

    sta actions

    sta sprite_data_1
    sta sprite_data_1+3
    sta sprite_data_1+2

    ; disable hit flag for all sprites
    ldx #SPRITE_TILES-1
@disable_loop:
    lda sprite_tile_flags, x
    and #%10111111
    sta sprite_tile_flags, x
    dex
    cpx #$FF
    bne @disable_loop

    jsr hide_damage_animation
    rts

; updates arrow moving it one tile until it
; collides with a wall
arrow_update:
    lda delay_timer
    and #$07
    bne @no_move

    lda last_move
    cmp #DOWN
    bne @not_down
    inc weapon_y
@not_down:
    cmp #UP
    bne @not_up
    dec weapon_y
@not_up:
    cmp #RIGHT
    bne @not_right
    inc weapon_x
@not_right:
    cmp #LEFT
    bne @not_left
    dec weapon_x
@not_left:
@no_move:
    jsr sword_update
    rts

; decs weapon damage unless it is 1
; then calls sword_done
arrow_done:
    lda player_damage
    cmp #$01
    beq @no_dec
    dec player_damage
@no_dec:
    jsr sword_done
    rts

; this sub routine checks if
; a move input should actually mvoe the player
; inputs:
;   move_timer
;   a -> last_move value
; side effect:
;   move_timer is incremented every call until check succeeds
;   stores value of A in last_move
;   removes move dlay if no move can go ahead that frame
; returns:
;   a -> 0 for no move
;   a -> 1 for move
check_move_delay:
    sta last_move

    lda move_timer
    cmp #$04
    bne @no_move
    lda #$01
    rts
@no_move:
    inc move_timer
    lda #$00
    sta move_delay
    rts

; this sub routine renders
; a tile buffer based on the last move direction
; inputs:
;   last_inputs
;   last_move
;   draw_buffer, _len, _x, _y
; side effects:
;   sets draw_buffer_len to 0
render_tile_updates:
    lda load_flags
    and #%01000000
    beq @done ; only load if flag is set

    ldy draw_buffer_len
    beq @done ; if 0 lenght no update is required

    lda last_move
    cmp #UP
    bne @not_up

    jsr draw_row
    jmp @draw_finished
@not_up:
    cmp #DOWN
    bne @not_down

    jsr draw_row
    jmp @draw_finished
@not_down:
    cmp #LEFT
    bne @not_left

    jsr draw_col
    jmp @draw_finished
@not_left:
    cmp #RIGHT
    bne @not_right

    jsr draw_col
@not_right:
@draw_finished:
    lda #$00
    sta draw_buffer_len
@done:
    rts

; this sub routine sets up
; the next draw buffer
;
; inputs:
;   last_inputs
;   last_move
;   player_x, player_y
; side_effcts:
;   modifies draw_buffer
setup_tile_updates:
    lda load_flags
    and #%01000000
    bne @start_setup ; only load if flag is set
    jmp @done
@start_setup:
    lda last_move
    cmp #UP
    bne @not_up

    ; set up coordinates
    lda player_x
    sec
    sbc #VISIBILITY_RADIUS
    sta get_tile_x
    sta draw_buffer_x

    lda player_y
    sec
    sbc #VISIBILITY_RADIUS-1
    sta get_tile_y
    sta draw_buffer_y

    ldy #31
    lda get_tile_x
    jsr verify_draw_buffer
    tay

    jsr get_row
    rts
@not_up:
    cmp #DOWN
    bne @not_down

    ; set up coordinates
    lda player_x
    sec
    sbc #VISIBILITY_RADIUS
    sta get_tile_x
    sta draw_buffer_x

    lda player_y
    clc
    adc #VISIBILITY_RADIUS-1
    sta get_tile_y
    sta draw_buffer_y

    cmp #30
    bcs @done

    ldy #31
    lda get_tile_x
    jsr verify_draw_buffer
    tay

    jsr get_row
    rts
@not_down:
    cmp #LEFT
    bne @not_left

    ; set up coordinates
    lda player_x
    sec
    sbc #VISIBILITY_RADIUS-1
    sta get_tile_x
    sta draw_buffer_x

    lda player_y
    sec
    sbc #VISIBILITY_RADIUS
    sta get_tile_y
    sta draw_buffer_y

    ldy #29
    lda get_tile_y
    jsr verify_draw_buffer
    tay

    jsr get_col
    rts
@not_left:
    cmp #RIGHT
    bne @not_right

    ; set up coordinates
    lda player_x
    clc
    adc #VISIBILITY_RADIUS-1
    sta get_tile_x
    sta draw_buffer_x


    cmp #31
    bcs @done

    lda player_y
    sec
    sbc #VISIBILITY_RADIUS
    sta get_tile_y
    sta draw_buffer_y

    ldy #29
    lda get_tile_y
    jsr verify_draw_buffer
    tay

    jsr get_col
    rts
@not_right:
@done:
    rts

; this sub routine makes the player take damage
; decs armor, if underflow decs hp
; sets iframes
; inputs:
;   a = amount of armor damage inflicted
; returns:
;   x == $00 if no hp left
;   x != 00 if hp left
;   ensures zero flag is set/unset at the end
take_damage:
    ldx player_armor
    beq @damage

    ; swap armor and damage value for sub
    tax
    lda player_armor
    stx player_armor
    sec
    sbc player_armor
    bcs @no_carry
    lda #$00 ; set to 0 if carry
@no_carry:
    sta player_armor

    ldx #$01
    stx iframes ; set iframe
    rts
@damage:
    ldx player_hp
    beq @done

    lda player_armor_base
    sta player_armor ; reset armor value
    ; if player still has hp, damage but no relaod
    dec player_hp
    lda #$01 ; iframes
    sta iframes

    ldx #$01
@done:
    rts

; cacl_checksum
; calculates save data sum
; inputs:
;   save_ptr pointing to save game location
; side effects:
;   uses a and y registers
; returns:
;   a = checksum
calc_checksum:
    ; validate checksum
    ldy #$01 ; offset starting at 1. 0 is checksum
    lda #$FF
    sec
@loop:
    sbc (save_ptr), y
    eor (save_ptr), y
    iny
    cpy #SAVE_DATA_SIZE
    bne @loop
    rts

; this sub rotuine copies all game state variables to sram
; inputs:
;   save_ptr pointing to save game location
; side effects:
;   uses a and y registers
load_save:
    jsr calc_checksum
    ldy #$00 ; offset
    cmp (save_ptr), y
    bne @invalid

    iny
    lda (save_ptr), y
    sta player_damage

    iny
    lda (save_ptr), y
    sta weapon_type

    iny
    lda (save_ptr), y
    sta player_hp

    iny
    lda (save_ptr), y
    sta player_armor

    iny
    lda (save_ptr), y
    sta player_armor_base

    iny
    lda (save_ptr), y
    sta level

    iny
    lda (save_ptr), y
    sta key_count

    iny
    lda (save_ptr), y
    sta seed
    iny
    lda (save_ptr), y
    sta seed+1

    iny
    lda (save_ptr), y
    sta coins
@invalid:
    rts

; this sub routine restores all game state variables from stram
; inputs:
;   save_ptr pointing to save game location
; side effects:
;   uses a and y registers
store_save:
    ldy #SAVE_DATA_SIZE-1

    lda coins
    sta (save_ptr), y

    dey
    lda seed+1
    sta (save_ptr), y
    dey
    lda seed
    sta (save_ptr), y

    dey
    lda key_count
    sta (save_ptr), y

    dey
    lda level
    sta (save_ptr), y

    dey
    lda player_armor_base
    sta (save_ptr), y

    dey
    lda player_armor
    sta (save_ptr), y

    dey
    lda player_hp
    sta (save_ptr), y

    dey
    lda weapon_type
    sta (save_ptr), y

    dey
    lda player_damage
    sta (save_ptr), y

    jsr calc_checksum
    ldy #$00
    sta (save_ptr), y

    rts
