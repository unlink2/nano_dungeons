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

    rts 

; this routine is called every frame
; it updates the game state
update_game:
    jmp update_done