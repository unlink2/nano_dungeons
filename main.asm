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
.define ATTR_SIZE 64 ; uncompressed attr size
.define PALETTE_SIZE 32 ; uncompressed palette size

.define EDITOR_MENU_MAX_SELECT 15
.define MAIN_MENU_MAX_SELECT 7

.define ATTRIBUTES $1
.define PALETTES $1

.define EDITOR_MENU_SAVE1 0
.define EDITOR_MENU_SAVE2 1
.define EDITOR_MENU_SAVE3 2
.define EDITOR_MENU_NEW 3
.define EDITOR_MENU_TILE 4
.define EDITOR_MENU_BACK 5
.define EDITOR_MENU_ATTR_1 6
.define EDITOR_MENU_COLOR 10
.define EDITOR_MENU_VALUE 11

.define MAIN_MENU_LEVEL 0 
.define MAIN_MENU_SLOT_1 1
.define MAIN_MENU_SLOT_2 2
.define MAIN_MENU_SLOT_3 3
.define MAIN_MENU_EDITOR 4

.enum $00
frame_count 1
nmi_flags 1 ; 0th bit = 1 -> loading, 1st bit = 1 -> nmi active, clear at end of nmi
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
attributes 1 ; colors used, index of address table
palette 1 ; selected palette
palette_ptr 2 ; pointer to current palette

src_ptr 2 ; source pointer for various subs
dest_ptr 2 ; destination pointer
.ende

; sprite memory
.enum $0200
sprite_data 4 ; all sprite data
sprite_data_1 4 ; sprite 2
sprite_data_2 4 ; sprite 3
sprite_data_3 4 ; sprite 4
sprite_data_4 4 ; sprite 5
sprite_data_5 4 ; sprite 6

sprite_data_6 4 ; sprite 7
sprite_data_7 4 ; sprite 8
sprite_data_8 4 ; sprite 9
sprite_data_9 4 ; sprite 10
sprite_data_A 4 ; sprite 11
sprite_data_pad 212 ; remainder, unused as of now
level_data LEVEL_SIZE ; copy of uncompressed level in ram, important this must always start at a page boundry
level_palette PALETTE_SIZE ; palette used by the currently loaded level, is copied whenever a level becomes active
player_x 1 ; tile location of player 
player_y 1 ; tile location of player
player_x_bac 1 ; backup location 
player_y_bac 1 ; backup location
attr_value 1 ; value used for attribute painting
level_select 1 ; value used to select a level
color_select 1 ; value for color to be edited
hex_buffer 2 ; buffer to convert hex number to be output on screen

smooth_up 1 ; smooht movement up
smooth_down 1 ; smooth movement down
smooth_left 1 ; smooth movement left 
smooth_right 1 ; smooth movement right
.ende

; start of prg ram
; which is used as sram in this case
; prg ram ends at $7FFF
; each save is the size of a LEVEL + 2 for the terminator
; this allows the user to store an entire screen without compression
; in thory 
; compression will still be applied however.
.enum $6000 
save_1 SAVE_SIZE ; saveslot 1
attr_1 ATTR_SIZE

save_2 SAVE_SIZE ; saveslot 2
attr_2 ATTR_SIZE

save_3 SAVE_SIZE ; saveslot 3
attr_3 ATTR_SIZE

palette_1 PALETTE_SIZE ; palette 1
palette_2 PALETTE_SIZE ; palette 2
palette_3 PALETTE_SIZE ; palette 3
.ende 

.macro vblank_wait
@.mi.vblank:
    bit $2002
    bpl @.mi.vblank
.endm

; this macro toggles the nmi enable flag
.macro set_nmi_flag 
    lda nmi_flags
    ora #%0000001
    sta nmi_flags
.endm 

.macro unset_nmi_flag
    lda nmi_flags
    and #%11111110
    sta nmi_flags
.endm 


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

    vblank_wait

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
    ; lda #$FE
    sta $0200, x    ;move all sprites off screen
    dex
    bne clear_mem
    

    vblank_wait

    ; set up palette pointer
    ldx #$00 
    stx palette
    ; ldx palette 
    lda palette_table_lo, x 
    sta palette_ptr 
    lda palette_table_hi, x 
    sta palette_ptr+1

    jsr load_palette

    ; set up game mode for editor for now
    lda #GAME_MODE_MENU 
    sta game_mode

    lda #$01 
    sta nametable

    ; load editor menu
    ldx #GAME_MODE_MENU
    jsr load_menu

    ; position editor sprite
    lda #$04
    sta player_x
    sta player_y

    jsr init_main_menu

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

    ldx attributes
    lda attr_table_lo, x 
    sta attr_ptr
    lda attr_table_hi, x
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
    ; store registers
    pha 
    txa 
    pha 
    tya 
    pha 

    lda nmi_flags 
    and #%00000010
    bne nmi_flag_set

    ; don't allow nmi until
    ; this one finishes
    ; nmi active flag
    lda nmi_flags 
    ora #%00000010
    sta nmi_flags

    jsr convert_tile_location

    ; apply smooth scrolling offsets
    jsr apply_smooth


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

    ; if load nmi flag is set skip normal updates until next frame
    lda nmi_flags
    and #%00000001
    bne update_done

    jsr adjust_smooth

    jmp (update_sub) ; jump to specific update sub routine
