; this sub routine calls all sprite 
; routines that are needed
; if sprtie_disable flag is set no updates will occur
; inputs:
;   sprite_tile_size -> amount of sprites in use on current map
; side effects:
;   updates all sprites up to 8 per frame
update_sprites:
    lda game_flags
    and #%01000000 ; sprite enable flag
    beq @done

    ; we need sprite tile size + 1
    ldx sprite_tile_size
    inx
    stx temp

    ; shuffle sprites to
    ; get everyone to render every once in a while
    ldy sprite_tile_size
    cpy #$FF
    beq @done
@shuffle_loop:
    lda sprite_tile_obj, y
    tax
    inx
    txa
    sec
    sbc #AI_SPRITES_START
    ; and #%00001111 ; remove this bit
    cmp temp ; sprite tile size
    bcc @not_out_of_bounds
@out_of_bounds:
    ldx #AI_SPRITES_START
@not_out_of_bounds:
    txa
    sta sprite_tile_obj, y
    dey
    cpy #$FF
    bne @shuffle_loop


    ldy sprite_tile_size
    cpy #$FF
    beq @done
@loop:
    ldx sprite_tile_ai, y
    lda sprite_ai_lo, x
    sta src_ptr
    lda sprite_ai_hi, x
    sta src_ptr+1

    jsr jsr_indirect

    dey
    cpy #$FF
    bne @loop
@done:
    rts

; this sub routine adjusts sprite positon
; inputs:
;   y -> pointing to sprite data offset
; sprite data documentation:
;   this AI type uses sprite_data as an offset to its x or y position
;   the lower 4 bits are the actual offset value
;   7th bit = 1 -> sbc; = 0 -> adc
;   6th bit = 1 -> x position; = 0 -> y position
;   5th bit = 1 -> inits falling animation, if lower 4 bits are 0 hides sprite
; returns:
;   x position in temp
;   y positon in temp+1
sprite_pos_adjust:
    ; load x position
    ldx sprite_tile_x, y
    lda tile_convert_table, x
    sta temp

    ; load y position
    ldx sprite_tile_y, y
    lda tile_convert_table, x
    sta temp+1

    ; set if we need fine tuning
    lda sprite_tile_data, y
    and #%00001111
    beq @no_adjust ; if the lower 4 bits are already 0 there is no need to adjust

    ; now test what value we need to use as a base
    lda sprite_tile_data, y
    sta temp+3 ; used for bit instruction

    bit temp+3 ; N flag = bit 7, V flag = bit 6

    bvs @y_position ; test bit 7

    ; x position adjust
    ; test if sbc or adc
    bpl @x_add

    ; x sub
    lda sprite_tile_data, y
    and #%00001111
    sta temp+3 ; store for sub
    lda temp
    sec
    sbc temp+3
    sta temp

    jmp @adjust_done
@x_add:
    lda sprite_tile_data, y

    lda sprite_tile_data, y
    and #%00001111
    clc
    adc temp
    sta temp

    jmp @adjust_done
@y_position

    ; y position adjust
    ; test if sbc or adc
    bpl @y_add

    ; y sub
    lda sprite_tile_data, y
    and #%00001111
    sta temp+3 ; store for sub
    lda temp+1
    sec
    sbc temp+3
    sta temp+1

    jmp @adjust_done
@y_add:
    lda sprite_tile_data, y

    lda sprite_tile_data, y
    and #%00001111
    clc
    adc temp+1
    sta temp+1


@adjust_done:
    lda sprite_tile_data, y
    sec
    sbc #$01
    sta sprite_tile_data, y
@no_adjust:
    rts

; this sub routine hides a sprite if it is outside of
; the players visible range
; in low visiblity mode
; inputs:
;   load_flags -> to test for low visibility mode
;   sprite_ptr -> pointing to the sprite in question
;   player_x and player_y -> player position
;   get_tile_x and get_tile_y -> sprites positon
; returns:
;   a = 0 -> was offscreen
;   a = 1 -> was onscreen
; side effects:
;   changes sprites graphics to $24 (empty) if out of range
sprite_offscreen:
    lda load_flags
    and #%01000000
    beq @done ; if not in low mode skip

    ; check if x and y are offscreen
    lda player_x
    ldx get_tile_x
    jsr calc_distance
    cmp #VISIBILITY_RADIUS+1
    bcs @offscreen ; if greater it is offscreen

    lda player_y
    ldx get_tile_y
    jsr calc_distance
    cmp #VISIBILITY_RADIUS+1
    bcc @done
@offscreen:
    ldy #$01
    lda #$24
    sta (sprite_ptr), y
    lda #$00
    rts
@done:
    lda #$01
    rts

; this sub routine verifies a sprite move
; handles general collision
; inputs:
;   y -> pointing to sprite data offset
;   get_tile_x -> proposed x positon
;   get_tile_y -> proposed y position
; returns:
;   a = 0 -> no collision
;   a = 1 -> collision
;   sets bit 6 of sprite_tile_data to 1 if collision occured with empty tile
; side effects:
;   sprtie position is updated if no collision occurs
verify_sprite_move:
    sty temp ; need y value again

    ; verify that the move can go ahead
    jsr get_tile
    and #%01111111 ; bit 7 does not matter

    cmp #$24 ; empty tile
    bne @not_empty

    ldy temp ; need y value again
    ; if it is an empty tile set the disable flag,
    ; this will remove the sprite when the offset in
    ; tile_data reaches 0
    lda sprite_tile_data, y
    ora #%00100000
    sta sprite_tile_data, y

    ; this is a branch always since a is a constant value
    ; saves a byte
    bne @no_collision
