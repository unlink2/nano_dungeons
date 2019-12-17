; header
.db $4E, $45, $53, $1A, ; NES + MS-DOS EOF
.db $01 ; prg rom size in 16kb 
.db $01 ; chr rom in 8k bits
.db $03 ; mapper 0 contains sram at $6000-$7FFF
.db $00 ; mirroring
.db $00 ; no prg ram 
.db $00, $00, $00, $00, $00, $00, $00 ; rest is unused 

.include "charmap.asm"

.define MOVE_DELAY_FRAMES 10
.define GAME_MODE_MENU 0
.define GAME_MODE_PUZZLE 1
.define GAME_MODE_EDITOR 2
.define GAME_MODE_EDITOR_MENU 3
.define GAME_MODE_MESSAGE 4
.define GAME_MODE_TITLE 5

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
.define EDITOR_MENU_BANK 12
.define EDITOR_MENU_ADDR 13
.define EDITOR_MENU_MEMVALUE 14

.define MAIN_MENU_LEVEL 0 
.define MAIN_MENU_SLOT_1 1
.define MAIN_MENU_SLOT_2 2
.define MAIN_MENU_SLOT_3 3
.define MAIN_MENU_EDITOR 4

.define MAX_HP $02

; start and end of non-collision tiles
.define START_TILE $60
.define CLEARABLE_TILES_START $60
.define CLEARABLE_TILES_END $7f
.define CLEARABLE_MIRROR_START $E0 
.define CLEARABLE_MIRROR_END $FF

.define ERROR_NO_START_TILE 1

.define SPRITE_TILES 32
.define SPRITE_TILES_START $70
.define SPRITE_TILES_END $7B
.define AI_SPRITES_START 16 ; sprites that may be used for AI


.define SPACE_TILE $24 ; space tile index, required for editor

; tile select bounds
.define TILE_SELECT_MIN_X $17
.define TILE_SELECT_MAX_X $1D
.define TILE_SELECT_MIN_Y $05
.define TILE_SELECT_MAX_Y $17

.define ACTIONS_PER_TURN $01 ; actions per turn, default value

.define LEFT $00
.define UP $01
.define RIGHT $02
.define DOWN $03

.define VISIBILITY_RADIUS $03 ; raiduis for in-game map loading

.enum $00
frame_count 1
; 7th bit = 1 -> loading; 6th bit = 1 -> nmi active, clear at end of nmi, 5th bit = 1 -> disable inputs
nmi_flags 1
; 7th bit = 1 -> switch disabled, barries can be passed, 6th bit = 1 -> sprite update enabled
; 0th bit = 1 -> collision check failed
game_flags 1
; 7th bit = 1 -> barrier disabled, 6th bit = 1 -> no collision (may not always be observed),
map_flags 1
; 6th bit = 1 -> enable low visibility mode in gameplay
load_flags 1
key_count 1 ; amount of keys collected
; editor flags, mostly used for menu select
; 7th bit = 1 -> tile select mode, = 0 -> menu mode
editor_flags 1

; 5th bit = 1 -> sprite pattent table
; 4th bit = 1 -> bg pattern table
gfx_flags 1

errno 1 ; error number, nonzero values are errors

rand8 1
game_mode 1
move_delay 1 ; delay between move inputs
select_delay 1 ; same as move delay, but prevnets inputs for selection keys such as select
actions 1 ; player's action until "turn" ends. Turn is considered ended when this has a non-zero value

level_ptr 2 ; points to the current level in ram
level_data_ptr 2 ; pointer to rom/sram of level
attr_ptr 2 ; points to the attributes for the current level
map_sub_ptr 2 ; pointing to an update routine for levels, if FFFF -> ignore. only runs duinrg gameplay
level_ptr_temp 2 ; 16 bit loop index for level loading or memcpy
temp 4 ; 4 bytes of universal temporary storage
nametable 1 ; either 0 or 1 depending on which nametable is active
menu_select 1 ; cursor location in menu

