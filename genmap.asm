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
