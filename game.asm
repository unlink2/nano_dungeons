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

    ; re-enable input just in case player died
    ; during sword animation
    lda nmi_flags
    and #%11011111 ; enables input
    sta nmi_flags

    lda #GAME_MODE_PUZZLE
    sta game_mode

    lda #MAX_HP ; hp
    sta player_hp

    lda #$00
    sta map_flags ; reset all map flags
    sta key_count ; no keys when map begins
    sta player_timer ; no timer for player
    sta weapon_type
    sta iframes ; no iframes
    sta move_timer ; reset move timer

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

    lda game_flags
    ora #%01000000
    sta game_flags ; enable sprite updating

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

    jsr init_test_song

    rts

; this routine is called every frame
; it updates the game state
; critical game update
update_game_crit:
    jsr render_tile_updates

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

; non-critical game updates
update_game:
    jsr check_player_move
    cmp #$01
    bne @player_not_moved

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
    jsr init_test_song
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

    ; test victory condition
    ; if only one tile is left to clear the player must be on it
    lda tiles_to_clear+1
    cmp #$00
    bne @done
    lda tiles_to_clear
    cmp #$01
    bne @done

    ; if animation timer is already going do not prceed
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

    ldy #VISIBILITY_RADIUS*2-1
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

    ldy #VISIBILITY_RADIUS*2-1
    jsr get_row
    rts
@not_down:
    cmp #LEFT
    beq @not_left

    ; set up coordinates
    lda player_x
    clc
    adc #VISIBILITY_RADIUS-1
    sta get_tile_x
    sta draw_buffer_x

    lda player_y
    sec
    sbc #VISIBILITY_RADIUS
    sta get_tile_y
    sta draw_buffer_y

    ldy #VISIBILITY_RADIUS*2-1
    jsr get_col
    rts
@not_left:
    cmp #RIGHT
    beq @not_right

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

    ldy #VISIBILITY_RADIUS*2-1
    jsr get_col
    rts
@not_right:
@done:
    rts
