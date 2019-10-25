; header
.db $4E, $45, $53, $1A, ; NES + MS-DOS EOF
.db $01 ; prg rom size in 16kb 
.db $01 ; chr rom in 8k bits
.db $03 ; mapper 0 contains sram at $6000-$7FFF
.db $00 ; mirroring
.db $00 ; no prg ram 
.db $00, $00, $00, $00, $00, $00, $00 ; rest is unused 

.define MOVE_DELAY_FRAMES 10
.define GAME_MODE_MENU 0
.define GAME_MODE_PUZZLE 1
.define GAME_MODE_EDITOR 2
.define GAME_MODE_EDITOR_MENU 3

.define LEVEL_SIZE 960 ; uncompressed level size
.define SAVE_SIZE LEVEL_SIZE+2 ; savegame size
.define ATTR_SIZE 60 ; uncompressed attr size

.define EDITOR_MENU_MAX_SELECT 3

.enum $00
frame_count 1
rand8 1
game_mode 1
move_delay 1 ; delay between move inputs
select_delay 1 ; same as move delay, but prevnets inputs for selection keys such as select

level_ptr 2 ; points to the current level in ram
level_data_ptr 2 ; pointer to rom/sram of level
attr_ptr 2 ; points to the attributes for the current level
level_ptr_temp 2 ; 16 bit loop index for level loading or memcpy
temp 4 ; 4 bytes of universal temporary storage
nametable 1 ; either 0 or 1 depending on which nametable is active
menu_select 1 ; cursor location in menu
update_sub 2 ; ptr to sub routine called for updates, must jmp to update_done label when finished
.end 

; sprite memory
.enum $0200
sprite_data 4 ; all sprite data
sprite_data_1 4 ; sprite 2
sprite_data_pad 248 ; remainder, unused as of now
level_data LEVEL_SIZE ; copy of uncompressed level in ram, important this must always start at a page boundry
player_x 1 ; tile location of player 
player_y 1 ; tile location of player
player_x_bac 1 ; backup location 
player_y_bac 1 ; backup location
.end 

; start of prg ram
; which is used as sram in this case
; prg ram ends at $7FFF
; each save is the size of a LEVEL + 2 for the terminator
; this allows the user to store an entire screen without compression
; in thory 
; compression will still be applied however.
.enum $6000 
save_1 SAVE_SIZE ; saveslot 1
save_2 SAVE_SIZE ; saveslot 2
save_3 SAVE_SIZE ; saveslot 3
.end 

.macro @vblank_wait
@vblank:
    bit $2002
    bpl @vblank
.end

.org $C000 ; start of program
init:
    sei ; disable interrupts 
    cld ; disable decimal mode
    ldx #$40
    stx $4017 ; disable APU frame IRQ
    ldx #$FF
    txs ; Set up stack
    inx ; now X = 0
    stx $2000 ; disable NMI
    stx $2001 ; disable rendering
    stx $4010 ; disable DMC IRQs

    @vblank_wait

    ldx #$FF
clear_mem:
    lda #$00
    sta $0000, x
    sta $0100, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    lda #$FE
    sta $0200, x    ;move all sprites off screen
    inx
    bne clear_mem
    

    @vblank_wait

load_palette:
    ; sets up ppu for palette transfer
    lda $2002 ; read PPU status to reset the high/low latch to high
    lda #$3F
    sta $2006
    lda #$10
    sta $2006

    ldx #$00 
