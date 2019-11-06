; game related code

; inits game mode
; inputs:
;   level_data_ptr -> pointing to compressed level
;   attr_ptr -> pointing to attributes
;   palette_ptr -> pointing to palette
init_game:
    lda #GAME_MODE_PUZZLE
    sta game_mode

    lda #<update_game
    sta update_sub
    lda #>update_game
    sta update_sub+1

    ; copy palette
    lda #<level_palette 
    sta palette_ptr 
    lda #>level_palette
    sta palette_ptr+1
    jsr load_palette

    lda player_x 
    sta player_x_bac
    lda player_y 
    sta player_y_bac

    ; player sprite
    lda #$32 
    sta sprite_data+1

    rts 

; this routine is called every frame
; it updates the game state
update_game:
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
    cmp #$01 
    bne @player_not_moved

    ; test collision
    jsr collision_check
    ; if a = 1 collision occured
    cmp #$01
    beq @player_not_moved 

    ; test if the current tile
    ; is already marked if so, do not update the previous tile but rather unmark the current
    jsr get_tile 
    and #%10000000 
    beq @tile_update_not_marked
    jsr update_tile
    jmp @skip_tile_update
@tile_update_not_marked:
    ; update current tile is player did move
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

    jmp update_done

; this sub routine updates the player's animation based on 
; the movement offset
; inputs:
;   smooth up, down, left, right
; side effects:
;   modifies registers, flags
;   modifies player sprite and attributes
update_player_animation:
    lda last_inputs
    and #%11110000
    beq @idle

    ; TODO check for specific keys

@idle 
    lda #$32
    sta sprite_data+1
    lda #$00 
    sta sprite_data+2

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
    jsr get_tile
    tax 
    ; get routine for current tile 
    lda tile_sub_lo, x 
    sta src_ptr 
    lda tile_sub_hi, x 
    sta src_ptr+1

    jsr jsr_indirect
    cmp #$01 
    bne @no_collision

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

@no_collision:
    rts 