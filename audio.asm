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
update_audio:
    rts

; this sub routine plays a cursor beep
; noise
; side effects:
;   uses a register
;   loads sound into square 1 channel
init_cursor_beep:
    lda #<279
    sta $4002

    lda #>279
    sta $4003

    lda #%10111111
    sta $4000

    rts 
