; this file contains all map related sub routines


; sub routine that is going to decompress level data from rom
; and store it in ram at level_ptr
; At this point in time the level data are not compressed and will
; be used directly 
; inputs:
;   level_data_ptr -> ptr to ROM/SRAM location of compressed level
;   level_ptr -> copy destination
; side effects:
;   all registers and flags may be changed
;   temp is written to
;   disables sprite updating in game flags
decompress_level:
    ; clear tile position
    lda #$00 
    sta tiles_to_clear
    sta tiles_to_clear

    lda game_flags 
    and #%10111111
    sta game_flags ; disable sprite updating

    lda #$FF 
    sta sprite_tile_size ; set invalid size

    ; save level data ptr
    lda level_data_ptr 
    pha 
    lda level_data_ptr+1 
    pha 

    ; to decompress a level we need to loop for a while
    ; until we find the terminating sequence of $FF $00
    lda level_ptr
    sta level_ptr_temp
    lda level_ptr+1
    sta level_ptr_temp+1

    ; lda #$01
    ; sta temp ; increment by 1 every time

@decompress_loop:
    ldy #$00
    ldx #$01 ; x is loop write counter

    lda (level_data_ptr), y ; load first byte of data
    cmp #$FF ; if it is a ff we can assume we need to decompress
    bne @single_value ; if not ff it is a single value

    jsr inc_level_data_ptr ; look for next byte
    lda (level_data_ptr), y ; load next byte
    tax ; a holds x index
    cmp #$00 ; if it is 00 we have found $FF $00 
    beq @decompress_done ; we are done here

    jsr inc_level_data_ptr ; next byte
    lda (level_data_ptr), y ; a now holds tile 

@single_value:
    jsr write_decompressed_byte ; write byte
    dex ; x is always at least 1
    bne @single_value

    ; increment level
    jsr inc_level_data_ptr ; next byte
    jmp @decompress_loop ; always loop
@decompress_done:

    ; restore original level data ptr
    pla
    sta level_data_ptr
    pla
    sta level_data_ptr+1

    rts

; increments level data ptr
; inputs:
;   level_data_ptr -> pointing to compressed level
; side effects:
;   a register and acarry flag are modified
;   level_data_ptr is incremented
inc_level_data_ptr:
    ; 16 bit add
    lda level_data_ptr
    clc
    adc #$01
    sta level_data_ptr
    lda level_data_ptr+1
    adc #$00
    sta level_data_ptr+1
    rts

; writes the decompressed byte contained in a
; to level_ptr_temp
; inputs:
;   level_ptr_temp pointing to the next byte location
; side effects:
;   increments level_ptr_temp for each iteration
;   y is set to 0
;   start_x and y may be set
;   tiles_to_clear may be incremented
;   if tile is a sprite tile it may set up the ai for the map
write_decompressed_byte:
    ldy #$00

    sta (level_ptr_temp), y

    pha ; store current value

    ; check tile id, between START and END value
    cmp #CLEARABLE_TILES_START
    bcc @not_clearable

    cmp #CLEARABLE_TILES_END
    bcs @not_clearable

    lda tiles_to_clear
    clc
    adc #$01
    sta tiles_to_clear
    lda tiles_to_clear+1
    adc #$00
    sta tiles_to_clear+1
@not_clearable:


    ; 16 bit add
    lda level_ptr_temp
    clc
    adc #$01
    sta level_ptr_temp
    lda level_ptr_temp+1
    adc #$00
    sta level_ptr_temp+1

    pla ; restore tile value
    rts

; this sub routine compresses a level
; it will follow the rules desribed in README
; inputs:
;   level_data_ptr -> pointing to destination
;   level_ptr -> pointing to uncompressed level in RAM/ROM
; side effects:
;   all registers and flags may be changed
;   temp, temp+1 and temp+2 are written to
compress_level:
    ; save level data ptr
    lda level_data_ptr
    pha
    lda level_data_ptr+1
    pha

    ; to compress a level we need to loop for a while
    ; until we reach LEVEL_SIZE bytes
    lda level_ptr
    sta level_ptr_temp
    sta temp+1
    lda level_ptr+1
    sta level_ptr_temp+1
    sta temp+2

    ; temp will hold the las tile read
    lda #$00
    sta temp

    ; pre-calculate end address of level
    ; temp+1 and +2 are holding the end address
    ; size is FF+FF+FF+C3
    ldx #$03 ; do this 3 times