@not_empty:
    cmp #CLEARABLE_TILES_START
    bcc @collision
    cmp #CLEARABLE_TILES_END
    bcs @collision

    ; test all active sprites to verify we are not colliding
    ldy sprite_tile_size
    cpy #$FF
    beq @no_collision
@sprite_collision_loop:
    lda sprite_tile_flags, y
    and #%10000000 ; check if sprite is enabled in the first place
    beq @skip ; if not, skip

    ; verify location matches, if so collision
    lda sprite_tile_x, y
    cmp get_tile_x
    bne @skip

    lda sprite_tile_y, y
    cmp get_tile_y
    beq @collision

@skip:
    dey
    cpy #$FF
    bne @sprite_collision_loop


@no_collision:
    ldy temp
    lda sprite_tile_data, y
    ora #$08 ; fine tuning offset for sprite to move
    sta sprite_tile_data, y

    lda get_tile_x
    sta sprite_tile_x, y
    lda get_tile_y
    sta sprite_tile_y, y

    lda #$00
    rts
@collision:
    ldy temp ; restore temp
    lda #$01
    rts

; this sub routine loops through all sprite tiles
; inputs:
;   player_x, _y
; returns:
;   a = 1 if collision occured
;   a = 0 if no collision
sprite_collision:
    ldx #$00
    txa
    pha ; push value to stack, this value is the collision result
    sta collision_counter ; reuse menu select to count amount of collisions
@loop:
    lda sprite_tile_flags, x
    and #%10000000 ; enable flag,
    beq @no_collision

    lda sprite_tile_x, x
    cmp player_x
    bne @no_collision

    lda sprite_tile_y, x
    cmp player_y
    beq @collision ; if both passed collision occured

@no_collision:
    inx
    cpx #SPRITE_TILES
    bne @loop


    pla ; pull result ; lda #$00
    rts
@collision:
    lda sprite_tile_ai, x
    tay

    ; call collision routine
    lda sprite_collision_lo, y
    sta src_ptr
    lda sprite_collision_hi, y
    sta src_ptr+1

    txa
    pha ; store x value for later
    tay ; put data offset into y

    jsr jsr_indirect
    sta temp
    pla
    tax ; get x value back

    pla
    ora temp
    pha ; next result

    inc collision_counter

    ; This was part of the code when
    ; collision was checked during time critical code
    ; it is now redundant
    ; lda collision_counter
    ; cmp #$02 ; no more than 3 please
    ; bne @no_wait
    ; lag frame if too many collisions happen
    ; lda #$00
    ; sta collision_counter
    ; vblank_wait
    ; sta $2005
    ; sta $2005 ; no scroll
; @no_wait:
    jmp @no_collision


; default sprite init, no special stuff
; inits the sprite as a barrier
; this routine should not destroy any registers
; inputs:
;   y -> pointing to sprite data offset
sprite_init_default:
    pha
    tya
    pha
    txa
    pha

    ; reset sprite flags and data
    lda #$00
    sta sprite_tile_data, y
    sta sprite_tile_temp, y

    lda level
    sta sprite_tile_hp, y

    lda #%00000000 ; turn off because collision is handeled by tile in this case
    sta sprite_tile_flags, y

    ; set up location
    lda sprite_tile_obj, y
    tax
    lda obj_index_to_addr, x
    sta sprite_ptr

    tya
    tax ; need y value, but need y for indirect,y

    lda sprite_tile_x, x
    sta temp
    lda sprite_tile_y, x
    sta temp+1

    ldx temp+1
    lda tile_convert_table, x ; y position
    ldy #$00 ; for indirect, y
    sta (sprite_ptr), y

    ldx temp
    lda tile_convert_table, x ; x position
    ldy #$03
    sta (sprite_ptr), y

    pla
    tax
    pla
    tay
    pla
    rts

; default sprite update routine
; this routine should not destry any registers
; updates a barrier sprite
; inputs:
;   y -> pointing to sprite data offset
;   stores if it was already onscreen once in sprite_tile_temp
sprite_update_default:
    pha
    tya
    pha
    txa
    pha

    tya
    pha ; push y value for later

    ; test hit flag
    ; this gets triggered every frame
    ; due to the hit flag being cleared
    ; this is fine as long as weapon timer is even
    ; and gives a flickering effect
    lda sprite_tile_flags, y
    and #%01000000
    bne @not_hit
    ; test for sword hit
    lda weapon_x
    cmp sprite_tile_x, y
    bne @not_hit
    lda weapon_y
    cmp sprite_tile_y, y
    bne @not_hit
    ; invert barrier on hit, wastes a turn
    lda map_flags
    eor #%10000000
    sta map_flags
    ; set hit flag, this flag is reset at the end of attack animation only
    lda sprite_tile_flags, y
    ora #%01000000
    sta sprite_tile_flags, y
@not_hit:

    ; load x position
    ldx sprite_tile_x, y
    stx get_tile_x
    lda tile_convert_table, x
    sta temp

    ; load y position
    ldx sprite_tile_y, y
    stx get_tile_y
    lda tile_convert_table, x
    sta temp+1

    ; set up pointer
    lda sprite_tile_obj, y
    tax
    lda obj_index_to_addr, x
    sta sprite_ptr

    ; check if barrier flag is set, if so make
    ; tile appear as barrier
    lda map_flags
    and #%10000000
    bne @barrier_clear

    ; barrier is not clear
    lda #%10000000
    sta sprite_tile_flags, y

    lda #$50
    bne @done

    ; barrier is clear
@barrier_clear:
    lda #%00000000
    sta sprite_tile_flags, y

    lda #$24 ; empty