collision_counter 1 ; counts amount of sprite collisions in a frame

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

; sweep settings for pulse channels
pulse_sweep_1 1
pulse_sweep_2 1

sprite_ptr 2 ; may be used as a pointer to sprite oam

delay_update 2 ; function pointer for update animation, set to 00, 00 to disable
delay_done 2 ; function pointer to be called when animation finishes, set to 00, 00 to disable

last_inputs 1 ; inputs of controller 1

; 16 bit count of tiles that have to be cleared, when both are $00 map is won
; this is populated during decompression of a map
tiles_to_clear 2

; x and y coordinates for get_tile
get_tile_x 1
get_tile_y 1
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
sprite_data_B 4 ; sprite 12

sprite_data_C 4 ; sprite 13
sprite_data_D 4 ; sprite 14
sprite_data_E 4 ; sprite 15
sprite_data_F 4 ; sprite 16
sprite_data_10 4 ;sprtie 17
sprite_data_11 4 ; sprite 18

sprite_data_pad 184 ; remainder, unused as of now
level_data LEVEL_SIZE ; copy of uncompressed level in ram, important this must always start at a page boundry
level_palette PALETTE_SIZE ; palette used by the currently loaded level, is copied whenever a level becomes active

player_x 1 ; tile location of player
player_y 1 ; tile location of player
player_x_bac 1 ; backup location
player_y_bac 1 ; backup location
player_timer 1 ; animation timer
last_move 1 ; 0 = up, 1 = down, 2 = left, 3 = right
weapon_x 1 ; players weapon x and y location
weapon_y 1
weapon_type 1 ; id of weapon 0 = sword
iframes 1 ; frames of invincibility after hit
player_hp 1 ; how much hp has player still got
move_timer 1 ; timer for movemnt

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
sprite_tile_temp SPRITE_TILES ; temporary storage for sprites may be used differently depending on sprite
sprite_tile_obj SPRITE_TILES ; object to be used for this sprite, may be set up as needed
sprite_tile_size 1 ; amount of tiles currently used

; these are backup pointers allowing
; the user to reload a room during puzzle mode
level_data_ptr_bac 2
palette_ptr_bac 2
attr_ptr_bac 2

draw_buffer VISIBILITY_RADIUS*2 ; draw buffer for screen updates
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

save_sub_1 32 ; 32 bytes of custom code
save_sub_2 32 ; 32 bytes of custom code
save_sub_3 32 ; 32 bytes of custom code
magic 16 ; hard-coded sequence of sram magic values, if they are not present run init
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

    ; init sram
    jsr init_sram

    ; set up hi byte sprite_ptr
    lda #$02
    sta sprite_ptr+1

    lda #$01
    sta rand8 ; rand8 must be nonzero


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
    ldx #GAME_MODE_TITLE
    jsr load_menu

    ; position editor sprite
    lda #$00
    sta player_x
    sta player_y

    jsr init_title

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
    ; lda GAME_MODE_EDITOR
    ; sta game_mode

    jsr init_audio_channels

start:
    ; load user defined patterns
    lda gfx_flags
    and #%00110000 ; only those bits are important
    ora #%10000000   ; enable NMI, sprites from Pattern Table 0
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

    ; check if actions have reached 0
    lda actions
    bne @no_new_turn
    lda #ACTIONS_PER_TURN
    sta actions ; refresh actions
    ; check if iframes are set, dec every action
    ldx iframes
    beq @no_new_turn
    dec iframes
@no_new_turn


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

    ; if load nmi flag is set skip normal updates until next frame
    lda nmi_flags
    and #%00000001
    bne update_crit_done

    jmp (update_sub_crit)

update_crit_done:

    ; inputs
    jsr input_handler

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

    lda gfx_flags
    and #%00110000 ; only those bits are important
    ora #%10000000   ; enable NMI, sprites from Pattern Table 0
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

    jsr random ; tick rng

    pla
    tay
    pla
    tax
    pla
    rti

