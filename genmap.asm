; this file will implement the map generator
; rooms are always the same size
; Algo:
; 1 create a room in the middle of the map
; 2 pick a random wall
; 3 add a feature (e.g. corridor) or random lenght
; 4 add a room at the end of that corridotr
; 5 continue with step 2-4 until enough rooms were added
; 6 overlapping rooms are ok
; 7 surround all floor-empty connections with walls
; 8 add random start+end tiles
; 9 add random items and enemies
; this sub routine generates a map based
; on the algo descirbed above
; inputs:
;   level_ptr -> pointing to buffer
;   seed -> rng seed for map
generate_map:
    ; start out center-ish
    ldx #$04
    ldy #$04
    lda #$00
    ; backup coordinates for later
    stx get_tile_x
    sty get_tile_y
    jsr insert_room

    ldx #$FF ; generate rooms x  more times
@gen_loop:
    txa
    pha ; loop counter

    ; advance seed
    lda seed
    jsr random_reg
    sta seed
    lda seed+1
    jsr random_reg
    sta seed+1

    ; TODO this is bad improve
    ; TODO prevent writes out of bounds
    ; TODO maps are too small rooms overlap
    ; which direction do we move


    ; pick room from seed
    lda seed
    eor seed+1
    and #ROOM_HEADERS
    tax
    sta temp
    ; set up ptr to read room size
    lda rooms_lo, x
    sta temp+1
    lda rooms_hi, x
    sta temp+2 ; ptr to rooms

    ; pick random coordinate
    lda seed
    eor seed+1
    and #$1F
    sta get_tile_x
    lda seed+1
    eor seed
    and #$1F
    sta get_tile_y

    ldy #$00
    lda get_tile_x
    sec
    sbc (temp+1), y
    sta get_tile_x
    lda get_tile_y
    sec
    sbc (temp+1), y
    sta get_tile_y

    ; oob check
    jsr check_oob_coordinates
    cmp #$01
    bne @not_oob
    pla
    tax ; pull x
    jmp @gen_loop ; back to loop
@not_oob:

    ; get the tile
    jsr get_tile
    cmp #$24 ; if not empty tile generate room
    bne @good_tile
    ; if bad tile try again
    pla
    tax
    jmp @gen_loop
@good_tile:

    ; offset coordinates
    ldx get_tile_x
    ldy get_tile_y
    lda temp ; room header ptr
    jsr insert_room

    pla
    tax  ; loop counter
    dex
    bne @gen_loop

    ; just place a start tile for testing purposes
    lda #$60
    ldy #$00
    sta (dest_ptr), y

    rts

; checks if coordinates will reach out of bounds
; inputs:
;   get_tile_x
;   get_tile_y
; returns:
;   a = 1 if oob
;   a = 0 if not oob
; side effects:
;   overwrites get_tile_x and _y
check_oob_coordinates:
    ; check oob coodrinates x
    lda get_tile_x
    cmp #31-MAX_ROOM_SIZE+1
    bcc @less_x
    lda #$0A
    sta get_tile_x
    lda #$01
    rts
@less_x:

    ; check oob coordinates y
    lda get_tile_y
    cmp #29-MAX_ROOM_SIZE+1
    bcc @less_y
    lda #$0A
    sta get_tile_y
    lda #$01
    rts
@less_y:

    lda #$00
    rts

; this sub routine copies a room of a certain id
; into level_data
; inputs:
;   x -> x location
;   y -> y location
;   a -> room id from room table
; side effects:
;   uses temp, temp+1, temp+2, and dst_ptr
insert_room:
    pha ; store room id for now

    lda level_ptr
    sta dest_ptr
    lda level_ptr+1
    sta dest_ptr+1

    ; low byte of level_ptr is alwasy $00, no need to add it
    lda tile_update_table_lo, x
    clc
    stx temp
    adc temp
    sta dest_ptr

    lda tile_update_table_hi, y
    adc dest_ptr+1
    sta dest_ptr+1

    pla ; room id
    tay

    lda rooms_lo, y
    sta temp ; ptr
    lda rooms_hi, y
    sta temp+1 ; temp now is the pointer to data

    ldy #$00 ; get room x size
    lda (temp), y
    sta temp+2 ; store x, we need it Y times
    dec temp+2 ; -1 to get actual size for loop

    iny
    lda (temp), y
    tax ; move y positon to X
    dex ; -1 to get actual size for loop

    iny
    lda (temp), y ; tile to place
    sta temp ; don't need pointer anymore


@y_loop:
    ldy temp+2 ; load x value
    lda temp ; load tile value
@x_loop:
    sta (dest_ptr), y

    dey
    cpy #$FF ; underflow
    bne @x_loop

    ; add 32 to ptr
    lda dest_ptr
    clc
    adc #32
    sta dest_ptr
    lda dest_ptr+1
    adc #$00
    sta dest_ptr+1

    dex
    cpx #$FF ; underflow
    bne @y_loop

    rts


; a list of room headers
; Room header doc:
;   Each room header consists of 3 bytes
;   Byte 2: X Size
;   Byte 1: Y Size
;   Byte 0: Fill Tile
rooms_lo:
.db <room6x6
.db <room6x3
.db <room3x6
.db <room3x3
.db <room8x2
.db <room8x2
.db <room2x8
.db <room2x8

rooms_hi:
.db >room6x6
.db >room6x3
.db >room3x6
.db >room3x3
.db >room8x2
.db >room8x2
.db >room2x8
.db >room2x8

room6x6:
.db $06, $06, $62
room6x3:
.db $06, $03, $62
room3x6:
.db $03, $06, $62
room3x3:
.db $03, $03, $62
room8x2:
.db $08, $02, $62
room2x8:
.db $02, $08, $62
