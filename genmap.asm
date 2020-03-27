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
; TODO seed BC5E is softlock seed
generate_map:
    ; start out center-ish
    ldx #$04
    ldy #$04
    lda #$00
    ; backup coordinates for later
    stx get_tile_x
    sty get_tile_y
    jsr insert_room
    ; jmp @gen_done
    ldx #$30
    ;ldx #$24 ; generate rooms x  more times
@gen_loop:
    txa
    pha ; loop counter

    ; advance seed
    jsr random_seed

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
    and #$1F
    sta get_tile_x

    lda seed+1
    and #$1F
    sta get_tile_y

    ldy #$00
    lda get_tile_x
    sec
    sbc (temp+1), y
    sta get_tile_x
    lda get_tile_y
    iny
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

    ; TODO place walls with doors or spaces
    ; in random spots
    jsr place_walls

    ; TODO pretty draw walls

    jsr place_sprites

    jsr insert_other

@gen_done:
    ; just place a start tile for testing purposes
    ; lda #$60
    ; ldy #$00
    ; sta (dest_ptr), y

    rts

; this sub routine places walls
; in random locations
; the walls will always have one door
; that is either open or locked
place_walls:
    rts

; this sub routine places sprite spawns
; on the map by selecting a location
; checking if it is in bounds
; and then placing a sprite spawner tile
place_sprites:
    lda #SPRITE_TILES
    tax ; loop counter
@loop:
    ; save x
    txa
    pha

    ; advance seed
    jsr random_seed

    jsr get_random_coordinate
    bne @good_tile
    pla
    tax ; pull values
    jmp @loop
@good_tile:

    ; place a sprite tile at this location
    lda seed
    eor seed+1
    tax
    lda sprite_tile_rng, x
    ldx get_tile_x
    ldy get_tile_y
    jsr place_tile

    ; restore x
    pla
    tax
    dex
    bne @loop

    rts

; inserts exit and start at random location
insert_other:
    lda #$68 ; exit tile
    jsr insert_single

    ; advance seed a bit
    ldx #$FF
@seed_loop:
    txa
    pha

    jsr random_seed

    pla
    tax

    dex
    bne @seed_loop

    lda #$60 ; start tile
    jsr insert_single

    rts

; inserts a single tile at a random location
; insert single cannot replace start or end tile id
; inputs:
;   a = tile id
; returns:
;   none
insert_single:
    pha ; store tile id
; insert tile
@loop:
    ; advance seed
    jsr random_seed

    jsr get_random_coordinate
    bne @good_tile
    jmp @loop
@good_tile:
    jsr get_tile
    cmp #$60 ; start tile
    beq @loop
    cmp #$68 ; exit tile
    beq @loop


    pla ; get tile id
    ldx get_tile_x
    ldy get_tile_y
    jsr place_tile


    rts

; selects a random coordinate
; inputs:
;   seed
; returns:
;   get_tile_x
;   get_tile_y
;   a != 0 if ok
get_random_coordinate:
    ; pick random coordinate
    lda seed
    and #$1F
    sta get_tile_x

    lda seed+1
    and #$1F
    sta get_tile_y

    ; oob check
    jsr check_oob_coordinates
    cmp #$01
    bne @not_oob
    lda #$00
    rts
    ; jmp @loop ; back to loop
@not_oob:

    jsr get_tile
    cmp #$24 ; empty tile
    bne @good_tile
    ; pull
    lda #$00 
    rts 
    ; jmp @loop
@good_tile:
    lda #$01 
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
@ret_x
    lda #$0A
    sta get_tile_x
    lda #$01
    rts
@less_x:
    ; check up oob x
    cmp #$03 ; 3 tiles over at least
    bcc @ret_x

    ; check oob coordinates y
    lda get_tile_y
    cmp #29-MAX_ROOM_SIZE+1
    bcc @less_y
@ret_y
    lda #$0A
    sta get_tile_y
    lda #$01
    rts
@less_y:
    ; check up oob y
    cmp #$03 ; 3 tiles down at least
    bcc @ret_y

    lda #$00
    rts

; this sub routine copies a room of a certain id
; into level_data
; inputs:
;   x -> x location
;   y -> y location
;   a -> room id from room table
; side effects:
;   uses temp, temp+1, temp+2, temp1_ptr, temp2_ptr and dst_ptr
insert_room:
    pha ; store room id for now

    lda level_ptr
    sta dest_ptr
    lda level_ptr+1
    sta dest_ptr+1

    ; low byte of level_ptr is alwasy $00, no need to add it
    lda tile_update_table_lo, y
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
    sta temp1_ptr ; ptr
    lda rooms_hi, y
    sta temp1_ptr+1 ; temp now is the pointer to data

    ldy #$00 ; get room x size
    lda (temp1_ptr), y
    sta temp+2 ; store x, we need it Y times
    dec temp+2 ; -1 to get actual size for loop

    iny
    lda (temp1_ptr), y
    tax ; move y positon to X
    dex ; -1 to get actual size for loop

    iny
    lda (temp1_ptr), y ; tile to place
    pha ; store for now

    iny
    lda (temp1_ptr), y ; options
    sta temp+1 ; don't need pointer anymore
    pla
    sta temp ; fill tile

    ; ptr index for tile loading if required
    lda #$04
    sta temp1_index
@y_loop:
    ldy temp+2 ; load x value
    lda temp ; load tile value