; this may be called by
; the APU on the last tick of $4017
irq:
    ; pha
    ; txa
    ; pha
    ; tya
    ; pha

    jmp crash_handler

    ; pla
    ; tay
    ; pla
    ; tax
    ; pla

    rti

.include "./utility.asm"
.include "./input.asm"
.include "./editor.asm"
.include "./mainmenu.asm"
.include "./game.asm"
.include "./title.asm"

.include "./map.asm"
.include "./tiles.asm"
.include "./delay.asm"
.include "./sprites.asm"
.include "./audio.asm"

palette_data:
.db $21,$0D,$20,$31,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F  ;background palette data
.db $21,$0D,$20,$31,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C  ;sprite palette data
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

title_gfx:
.incbin "./graphics/title.gfx"
title_attr:
.incbin "./graphics/title.attr"
title_pal:
.incbin "./graphics/title.pal"

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
.db $0C ; bank
.db $0C ; address
.db $0C ; value

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
.db $12
.db $13
.db $14

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
.db $00
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
.db #<title_gfx
.db #<level_1_gfx

map_table_hi:
.db #>empty_map
.db #>editor_menu_gfx
.db #>main_menu_gfx
.db #>win_gfx
.db #>no_start_msg_gfx
.db #>title_gfx
.db #>level_1_gfx

; color attribute lookup table
attr_table_lo:
.db #<test_attr
.db #<test_attr
.db #<test_attr
.db #<win_attr
.db #<test_attr
.db #<title_attr
.db #<level_1_attr

attr_table_hi:
.db #>test_attr
.db #>test_attr
.db #>test_attr
.db #>win_attr
.db #>test_attr
.db #>title_attr
.db #>level_1_attr

; color palette table
palette_table_lo:
.db #<palette_data
.db #<palette_data
.db #<palette_data
.db #<win_pal
.db #<palette_data
.db #<title_pal
.db #<level_1_pal

palette_table_hi:
.db #>palette_data
.db #>palette_data
.db #>palette_data
.db #>win_pal
.db #>palette_data
.db #>title_pal
.db #>level_1_pal

; map update routines
map_sub_lo:
.db #<empty_sub
.db #<empty_sub
.db #<empty_sub
.db #<empty_sub
.db #<empty_sub
.db #<empty_sub
.db #<empty_sub

map_sub_hi:
.db #>empty_sub
.db #>empty_sub
.db #>empty_sub
.db #>empty_sub
.db #>empty_sub
.db #>empty_sub
.db #>empty_sub

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

.db #<exit_collision ; exit collision
.db #<no_collision
.db #<no_collision
.db #<no_collision ; unused as of now

.db #<barrier_switch ; barrier switch tile
.db #<no_collision
.db #<no_collision
.db #<no_collision ; some as of now unused tiles

.db #<barrier_tile ; barrier tile
.db #<barrier_tile_invert ; inverted barrier
.db #<no_collision ; push tile
.db #<no_collision ; key tile
.db #<no_collision ; door tile
.db #<no_collision ; skel tile
.db #<no_collision ; sword tile
.db #<no_collision ; bat tile
.db #<no_collision ; bat left tile
.db #<no_collision ; mimic tile
.db #<no_collision ; hp tile

; remainder of clearable tiles
.mrep CLEARABLE_MIRROR_START-CLEARABLE_TILES_START+27
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

.db #<no_collision ; exit inverted
.db #<no_collision
.db #<no_collision
.db #<no_collision ; unused as of now

.db #<barrier_switch ; barrier switch tile
.db #<no_collision
.db #<no_collision
.db #<no_collision ; some as of now unused tiles

.db #<barrier_tile ; barrier tile
.db #<barrier_tile_invert ; inverted barrier
.db #<no_collision ; push tile
.db #<no_collision ; key tile
.db #<no_collision ; door tile
.db #<no_collision ; skel tile
.db #<no_collision ; sword tile
.db #<no_collision ; bat tile
.db #<no_collision ; bat left tile
.db #<no_collision ; mimic tile
.db #<no_collision ; hp tile

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

