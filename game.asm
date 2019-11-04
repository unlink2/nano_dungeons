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

    lda #$00 
    sta player_x_bac
    sta player_y_bac

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
    ; store previous position
    lda player_x 
    sta player_x_bac 
    lda player_y 
    sta player_y_bac

    ; dec smooht values
    lda #$00 
    cmp smooth_left 
    beq @no_dec_left
    dec smooth_left
@no_dec_left

    cmp smooth_right 
    beq @no_dec_right 
    dec smooth_right
@no_dec_right:

    cmp smooth_up 
    beq @no_dec_up 
    dec smooth_up
@no_dec_up:

    cmp smooth_down 
    beq @no_dec_down
    dec smooth_down
@no_dec_down:

    jmp update_done