@done:
    ; store in sprite
    ldy #$01
    sta (sprite_ptr), y

    ; positon sprite
    ldy #$00
    lda temp+1
    sta (sprite_ptr), y

    ; attributes
    lda #$00
    ldy #$02
    sta (sprite_ptr), y

    ldy #$03
    lda temp
    sta (sprite_ptr), y

    ; avoid moving offscreen if
    ; it was alrady onscreen once before
    pla
    tay
    lda sprite_tile_temp, y
    bne @no_offscreen
    sty temp+1 ; need it again
    jsr sprite_offscreen
    ldy temp+1
    sta sprite_tile_temp, y
@no_offscreen:

    pla
    tax
    pla
    tay
    pla
    rts

; same routine as above, but it inverts the barrier behaviour
sprite_update_barrier_invert:
    pha
    tya
    pha
    txa
    pha

    tya
    pha ; keep y for later

    ; test hit flag
    ; this gets triggered every frame
    ; due to the hit flag being cleared
    ; this is fine as long as weapon timer is even
    ; and gives a flickering effect
    lda sprite_tile_flags, y
    and #%01000000
    bne @not_hit
    ; test for sword hit
    lda weapon_x
    cmp sprite_tile_x, y
    bne @not_hit
    lda weapon_y
    cmp sprite_tile_y, y
    bne @not_hit
    ; invert barrier on hit, wastes a turn
    lda map_flags
    eor #%10000000
    sta map_flags
    ; set hit flag, this flag is reset at the end of attack animation only
    lda sprite_tile_flags, y
    ora #%01000000
    sta sprite_tile_flags, y
@not_hit:

    ; load x position
    ldx sprite_tile_x, y
    stx get_tile_x
    lda tile_convert_table, x
    sta temp

    ; load y position
    ldx sprite_tile_y, y
    stx get_tile_y
    lda tile_convert_table, x
    sta temp+1

    ; set up pointer
    lda sprite_tile_obj, y
    tax
    lda obj_index_to_addr, x
    sta sprite_ptr

    ; check if barrier flag is set, if so make
    ; tile appear as barrier
    lda map_flags
    and #%10000000
    sta sprite_tile_flags, y
    beq @barrier_clear

    ; barrier is not clear
    lda #$50
    bne @done

    ; barrier is clear
@barrier_clear:
    lda #$24 ; empty
@done:
    ; store in sprite
    ldy #$01
    sta (sprite_ptr), y

    ; positon sprite
    ldy #$00
    lda temp+1
    sta (sprite_ptr), y

    ldy #$03
    lda temp
    sta (sprite_ptr), y

    ; attributes
    lda #$00
    ldy #$02
    sta (sprite_ptr), y

    ; avoid moving offscreen if
    ; it was alrady onscreen once before
    pla
    tay
    lda sprite_tile_temp, y
    bne @no_offscreen
    sty temp+1 ; need it again
    jsr sprite_offscreen
    ldy temp+1
    sta sprite_tile_temp, y
@no_offscreen:


    pla
    tax
    pla
    tay
    pla
    rts

; default sprite on collision handler
; inputs:
;   y -> pointing to sprite data offset
; returns:
;   a = 1 if collision was valid
;   a = 0 when collision was invalid
sprite_on_collision:
    lda #$01
    rts


; inits the push tile
; inputs:
;   y -> sprite data offset
sprite_init_push:
    pha
    tya
    pha
    txa
    pha

    jsr sprite_init_default

    lda #$80 ; enable flag
    sta sprite_tile_flags, y

    pla
    tax
    pla
    tay
    pla
    rts

    rts

; this sub routine updates a push block
; inputs:
;   y -> pointing to sprite data offset
; sprite data documentation:
;   this AI type uses sprite_data as an offset to its x or y position
;   the lower 4 bits are the actual offset value
;   7th bit = 1 -> sbc; = 0 -> adc
;   6th bit = 1 -> x position; = 0 -> y position
;   5th bit = 1 -> inits falling animation, if lower 4 bits are 0 hides sprite
;   stores if object was on-screen before in sprite_tile_temp:
;   0th bit = 1 -> was oncreen before
sprite_update_push:
    pha
    tya
    pha
    txa
    pha

    jsr sprite_pos_adjust

    lda #$37
    sta temp+2 ; sprite value
    ; check data flag to see if we need to disable
    lda sprite_tile_data, y
    and #%00100000 ; both flag needs to be set and the offset needs to be 0
    beq @no_disable

    ; load smaller sprite
    lda #$39
    sta temp+2

    lda sprite_tile_data, y
    and #%00001111 ; although both need to be true it needs to be 2 checks
    bne @no_disable
    lda #$24 ; empty tile
    sta temp+2
@no_disable
    

    ; set up pointer
    lda sprite_tile_obj, y
    tax
    lda obj_index_to_addr, x
    sta sprite_ptr

    ; set up sprite values for oov check
    lda sprite_tile_x, y
    sta get_tile_x
    lda sprite_tile_y, y
    sta get_tile_y

    tya
    pha ; need y again later

    ldy #$00
    lda temp+1
    sta (sprite_ptr), y

    iny
    lda temp+2
    sta (sprite_ptr), y

    ; attributes
    lda #$00
    ldy #$02
    sta (sprite_ptr), y

    ldy #$03
    lda temp
    sta (sprite_ptr), y

    pla
    tay
    lda sprite_tile_temp, y
    bne @no_offscreen
    sty temp+1 ; need it again
    jsr sprite_offscreen
    ldy temp+1
    sta sprite_tile_temp, y
