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
.define GAME_MODE_MESSAGE 4

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

; start and end of non-collision tiles
.define START_TILE $60
.define CLEARABLE_TILES_START $60
.define CLEARABLE_TILES_END $7f
.define CLEARABLE_MIRROR_START $E0 
.define CLEARABLE_MIRROR_END $FF

.define ERROR_NO_START_TILE 1

.define SPRITE_TILES 8
.define SPRITE_TILES_START $70
.define SPRITE_TILES_END $72
.define AI_SPRITES_START 16 ; sprites that may be used for AI

.define SPACE_TILE $24 ; space tile index, required for editor

; tile select bounds
.define TILE_SELECT_MIN_X $17
.define TILE_SELECT_MAX_X $1D
.define TILE_SELECT_MIN_Y $05
.define TILE_SELECT_MAX_Y $17

.enum $00
frame_count 1
; 7th bit = 1 -> loading; 6th bit = 1 -> nmi active, clear at end of nmi, 5th bit = 1 -> disable inputs
nmi_flags 1
; 7th bit = 1 -> switch disabled, barries can be passed, 6th bit = 1 -> sprite update enabled
game_flags 1
; 7th bit = 1 -> barrier disabled, 6th bit = 1 -> no collision (may not always be observed),
map_flags 1
; editor flags, mostly used for menu select
; 7th bit = 1 -> tile select mode, = 0 -> menu mode
editor_flags 1 

errno 1 ; error number, nonzero values are errors

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

; ptr to sub routine called for timing critical updates such as ppu updates, is called right at start of nmi
; must be short.
; must jump to update_crti_done when finished
update_sub_crit 2
update_sub 2 ; ptr to sub routine called for updates, must jmp to update_done label when finished
attributes 1 ; colors used, index of address table
palette 1 ; selected palette
palette_ptr 2 ; pointer to current palette

src_ptr 2 ; source pointer for various subs
dest_ptr 2 ; destination pointer

; thse pointers are incremented every time the timer reached 0
; as long as the next timer value is not already 0
pulse_ptr_1 2 ; audio data for pulse 1
pulse_ptr_2 2 ; audio data for pulse 2
triangle_ptr 2 ; audio data for triangle 2
noise_ptr 2 ; audio data for noise

; timers dec every frame, when 0 is reached they will
; reset to their respective periode
; and load the next note to play
pulse_timer_1 1 ; timer pulse 1
pulse_timer_2 1 ; timer pulse 2
triangle_timer 1 ; triangle timer
noise_timer 1 ; noise timer

; the periode is used as a base value for each of the timers
pulse_periode_1 1 ; timer periode
pulse_periode_2 1 ; timer periode
triangle_periode 1 ; triangle timer
noise_periode 1 ; noise periode

sprite_ptr 2 ; may be used as a pointer to sprite oam

delay_update 2 ; function pointer for update animation, set to 00, 00 to disable
delay_done 2 ; function pointer to be called when animation finishes, set to 00, 00 to disable

last_inputs 1 ; inputs of controller 1

; 16 bit count of tiles that have to be cleared, when both are $00 map is won
; this is populated during decompression of a map
tiles_to_clear 2 
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

start_x 1 ; x and y value of start location
start_y 1 ; values are populated during decompression

attr_value 1 ; value used for attribute painting
level_select 1 ; value used to select a level
color_select 1 ; value for color to be edited
hex_buffer 2 ; buffer to convert hex number to be output on screen

smooth_up 1 ; smooht movement up
smooth_down 1 ; smooth movement down
smooth_left 1 ; smooth movement left
smooth_right 1 ; smooth movement right
delay_timer 2 ; frames of animation, 16 bit integer

collision_data 2 ; temporary data used by collision routines

sprite_tile_x SPRITE_TILES ; 32 slots for sprite tiles, x and y position in one
sprite_tile_y  SPRITE_TILES ; y position
sprite_tile_ai SPRITE_TILES ; ai type
sprite_tile_data SPRITE_TILES ; data for sprite may be used by AI as needed
; flags for each sprite
; 7th bit = 1 -> sprite enabled, collision will occur
sprite_tile_flags SPRITE_TILES
sprite_tile_obj SPRITE_TILES ; object to be used for this sprite, may be set up as needed
sprite_tile_size 1 ; amount of tiles currently used
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

    ; set up hi byte sprite_ptr
    lda #$02
    sta sprite_ptr+1

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

    jsr init_audio_channels

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
    beq nmi_flag_not_set
    jmp nmi_flag_set
nmi_flag_not_set:
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

    ; update animation just before dma
    jsr update_delay
    cmp #$01
    bne @delay_not_finished
    jmp update_done
@delay_not_finished:

    ; inputs
    jsr input_handler

    ; if load nmi flag is set skip normal updates until next frame
    lda nmi_flags
    and #%00000001
    bne update_crit_done

    jmp (update_sub_crit)