@end_calc_loop:
    lda temp+1
    clc
    adc #$FF
    sta temp+1
    lda temp+2
    adc #$00 ; add carry
    sta temp+2
    dex
    bne @end_calc_loop
    ; add rest
    lda temp+1
    clc
    adc #$C3 ; +1 since we break after
    sta temp+1
    lda temp+2
    adc #$00 ; carry
    sta temp+2

    ; loop until level_ptr_temp is the same as the end address
@compress_loop:
    ldy #$00 ; used for indirect access
    ldx #$01 ; start off at count 1
    lda (level_ptr_temp), y ; get first tile for comparison
    jmp @next_byte ; start loop
@count_repeates:
    ; sta temp ; store last tile, or if at start store first tile again
    lda (level_ptr_temp), y ; get tile from ram
    ; check for different tile
    cmp temp
    bne @store_data
    inx
    cpx #$FF
    beq @store_data
    bne @next_byte
@store_data
    lda temp
    jsr write_compressed_data
    cpx #$FF ; if we did hit FF we need to go to next byte
    bne @compress_loop ; if not ff continue on normall
@next_byte:
    sta temp ; store last tile now
    ; increment pointer 16 bit math
    lda level_ptr_temp
    clc
    adc #$01
    sta level_ptr_temp
    lda level_ptr_temp+1
    adc #$00
    sta level_ptr_temp+1

    ; compare to end pointer
    lda level_ptr_temp
    cmp temp+1
    bne @not_done
    lda level_ptr_temp+1
    cmp temp+2
    bne @not_done
    beq @compress_done ; if both are equal we are done
@not_done:
    cpx #$FF ; if $ff start over from start
    beq @compress_loop
    bne @count_repeates
@compress_done:
    lda temp
    jsr write_compressed_data ; add last data

    lda #$FF
    ldx #$01
    ; write FF at the end
    jsr write_compressed_data
    lda #$00
    ldx #$01
    ; write 00 at the end
    jsr write_compressed_data

    ; restore original level data ptr
    pla
    sta level_data_ptr
    pla
    sta level_data_ptr+1
    rts

; this sub routine saves attributes from ppu
; memory to
; a location pointed to by attr_ptr
; inputs:
;   attr_ptr -> pointing to attribute destination
;   x -> the nametable
; side effects:
;   registers and flags are modified
write_attr:
    lda #$00
    bit $2002 ; read PPU status to reset the high/low latch
    ; sta $2005
    ; sta $2005 ; no scrolling

    lda #$23 ; write $23C0 to ppu as start address

    cpx #$01
    bne @no_add
    ; if x is 0 do not add, if 1 nt1 is needed
    clc
    adc #$04

@no_add:
    sta $2006
    lda #$C0
    sta $2006 ; set up ppu for attribute transfer

    lda $2007 ; do one invalid read before starting transfer

    ldy #$00
@attr_loop:
    lda $2007
    sta (attr_ptr), y ; transfer
    iny
    cpy #ATTR_SIZE
    bne @attr_loop

    lda #$00
    sta $2005
    sta $2005

    rts

; sub routine that writes compressed data to output pointer
; inputs:
;   level_ptr -> the output ptr, gets incremented
;   a -> the tile to write
;   x -> tile count
; side effects:
;   increments level_ptr by  1-3 bytes
write_compressed_data:
    pha ; save tile state

    ; first determine what needs to be done
    cpx #$03
    bcc @single_values ; branch if less than

@compress:
    ; add an ff first
    lda #$FF
    sta (level_data_ptr), y
    jsr inc_level_data_ptr
    txa ; write amount
    sta (level_data_ptr), y
    jsr inc_level_data_ptr

    pla ; get tile
    sta (level_data_ptr), y ; store tile id
    pha ; push it back since inc will destroy the value
    jsr inc_level_data_ptr
    pla ; get tile again
    ; ldx #$00
    rts ; done
@single_values:
    ldy #$00 ; index
    sta (level_data_ptr), y
    pha ; save a's state
    jsr inc_level_data_ptr
    pla
    dex
    bne @single_values