@no_offscreen:
    pla
    tax
    pla
    tay
    pla
    rts


    rts

; this sub routine handles collision with a push sprite
; inputs:
;   y -> pointing to sprite data offset
sprite_push_collision:
    ; check which direction the player is coming from
    lda player_y
    cmp player_y_bac
    beq @not_up_down ; if equal skip
    bcs @down ; if greater than player went down


@up:
    ldx sprite_tile_y, y
    dex
    stx get_tile_y
    ldx sprite_tile_x, y
    stx get_tile_x

    lda #%01000000
    sta sprite_tile_data, y

    jmp @tile_got

@down:
    ldx sprite_tile_y, y
    inx
    stx get_tile_y
    ldx sprite_tile_x, y
    stx get_tile_x

    lda #%11000000
    sta sprite_tile_data, y

    jmp @tile_got

@not_up_down:
    lda player_x
    cmp player_x_bac
    beq @not_left_right ; if equal skip
    bcs @right ; if greater player went right


@left:
    ldx sprite_tile_x, y
    dex
    stx get_tile_x
    ldx sprite_tile_y, y
    stx get_tile_y

    lda #%00000000
    sta sprite_tile_data, y

    jmp @tile_got
@right:
    ldx sprite_tile_x, y
    inx
    stx get_tile_x
    ldx sprite_tile_y, y
    stx get_tile_y

    lda #%10000000
    sta sprite_tile_data, y

    jmp @tile_got


@not_left_right:
@collision:
    lda #$01
    rts

@tile_got:
    jsr verify_sprite_move

    pha
    bne @no_noise ; no collision
    jsr init_push_noise
@no_noise:
    pla 

    rts

; this sub routine handles collision with a key sprite
; if touched increments key count by 1 and disables sprite
; inputs:
;   y -> pointing to sprite data offset
sprite_key_collision:
    ; test collected flag
    lda sprite_tile_data, y
    and #%10000000
    bne @done

    ; add one to key count and flag key as collected
    inc key_count
    lda #$F0
    sta sprite_tile_data, y

@done:
    lda #$00
    rts

; this sub routine updates key sprites
; inputs:
;   y -> pointing to sprite data offset
; sprite data documentation:
;   7th bit = 1 -> key was collected, disable functionality
sprite_key_update:
    pha
    tya
    pha
    txa
    pha

    ; load x position
    ldx sprite_tile_x, y
    lda tile_convert_table, x
    sta temp

    ; load y position
    ldx sprite_tile_y, y
    lda tile_convert_table, x
    sta temp+1

    ; test if key is makred as collected
    lda sprite_tile_data, y
    and #%10000000
    bne @collected

    ; enable sprite for collision
    lda #$F0
    sta sprite_tile_flags, y

    ; set up pointer
    lda sprite_tile_obj, y
    tax
    lda obj_index_to_addr, x
    sta sprite_ptr

    ; set up sprite values for oov check
    lda sprite_tile_x, y
    sta get_tile_x
    lda sprite_tile_y, y
    sta get_tile_y

    ldy #$00
    lda temp+1
    sta (sprite_ptr), y

    iny
    lda #$59
    sta (sprite_ptr), y

    ldy #$03
    lda temp
    sta (sprite_ptr), y

    jmp @offscreen_check
@collected:
    ; enable sprite for no collision
    lda #$00
    sta sprite_tile_flags, y

    ; set up pointer
    lda sprite_tile_obj, y
    tax
    lda obj_index_to_addr, x
    sta sprite_ptr

    ; set up sprite values for oov check
    lda sprite_tile_x, y
    sta get_tile_x
    lda sprite_tile_y, y
    sta get_tile_y

    ; if it was collected we display the key in the bottom left
    ; corner to indicate a key is in players posession unless key count is 0

    ldy #$00
    lda #$D0
    sta (sprite_ptr), y

    ldy #$03
    lda #$10
    sta (sprite_ptr), y

    ; attributes
    lda #$00
    ldy #$02
    sta (sprite_ptr), y

    lda key_count
    beq @no_key

    ldy #$01
    lda #$59
    sta (sprite_ptr), y

    jmp @done
@no_key:
    ldy #$01
    lda #$24
    sta (sprite_ptr), y
    jmp @done
@offscreen_check:
    jsr sprite_offscreen
@done:
    pla
    tax
    pla
    tay
    pla

    rts

; this sub routine handles collision with a door sprite
; doors only allow passage if keycound > 0
; dec key count by 1 when passed and disables door
; inputs:
;   y -> pointing to sprite data offset
; sprite data documentation:
;   7th bit = 1 -> door was opened, disable functionality
sprite_door_collision:
    ; test if sprite is enabled
    lda sprite_tile_data, y
    and #%10000000
    bne @done

    lda key_count
    bne @got_key
    lda #$01
    rts ; do not let palyer proceed without a key
@got_key:
    lda #$F0
    sta sprite_tile_data, y
    dec key_count

@done:
    lda #$00
    rts

; this sub routine handles door sprite updates
; inputs:
;   y -> pointing to sprite data offset
;   keep on-screen results in sprite_tile_temp
sprite_door_update:
    pha
    tya
    pha
    txa
    pha

    tya
    pha ; need y for later

    ; load x position
    ldx sprite_tile_x, y
    lda tile_convert_table, x
    sta temp

    ; load y position
    ldx sprite_tile_y, y
    lda tile_convert_table, x
    sta temp+1


    ; if hp is 0 door is open
    lda sprite_tile_hp, y
    beq @door_open

    ; check sword collision
    lda weapon_x
    cmp sprite_tile_x, y
    bne @no_weapon_hit
    lda weapon_y
    cmp sprite_tile_y, y
    bne @no_weapon_hit

    ; test if hit already occured once this attack cycle
    lda sprite_tile_flags, y
    and #%01000000
    bne @no_weapon_hit

    ; need to transfer y -> x
    tya
    tax
    dec sprite_tile_hp, x ; dec hp

    lda sprite_tile_flags, y
    ora #%01000000
    sta sprite_tile_flags, y