.db #>exit_collision ; staircase
.db #>no_collision
.db #>no_collision
.db #>no_collision ; unused as of now

.db #>barrier_switch ; barrier switch tile
.db #>no_collision
.db #>no_collision
.db #>no_collision ; some as of now unused tiles

.db #>barrier_tile ; barrier tile
.db #>barrier_tile_invert ; inverted barrier
.db #>no_collision ; push tile
.db #>no_collision ; key tile
.db #>no_collision ; door tile
.db #>no_collision ; skel tile
.db #>no_collision ; sword tile
.db #>no_collision ; bat tile
.db #>no_collision ; bat left tile
.db #>no_collision ; mimic tile
.db #>no_collision ; hp tile

; remainder of clearable tiles
.mrep CLEARABLE_MIRROR_START-CLEARABLE_TILES_START+27
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

.db #>no_collision ; exit inverted
.db #>no_collision
.db #>no_collision
.db #>no_collision ; unused as of now

.db #>barrier_switch ; barrier switch tile
.db #>no_collision
.db #>no_collision
.db #>no_collision ; some as of now unused tiles

.db #>barrier_tile ; barrier tile
.db #>barrier_tile_invert ; inverted barrier
.db #>no_collision ; push tile
.db #>no_collision ; key tile
.db #>no_collision ; door tile
.db #>no_collision ; skel tile
.db #>no_collision ; sword tile
.db #>no_collision ; bat tile
.db #>no_collision ; bat left tile
.db #>no_collision ; mimic tile
.db #>no_collision ; hp tile

; error handlers
error_lo:
.db $00
.db #<load_map_start_error

error_hi:
.db $00
.db #>load_map_start_error

sprite_init_lo:
.db #<sprite_init_default ; barrier
.db #<sprite_init_default ; inverted barrier
.db #<sprite_init_push ; push tile
.db #<sprite_init_default ; key tile
.db #<sprite_init_default ; door tile
.db #<sprite_init_default ; skelleton tile
.db #<sprite_init_default ; sword weapon
.db #<sprite_init_default ; bat tile
.db #<sprite_init_default ; bat left tile
.db #<sprite_init_default ; mimic tile
.db #<sprite_init_default ; hp tile

sprite_init_hi:
.db #>sprite_init_default
.db #>sprite_init_default
.db #>sprite_init_push
.db #>sprite_init_default
.db #>sprite_init_default
.db #>sprite_init_default
.db #>sprite_init_default
.db #>sprite_init_default
.db #>sprite_init_default
.db #>sprite_init_default
.db #>sprite_init_default

sprite_ai_lo:
.db #<sprite_update_default
.db #<sprite_update_barrier_invert
.db #<sprite_update_push
.db #<sprite_key_update
.db #<sprite_door_update
.db #<sprite_skel_update
.db #<sprite_sword_update
.db #<sprite_skel_update
.db #<sprite_skel_update
.db #<sprite_skel_update
.db #<sprite_hp_update

sprite_ai_hi:
.db #>sprite_update_default
.db #>sprite_update_barrier_invert
.db #>sprite_update_push
.db #>sprite_key_update
.db #>sprite_door_update
.db #>sprite_skel_update
.db #>sprite_sword_update
.db #>sprite_skel_update
.db #>sprite_skel_update
.db #>sprite_skel_update
.db #>sprite_hp_update

sprite_collision_lo:
.db #<sprite_on_collision
.db #<sprite_on_collision
.db #<sprite_push_collision
.db #<sprite_key_collision
.db #<sprite_door_collision
.db #<sprite_skel_collision
.db #<sprite_sword_collision
.db #<sprite_skel_collision
.db #<sprite_skel_collision
.db #<sprite_skel_collision
.db #<sprite_hp_collision