@done:
    pla ; restore tile state
    rts

; this sub routine loads all attributes for NT1
; inputs:
;   attr_ptr -> pointing to attributes
;   x -> decides start address based on nametable
load_attr:
    bit $2002 ; read PPU status to reset the high/low latch
    ; lda #$00
    ; sta $2005
    ; sta $2005 ; no scrolling

    lda #$23 ; write $23C0 to ppu as start address

    cpx #$01
    bne @no_add
    ; if x is 0 do not add, if 1 nt1 is needed
    clc
    adc #$04

@no_add:
    sta $2006
    lda #$C0
    sta $2006 ; set up ppu for attribute transfer

    ldy #$00
@attr_loop:
    lda (attr_ptr), y
    sta $2007 ; transfer
    iny
    cpy #ATTR_SIZE
    bne @attr_loop

    rts

; this sub routine loads a color palette
; inputs:
;   palette_ptr -> ptr to palette
; side effects:
;   modifies registers and flags
load_palette:
    ; sets up ppu for palette transfer
    bit $2002 ; read PPU status to reset the high/low latch to high
    ; lda #$00
    ; sta $2005
    ; sta $2005 ; no scrolling

    lda #$3F
    sta $2006
    lda #$00
    sta $2006

    ldy #$00
load_palette_loop:
    lda (palette_ptr), y
    sta $2007 ; write to PPU
    iny
    cpy #palette_data_end-palette_data
    bne load_palette_loop

    ; no scrolling
    lda #$00
    sta $2005
    sta $2005

    rts


; this sub routine loads a level into NT1
; inputs:
;   level_ptr -> pointing to level data
;   x -> decides the start address based on nametable
load_level:
    lda $2002 ; read PPU status to reset the high/low latch

    ; reset scroll
    ; lda #$00
    ; sta $2005
    ; sta $2005

    lda #$20  ; $2000 = start of ppu address
    cpx #$01
    bne @no_add
    ; if nt is 0 we dont need to change the address
    clc
    adc #$04 ; add 4 to get start address of nt1
@no_add:
    sta $2006
    lda #$00
    sta $2006 ; set up ppu for level transfer

    ; copy the pointer to
    ; save the original one
    lda level_ptr
    sta level_ptr_temp
    lda level_ptr+1
    sta level_ptr_temp+1

    jsr load_level_iter
    ; same loop again, but add $FF to level ptr
    jsr inc_level_temp_ptr
    jsr load_level_iter
    jsr inc_level_temp_ptr
    jsr load_level_iter
    jsr inc_level_temp_ptr
    ; last iteration is different so no jsr
    ldy #$00 ; remainder
@load_level_loop:
    lda (level_ptr_temp), y
    sta $2007 ; write to ppu
    iny
    cpy #$C3
    bne @load_level_loop

    rts

; loads menu background into nametable 1
; inputs:
;   x -> menu type (same as game mode), sets up level_ptr
; side effects:
;   changes registers
;   overwrites level_ptr with a menu
;   changes level data to menu (since it decompresses the level itself)
;       therefore it should always be called before loading an actual level!
load_menu:
    cpx #GAME_MODE_EDITOR_MENU
    bne @not_editor

    ; load editor menu compressed tiles
    lda #<editor_menu_gfx
    sta level_data_ptr
    lda #>editor_menu_gfx
    sta level_data_ptr+1

    ; decompress location, same as level
    lda #<level_data
    sta level_ptr
    lda #>level_data
    sta level_ptr+1

    jsr decompress_level

    ldx #$01 ; load into nametable 1
    jsr load_level
    rts
@not_editor:
    cpx #GAME_MODE_MENU
    bne @not_main

    ; load editor menu compressed tiles
    lda #<main_menu_gfx
    sta level_data_ptr
    lda #>main_menu_gfx
    sta level_data_ptr+1

    ; decompress location, same as level
    lda #<level_data
    sta level_ptr
    lda #>level_data
    sta level_ptr+1

    jsr decompress_level

    ldx #$01 ; load into nametable 1
    jsr load_level
    rts

