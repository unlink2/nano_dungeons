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
decompress_level:
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
write_decompressed_byte:
    ldy #$00 

    sta (level_ptr_temp), y
    pha ; store current value

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
    sta $2002 ; read PPU status to reset the high/low latch
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
    lda $2007 
    sta (attr_ptr), y ; transfer
    iny 
    cpy #ATTR_SIZE
    bne @attr_loop

    rts 

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
    lda $2002 ; read PPU status to reset the high/low latch
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
    lda $2002 ; read PPU status to reset the high/low latch to high
    lda #$3F
    sta $2006
    lda #$10
    sta $2006

    ldy #$00 
load_palette_loop:
    lda (palette_ptr), y 
    sta $2007 ; write to PPU
    iny 
    cpy #palette_data_end-palette_data
    bne load_palette_loop 

    rts 


; this sub routine loads a level into NT1
; inputs:
;   level_ptr -> pointing to level data
;   x -> decides the start address based on nametable
load_level:
    lda $2002 ; read PPU status to reset the high/low latch

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
    bne @invalid_menu

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

@invalid_menu:
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
; with the player's currently active tile
; inputs:
;   player_x -> x position
;   player_y -> y position
;   sprite_data+1 -> the tile to place
; side effects:
;   updates level_data and nametable
;   changes registers and flags
update_tile:
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
    lda temp+1 ; write temp to ppu as start address
    sta $2006
    lda temp
    sta $2006 ; set up ppu for tile transfer

    lda sprite_data+1
    sta $2007 ; store in ppu
    ldy #$00 
    sta (level_ptr), y 

    ; restore level_ptr 
    pla 
    sta level_ptr+1
    pla 
    sta level_ptr

    lda #$00
    sta $2005 ; no horizontal scroll 
    sta $2005 ; no vertical scroll

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