@no_weapon_hit:

    ; load tile
    lda sprite_tile_data, y
    and #%10000000
    beq @door_locked

@door_open:
    lda #$24
    sta temp+2
    lda #$00
    sta sprite_tile_flags, y ; disable collision

    jmp @tile_found
@door_locked:
    lda #$5A
    sta temp+2
    ; enable sprite for collision
    lda #%10000000
    ora sprite_tile_flags, y
    sta sprite_tile_flags, y

@tile_found:

    ; set up pointer
    lda sprite_tile_obj, y
    tax
    lda obj_index_to_addr, x
    sta sprite_ptr

    ; set up sprite values for oov check
    lda sprite_tile_x, y
    sta get_tile_x
    lda sprite_tile_y, y
    sta get_tile_y

    ldy #$00
    lda temp+1
    sta (sprite_ptr), y

    iny
    lda temp+2
    sta (sprite_ptr), y

    ldy #$03
    lda temp
    sta (sprite_ptr), y

    ; attributes
    lda #$00
    ldy #$02
    sta (sprite_ptr), y


    ; avoid moving offscreen if
    ; it was alrady onscreen once before
    pla
    tay
    lda sprite_tile_temp, y
    bne @no_offscreen
    sty temp+1 ; need it again
    jsr sprite_offscreen
    ldy temp+1
    sta sprite_tile_temp, y
@no_offscreen:

    pla
    tax
    pla
    tay
    pla

    rts

; updates skelleton sprite
; inputs:
;   y -> pointing to sprite data offset
; AI behaviour:
;   if player is within a distance of 10 tiles
;   the AI will try to move towards said tile
;   it will always prefer a path
;   that directly reduces the distance,
;   it will prefer the following directions:
;   down, up, left, right
;   if it is unable to reduce the distance it will pick
;   a direction that increases it by its preference
;   it will only make its next move once
;   the player has 0 actions remaining
; temp data:
;   temp holds the previous move, this is read by
;   the movement routine to prevent moving back
sprite_skel_update:
    pha
    tya
    pha
    txa
    pha

    lda #%10000000 ; enable collison
    ora sprite_tile_flags, y
    sta sprite_tile_flags, y

    ; check if new position is the same as player
    lda sprite_tile_y, y ; y position
    cmp player_y
    bne @no_collision
    lda sprite_tile_x, y ; x position
    cmp player_x
    bne @no_collision
    ; if collision trigger skel collision code
    jsr sprite_skel_collision
@no_collision

    ; test hit flag fisrt
    lda sprite_tile_flags, y
    and #%01000000
    bne @no_weapon_hit

    ; if position is the same as
    ; the player's weapon
    ; we move this sprite 0/0
    lda sprite_tile_x, y
    cmp weapon_x
    bne @no_weapon_hit
    lda sprite_tile_y, y
    cmp weapon_y
    bne @no_weapon_hit

    ; only play noise if location is not already 0/0
    lda sprite_tile_hp, y
    beq @no_weapon_hit
    jsr init_hit_noise
@no_noise:
    ; set hit flag, this flag is reset at the end of attack animation only
    lda sprite_tile_flags, y
    ora #%01000000
    sta sprite_tile_flags, y

    ; first reduce hp, if hp 0 then move offscreen
    ; tya
    ; tax ; need y -> x for dec
    ; apply weapon damage
    lda sprite_tile_hp, y
    sec
    sbc player_damage
    sta sprite_tile_hp, y
    ; dec sprite_tile_hp, x
    beq @zero_hp ; if equal 0 hp
    bcs @not_zero_hp ; if carry less than 0 was reached

@zero_hp:
    ; call damage animation
    lda sprite_tile_x, y
    sta get_tile_x
    lda sprite_tile_y, y
    sta get_tile_y
    jsr init_damage_animation

    lda #$00
    sta sprite_tile_hp, y ; 0 hp

    ; roll rng to decide if sprite becomes a coin
    jsr random
    lda rand8
    and #$01 ; if 0th bit is set turn AI into coin
    beq @no_coin
    lda #$0E ; coin AI
    sta sprite_tile_ai, y
    jmp @no_move
@no_coin:
    lda #$00
    sta sprite_tile_x, y
    sta sprite_tile_y, y
@not_zero_hp:
    ; after hit move away from player
    ; by setting player's direction as last direction
    lda last_move
    sta sprite_tile_temp, y

    jmp @no_move
@no_weapon_hit:

    ; movement code

    lda sprite_tile_ai, y
    cmp #$05 ; skel AI
    beq @skel_sprite
    cmp #$07 ; bat AI
    beq @bat_sprite
    cmp #$08 ; also bat AI
    beq @bat_sprite
    cmp #$09 ; mimic AI
    beq @mimic_sprite
    cmp #$0D ; archer AI
    beq @archer_sprite
@skel_sprite:
    ; decide what sprite to use
    lda #$34
    sta temp+2 ; sprite gfx
    bne @sprite_picked
@bat_sprite
    lda #$35
    sta temp+2 ; bat sprite
    bne @sprite_picked

@mimic_sprite:
    lda #$36
    sta temp+2 ; mimic sprite
    bne @sprite_picked