@not_main:
    cpx #GAME_MODE_MESSAGE
    bne @not_message

    ; load win menu compressed tiles
    lda #<win_gfx
    sta level_data_ptr
    lda #>win_gfx
    sta level_data_ptr+1

    ; decompress location, same as level
    lda #<level_data
    sta level_ptr
    lda #>level_data
    sta level_ptr+1

    lda #<win_attr
    sta attr_ptr
    lda #>win_attr
    sta attr_ptr+1

    jsr decompress_level
    jsr load_attr

    ; copy palette
    lda #<win_pal
    sta palette_ptr
    lda #>win_pal
    sta palette_ptr+1
    jsr load_palette

    ldx #$01 ; load into nametable 1
    jsr load_level

    rts
@not_message:
    cpx #GAME_MODE_TITLE
    bne @invalid_menu

    ; load win menu compressed tiles
    lda #<win_gfx
    sta level_data_ptr
    lda #>win_gfx
    sta level_data_ptr+1

    ; decompress location, same as level
    lda #<level_data
    sta level_ptr
    lda #>level_data
    sta level_ptr+1

    lda #<win_attr
    sta attr_ptr
    lda #>win_attr
    sta attr_ptr+1

    jsr decompress_level
    jsr load_attr

    ; copy palette
    lda #<win_pal
    sta palette_ptr
    lda #>win_pal
    sta palette_ptr+1
    jsr load_palette

    ldx #$01 ; load into nametable 1
    jsr load_level

@invalid_menu:
    rts

; this sub routine displays
; a map load error
; inputs:
;   none
; side effects:
;   decompresses a map,
;   overwrites nt1
;   registers/flags changed
load_map_start_error:
    lda #$00
    sta $2001 ; no rendering

    set_nmi_flag

    lda #GAME_MODE_MESSAGE
    sta game_mode

    lda #$01
    sta nametable

    lda #<update_none
    sta update_sub
    lda #>update_none
    sta update_sub+1

    lda #<update_crit_none
    sta update_sub_crit
    lda #>update_crit_none
    sta update_sub_crit+1

    ; load editor menu compressed tiles
    lda #<no_start_msg_gfx
    sta level_data_ptr
    lda #>no_start_msg_gfx
    sta level_data_ptr+1

    ; decompress location, same as level
    lda #<level_data
    sta level_ptr
    lda #>level_data
    sta level_ptr+1

    jsr decompress_level

    ldx #$01 ; load into nametable 1
    jsr load_level

    vblank_wait

    rts

; increments level ptr by FF
inc_level_temp_ptr:
    lda level_ptr_temp
    clc
    adc #$FF
    sta level_ptr_temp
    bcc @no_carry:
    lda level_ptr_temp+1
    adc #$00 ; add carry
    sta level_ptr_temp+1
@no_carry:
    rts

; first second and third iteration of load level
load_level_iter:
    ldy #$00 ; loop counter
@load_level_loop:
    lda (level_ptr_temp), y
    sta $2007 ; write to ppu
    iny
    cpy #$FF
    bne @load_level_loop
    rts

; this sub routine updates a tile at
; the player's current x/y position (tile location)
; with the player's currently active tile if the game is in editor mode
; or sets it
; to a passed over tile when game mode is in puzzle mode
; a tile is considered 'passed' when the 7th bit is set, and not passed if it is not set
; it will not allow placing AI tiles if max AI tiles is reached
; inputs:
;   player_x -> x position
;   player_y -> y position
;   sprite_data+1 -> the tile to place
;   game_mode -> decides the effect of the update
; side effects:
;   updates level_data and nametable
;   changes registers and flags
;   increments or decrements tiles_to_clear if in puzzle mode
;   inc/dec sprite_tile_size in editor mode
update_tile:
    lda game_mode
    cmp #GAME_MODE_EDITOR
    bne @not_replacing_sprite
    lda sprite_data+1
    ; check if it is an AI tile
    cmp #SPRITE_TILES_START
    bcc @not_sprite
    cmp #SPRITE_TILES_END
    bcs @not_sprite
    lda sprite_tile_size
    cmp #SPRITE_TILES-1
    bne @not_max_ai
    rts ; if max ai is reached return
@not_max_ai:
    inc sprite_tile_size
@not_sprite

    ; check if previous tile was AI tile
    lda player_x
    sta get_tile_x
    lda player_y
    sta get_tile_y
    jsr get_tile
    cmp #SPRITE_TILES_START
    bcc @not_replacing_sprite
    cmp #SPRITE_TILES_END
    bcs @not_replacing_sprite
    dec sprite_tile_size