load_palette_loop:
    lda palette_data, x 
    sta $2007 ; write to PPU
    inx 
    cpx #palette_data_end-palette_data
    bne load_palette_loop 

    ; set up game mode for editor for now
    lda #GAME_MODE_EDITOR_MENU 
    sta game_mode

    lda #$01 
    sta nametable

    ; load editor menu
    ldx #GAME_MODE_EDITOR_MENU
    jsr load_menu

    jsr init_editor_menu

    ; set up empty
    lda #<empty_map
    sta level_data_ptr
    lda #>empty_map
    sta level_data_ptr+1

    lda #<level_data 
    sta level_ptr 
    lda #>level_data 
    sta level_ptr+1

    jsr decompress_level


    lda #<test_attr
    sta attr_ptr
    lda #>test_attr
    sta attr_ptr+1

    ldx #$00 ; nametable 0
    jsr load_level
    jsr load_attr

    ; set up game mode for editor testing
    lda GAME_MODE_EDITOR
    sta game_mode

start:
    lda #%10000000   ; enable NMI, sprites from Pattern Table 0
    sta $2000

    lda #%00011110   ; enable sprites
    sta $2001

main_loop:
    jmp main_loop

nmi: 
    jsr convert_tile_location

    inc frame_count
    ldx move_delay
    beq @skip_move_delay
    dec move_delay
@skip_move_delay:

    lda select_delay
    beq @skip_select_delay 
    dec select_delay
@skip_select_delay:

    bit $2002 ; read ppu status to reset latch

    ; sprite DMA
    lda #<sprite_data
    sta $2003  ; set the low byte (00) of the RAM address
    lda #$>sprite_data
    sta $4014  ; set the high byte (02) of the RAM address, start the transfer

    lda #$00
    sta $2005 ; no horizontal scroll 
    sta $2005 ; no vertical scroll
    
    ; inputs
    jsr input_handler

    lda #%10000000   ; enable NMI, sprites from Pattern Table 0
    ora nametable
    sta $2000

    lda #%00011110   ; enable sprites
    sta $2001

    jmp (update_sub) ; jump to specific update sub routine
update_done: rti 

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
    rts 

; handles all inputs
input_handler:
    ; reset latch
    lda #$01 
    sta $4016
    lda #$00 
    sta $4016 ; both controllers are latching now

    lda $4016 ; p1 - A
    and #%00000001 
    beq @no_a
    jsr a_input
@no_a:

    lda $4016 ; p1 - B
    and #%00000001
    beq @no_b
    jsr b_input
@no_b:

    lda $4016 ; p1 - select
    and #%00000001
    beq @no_select
    jsr select_input
@no_select:

    lda $4016 ; p1 - start
    and #%00000001
    beq @no_start 
    jsr start_input
@no_start:

    lda $4016 ; p1 - up
    and #%0000001
    beq @no_up
    jsr go_up
@no_up:

    lda $4016 ; p1 - down
    and #%00000001
    beq @no_down 
    jsr go_down
@no_down:

    lda $4016 ; p1 - left
    and #%00000001
    beq @no_left 
    jsr go_left
@no_left:

    lda $4016 ; p1 - right 
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
    bne @done

    ; set up the right pointers for data write
    ; save slot is based on menu select
    lda menu_select
    cmp #$02 
    bne @not_slot3
    lda #<save_3
    sta level_data_ptr
    lda #>save_3
    sta level_data_ptr+1
    jmp @slot_slected
@not_slot3:

    cmp #$01 
    bne @not_slot2

    lda #<save_2
    sta level_data_ptr
    lda #>save_2
    sta level_data_ptr+1
    jmp @slot_slected
@not_slot2:

    ; always pick slot 1 as default option
    lda #<save_1
    sta level_data_ptr
    lda #>save_1
    sta level_data_ptr+1
@slot_slected:
    lda #<level_data 
    sta level_ptr 
    lda #>level_data 
    sta level_ptr+1

    ; disable NMI, don't change other flags
    ; NMI needs to be disabled 
    ; to prevent it being called again
    ; while compression is ongoing
    lda $2000
    and #%01111111
    ora nametable ; display the correct nametable to avoid flickering
    sta $2000
    jsr compress_level
    ;lda $2000
    ;ora #%10000000
    ;sta $2000 ; enable NMI again
@done: 
    rts