@archer_sprite:
    lda #$3E
    sta temp+2
@sprite_picked:

    lda actions
    beq @move
    jmp @no_move
@move:
    ; save locations
    ; in case it tries to go oob
    lda sprite_tile_y, y
    pha
    lda sprite_tile_x, y
    pha


    ; compare which AI is loaded
    ; this is because all enemies share the same logic, apart
    ; fro mthe way the direction is picked
    ; for now there is only one moveable AI type
    lda sprite_tile_ai, y
    cmp #$05 ; skel AI
    beq @skel_move_logic
    cmp #$07 ; bat AI
    beq @bat_up_move_logic
    cmp #$08 ; bat left AI
    beq @bat_left_move_logic
    cmp  #$09 ; mimic move AI
    beq @mimic_move_logic
    ; skel/archer move logic, random
@skel_move_logic:
    ; pick a direction to move in randomly
    jsr random
    and #%00000111
    jmp @direction_pick

@bat_up_move_logic:
    lda #$01 ; always up
    bne @direction_pick

@bat_left_move_logic:
    lda #$00
    beq @direction_pick

@mimic_move_logic:
    lda last_move

@direction_pick:
    beq @left
    cmp #UP
    beq @up
    cmp #RIGHT
    beq @right
    cmp #DOWN
    beq @down

@resume_direction:
    ; otherwise just keep going the same way
    ; this is eaily done by just shifting bits in
    ; data
    lda sprite_tile_data, y
    and #%11000000
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    jmp @direction_pick

@down:
    ; check previous move
    lda sprite_tile_temp, y
    cmp #UP
    beq @up

    lda sprite_tile_y, y
    tax
    inx
    stx get_tile_y

    lda sprite_tile_x, y
    sta get_tile_x

    lda #%11000000 ; down animation
    sta sprite_tile_data, y
    bne @tile_found_preference ; branch always
@up:
    lda sprite_tile_temp, y
    cmp #DOWN
    beq @down

    lda sprite_tile_y, y
    tax
    dex
    stx get_tile_y

    lda sprite_tile_x, y
    sta get_tile_x

    lda #%01000000 ; up animation
    sta sprite_tile_data, y
    bne @tile_found_preference ; branch always
@right:
    lda sprite_tile_temp, y
    cmp #LEFT
    beq @left

    lda sprite_tile_x, y
    tax
    inx
    stx get_tile_x

    lda sprite_tile_y, y
    sta get_tile_y

    lda #%10000000 ; right animation
    sta sprite_tile_data, y
    bne @tile_found_preference ; branch always
@left:
    lda sprite_tile_temp, y
    cmp #RIGHT
    beq @right

    lda sprite_tile_x, y
    tax
    dex
    stx get_tile_x

    lda sprite_tile_y, y
    sta get_tile_y

    lda #%00000000 ; left animation
    sta sprite_tile_data, y
    bne @tile_found_preference ; branch always

@tile_found_preference:
    ; verify move based on preference, if collision happenes
    ; pick first best non-collision tile that is allowed
    jsr verify_sprite_move
    cmp #$01
    beq @collision
    ; if 6th bit of data is set restore positon and dont have any movement
    lda sprite_tile_data, y
    and #%00100000
    beq @no_empty_tile

@collision:
    ; store the bad previous move so the AI
    ; does not pick it again
    lda sprite_tile_data, y
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    eor #%00000010 ; eor this bit to invert the invalid move
    sta sprite_tile_temp, y ; store invalid move to allow next move to proceed regardless

    lda #$00
    sta sprite_tile_data, y ; no animation

    pla
    sta sprite_tile_x, y
    pla
    sta sprite_tile_y, y
    jmp @no_move ; done

@no_empty_tile:
    pla
    pla ; just pull

    ; store previous move
    lda sprite_tile_data, y
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr ; 6 shifts to get the correct number
    sta sprite_tile_temp, y ; store it
@no_move:

    ; test for archer AI
    lda sprite_tile_ai, y
    cmp #$0D
    bne @not_archer
    ; test if moves are 0
    lda actions
    bne @not_archer

    ; special archer AI may spawn projectile if player is
    ; in front of it
    jsr random
    lda rand8
    and #$0F
    cmp #$02
    bcs @not_archer ; don't shoot

    lda sprite_tile_x, y
    sta get_tile_x
    lda sprite_tile_y, y
    sta get_tile_y

    ; check if x position is the same
    lda player_x
    cmp get_tile_x
    bne @not_x
    ; if x test which direction to shoot
    lda player_y
    cmp get_tile_y
    bcs @shoot_down
    lda #UP
    jsr spawn_projectile
    jmp @not_archer
@shoot_down:
    lda #DOWN
    jsr spawn_projectile
    jmp @not_archer
@not_x:

    lda player_y
    cmp get_tile_y
    bne @not_y
    ; if y test which direction to shoot
    lda player_x
    cmp get_tile_x
    bcs @shoot_right
    lda #LEFT
    jsr spawn_projectile
    jmp @not_archer
@shoot_right:
    lda #RIGHT
    jsr spawn_projectile
@not_y:

@not_archer:


    jsr sprite_pos_adjust
    ; set up pointer
    lda sprite_tile_obj, y
    tax
    lda obj_index_to_addr, x
    sta sprite_ptr

    ; set up sprite values for oov check
    lda sprite_tile_x, y
    sta get_tile_x
    lda sprite_tile_y, y
    sta get_tile_y

    ldy #$00
    lda temp+1
    sta (sprite_ptr), y

    ldy #$03
    lda temp
    sta (sprite_ptr), y

    ; attributes
    lda #$00
    ldy #$02
    sta (sprite_ptr), y

    ldy #$01
    lda temp+2 ; sprite to load
    sta (sprite_ptr), y

    ; oov check
    jsr sprite_offscreen