@not_replacing_sprite:

    ; store all pointers
    lda level_ptr
    pha
    lda level_ptr+1
    pha

    ; temp holds pointer to ppu ram
    lda #$00
    sta temp
    lda #$20
    sta temp+1

    ldx player_y
    lda tile_update_table_lo, x
    clc
    adc player_x
    sta level_ptr

    lda tile_update_table_hi, x
    adc level_ptr+1
    sta level_ptr+1

    ; same calculation for ppu address
    lda tile_update_table_lo, x
    clc
    adc player_x
    sta temp

    lda tile_update_table_hi, x
    adc temp+1
    sta temp+1

    lda $2002 ; read PPU status to reset the high/low latch
    lda #$00
    sta $2005
    sta $2005 ; no scrolling

    lda temp+1 ; write temp to ppu as start address
    sta $2006
    lda temp
    sta $2006 ; set up ppu for tile transfer

    lda game_mode
    cmp #GAME_MODE_EDITOR
    bne @not_editor

    lda sprite_data+1
    jmp @update
@not_editor:
    ldy #$00
    lda (level_ptr), y
    eor #%10000000
    jsr update_tiles_to_clear
@update:
    sta $2007 ; store in ppu
    ldy #$00
    sta (level_ptr), y ; store in level

    ; restore level_ptr
    pla
    sta level_ptr+1
    pla
    sta level_ptr

    lda #$00
    sta $2005 ; no horizontal scroll
    sta $2005 ; no vertical scroll

    rts

; this sub routine returns the current
; tile at the player's position
; inputs:
;   get_tile_x
;   get_tile_y
; side effects:
;   registers are modified
; returns:
;   a -> the tile index
get_tile:
    ; store all pointers
    lda level_ptr
    pha
    lda level_ptr+1
    pha

    ldx get_tile_y
    lda tile_update_table_lo, x
    clc
    adc get_tile_x
    sta level_ptr

    lda tile_update_table_hi, x
    adc level_ptr+1
    sta level_ptr+1

    ldy #$00
    lda (level_ptr), y
    tax

    ; restore level_ptr
    pla
    sta level_ptr+1
    pla
    sta level_ptr

    txa
    rts

; this sub rotuine returns
; the tile at the current player position
; from the nametable
; inputs:
;   get_tile_x, get_tile_y
;   x -> the nametable
; returns:
;   the tile in A
; side effects:
;   uses temp,
;   uses A and X register
;   does a nametable read
get_tile_nametable:
    lda $2002 ; read PPU status to reset the high/low latch

    txa
    tay ; store x value somewhere else

    ; use temp for pointer math
    lda #$20
    sta temp+1
    lda #$00
    sta temp

    ldx get_tile_y
    lda tile_update_table_lo, x
    clc
    adc get_tile_x
    sta temp

    lda tile_update_table_hi, x
    adc temp+1
    sta temp+1

    lda temp+1  ; $2000 = start of ppu address
    cpy #$01
    bne @no_add
    ; if nt is 0 we dont need to change the address
    clc
    adc #$04 ; add 4 to get start address of nt1
@no_add:
    sta $2006
    lda temp
    sta $2006 ; set up ppu for level transfer

    ; read tile
    lda $2007 ; dummy read
    lda $2007

    rts

; this sub routine updates an attribute at the
; player's x/y position
; the chosen value is the player's tile index
; inputs:
;   player_x and player_y location
;   player tile
; side effects:
;   updates ppu memory for nametable 0
;   modfies registers and flags
; TODO make a color select register
; that counts from 0-3
; based on that and player location we can AND
; the correct value by reading ppu back and then writing again
; can use lookup table for every possible combination of location, amount
; of shifts and where to write to
update_attr:
    ; temp holds pointer to ppu ram
    lda #$C0
    sta temp
    lda #$23
    sta temp+1

    ldx player_y
    lda attr_update_table_y, x
    clc
    adc temp
    sta temp

    ldx player_x
    lda attr_update_table_x, x
    clc
    adc temp
    sta temp

    sta src_ptr

    lda $2002 ; read PPU status to reset the high/low latch
    ; lda #$00
    ; sta $2005
    ; sta $2005 ; no scrolling

    lda temp+1 ; write temp to ppu as start address
    sta $2006
    lda temp
    sta $2006 ; set up ppu for tile transfer

    lda attr_value
    sta $2007 ; store in ppu

    ; no scrolling
    lda #$00
    sta $2005
    sta $2005

    rts

