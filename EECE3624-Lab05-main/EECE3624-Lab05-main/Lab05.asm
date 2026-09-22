/**************************************************************************
 *      File: Lab05.asm
 *  Lab Name: Pardon the Interruption...
 *    Author: Dr. Greg Nordstrom
 *   Created: 02/19/2021
 * Processor: ATmega128A (on the ReadyAVR board)
 *
 * Modified by: Julia Camille McCamey
 * Modified on: 09/22/2026
 *
 * This program implements a joystick to control the blink rate of an LED.
 * Blinks the "BOOT" LED at rate of ~1 to 15 Hz within 15 steps.
 * Toggle up increases rate by a step and toggle down decreases rate by a step.
 * Blink rate is displayed in 4-bit binary on LEDs 0-3 connected to PORTC.0 through PORTC.3
 *************************************************************************/

 /*********
 * Interrupt Jump Table
 *********/
.org 0x0000                 ; next instruction address is 0x0000
                            ; (the location of the reset vector)
rjmp main                   ; allow reset to run this program

.org 0x0004
rjmp int1_isr

.org 0x0008
rjmp int3_isr

 /*********
 * Interrupt setup
 *********/
.org 0x0010
LDI R16, (1<<ISC11)|(1<<ISC10) | (1<<ISC31)|(1<<ISC30) ;INT1 and INT3 rising edge trigger
STS EICRA, R16

LDI R16, (1<<INT1)|(1<<INT3) ; INT1 and INT3 interrupts
STS EIMSK, R16

LDI R16, 0x00
OUT DDRB, R16

LDI R16, 0x00
OUT DDRD, R16

LDI R16, (1<<PORTB1)|(1<<PORTB3)
OUT PORTB, R16

SEI

/**********
* Main code
**********/
.def BlinkFreq        = R20 ; holds blink rate (1-15 Hz)
.equ BlinkFreqMin     = 1
.equ BlinkFreqMax     = 15
.equ InitialBlinkFreq = BlinkFreqMin

.org 0x0020                 ; Move the "main" to 0x0020 to make room for ISRs
main:                       ; jump here on reset
    ldi R16, HIGH(RAMEND)   ; initialize stack (default RAMEND = 0x10FF)
    out SPH, R16
    ldi R16, low(RAMEND)
    out SPL, R16

    LDI R16, (1<<DDA7) ; Configure PORTA.7 as BOOT LED ouput
    OUT DDRA, R16      ; other PORTA pins as inputs

    LDI R16, (1<<DDC0)|(1<<DDC1)|(1<<DDC2)|(1<<DDC3)
    OUT DDRC, R16      ; PORTC.3:0 as outputs, others as inputs

    LDI BlinkFreq, InitialBlinkFreq ; +++
    
mainLoop:
    ; PORT.3:0 show BlinkFreq lower 4 bits +++
    MOV R17, BlinkFreq
    ANDI R17, 0x0F
    OUT PORTC, R17

    CBI  PORTA, PORTA7       ; turn BOOT LED on (active low) by clearing PORTA.7

    ; kill some time
    ldi R16, 16             ; R16 is outer loop counter ++
    SUB R16, BlinkFreq      ; R16 = 16 - BlinkFreq +++
outer_loop1:
    ldi R24, low(0xFFFF)     ; ~1 Hz when BlinkFreq = 1 ++
    ldi R25, high(0xFFFF)    ; ++
inner_loop1:
        sbiw R24, 1         ; decrement inner loop counter (R25:R24 pair)
        brne inner_loop1    ; loop back if R25:R24 isn't zero
    dec R16                 ; decrement the outer loop counter (R16)
    brne outer_loop1        ; loop back if R16 isn't zero

    sbi PORTA, PORTA7       ; turn BOOT LED off (active low) by setting PORTA.7

    ; kill some more time
    ldi R16, 16             ; R16 is outer loop counter ++
    SUB R16, BlinkFreq      ; R16 = 16 - BlinkFreq +++
outer_loop2:
    ldi R24, low(0xFFFF)     ; load low and high parts of R25:R24 pair with ++
    ldi R25, high(0xFFFF)    ; loop count by loading registers separately ++
inner_loop2:
        sbiw R24, 1         ; decrement inner loop counter (R25:R24 pair)
        brne inner_loop2    ; loop back if R25:R24 isn't zero
    dec R16                 ; decrement the outer loop counter (R16)
    brne outer_loop2        ; loop back if R16 isn't zero

    rjmp mainLoop           ; play it again, Sam...

/**********
* ISR code
**********/
.org 0x0200                         ; Load the ISR code higher than main code
int1_isr:
        CPI BlinkFreq, BlinkFreqMax
        BRGE Up_Done                ; >= max, skip increment
        INC BlinkFreq
Up_Done:
        MOV R17, BlinkFreq
        ANDI R17,0x0F      ; lower 4 bits
        OUT PORTC, R17
        RETI

.org 0x0220
int3_isr:
        CPI BlinkFreq, BlinkFreqMin
        BRLE Down_Done              ; <= min, skip decrement
        DEC BlinkFreq
Down_Done:
        MOV R17, BlinkFreq
        ANDI R17, 0x0F
        OUT PORTC, R17
        RETI