@done:
    pla
    tax
    pla
    tay
    pla

    rts

; handles collision with skelleton sprite
; inputs:
;   y -> pointing to sprite data offset
sprite_skel_collision:
    lda iframes
    beq @hit
    rts ; no hit if iframes are enabled

@hit:
    lda level ; 1 damage per level
    jsr take_damage
    beq @reload
    rts 
@reload:
game_over:
    ; TODO set up delay timer to play death animation
    lda #<empty_sub
    sta delay_update
    lda #>empty_sub
    sta delay_update+1

    lda #<@reload_map
    sta delay_done
    lda #>@reload_map
    sta delay_done+1

    lda #$00
    sta delay_timer+1
    lda #$01
    sta delay_timer

@reload_map:
    ; init game over menu
    jsr init_game_over

    ; vblank_wait
    ; dec level ; dec leve to avoid a level increase on reload
    ; jsr reload_room ; on collision reload area
    ; jsr init_hit_noise
    rts

; sword pikcup AI
; inputs:
;   y -> pointing to sprite data offset
sprite_sword_collision:
    lda sprite_tile_data, y
    and #%10000000 ; disable flag
    bne @done
    ora #%10000000
    sta sprite_tile_data, y

    inc player_damage

    ; test which weapon type to give
    lda sprite_tile_ai, y
    cmp #$06
    bne @not_sword
    lda #$01 ; sword value
    bne @store_type
@not_sword:
    cmp #$0C
    bne @not_arrow
    lda #$02 ; arrow value
@not_arrow:
@store_type:
    sta weapon_type
@done:
    lda #$00 ; never return a collision value
    rts

; sprite pickup update
; inputs:
;   y -> pointing to sprite data offset
; Data:
;   7th bit -> collected, disable collision and draw next to key icon
sprite_sword_update:
    pha
    tya
    pha
    txa
    pha


    lda sprite_tile_data, y
    and #%10000000
    beq @enabled

    lda #$00
    sta sprite_tile_flags, y
    sta temp+2

    ; store position in UI
    lda #0*8
    sta temp

    lda #0*8
    sta temp+1

    jmp @done
@enabled:
    lda #%10000000
    sta sprite_tile_flags, y
    sta temp+2

    ; load x position
    ldx sprite_tile_x, y
    lda tile_convert_table, x
    sta temp

    ; load y position
    ldx sprite_tile_y, y
    lda tile_convert_table, x
    sta temp+1

@done:

    ; decide what sprite to use
    lda sprite_tile_ai, y
    cmp #$06
    bne @not_sword
    lda #$33
    sta temp+3
    bne @sprite_picked
@not_sword:
    cmp #$0C
    bne @not_arrow
    lda #$3D
    sta temp+3
    bne @sprite_picked
@not_arrow:
@sprite_picked:

    ; set up sprite values for oov check
    lda sprite_tile_x, y
    sta get_tile_x
    lda sprite_tile_y, y
    sta get_tile_y

    ; set up pointer
    lda sprite_tile_obj, y
    tax
    lda obj_index_to_addr, x
    sta sprite_ptr

    ldy #$00
    lda temp+1
    sta (sprite_ptr), y

    iny
    lda temp+3
    sta (sprite_ptr), y

    ldy #$03
    lda temp
    sta (sprite_ptr), y

    ; attributes
    lda #$00
    ldy #$02
    sta (sprite_ptr), y

    lda temp+2 ; holds enable flag
    beq @no_offscreen
    jsr sprite_offscreen

@no_offscreen:
    pla
    tax
    pla
    tay
    pla

    rts


; hp pikcup AI
; inputs:
;   y -> pointing to sprite data offset
sprite_hp_collision:
    lda sprite_tile_data, y
    and #%10000000 ; disable flag
    bne @done
    ora #%10000000
    sta sprite_tile_data, y

    ldx player_hp
    cpx #MAX_HP
    beq @no_inx
    inx
@no_inx:
    stx player_hp
@done:
    lda #$00 ; never return a collision value
    rts

; sprite hp update
; inputs:
;   y -> pointing to sprite data offset
; Data:
;   7th bit -> collected, disable collision and draw at 0 0
sprite_hp_update:
    pha
    tya
    pha
    txa
    pha


    lda sprite_tile_data, y
    and #%10000000
    beq @enabled

    lda #$00
    sta sprite_tile_flags, y

    ; store position in UI
    lda #00
    sta temp

    lda #00
    sta temp+1

    jmp @done
@enabled:
    lda #%10000000
    sta sprite_tile_flags, y

    ; load x position
    ldx sprite_tile_x, y
    lda tile_convert_table, x
    sta temp

    ; load y position
    ldx sprite_tile_y, y
    lda tile_convert_table, x
    sta temp+1

@done:


    ; set up pointer
    lda sprite_tile_obj, y
    tax
    lda obj_index_to_addr, x
    sta sprite_ptr

    ; set up sprite values for oov check
    lda sprite_tile_x, y
    sta get_tile_x
    lda sprite_tile_y, y
    sta get_tile_y

    ldy #$00
    lda temp+1
    sta (sprite_ptr), y

    iny
    lda #$3A
    sta (sprite_ptr), y

    iny
    lda #$02
    sta (sprite_ptr), y

    ldy #$03
    lda temp
    sta (sprite_ptr), y

    jsr sprite_offscreen

    pla
    tax
    pla
    tay
    pla

    rts


