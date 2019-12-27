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

; this sub routine copies a room of a certain id
; into level_data
; inputs:
;   x -> x location
;   y -> y location
;   a -> room id from room table
copy_room:
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
