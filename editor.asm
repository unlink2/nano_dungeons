; this sub routine 
; calculates the visuals 
; for the attribute memory display in the
; editor pause menu
; inputs:
;   attr_value -> the value to be used
; modifies:
;   registers and sprite index for sprite_2 - 5
init_attr_display:
    lda attr_value
    and #%00000011 ; top left
    sta sprite_data_2+1

    lda attr_value
    and #%00001100 ; bottom left
    lsr 
    lsr 
    sta sprite_data_3+1

    lda attr_value
    and #%00110000 ; top right
    lsr 
    lsr 
    lsr 
    lsr 
    sta sprite_data_4+1

    lda attr_value
    and #%11000000 ; bottom right 
    lsr 
    lsr 
    lsr 
    lsr 
    lsr 
    lsr 
    sta sprite_data_5+1

    rts 

; transfers attribute visual display back to the attr_value
; inputs:
;   sprite_data 2-5
; side effects
;   registers and sprite_value
transfert_attr_display:
    lda #$00
    sta attr_value

    lda sprite_data_5+1
    asl 
    asl 
    asl 
    asl 
    asl 
    asl 
    sta attr_value

    lda sprite_data_4+1
    sta src_ptr
    asl 
    asl 
    asl 
    asl
    ora attr_value
    sta attr_value

    lda sprite_data_3+1
    asl 
    asl 
    ora attr_value
    sta attr_value

    lda sprite_data_2+1
    ora attr_value
    sta attr_value
    rts 

.macro inc_dec_attr_macro sprite_data_addr
    ldy sprite_data_addr 
    cpx #$01 
    bne @.mi.dec 
    iny 
    jmp @.mi.add_done
@.mi.dec:
    dey 
@.mi.add_done:
    tya 
    and #%00000011
    sta sprite_data_addr
    rts  
.end

; this sub routine incs or decs
; the attribute value
; inputs:
;   attr_value -> the attribute value
;   x -> 0 = increment, 1 = decrement
;   y -> area -> 0=top left, 1=bottom left, 2=top right, 3=bottom right
; side effects:
;   modifies registers and attr_value   
inc_dec_attr:
    cpy #$03
    bne @not_br
    inc_dec_attr_macro sprite_data_5+1
@not_br:
    cpy #$02
    bne @not_tr
    ldy sprite_data_4+1
    inc_dec_attr_macro sprite_data_4+1
@not_tr:
    cpy #$01 
    bne @not_bl
    inc_dec_attr_macro sprite_data_3+1
@not_bl:
    inc_dec_attr_macro sprite_data_2+1

; inits editor menu
init_editor_menu:
    ; backup player's location and
    ; move to cursor position
    lda player_x 
    sta player_x_bac
    lda player_y
    sta player_y_bac

    ; set up initial location (redudant really)
    lda #$01 
    sta player_x
    lda #$09 
    sta player_y

    ; move sprite 1 to tile select location
    lda #$77
    sta sprite_data_1
    lda #$38
    sta sprite_data_1+3

    lda #$00
    sta sprite_data_1+1
    sta sprite_data_1+2
    ; attributes 0
    sta sprite_data_2+2
    sta sprite_data_3+2 
    sta sprite_data_4+2 
    sta sprite_data_5+2

    ; set other spirtes to 0/0
    sta sprite_data_2
    sta sprite_data_2+3 
    sta sprite_data_3
    sta sprite_data_3+3
    sta sprite_data_4
    sta sprite_data_4+3

    ; set the tile select's tile index
    lda sprite_data+1 
    sta sprite_data_1+1

    lda #<update_editor_menu
    sta update_sub
    lda #>update_editor_menu
    sta update_sub+1

    ; set up player tile to become a pointer
    lda #$31
    sta sprite_data+1

    ; move sprites indicating 
    ; attr values to correct position
    ; sprites_2, 3, 4, 5
    lda #$70 ; x position
    sta sprite_data_2+3 ; up left
    sta sprite_data_3+3 ; bottom left

    lda #$7F ; x position
    sta sprite_data_4+3 ; up right 
    sta sprite_data_5+3 ; bottom right

    lda #$28 ; y positon
    sta sprite_data_2 ; up left
    sta sprite_data_4 ; up right

    lda #$38 ; y position
    sta sprite_data_3 ; bottom left
    sta sprite_data_5 ; bottom right

    jsr init_attr_display

    rts 

; init editor
init_editor:
    jsr transfert_attr_display

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
    sta sprite_data_5
    sta sprite_data_5+3

    ; attributes 0 for player
    sta sprite_data+2

    lda #<update_editor
    sta update_sub
    lda #>update_editor
    sta update_sub+1

    ; set up other sprites used to attribute drawing
    lda #$30 ; corner tile
    sta sprite_data_1+1 
    sta sprite_data_2+1
    sta sprite_data_3+1 
    sta sprite_data_4+1

    ; set up rotation
    lda #%01000000
    sta sprite_data_2+2

    lda #%10000000
    sta sprite_data_3+2

    lda #%11000000
    sta sprite_data_4+2

    rts 

; update sub routine for editor menu
update_editor_menu:
    lda menu_select
    and #EDITOR_MENU_MAX_SELECT ; only 3 possible options
    cmp #$09 ; if more than 8, overflow
    bcc @no_overflow
    lda #$00
@no_overflow
    sta menu_select

    ; set sprite at correct position 
    tax 
    lda editor_menu_cursor_x, x 
    sta player_x

    lda editor_menu_cursor_y, x 
    sta player_y

    lda editor_menu_cursor_attr, x
    sta sprite_data+2
@done:
    jmp update_done

; update sub routne for editor
update_editor:
    jmp update_done