
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
    lda #$24
    sta sprite_data+1, x
    lda #$00
    sta sprite_data, x
    sta sprite_data+2, x
    sta sprite_data+3, x
    inx
    inx 
    inx 
    inx 
    cpx #$00
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

; this sub routine generates
; an 8 bit random number
; inputs:
;   a -> nonzero value
; returns:
;   new random number in a
random_reg:
	lsr
	bcc @noeor
	eor #$B4
@noeor
    rts 

; this sub routine reloads a room
; inputs:
;   level_data_ptr_bac
;   level_ptr_bac
;   attr_ptr_bac
;   palette_ptr_bac  (src_ptr)
;   seed_bac for random map
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

    lda seed_bac
    sta seed
    lda seed_bac+1
    sta seed+1

    ldx #$00
    stx $2001 ; disable rendering


    ; load an empty map first
    lda #<empty_map
    sta level_data_ptr
    lda #>empty_map
    sta level_data_ptr+1

    lda #<level_data
    sta level_ptr
    lda #>level_data
    sta level_ptr+1

    ; disable NMI until load is complete
    set_nmi_flag

    jsr decompress_level
    ldx #$00 ; nt 0
    jsr load_level

    ; load actual map
    lda level_data_ptr_bac
    sta level_data_ptr
    lda level_data_ptr_bac+1
    sta level_data_ptr+1

    lda #<level_data
    sta level_ptr
    lda #>level_data
    sta level_ptr+1

    ; load sram values before generating map
    lda load_flags
    and #%00100000
    bne @no_load
    jsr load_save
@no_load:

    ; if level select is #$00 we generate a map, otherwise decompress
    lda load_flags
    and #%10000000
    beq @decompress

    jsr generate_map

    jmp @map_in_buffer
@decompress:
    jsr decompress_level
@map_in_buffer:

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


    ; test if partial load is needed now
    ; if so we have start location and can go ahead
    lda load_flags
    and #%01000000 ; flag for partial load
    beq @no_part_load
    lda player_x
    sta get_tile_x
    lda player_y
    sta get_tile_y
    ldx #$00 ; nametable 0
    jsr load_level_part
    jmp @done
@no_part_load:
    ldx #$00 ; nametable 0
    jsr load_level
@done:
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

; this sub routine calculates the
; absolute distance between 2 numbers
; inputs:
;   a -> x1
;   x -> x2
; returns:
;   absolute distance between x1 and x2
; side effects:
;   uses temp for subtraction
calc_distance:
    stx temp
    sec
    sbc temp
    ; if overflow flag is set we got a negative result
    bpl @no_negative

    ; to convert, invert all bits and add 1
    eor #%11111111
    clc
    adc #$01
@no_negative

    rts 

; this sub routine is called when
; a brk occurs
; or any other IRQ is called
; since IRQ should never be activated
; it prints out all register values
; and the stack
; abandon all hope ye who calls this
crash_handler:
    pha ; store A value for output later on
    txa
    pha ; store X value
    tya
    pha ; store Y value

    vblank_wait

    ; disable sprites and rendering
    ; disable NMI
    lda #$00
    sta $2000
    sta $2001

    bit $2002 ; reset latch

    lda #$20
    sta $2006
    lda #$00
    sta $2006 ; write address

    lda #$22 ; 'Y'
    sta $2007
    pla ; y value

    ; this macro outputs
    ; prints value in A to the screen
.macro output_value_crash
    pha
    lsr
    lsr
    lsr
    lsr
    sta $2007
    pla
    and #$0F
    sta $2007
.endm
    ; y value
    output_value_crash

    lda #$24 ; space
    sta $2007

    lda #$21 ; 'X'
    sta $2007

    pla ; x value
    output_value_crash

    lda #$24 ; space
    sta $2007

    lda #$0A ; 'A'
    sta $2007
    pla
    output_value_crash

    lda #$24 ; space
    sta $2007

    lda #$1C ; 'S'
    sta $2007

    tsx
    txa
    output_value_crash

    ; output error message
    lda #$20
    sta $2006
    lda #$80
    sta $2006

    ldy #$00
@message_loop:
    lda @error_str, y
    beq @message_done
    sta $2007
    iny
    bne @message_loop
@message_done:

    ; loop all of stack
    lda #$20
    sta $2006
    lda #$C0
    sta $2006

    ldy #$00
    ldx #$24
@stack_loop:
    lda $0100, y
    output_value_crash
    ; stx $2007

    iny
    bne @stack_loop

@crash_loop:
    vblank_wait
    ; enable rendering
    lda #%00000000   ; enable NMI, sprites from Pattern Table 0
    sta $2000

    lda #%00001111   ; enable sprites, bg, grayscale mode
    sta $2001

    lda #$00
    sta $2005
    sta $2005
    jmp @crash_loop
; strings for crash handler
@error_str
.db "OH NO THE GAME CRASHED", $00
@error_str_end