; b button input 
; b loads a map in editor menu
b_input:
    lda game_mode
    cmp #GAME_MODE_EDITOR_MENU
    bne @not_editor_menu

    lda menu_select
    cmp #$03
    bne @not_new_map


    lda #<empty_map
    sta level_data_ptr
    lda #>empty_map
    sta level_data_ptr+1
    jmp @slot_selected
@not_new_map:    

    cmp #$01
    bne @not_slot2

    lda #<save_2
    sta level_data_ptr
    lda #>save_2
    sta level_data_ptr+1
    jmp @slot_selected
@not_slot2:

    cmp #$02
    bne @not_slot3

    lda #<save_3
    sta level_data_ptr
    lda #>save_3
    sta level_data_ptr+1
    jmp @slot_selected
    ; set up for load
@not_slot3:
    ; otherwise it is slot 1
    lda #<save_1
    sta level_data_ptr
    lda #>save_1
    sta level_data_ptr+1
@slot_selected:
    ldx #$00
    stx $2001 ; disable rendering

    lda #<level_data 
    sta level_ptr 
    lda #>level_data 
    sta level_ptr+1

    ; disable NMI until load is complete
    lda $2000
    and #%01111111
    ora nametable ; display the correct nametable to avoid flickering
    sta $2000

    jsr decompress_level

    lda #<test_attr
    sta attr_ptr
    lda #>test_attr
    sta attr_ptr+1

    ldx $00 ; nametable 0
    jsr load_level

    lda #GAME_MODE_EDITOR
    sta game_mode
    jsr init_editor
    lda #$00
    sta nametable

@not_editor_menu:
@done:
    rts 

; select button input
; select changes the players sprite index 
; this is only temporary
select_input:
    jsr can_select
    bne @done
    lda game_mode
    cmp #GAME_MODE_EDITOR 
    bne @done

    lda #MOVE_DELAY_FRAMES
    sta select_delay
    ; change sprite 0s sprite index
    inc sprite_data+1
@done: 
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
    ; swap to menu and nametable 1
    lda #GAME_MODE_EDITOR_MENU
    sta game_mode
    lda #$01
    sta nametable

    jsr init_editor_menu

    rts 
@not_editor:
    cmp #GAME_MODE_EDITOR_MENU
    bne @not_editor_menu
    ; sawp to editor mode and nt 0
    lda #GAME_MODE_EDITOR
    sta game_mode
    lda #$00 
    sta nametable

    jsr init_editor

    rts 
@not_editor_menu:
    cmp GAME_MODE_PUZZLE
    bne @not_puzzle
@not_puzzle:
@done:
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

    lda #$00
    cmp player_x ; dont allow underflow 
    beq @no_dec

    dec player_x
@no_dec:
    rts 
@not_editor:
    cmp #GAME_MODE_EDITOR_MENU
    bne @not_editor_menu
    ; if in editor menu we decrement tile id
    dec sprite_data_1+1
@not_editor_menu
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

    lda #$1F
    cmp player_x ; dont allow overflow 
    beq @no_inc

    inc player_x
@no_inc:
    rts 
@not_editor:
    cmp #GAME_MODE_EDITOR_MENU
    bne @not_editor_menu
    ; if in editor menu we increment tile id
    inc sprite_data_1+1
@not_editor_menu
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

    lda #$00
    cmp player_y ; dont allow underflow 
    beq @no_dec

    dec player_y
@no_dec:
    rts 

@not_editor:
    cmp #GAME_MODE_EDITOR_MENU
    bne @not_editor_menu

    dec menu_select
@not_editor_menu:
@done:
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

    lda #$1D
    cmp player_y ; dont allow overflow 
    beq @no_inc 

    inc player_y
@no_inc:
    rts 
@not_editor:
    cmp #GAME_MODE_EDITOR_MENU
    bne @not_editor_menu

    inc menu_select
