; sets up  projectile slots
init_projectile_slots:
    ldy #PROJECTILES-1
    ldx #PROJECTILES+PROJECTILES_START-1
@loop:
    txa
    sta projectile_obj, y
    lda #$00
    sta projectile_flags, y
    sta projectile_x, y
    sta projectile_y, y
    sta projectile_data, y
    dex
    dey
    cpy #$FF
    bne @loop
    rts

; updates projectile objects
; if sprtie_disable flag is set no updates will occur
update_projectiles:
    lda game_flags
    and #%01000000 ; sprite enable flag
    beq @done

    ; loop all projectile slots
    ldy #PROJECTILES-1
@loop:
    ; modify obj slot for flickering
    lda projectile_obj, y
    tax
    inx
    txa
    cmp #PROJECTILES+PROJECTILES_START
    bcc @out_of_bounds
    lda #PROJECTILES_START
@out_of_bounds:
    sta projectile_obj, y 

    jsr projectile_update

    dey
    cpy #$FF
    bne @loop

@done:
    rts

; updates a projectile slot
; inputs:
;   y -> the projectile slot
; side effects:
;   uses sprite_ptr for object
projectile_update:
    tya
    pha ; store y

    ; set up pointer
    lda projectile_obj, y
    tax
    lda obj_index_to_addr, x
    sta sprite_ptr

    lda projectile_flags, y ; check enable flag
    and #%10000000
    bne @no_skip_flag
    jmp @skip
@no_skip_flag:
    ; check timer
    lda projectile_data, y
    bne @no_skip_timer
    jmp @disable
@no_skip_timer:
    ; dec timer
    tax
    dex
    txa
    sta projectile_data, y

    ; update movement
    lda projectile_flags, y
    and #%0000011 ; direction
    cmp #UP
    bne @not_up

    ; tile to use
    lda #$3D
    sta temp+2

    ; attributes
    lda #%10000000
    sta temp+3

    ; test if position can be changed
    lda projectile_data, y
    and #$07
    bne @not_right
    lda projectile_y, y
    sec
    sbc #$01 ; next tile
    ; if ff we are oob and done
    cmp #$FF
    bne @not_disable_up
    jmp @disable
@not_disable_up:
    sta projectile_y, y
    jmp @not_right ; done

@not_up:
    cmp #DOWN
    bne @not_down

    ; tile to use
    lda #$3D
    sta temp+2

    ; attributes
    lda #$00
    sta temp+3

    ; test if position can be changed
    lda projectile_data, y
    and #$07
    bne @not_right
    lda projectile_y, y
    clc
    adc #$01 ; next tile
    ; if ff we are oob and done
    cmp #$1E
    bne @not_dsiable_down
    jmp @disable
@not_dsiable_down:
    sta projectile_y, y
    jmp @not_right ; done

@not_down:
    cmp #LEFT
    bne @not_left

    ; tile to use
    lda #$BD
    sta temp+2

    ; attributes
    lda #%01000000
    sta temp+3

    ; test if position can be changed
    lda projectile_data, y
    and #$07
    bne @not_right
    lda projectile_x, y
    sec
    sbc #$01 ; next tile
    ; if ff we are oob and done
    cmp #$FF
    beq @disable
    sta projectile_x, y
    jmp @not_right ; done

@not_left:
    cmp #RIGHT
    bne @not_right

    ; tile to use
    lda #$BD
    sta temp+2

    ; attributes
    lda #%00000000
    sta temp+3

    ; test if position can be changed
    lda projectile_data, y
    and #$07
    bne @not_right
    lda projectile_x, y
    clc
    adc #$01 ; next tile
    ; if ff we are oob and done
    cmp #$20
    beq @disable
    sta projectile_x, y
@not_right:


    ; set position
    lda projectile_x, y
    sta get_tile_x

    lda projectile_y, y
    sta get_tile_y

    jsr sprite_offscreen
    beq @offscreen
    bne @sprite_picked
@offscreen:
    lda #$24
    sta temp+2
@sprite_picked:

    ; get position
    ldx get_tile_x
    lda tile_convert_table, x
    sta temp

    ldx get_tile_y
    lda tile_convert_table, x
    sta temp+1

    ; test collision
    lda get_tile_x
    cmp player_x
    bne @no_collision
    lda get_tile_y
    cmp player_y
    bne @no_collision
    ; TODO enable this when debugging is done
    jsr sprite_skel_collision
    jmp @disable ; if collision happened disable
@no_collision:

    ; set position
    lda temp+1
    ldy #$00
    sta (sprite_ptr), y

    lda temp+2 ; tile
    iny
    sta (sprite_ptr), y

    lda temp+3 ; attributes
    iny
    sta (sprite_ptr), y

    lda temp
    iny
    sta (sprite_ptr), y

    pla
    tay ; restore y

    rts

@disable:
    lda #$00 ; disable
    sta projectile_flags, y
@skip:
    ; move offscreen
    ldy #$00
    lda #$00
    sta (sprite_ptr), y

    ldy #$03
    sta (sprite_ptr), y

    pla
    tay ; restore y 

    rts

; this sub routine finds the first empty projectile slot
; and enables it
; if no slot is found the spawn is simply dropped
; inputs:
;   get_tile_x -> x position
;   get_tile_y -> y position
;   a -> direction
spawn_projectile:
    pha ; direction

    ldy #PROJECTILES-1
@loop:
    lda projectile_flags, y
    and #%10000000
    beq @slot_found ; if enable flag is off

    dey
    cpy #$FF
    bne @loop

    pla ; pull and drop spawn request

    rts

@slot_found:
    ; enable slot
    pla ; direction
    ora #%10000000 ; also set enable flag
    sta projectile_flags, y

    lda get_tile_x
    sta projectile_x, y
    lda get_tile_y
    sta projectile_y, y

    lda #$2F
    sta projectile_data, y ; timer

    rts 