; this sub routine finds the start location
; of the currently loaded level
; it loops until start is found, or
; 960 bytes are reached
; inputs:
;   level_ptr pointing to level
; side effects:
;   sets start_x and y
;   player_x and player_y are set to start location
;   a and x are used
; returns:
;   a = 1 if location found
;   a = 0 if no location found = ERROR state
find_start:
    lda #$00
    sta start_x
    sta start_y
    sta player_x
    sta player_y
@x_loop:

    lda player_x
    sta get_tile_x
    lda player_y
    sta get_tile_y
    jsr get_tile
    cmp #START_TILE ; if current tile is start tile we found it
    beq @found

    ldx player_x
    inx
    txa
    and #%00011111 ; cannot be greater than 32
    sta player_x
    bne @x_loop
    ; if zero increemnt y
    ldx player_y
    inx
    cpx #30 ; cant be more than 29 y
    beq @done
    stx player_y
    bne @x_loop
@done:
    lda #$00 ; not found!
    sta player_x
    sta player_y
    sta start_x
    sta start_y
    rts
@found:
    lda player_x
    sta start_x
    lda player_y
    sta start_y
    lda #$01 ; found
    rts

; this sub routine inits all ai tiles
; inputs:
;   game_flags -> if sprites are disabled init is not called
; side effects:
;   registers affected, sprite oam changed
init_ai_tiles:
    ; clear all AI tiles first
    ldy #$00
    lda #$00
@clear_loop:
    sta sprite_tile_ai, y
    sta sprite_tile_obj, y
    sta sprite_tile_x, y
    sta sprite_tile_y, y
    sta sprite_tile_data, y
    sta sprite_tile_flags, y

    iny
    cpy #SPRITE_TILES
    bne @clear_loop


    lda #$00
    sta start_x
    sta start_y
    sta player_x
    sta player_y
@x_loop:
    lda player_x
    sta get_tile_x
    lda player_y
    sta get_tile_y
    jsr get_tile

    ; check if it is an AI tile
    cmp #SPRITE_TILES_START
    bcc @not_sprite
    cmp #SPRITE_TILES_END
    bcs @not_sprite

    sec
    sbc #SPRITE_TILES_START ; get offset for ai/init

    inc sprite_tile_size ; increment amount of sprites in use

    ldy sprite_tile_size
    sta sprite_tile_ai, y ; store AI offset

    lda #AI_SPRITES_START
    clc
    adc sprite_tile_size ; sprite to be used
    sta sprite_tile_obj, y ; object to be used

    ; store source tile's x and y position
    lda player_x
    sta sprite_tile_x, y
    lda player_y
    sta sprite_tile_y, y

    ; call init
    lda sprite_tile_ai, y
    tay

    lda game_flags
    and #%01000000
    beq @no_init ; no init if sprites are disabled

    ; save src_ptr
    lda src_ptr
    pha
    lda src_ptr+1
    pha

    lda sprite_init_lo, y
    sta src_ptr
    lda sprite_init_hi, y
    sta src_ptr+1
    ldy sprite_tile_size ; load offset into y
    jsr jsr_indirect

    ; restore src ptr
    pla
    sta src_ptr+1
    pla
    sta src_ptr

@no_init:
@not_sprite


    ldx player_x
    inx
    txa
    and #%00011111 ; cannot be greater than 32
    sta player_x
    bne @x_loop
    ; if zero increemnt y
    ldx player_y
    inx
    cpx #30 ; cant be more than 29 y
    beq @done
    stx player_y
    bne @x_loop
@done:
    lda #$00 ; not found!
    sta player_x
    sta player_y
    sta start_x
    sta start_y
    rts

; TODO
; this sub routine clears all bytes
; used by level_ptr
; inputs:
;   level_ptr pointing to RAM
; effects:
;   clears everything at level_ptr
;   uses level_ptr_temp to clear
clear_level:
    rts