@not_editor_menu:
@done: 
    rts 


init_editor_menu:
    ; backup player's location and
    ; move to cursor position
    lda player_x 
    sta player_x_bac
    lda player_y
    sta player_y_bac

    lda #$01 
    sta player_x
    lda #$09 
    sta player_y

    ; more sprite 1 to tile select location
    lda #$37
    sta sprite_data_1
    lda #$38
    sta sprite_data_1+3

    ; set the tile select's tile index
    lda sprite_data+1 
    sta sprite_data_1+1

    lda #<update_editor_menu
    sta update_sub
    lda #>update_editor_menu
    sta update_sub+1

    rts 

init_editor:
    ; restore player's location
    lda player_x_bac
    sta player_x
    lda player_y_bac
    sta player_y

    ; set the tile select's tile index
    lda sprite_data_1+1 
    sta sprite_data+1

    ; hide other sprite offscreen
    lda #$00 
    sta sprite_data_1
    sta sprite_data_1+3

    lda #<update_editor
    sta update_sub
    lda #>update_editor
    sta update_sub+1

    rts 

; update sub routine for editor menu
update_editor_menu:
    lda menu_select
    and #EDITOR_MENU_MAX_SELECT ; only 3 possible options
    sta menu_select

    ; set sprite at correct position 
    lda #$09 
    clc 
    adc menu_select
    sta player_y

    ; if menu select is at 3 we inc once more to get the desired value
    ; for the correct offset to display 'new'
    lda menu_select
    cmp #EDITOR_MENU_MAX_SELECT 
    bne @done
    inc player_y
@done:
    jmp update_done

; update sub routne for editor
update_editor:
    jmp update_done


.include "./map.asm"

palette_data:
.db $0F,$31,$32,$33,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F  ;background palette data
.db $0F,$1C,$15,$14,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C  ;sprite palette data
palette_data_end:

; compressed menu gfx
editor_menu_gfx:
.db $FF, $41, $24, $0E, $0D, $12, $1D, $24, $16, $0E, $17, 
.db $1E, $FF, $98, $24, $1D, $12, $15, $0E, $FF, $3C, $24, 
.db $1C, $15, $18, $1D, $01, $FF, $1B, $24, $1C, $15, $18, 
.db $1D, $02, $FF, $1B, $24, $1C, $15, $18, $1D, $03, $FF, 
.db $3B, $24, $17, $0E, $20, $FF, $3D, $24, $0A, $24, $1D, 
.db $18, $24, $1C, $0A, $1F, $0E, $FF, $17, $24, $0B, $24, 
.db $1D, $18, $24, $15, $18, $0A, $0D, $FF, $FF, $24, $FF, 
.db $B6, $24, $FF, $00

; an empty map
; $24 being an empty tile (bg only)
empty_map:
.db $FF, $FF, $24
.db $FF, $FF, $24
.db $FF, $FF, $24
.db $FF, $C3, $24
.db $FF, $00

test_attr:
.mrep 60
.db 0
.endrep

; test decompress data
test_decompress:
.db $01, $02, $02, $03, $FF, $09, $FA, $FF, $FF, $01, $FF, $FF, $01, $FF, $FF, $03, $FF, $B6, $04, $FF, $00

; lookup table of all possible tile conversion positions
tile_convert_table:
.mrep $FF
.db (.ri.*8)
.endrep

; lookup table of the low byte 
; for ppu updates for all possible player positions
; this is for every possible y position
tile_update_table_lo:
.mrep 32 
.db <(.ri.)*32
.endrep 

; counts the amounts of carrys that occur 
; when calculating the tile's address
tile_update_table_hi:
.mrep 32 
.db >((.ri.)*32)
.endrep

.pad $FFFA
.dw nmi ; nmi
.dw init ; reset 
.dw init ; irq

; chr bank 8k
.base $0000
.incbin "./gfx.chr" ; exported memory dump from mesen