; armor pikcup AI
; inputs:
;   y -> pointing to sprite data offset
sprite_armor_collision:
    lda sprite_tile_data, y
    and #%10000000 ; disable flag
    bne @done
    ora #%10000000
    sta sprite_tile_data, y

    inc player_armor_base
    inc player_armor
@done:
    lda #$00 ; never return a collision value
    rts

; sprite pickup update
; inputs:
;   y -> pointing to sprite data offset
; Data:
;   7th bit -> collected, disable collision and draw next to key icon
sprite_armor_update:
    pha
    tya
    pha
    txa
    pha


    lda sprite_tile_data, y
    and #%10000000
    beq @enabled

    lda #$00
    sta sprite_tile_flags, y
    sta temp+2

    ; store position in UI
    lda #0*8
    sta temp

    lda #0*8
    sta temp+1

    jmp @done
@enabled:
    lda #%10000000
    sta sprite_tile_flags, y
    sta temp+2

    ; load x position
    ldx sprite_tile_x, y
    lda tile_convert_table, x
    sta temp

    ; load y position
    ldx sprite_tile_y, y
    lda tile_convert_table, x
    sta temp+1

@done:

    ; set up sprite values for oov check
    lda sprite_tile_x, y
    sta get_tile_x
    lda sprite_tile_y, y
    sta get_tile_y

    ; set up pointer
    lda sprite_tile_obj, y
    tax
    lda obj_index_to_addr, x
    sta sprite_ptr

    ldy #$00
    lda temp+1
    sta (sprite_ptr), y

    iny
    lda #$3C
    sta (sprite_ptr), y

    ldy #$03
    lda temp
    sta (sprite_ptr), y

    ; attributes
    lda #$00
    ldy #$02
    sta (sprite_ptr), y

    lda temp+2 ; holds enable flag
    beq @no_offscreen
    jsr sprite_offscreen

@no_offscreen:
    pla
    tax
    pla
    tay
    pla

    rts


; coin pikcup AI
; inputs:
;   y -> pointing to sprite data offset
sprite_coin_collision:
    lda sprite_tile_data, y
    and #%10000000 ; disable flag
    bne @done
    ora #%10000000
    sta sprite_tile_data, y

    inc coins
@done:
    lda #$00 ; never return a collision value
    rts

; sprite pickup update
; inputs:
;   y -> pointing to sprite data offset
; Data:
;   7th bit -> collected, disable collision and draw next to key icon
sprite_coin_update:
    pha
    tya
    pha
    txa
    pha


    lda sprite_tile_data, y
    and #%10000000
    beq @enabled

    lda #$00
    sta sprite_tile_flags, y
    sta temp+2

    ; store position in UI
    lda #0
    sta temp

    lda #0
    sta temp+1

    jmp @done
@enabled:
    lda #%10000000
    sta sprite_tile_flags, y
    sta temp+2

    ; load x position
    ldx sprite_tile_x, y
    lda tile_convert_table, x
    sta temp

    ; load y position
    ldx sprite_tile_y, y
    lda tile_convert_table, x
    sta temp+1

@done:

    ; set up sprite values for oov check
    lda sprite_tile_x, y
    sta get_tile_x
    lda sprite_tile_y, y
    sta get_tile_y

    ; set up pointer
    lda sprite_tile_obj, y
    tax
    lda obj_index_to_addr, x
    sta sprite_ptr

    ldy #$00
    lda temp+1
    sta (sprite_ptr), y

    iny
    lda #$3F
    sta (sprite_ptr), y

    ldy #$03
    lda temp
    sta (sprite_ptr), y

    ; attributes
    lda #$00
    ldy #$02
    sta (sprite_ptr), y

    lda temp+2 ; holds enable flag
    beq @no_offscreen
    jsr sprite_offscreen

@no_offscreen:
    pla
    tax
    pla
    tay
    pla

    rts



; this sub routine inits the damage animation
; uses sprites 04 05 06 07
; inputs:
;   get_tile_x
;   get_tile_y -> location of animation
; side effects:
;   overwrites x and a register
init_damage_animation:
    ldx get_tile_x
    ; set up x coordinate
    dex
    lda tile_convert_table, x
    clc
    adc #$04 ; move half a tile
    sta sprite_data_4+3
    sta sprite_data_5+3

    inx
    inx
    lda tile_convert_table, x
    sec
    sbc #$04 ; move half a tile
    sta sprite_data_6+3
    sta sprite_data_7+3

    ldx get_tile_y
    ; set up x coordinates
    dex
    lda tile_convert_table, x
    clc
    adc #$04 ; move half a tile
    sta sprite_data_4
    sta sprite_data_6

    inx
    inx
    lda tile_convert_table, x
    sec
    sbc #$04 ; move half a tile
    sta sprite_data_5
    sta sprite_data_7

    lda #$4B ; tile to use
    sta sprite_data_4+1
    sta sprite_data_5+1
    sta sprite_data_6+1
    sta sprite_data_7+1 

    rts

; moves damage animation off-screen
hide_damage_animation:
    lda #$00
    sta sprite_data_4
    sta sprite_data_4+3
    sta sprite_data_5
    sta sprite_data_5+3
    sta sprite_data_6
    sta sprite_data_6+3
    sta sprite_data_7
    sta sprite_data_7+3

    rts

; updates damage animation
; currently unused
update_damage_animation:
    lda sprite_data_4+2
    eor #%00100000 ; front/background bit
    sta sprite_data_4+2
    sta sprite_data_5+2
    sta sprite_data_6+2
    sta sprite_data_7+2
    rts 
