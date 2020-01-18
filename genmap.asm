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
    ldx #$0A
    ldy #$0A
    lda #$00
    ; backup coordinates for later
    stx get_tile_x
    sty get_tile_y
    jsr insert_room

    ; just place a start tile for testing purposes
    lda #$60
    ldy #$00
    sta (dest_ptr), y

    ldx #$20 ; generate rooms x  more times
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
    ; which direction do we move
    lda seed
    eor seed+1
    and #$03
    cmp #UP
    bne @not_up:

    dec get_tile_y
    dec get_tile_y
    dec get_tile_y
    dec get_tile_y
    inc get_tile_x
    inc get_tile_x
    jmp @done
@not_up:
    cmp #DOWN
    bne @not_down
    ; down
    inc get_tile_y
    inc get_tile_y
    inc get_tile_y
    inc get_tile_y
    dec get_tile_x
    dec get_tile_x
    jmp @done
@not_down:
    cmp #LEFT
    bne @not_left
    dec get_tile_x
    dec get_tile_x
    dec get_tile_x
    dec get_tile_x
    inc get_tile_y
    inc get_tile_y
    jmp @done
@not_left:
    cmp #RIGHT
    bne @not_right
    inc get_tile_x
    inc get_tile_x
    inc get_tile_x
    inc get_tile_x
    dec get_tile_y
    dec get_tile_y
    jmp @done
@not_right:
@done:

    ldx get_tile_x
    ldy get_tile_y
    lda #$00
    jsr insert_room
    pla
    tax  ; loop counter
    dex
    bne @gen_loop

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
.db <test_room

rooms_hi:
.db >test_room

test_room:
.db $04, $04, $62