update_done: 
    ; always clear the nmi flag when 
    ; a normal nmi finishes
    unset_nmi_flag
    ; unset nmi active flag
    lda nmi_flags
    and #%11111101
    sta nmi_flags
nmi_flag_set:
    pla 
    tay 
    pla 
    txa 
    pla
    rti


.include "./utility.asm"
.include "./input.asm"
.include "./editor.asm"
.include "./mainmenu.asm"
.include "./game.asm"

.include "./map.asm"

palette_data:
.db $0F,$31,$32,$33,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F  ;background palette data
.db $0C,$1C,$15,$14,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C  ;sprite palette data
palette_data_end:

; compressed menu gfx
editor_menu_gfx:
.incbin "./graphics/editor.gfx"

main_menu_gfx:
.incbin "./graphics/mainmenu.gfx"

; x and y locations for cursor in editor menu
editor_menu_cursor_x:
.db $01 ; location save 1
.db $01 ; save 2
.db $01 ; save 3
.db $01 ; new 
.db $01 ; tile select
.db $01 ; back 
.db $0C  ; color top left
.db $0C  ; color bottom left
.db $12  ; color top right
.db $12  ; color bottom right
.db $0C ; color palette select
.db $0C ; color select

editor_menu_cursor_y:
.db $09
.db $0A
.db $0B
.db $0D
.db $0F
.db $11
.db $05
.db $07
.db $05 
.db $07
.db $0A
.db $0C

editor_menu_cursor_attr:
.db $00
.db $00
.db $00
.db $00
.db $00
.db $00
.db $00
.db $00
.db %01000000
.db %01000000
.db $00 
.db $00

; same as editor menu tables
main_menu_cursor_x:
.db $01 ; level select
.db $01 ; slot 1
.db $01 ; slot 2
.db $01 ; slot 3
.db $01 ; edit menu

main_menu_cursor_y:
.db $08
.db $0A
.db $0B
.db $0C
.db $0E

main_menu_cursor_attr:
.db $00
.db $00
.db $00
.db $00 
.db $00

; an empty map
; $24 being an empty tile (bg only)
empty_map:
.db $FF, $FF, $24
.db $FF, $FF, $24
.db $FF, $FF, $24
.db $FF, $C3, $24
.db $FF, $00

test_attr:
.mrep 64
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

; lokup table to convert a tile location to attribute location
attr_convert_table:
.mrep 16
.db (.ri.*4)
.db (.ri.*4)
.db (.ri.*4)
.db (.ri.*4)
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

; lookup talbe for attribute updates
; same as tile update table
attr_update_table_y:
.mrep 8
.db (.ri.*8)
.db (.ri.*8)
.db (.ri.*8)
.db (.ri.*8)
.endrep 

attr_update_table_x:
.mrep 8
.db (.ri.)
.db (.ri.)
.db (.ri.)
.db (.ri.)
.endrep 

; table of pointers to map entries
map_table_lo:
.db #<empty_map
.db #<editor_menu_gfx
.db #<main_menu_gfx

map_table_hi:
.db #>empty_map
.db #>editor_menu_gfx
.db #>main_menu_gfx

; color attribute lookup table
attr_table_lo:
.db #<test_attr
.db #<test_attr
.db #<test_attr

attr_table_hi:
.db #>test_attr
.db #>test_attr
.db #>test_attr

; color palette table
palette_table_lo:
.db #<palette_data
.db #<palette_data
.db #<palette_data
palette_table_hi:
.db #>palette_data
.db #>palette_data 
.db #>palette_data

; player animation frames for each direction
player_animation_right:
.db $32 ; idle 
.db $32 ; idle 
.db $35 
.db $34 
.db $33 
.db $33 
.db $34
.db $35
.db $35 ; rotation start again

player_attr_right:
.db %00000000 
.db %00000000
.db %00000000
.db %00000000
.db %01000000
.db %01000000
.db %01000000
.db %01000000
.db %01000000

player_animation_left:
.db $32 ; idle 
.db $32 ; idle 
.db $35 
.db $34 
.db $33 
.db $33 
.db $34
.db $35
.db $35 ; rotation start again

player_attr_left:
.db %01000000 
.db %01000000
.db %01000000
.db %01000000
.db %00000000
.db %00000000
.db %00000000
.db %00000000
.db %00000000

player_animation_up:
.db $32 ; idle 
.db $32 ; idle 
.db $35 
.db $34 
.db $33 
.db $33 
.db $34
.db $35
.db $35 ; rotation start again

player_attr_up:
.db %00000000 
.db %00000000
.db %00000000
.db %00000000
.db %01000000
.db %01000000
.db %01000000
.db %01000000
.db %01000000

player_animation_down:
.db $32 ; idle 
.db $32 ; idle 
.db $35 
.db $34 
.db $33 
.db $33 
.db $34
.db $35
.db $35 ; rotation start again

player_attr_down:
.db %00000000 
.db %00000000
.db %00000000
.db %00000000
.db %01000000
.db %01000000
.db %01000000
.db %01000000
.db %01000000


.pad $FFFA
.dw nmi ; nmi
.dw init ; reset 
.dw init ; irq

; chr bank 8k
.base $0000
.incbin "./graphics/gfx.chr" ; exported memory dump from mesen
