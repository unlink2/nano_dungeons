
; sub routine that converts the sprite's 
; tile position to an actual 
; location on  the screen
convert_tile_location:
    ldx player_y
    lda tile_convert_table, x 
    sec 
    sbc #$01
    cmp #$FF ; if y location is FF we set it to 0
    bne @not_ff
    lda #$00
@not_ff:
    sta sprite_data

    ldx player_x
    lda tile_convert_table, x 
    clc 
    adc #$00
    sta sprite_data+3

    ; check game mode
    lda game_mode
    cmp #GAME_MODE_EDITOR
    bne @done

    ; if editor mode also update sprites 1-5
    ldx player_y
    lda attr_convert_table, x
    tax 
    lda tile_convert_table, x
    sec 
    sbc #$01 
    cmp #$FF 
    bne @not_ff_editor
    lda #$00
@not_ff_editor:

    sta sprite_data_1
    sta sprite_data_2

    clc 
    adc #$8*3
    sta sprite_data_3
    sta sprite_data_4

    ldx player_x
    lda attr_convert_table, x
    tax 
    lda tile_convert_table, x
    sta sprite_data_1+3
    sta sprite_data_3+3

    clc 
    adc #$8*3
    sta sprite_data_2+3 
    sta sprite_data_4+3

@done:
    rts

; this sub routine applies smooth scrolling
; to sprite 0
; inputs:
;   smooth_up,_down,_left,_right
; side effects:
;   changes position of sprite 0
;   overwirtes a and carry flag
apply_smooth:
    lda sprite_data  
    sec 
    sbc smooth_down
    clc 
    adc smooth_up
    sta sprite_data

    lda sprite_data+3
    sec 
    sbc smooth_right
    clc 
    adc smooth_left 
    sta sprite_data+3
    rts 

; this sub routine decrements all
; smooth movement values if they are greater than 0
; inputs:
;   smooth up, down, left, right
; side effects:
;   a register and carry flag are modified
;   smooth_x values may be decremented
adjust_smooth:
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
    rts 

; this sub routine copies memory from one 
; location to another
; inputs:
;   y -> size
;   src_ptr -> original data
;   dest_ptr -> destination 
; side effects:
;   y is changed, data is written at dest_ptr
memcpy:
    dey 
@loop:
    lda (src_ptr), y 
    sta (dest_ptr), y
    dey
    cpy #$FF ; if underflow stop
    bne @loop
    rts 

; this sub routine converts a number to hex values
; that are ready to be pritned to the screen
; inputs:
;   a -> the number
; side effects:
;   hex_buffer if overwritten
;   a is changed
convert_hex:
    pha ; save value of a

    and #$0F ; first nibble
    sta hex_buffer

    pla 
    and #$F0 ; second nibble
    lsr 
    lsr 
    lsr 
    lsr ; shift to get right value
    sta hex_buffer+1
    
    rts 

; this sub routine 
; makes an indirect jsr 
; based on src_ptr
; inputs
;   src_ptr -> the rotuine to jump to
; side effects:
;   depends on indirect routine called
jsr_indirect:
    jmp (src_ptr)

; this sub routine is a no-op update routine
update_none:
    jmp update_done

; no critical update
update_crit_none:
    jmp update_crit_done

; this is an empty sub routine 
; useful for function pointers that
; require an input
empty_sub:
    rts 

; this sub routine hides objects
; at 0/0
; side effects:
;   moves obejcts
hide_objs:
    lda #$00
    ldx #$00
@loop:
    sta sprite_data, x 
    inx
    cpx #$FF
    bne @loop 
    rts

; this sub routine generates
; a simple 8-bit pseudo
; random number
; inputs:
;   rand8 -> nonzero value
; side effects:
;   a register and flags are used
;   rand8 changes
random:
	lda rand8
	lsr
	bcc @noeor
	eor #$B4
@noeor
	sta rand8
	rts

; this sub routine reloads a room
; inputs:
;   level_data_ptr_bac
;   level_ptr_bac
;   attr_ptr_bac
;   palette_ptr_bac  (src_ptr)
reload_room:
    ; reload the pointers
    lda level_data_ptr_bac
    sta level_data_ptr
    lda level_data_ptr_bac+1
    sta level_data_ptr+1

    lda attr_ptr_bac
    sta attr_ptr
    lda attr_ptr_bac+1
    sta attr_ptr+1

    lda palette_ptr_bac
    sta src_ptr
    lda palette_ptr_bac+1
    sta src_ptr+1

    ldx #$00
    stx $2001 ; disable rendering

    lda #<level_data
    sta level_ptr
    lda #>level_data
    sta level_ptr+1

    ; disable NMI until load is complete
    set_nmi_flag

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

    lda #$00
    sta nametable

    vblank_wait
    ; lda #$00
    ; sta $2005
    ; sta $2005 ; no scrolling
    jsr init_game

    vblank_wait
    rts

; this sub routine should be called at the start of the
; program
; first it checks the magic number sequence
; if it is not present it sets up default values
; for all sram functionality
init_sram:
    ldx #$00
@magic_check:
    lda magic_bytes, x
    cmp magic, x
    bne @init
    inx
    cpx #16
    bne @magic_check

    rts

@init:
    ; if check was not OK start
    ; init
    ; first set up magic values correctly

    ldx #$00
@magic_init:
    lda magic_bytes, x
    sta magic, x
    inx
    cpx #16
    bne @magic_init


    ; lastly make the custom code
    ; an rts
    lda #$60 ; rts opcode
    sta save_sub_1
    sta save_sub_2
    sta save_sub_3

    ; then set up a completely empty
    ; tileset for all maps
    ldx #00
@empty_map_init:
    lda empty_map, x
    sta save_1, x
    sta save_2, x
    sta save_3, x
    inx
    cpx #$14
    bne @empty_map_init 


    rts 

; 16 random values
magic_bytes:
.db $0e ,$94 ,$3f ,$76 ,$9c ,$dd ,$f0 ,$ba ,$5c ,$ba ,$72 ,$36 ,$f8 ,$2d ,$d3, $46