update_crit_done:

    bit $2002 ; read ppu status to reset latch

    ; sprite DMA
    lda #<sprite_data
    sta $2003  ; set the low byte (00) of the RAM address
    lda #$>sprite_data
    sta $4014  ; set the high byte (02) of the RAM address, start the transfer

    lda #$00
    sta $2005 ; no horizontal scroll
    sta $2005 ; no vertical scroll

    ; error handler
    ldx errno
    beq @no_error
    lda error_lo, x
    sta src_ptr
    lda error_hi, x
    sta src_ptr+1
    jsr jsr_indirect

    lda #$00
    sta errno
    jmp update_done
@no_error:

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

    jsr update_sprites

    jmp (update_sub) ; jump to specific update sub routine

    ; all updates after this should not require ppu access
    ; since by now vblank time is likely over
update_done:
    ; always clear the nmi flag when
    ; a normal nmi finishes
    unset_nmi_flag
    ; unset nmi active flag
    lda nmi_flags
    and #%11111101
    sta nmi_flags
nmi_flag_set:
    ; no matter what we always update
    ; audio
    jsr update_audio

    pla
    tay
    pla
    tax
    pla
    rti

; this may be called by
; the APU on the last tick of $4017
irq:
    pha
    txa
    pha
    tya
    pha 

    pla
    tay
    pla
    tax
    pla

    rti 

.include "./utility.asm"
.include "./input.asm"
.include "./editor.asm"
.include "./mainmenu.asm"
.include "./game.asm"

.include "./map.asm"
.include "./tiles.asm"
.include "./delay.asm"
.include "./sprites.asm"
.include "./audio.asm"

palette_data:
.db $0F,$20,$2D,$33,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F  ;background palette data
.db $0C,$20,$2D,$14,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C  ;sprite palette data
palette_data_end:

; compressed menu gfx
editor_menu_gfx:
.incbin "./graphics/editor.gfx"

main_menu_gfx:
.incbin "./graphics/mainmenu.gfx"

win_gfx:
.incbin "./graphics/win.gfx"
win_attr:
.incbin "./graphics/win.attr"
win_pal:
.incbin "./graphics/win.pal"

no_start_msg_gfx:
.incbin "./graphics/no_start_msg.gfx"

; include all levels
level_1_gfx:
.incbin "./graphics/level_1.gfx"
level_1_attr:
.incbin "./graphics/level_1.attr"
level_1_pal:
.incbin "./graphics/level_1.pal"

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
.db #<win_gfx
.db #<no_start_msg_gfx
.db #<level_1_gfx

map_table_hi:
.db #>empty_map
.db #>editor_menu_gfx
.db #>main_menu_gfx
.db #>win_gfx
.db #>no_start_msg_gfx
.db #>level_1_gfx

; color attribute lookup table
attr_table_lo:
.db #<test_attr
.db #<test_attr
.db #<test_attr
.db #<win_attr
.db #<test_attr
.db #<level_1_attr

attr_table_hi:
.db #>test_attr
.db #>test_attr
.db #>test_attr
.db #>win_attr
.db #>test_attr
.db #>level_1_attr

; color palette table
palette_table_lo:
.db #<palette_data
.db #<palette_data
.db #<palette_data
.db #<win_pal
.db #<palette_data
.db #<level_1_pal

palette_table_hi:
.db #>palette_data
.db #>palette_data
.db #>palette_data
.db #>win_pal
.db #>palette_data
.db #>level_1_pal

; player animation frames for each direction
player_animation_right:
.db $32 ; idle
.db $32 ; idle
.db $35
.db $36
.db $34
.db $33
.db $34
.db $36
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

; sub routine for tiles, based on tile index
tile_sub_lo:
.mrep CLEARABLE_TILES_START-4
.db #<collision
.endrep

.db #<jump_right ; left jump tile
.db #<jump_up ; up jump tile 
.db #<jump_down ; down jump tile 
.db #<jump_left ; right jump tile

.db #<no_collision ; start tile 
.db #<no_collision ; end tile
.db #<no_collision ; floor tile 1
.db #<no_collision ; floor tile 2
.db #<one_way_right ; right one way
.db #<one_way_up ; up one way
.db #<one_way_down ; down one way
.db #<one_way_left ; left one way

.db #<no_collision
.db #<no_collision
.db #<no_collision
.db #<no_collision ; unused as of now

.db #<barrier_switch ; barrier switch tile
.db #<no_collision
.db #<no_collision
.db #<no_collision ; some as of now unused tiles

.db #<barrier_tile ; barrier tile
.db #<barrier_tile_invert ; inverted barrier

; remainder of clearable tiles
.mrep CLEARABLE_MIRROR_START-CLEARABLE_TILES_START+18
.db #<no_collision
.endrep