@x_loop:
    lda temp+1 ; options
    and #%10000000 ; is room pre-defined
    beq @not_pre_defined

    tya
    pha ; store y for a moment
    ldy temp1_index
    lda (temp1_ptr), y
    iny
    sty temp1_index ; next index
    sta temp ; store tile value
    pla
    tay ; original y restored

@not_pre_defined:
    lda temp ; load tile value 
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


; places a tile in the map data
; inputs:
;   x -> x location
;   y -> y location
;   a = tile to place
place_tile:
    pha ; store tile

    lda level_ptr
    sta dest_ptr
    lda level_ptr+1
    sta dest_ptr+1

    ; low byte of level_ptr is alwasy $00, no need to add it
    lda tile_update_table_lo, y
    clc
    stx temp
    adc temp
    sta dest_ptr

    lda tile_update_table_hi, y
    adc dest_ptr+1
    sta dest_ptr+1

    pla
    ldy #$00
    sta (dest_ptr), y

    rts

; tabel of 256 possible
; tile to number mappings
; for easy placement on the map
sprite_tile_rng:
.mrep 14
.db $70+.ri., $70+.ri., $70+.ri., $70+.ri., $70+.ri., $70+.ri., $70+.ri., $70+.ri.
.db $70+.ri., $70+.ri., $70+.ri., $70+.ri., $70+.ri., $70+.ri., $70+.ri., $70+.ri.
.db $70+.ri.
.endrep
; .db $5C, $5D, $5E, $5F ; jump tiles
.db $6C, $6C, $6C, $6C, $6C ; switch tile
.db $68 ; end tile, more than one allowed
.db $7F, $7F, $7F, $7F, $7F ; flame tiles
.db $80 ; bear trap
.mrep 6
.db $72 ; push block
.endrep

; a list of room headers
; Room header doc:
;   Each room header consists of 3 bytes
;   Byte 0: X Size
;   Byte 1: Y Size
;   Byte 2: Fill Tile
;   Byte 3: Options
;       7th bit = 1 -> pre-defined room, tiles follow the header (tiles are mirrored horizontally)
;   Byte 4-N: Raw room tiles
;   TODO implement byte 3
rooms_lo:
.db <room6x6
.db <room6x3
.db <room3x6
.db <room3x3
.db <room8x2
.db <room4x4
.db <room2x8
.db <room4x4
.db <room1x4wall
.db <room4x1wall
.db <room6x6
.db <room6x6_one_way
.db <room3x6
.db <room3x3
.db <room8x2
.db <room5x5
; ===========
.db <room6x6
.db <room6x3
.db <room3x6
.db <room3x3
.db <room8x2
.db <room4x4
.db <room2x8
.db <room4x4
.db <room1x4wall
.db <room4x1wall
.db <room6x6
.db <room6x6_one_way
.db <room3x6
.db <room3x3
.db <room8x2
.db <room5x5

rooms_hi:
.db >room6x6
.db >room6x3
.db >room3x6
.db >room3x3
.db >room8x2
.db >room4x4
.db >room2x8
.db >room4x4
.db >room1x4wall
.db >room4x1wall
.db >room6x6
.db >room6x6_one_way
.db >room3x6
.db >room3x3
.db >room8x2
.db >room5x5
; ===========
.db >room6x6
.db >room6x3
.db >room3x6
.db >room3x3
.db >room8x2
.db >room4x4
.db >room2x8
.db >room4x4
.db >room1x4wall
.db >room4x1wall
.db >room6x6
.db >room6x6_one_way
.db >room3x6
.db >room3x3
.db >room8x2
.db >room5x5

room6x6:
.db $08, $08, $62, $80
.db $62, $62, $62, $62, $62, $62, $62, $62
.db $62, $37, $37, $62, $62, $37, $37, $62
.db $62, $37, $62, $62, $62, $62, $37, $62
.db $62, $62, $62, $62, $62, $62, $62, $62
.db $62, $62, $62, $62, $62, $62, $62, $62
.db $62, $37, $62, $62, $62, $62, $37, $62
.db $62, $37, $37, $62, $62, $37, $37, $62
.db $62, $62, $62, $62, $62, $62, $62, $62
room6x6_one_way:
.db $08, $08, $62, $80
.db $62, $62, $62, $62, $62, $62, $62, $62
.db $62, $37, $37, $65, $65, $37, $37, $62
.db $62, $37, $62, $62, $62, $62, $37, $62
.db $62, $64, $62, $62, $62, $62, $64, $62
.db $62, $64, $62, $62, $62, $62, $64, $62
.db $62, $37, $62, $62, $62, $62, $37, $62
.db $62, $37, $37, $65, $65, $37, $37, $62
.db $62, $62, $62, $62, $62, $62, $62, $62
room5x5:
.db $05, $05, $62, $80
.db $62, $62, $62, $62, $62
.db $62, $48, $62, $47, $62
.db $62, $62, $62, $62, $62
.db $62, $4A, $62, $49, $62
.db $62, $62, $62, $62, $62
room6x3:
.db $06, $03, $62, $00
room3x6:
.db $03, $06, $62, $00
room3x3:
.db $03, $03, $62, $00
room8x2:
.db $08, $02, $62, $00
room2x8:
.db $02, $08, $62, $00
room4x4:
.db $04, $04, $62, $00
room1x4wall
.db $01, $05, $62, $00
room4x1wall
.db $05, $01, $62, $00
