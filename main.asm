; header
.db $4E, $45, $53, $1A, ; NES + MS-DOS EOF
.db $01 ; prg rom size in 16kb 
.db $01 ; chr rom in 8k bits
.db $00 ; mapper 0 no special stuff
.db $01 ; mirroring
.db $00 ; no prg ram 
.db $00, $00, $00, $00, $00, $00, $00 ; rest is unused 

.define MOVE_DELAY_FRAMES 10

.enum $00
frame_count 1
rand8 1
game_mode 1
move_delay 1 ; delay between move inputs
.end 

; sprite memory
.enum $0200
sprite_data 256 ; all sprite data
player_x 1 ; tile location of player 
player_y 1 ; tile location of player
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

    ; test sprite 0
    lda #$80
    sta sprite_data ; put sprite 0 in center ($80) of screen vert
    sta sprite_data+3 ; put sprite 0 in center ($80) of screen horiz
    lda #$00
    sta sprite_data+1 ; tile number = 0
    sta sprite_data+2 ; color = 0, no flipping
  ; end test

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

    bit $2002 ; read ppu status to reset latch

    ; sprite DMA
    lda #<sprite_data
    sta $2003  ; set the low byte (00) of the RAM address
    lda #$>sprite_data
    sta $4014  ; set the high byte (02) of the RAM address, start the transfer

    sta $2005 ; no horizontal scroll 
    sta $2005 ; no vertical scroll

    ; inputs
    jsr input_handler

    rti 

; sub routine that converts the sprite's 
; tile position to an actual 
; location on  the screen
convert_tile_location:
    ldx player_y
    lda tile_convert_table, x 
    sta sprite_data

    ldx player_x
    lda tile_convert_table, x 
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
    bne @no_a
    ; TODO A button press
@no_a:

    lda $4016 ; p1 - B
    and #%00000001
    bne @no_b
    ; TODO B button press
@no_b:

    lda $4016 ; p1 - select
    and #%00000001
    bne @no_select
    ; TODO select button press
@no_select:

    lda $4016 ; p1 - start
    and #%00000001
    bne @no_start 
    ; TODO start button press
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
; if move delay is nonzero
; dec move delay
; inputs:
;   none 
; returns:
;   a -> 0 if move can go ahead
;   a -> 1 if move cannot go ahead 
can_move:
    lda move_delay 
    beq @done
@done:
    rts 

; left input
go_left:
    jsr can_move
    bne @done
    dec player_x
    lda #MOVE_DELAY_FRAMES
    sta move_delay
@done:
    rts 

; right input
go_right:
    jsr can_move
    bne @done 
    inc player_x
    lda #MOVE_DELAY_FRAMES
    sta move_delay
@done:
    rts 

; up input
go_up:
    jsr can_move
    bne @done 
    dec player_y
    lda #MOVE_DELAY_FRAMES
    sta move_delay
@done:
    rts 

; down input
go_down:
    jsr can_move
    bne @done
    inc player_y
    lda #MOVE_DELAY_FRAMES
    sta move_delay
@done: 
    rts 

palette_data:
.db $0F,$31,$32,$33,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F  ;background palette data
.db $0F,$1C,$15,$14,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C  ;sprite palette data
palette_data_end:

; lookup table of all possible tile conversion positions
tile_convert_table:
.mrep $FF
.db .ri.*8
.endrep

.pad $FFFA
.dw nmi ; nmi
.dw init ; reset 
.dw init ; irq

; chr bank 8k
.base $0000
.incbin "./gfx.chr" ; exported memory dump from mesen