; mirror tiles
.db #<no_collision ; start tile
.db #<no_collision ; end tile
.db #<no_collision ; floor tile 1
.db #<no_collision ; floor tile 2
.db #<one_way_left ; right one way
.db #<one_way_down ; up one way
.db #<one_way_up ; down one way
.db #<one_way_right ; left one way

.db #<no_collision
.db #<no_collision
.db #<no_collision
.db #<no_collision ; unused as of now

.db #<barrier_switch ; barrier switch tile
.db #<no_collision
.db #<no_collision
.db #<no_collision ; some as of now unused tiles

.db #<barrier_tile ; barrier tile
.db #<barrier_tile_invert ; inverted barrier

tile_sub_hi:
.mrep CLEARABLE_TILES_START-4
.db #>collision
.endrep

.db #>jump_right ; left jump tile
.db #>jump_up ; up jump tile
.db #>jump_down ; down jump tile
.db #>jump_left ; right jump tile

.db #>no_collision ; start tile
.db #>no_collision ; end tile
.db #>no_collision ; floor tile 1
.db #>no_collision ; floor tile 2
.db #>one_way_right ; right one way
.db #>one_way_up ; up one way
.db #>one_way_down ; down one way
.db #>one_way_left ; left one way

.db #>no_collision
.db #>no_collision
.db #>no_collision
.db #>no_collision ; unused as of now

.db #>barrier_switch ; barrier switch tile
.db #>no_collision
.db #>no_collision
.db #>no_collision ; some as of now unused tiles

.db #>barrier_tile ; barrier tile
.db #>barrier_tile_invert ; inverted barrier

; remainder of clearable tiles
.mrep CLEARABLE_MIRROR_START-CLEARABLE_TILES_START+18
.db #>no_collision
.endrep

; mirror tiles
.db #>no_collision ; start tile
.db #>no_collision ; end tile
.db #>no_collision ; floor tile 1
.db #>no_collision ; floor tile 2
.db #>one_way_left ; right one way
.db #>one_way_down ; up one way
.db #>one_way_up ; down one way
.db #>one_way_right ; left one way

.db #>no_collision
.db #>no_collision
.db #>no_collision
.db #>no_collision ; unused as of now

.db #>barrier_switch ; barrier switch tile
.db #>no_collision
.db #>no_collision
.db #>no_collision ; some as of now unused tiles

.db #>barrier_tile ; barrier tile
.db #>barrier_tile_invert ; inverted barrier

; error handlers
error_lo:
.db $00
.db #<load_map_start_error

error_hi:
.db $00
.db #>load_map_start_error

sprite_init_lo:
.db #<sprite_init_default
.db #<sprite_init_default

sprite_init_hi:
.db #>sprite_init_default
.db #>sprite_init_default

sprite_ai_lo:
.db #<sprite_update_default
.db #<sprite_update_barrier_invert

sprite_ai_hi:
.db #>sprite_update_default
.db #>sprite_update_barrier_invert

; converts object index to an address, only the lo byte is given, hi is always $02
obj_index_to_addr:
.mrep 64
.db .ri.*4
.endrep

; audio stuff

; timer value is FF therefore no audio will play
no_audio:
.db $FF

cursor_beep:
.db #%10011111, $0F, $00, $00, $FF

cursor_noise:
.db #%00011111, #%00000101, #%0011000, $FF

jump_noise:
.db #%00011111, #%00000111, #%0010000, $FF

; NTSC period table generated by mktables.py
period_table_lo:
.db $f1,$7f,$13,$ad,$4d,$f3,$9d,$4c,$00,$b8,$74,$34
.db $f8,$bf,$89,$56,$26,$f9,$ce,$a6,$80,$5c,$3a,$1a
.db $fb,$df,$c4,$ab,$93,$7c,$67,$52,$3f,$2d,$1c,$0c
.db $fd,$ef,$e1,$d5,$c9,$bd,$b3,$a9,$9f,$96,$8e,$86
.db $7e,$77,$70,$6a,$64,$5e,$59,$54,$4f,$4b,$46,$42
.db $3f,$3b,$38,$34,$31,$2f,$2c,$29,$27,$25,$23,$21
.db $1f,$1d,$1b,$1a,$18,$17,$15,$14

period_table_hi:
.db $07,$07,$07,$06,$06,$05,$05,$05,$05,$04,$04,$04
.db $03,$03,$03,$03,$03,$02,$02,$02,$02,$02,$02,$02
.db $01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01,$01
.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
.db $00,$00,$00,$00,$00,$00,$00,$00


.pad $FFFA
.dw nmi ; nmi
.dw init ; reset 
.dw irq ; irq

; chr bank 8k
.base $0000
.incbin "./graphics/gfx.chr" ; exported memory dump from mesen
