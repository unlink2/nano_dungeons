; this sub routine inits audio
; side effects:
;   overwrites a register
init_audio_channels:
        ; Init $4000-4013
    ldy #$13
@loop:  lda @regs,y
    sta $4000,y
    dey
    bpl @loop

    ; We have to skip over $4014 (OAMDMA)
    ; enable Square 1, Square 2, Triangle and Noise channels.  Disable DMC.
    lda #$0F
    sta $4015
    lda #$40
    sta $4017

    ; set up audio pointers
    lda #<no_audio
    sta pulse_ptr_1
    sta pulse_ptr_2
    sta triangle_ptr
    sta noise_ptr

    lda #>no_audio
    sta pulse_ptr_1+1
    sta pulse_ptr_2+1
    sta triangle_ptr+1
    sta noise_ptr+1

    rts
@regs:
.db $30,$08,$00,$00
.db $30,$08,$00,$00
.db $80,$00,$00,$00
.db $30,$00,$00,$00
.db $00,$00,$00,$00

; this sub routine update all audio playback
; inputs:
;   pulse, triangle and noise_ptrs
; side effects:
;   updates audio timer and registers
;   user register a, x, y
update_audio:

    ; pulse 1 code
    ldy #$00
    lda (pulse_ptr_1), y
    cmp #$FF
    beq @not_pulse_1 ; no update

    ldx pulse_timer_1
    dex
    stx pulse_timer_1
    bne @not_pulse_1 ; if timer is not 0 do not play yet

    ldx pulse_periode_1
    stx pulse_timer_1 ; store periode again

    sta $4000 ; store channel settings

    iny
    lda (pulse_ptr_1), y
    tax ; note offset


    lda period_table_hi, x
    sta $4003
    lda period_table_lo, x
    sta $4002

    lda pulse_ptr_1
    clc
    adc #$02 ; add 2 for next pair
    sta pulse_ptr_1
    lda pulse_ptr_1+1
    adc #$00
    sta pulse_ptr_1+1

@not_pulse_1:

    ; pulse 2 code
    ldy #$00
    lda (pulse_ptr_2), y
    cmp #$FF
    beq @not_pulse_2 ; no update

    ldx pulse_timer_2
    dex
    stx pulse_timer_2
    bne @not_pulse_2 ; if timer is not 0 do not play yet

    ldx pulse_periode_2
    stx pulse_timer_2 ; store periode again

    sta $4004 ; store channel settings

    iny
    lda (pulse_ptr_2), y
    tax ; note offset


    lda period_table_hi, x
    sta $4007
    lda period_table_lo, x
    sta $4006

    lda pulse_ptr_2
    clc
    adc #$02 ; add 2 for next pair
    sta pulse_ptr_2
    lda pulse_ptr_2+1
    adc #$00
    sta pulse_ptr_2+1

@not_pulse_2:

    ; triangle code
    ldy #$00
    lda (triangle_ptr), y
    cmp #$FF 
    beq @not_triangle ; no update

    ldx triangle_timer
    dex
    stx triangle_timer
    bne @not_triangle ; if timer is not 0 do not play yet

    ldx triangle_periode
    stx triangle_timer ; store periode again

    sta $4008 ; store channel settings
    sta $4017

    iny
    lda (triangle_ptr), y
    tax ; note offset


    lda period_table_hi+12, x
    sta $400B
    lda period_table_lo+12, x
    sta $400A

    lda triangle_ptr
    clc
    adc #$02 ; add 2 for next pair
    sta triangle_ptr
    lda triangle_ptr+1
    adc #$00
    sta triangle_ptr+1

@not_triangle:

    ; triangle code
    ldy #$00
    lda (noise_ptr), y
    cmp #$FF
    beq @not_noise ; no update

    ldx noise_timer
    dex
    stx noise_timer
    bne @not_noise ; if timer is not 0 do not play yet

    ldx noise_periode
    stx noise_timer ; store periode again

    sta $400C ; store channel settings

    iny
    lda (noise_ptr), y

    sta $400E

    iny
    lda (noise_ptr), y
    sta $400F

    lda noise_ptr
    clc
    adc #$03 ; add 3 for next pair
    sta noise_ptr
    lda noise_ptr+1
    adc #$00
    sta noise_ptr+1

@not_noise:

    rts

; this sub routine plays a cursor beep
; noise
; side effects:
;   uses a register
;   loads sound into square 1 channel
init_cursor_beep:
    lda #<test_noise
    sta noise_ptr
    lda #>test_noise
    sta noise_ptr+1

    lda #10
    sta noise_periode ; 10 frames per periode

    lda #$01
    sta noise_timer

    rts