sprite_collision_hi:
.db #>sprite_on_collision
.db #>sprite_on_collision
.db #>sprite_push_collision
.db #>sprite_key_collision
.db #>sprite_door_collision
.db #>sprite_skel_collision
.db #>sprite_sword_collision
.db #>sprite_skel_collision
.db #>sprite_skel_collision
.db #>sprite_skel_collision
.db #>sprite_hp_collision

; sub routines for weapon upgrades
weapon_update_lo:
.db #<empty_sub
.db #<sword_update

weapon_update_hi:
.db #>empty_sub
.db #>sword_update

weapon_done_lo:
.db #<sword_done
.db #<sword_done

weapon_done_hi:
.db #>sword_done
.db #>sword_done

; sprites based on tile
; this number is the vertical sprite
; it is ord with #%10000000 to get the horizontal version
weapon_sprite:
.db #$24
.db #$33

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

.define TEST_SONG_DUTY1 #%01000011
.define TEST_SONG_DUTY2 #%11100011
test_song_square_1:
.db TEST_SONG_DUTY1, 24, TEST_SONG_DUTY1, 28, TEST_SONG_DUTY1, 24, TEST_SONG_DUTY1, 28
.db TEST_SONG_DUTY1, 26, TEST_SONG_DUTY1, 30, TEST_SONG_DUTY1, 26, TEST_SONG_DUTY1, 30
.db TEST_SONG_DUTY1, 24, TEST_SONG_DUTY1, 28, TEST_SONG_DUTY1, 24, TEST_SONG_DUTY1, 28
.db TEST_SONG_DUTY1, 26, TEST_SONG_DUTY1, 30, TEST_SONG_DUTY1, 26, TEST_SONG_DUTY1, 30
.db TEST_SONG_DUTY1, 24, TEST_SONG_DUTY1, 28, TEST_SONG_DUTY1, 24, TEST_SONG_DUTY1, 28
.db TEST_SONG_DUTY1, 26, TEST_SONG_DUTY1, 30, TEST_SONG_DUTY1, 26, TEST_SONG_DUTY1, 30
.db TEST_SONG_DUTY1, 24, TEST_SONG_DUTY1, 28, TEST_SONG_DUTY1, 24, TEST_SONG_DUTY1, 28
.db TEST_SONG_DUTY1, 26, TEST_SONG_DUTY1, 30, TEST_SONG_DUTY1, 26, TEST_SONG_DUTY1, 30
.db $00, $00, $FF, $FF

test_song_square_2:
.db TEST_SONG_DUTY2, 36, TEST_SONG_DUTY2, 38, TEST_SONG_DUTY2, 34, TEST_SONG_DUTY2, 36,
.db $00, $00, TEST_SONG_DUTY2, 37, $00, $00, TEST_SONG_DUTY2, 40
.db TEST_SONG_DUTY2, 37, $00, $00, TEST_SONG_DUTY2, 40, $00, $00
.db $00, $00, $FF, $FF

test_song_triangle:
.db $0C, $20, $0C, $21, $00, $00, $FF, $FF


; NTSC period table generated by mktables.py
; first value = A on piano
period_table_lo:
.db $f1,$7f,$13,$ad,$4d,$f3,$9d,$4c,$00,$b8,$74,$34 ; A
.db $f8,$bf,$89,$56,$26,$f9,$ce,$a6,$80,$5c,$3a,$1a ; B
.db $fb,$df,$c4,$ab,$93,$7c,$67,$52,$3f,$2d,$1c,$0c ; C
.db $fd,$ef,$e1,$d5,$c9,$bd,$b3,$a9,$9f,$96,$8e,$86 ; D
.db $7e,$77,$70,$6a,$64,$5e,$59,$54,$4f,$4b,$46,$42 ; E
.db $3f,$3b,$38,$34,$31,$2f,$2c,$29,$27,$25,$23,$21 ; F
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
