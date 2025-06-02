; Namco 52XX replacement
; ATMega8515 MCU
; V 1.0
; IZ8DWF 08/2024

.device  ATmega8515

; fuses: CKSEL3..0 = 0000 (external clock)
;        CKOPT = 1, BOOTRST = 1
;        HB 11011001 0xd9
;        LB 11100000 0xe0

; Inputs:
; Port A = byte read from ROM
; Port D7..4 = sample index from CPU (read during INT1)
; PE2 = /2732 read during initialization

; PB0 special  (T0 for external counter clock)
; PD3 special  (INT1)

; Outputs:
; PB1 = A9
; PB2 = A10
; PB3 = A11
; PB4 = A12 if /2732 = 1, /E0 if 0
; PB5 = A13 if /2732 = 1, /E1 if 0
; PB6 = A14 if /2732 = 1, /E2 if 0
; PB7 = A15 if /2732 = 1, /E3 if 0

; PC0..3  = OUT0..3  digital sample output
; PC7..4  = A7..4
; PD2..0  = A2..0
; PE1 = A3
; PE0 = A8

; registers map
; r0 = always 0
; r1 = /2732
; r2 = general purpose
; r3 = playing clip index
; r4 = used in address output routine
; r5 = status register save in interrupts

; r16 = general purpose always lost (DO NOT use in interrupts)
; r17 = clip index read from CPU
; r18 = general purpose (mostly used in ROM address output)
; r19 = current sample
; r20 = timer compare value/interrupt enable mask
; r21 = only used in timer interrupt routine
; r22 = only used in timer interrupt routine

; r24 = sample index

; r26 low, r27 high = X 
; r28 low, r29 high = Y
; r30 low, r31 high = Z

; ATMega8515 I/O space

.equ base = 0x0000
.equ init = 0x0011
.equ ram  = 0x0060
.equ ramend = 0x025f

.equ SREG = 0x3f
.equ SPH = 0x3e
.equ SPL = 0x3d
.equ GICR = 0x3b
.equ GIFR = 0x3a
.equ TIMSK = 0x39
.equ TIFR = 0x38
.equ SPMCR = 0x37
.equ EMCUCR = 0x36
.equ MCUCR = 0x35
.equ MCUCSR = 0x34
.equ TCCR0 = 0x33
.equ TCNT0 = 0x32
.equ OCR0 = 0x31
.equ SFIOR = 0x30
.equ TCCR1A = 0x2f
.equ TCCR1B = 0x2e
.equ TCNT1H = 0x2d
.equ TCNT1L = 0x2c
.equ OCR1AH = 0x2b
.equ OCR1AL = 0x2a
.equ OCR1BH = 0x29
.equ OCR1BL = 0x28
.equ ICR1H = 0x25
.equ ICR1L = 0x24
.equ WDTCR = 0x21
.equ UBRRH = 0x20
.equ UCSRC = 0x20
.equ EEARH = 0x1f
.equ EEARL = 0x1e
.equ EEDR = 0x1d
.equ EECR = 0x1c
.equ PORTA = 0x1b
.equ DDRA = 0x1a
.equ PINA = 0x19
.equ PORTB = 0x18
.equ DDRB = 0x17
.equ PINB = 0x16
.equ PORTC = 0x15
.equ DDRC = 0x14
.equ PINC = 0x13
.equ PORTD = 0x12
.equ DDRD = 0x11
.equ PIND = 0x10
.equ SPDR = 0x0f
.equ SPSR = 0x0e
.equ SPCR = 0x0d
.equ UDR = 0x0c
.equ UCSRA = 0x0b
.equ UCSRB = 0x0a
.equ UBRRL = 0x09
.equ ACSR = 0x08
.equ PORTE = 0x07
.equ DDRE = 0x06
.equ PINE = 0x05
.equ OSCCAL = 0x04


; ram/local constants 
; timer compare value on Pole Position should result in approx. 4 kHz sample
; reproduction rate.
.equ INTMAX	= 0x30	; internal timer compare (top) value

; timer compare value when using external clock. Assuming it's 1 cycle = 
; 1 sample. I've never seen an actual board using external clock so far
.equ EXTMAX	= 0x01	; external timer compare (top)  value

.cseg
.org base
	rjmp RESET
	rjmp DUMMYI	; external interrupt 0
	rjmp INT1	; external interrupt 1
	rjmp DUMMYI	; timer 1 capture
	rjmp DUMMYI	; timer 1 compare A
	rjmp DUMMYI	; timer 1 compare B
	rjmp DUMMYI	; timer 1 overflow 
	rjmp DUMMYI	; timer 0 overflow 
	rjmp DUMMYI	; SPI serial xfer complete 
	rjmp DUMMYI	; uart rxc
	rjmp DUMMYI	; uart udre
	rjmp DUMMYI	; uart txc
	rjmp DUMMYI	; analog comp
	rjmp DUMMYI	; external interrupt 2
	rjmp TMI	; timer 0 compare
	rjmp DUMMYI	; eeprom ready
	rjmp DUMMYI	; store program memory ready
	
.org init


INT1:
	in r17, PIND	; read sample clip index 
	in r5, SREG	; save status register
	andi r17, 0xf0  ; data is on high nibble only
	swap r17	; so put it on low nibble now
	out SREG, r5	; restore status
DUMMYI:	reti

TMI:
	in r5, SREG	; save status register
	in r21, PORTC
	andi r21, 0xf0
	mov r22, r19
	andi r22, 0x0f
	or r22, r21
	out PORTC, r22
	swap r19
	inc r24		; increment played sample index
	out SREG, r5	; restore status
	reti

RESET:	cli
	sbi ACSR, 7		; power off analog comparator
	clr r0
	clr r17			; clear sample index register
	out DDRA, r17		; port A is all inputs
	out PORTA, r17		; also disable pullups

	ldi r16, low(ramend)	; set stack pointer (low byte)
	out SPL, r16
	ldi r16, high(ramend)	; high byte now
	out SPH, r16

	ldi r16, 0xfe		
	out DDRB, r16		; PB1 to PB7 are outputs
	ldi r16, 0xff		
	out DDRC, r16		; PC0 to PC7 are outputs
	ldi r16, 0x07		
	out DDRD, r16		; PD0 to PD2  are outputs
	ldi r16, 0x03		
	out DDRE, r16		; PE0 and PE1 are outputs	
	cbi PORTE, 2		; disable pullup on PE2 input
	clr r1
	sbic PINE, 2		; check /2732 pin
	inc r1
	clr r27			; check configuration byte at ROM addr 0x0020
	ldi r26, 0x20
	rcall romrd
	in r18, PINA
	ldi r20, INTMAX		; set the timer top value
	ldi r16, 0x0a		; CTC, internal clock prescaler = 1/8
	cpi r18, 0xf0		; internal timer = 0xf0, external = 0xff
	breq timinit 
	ldi r20, EXTMAX
	ldi r16, 0x0f		; CTC, external clock rising edge
timinit:
	out OCR0, r20
	out TCCR0, r16
	ldi r20, 0x01		; timer interrupt on compare match
	
	in r16, MCUCR		; setup INT1 as falling edge
	ori r16, 0x08
	out MCUCR, r16
	in r16, GICR
	ori r16, 0x80		; enable INT1
	out GICR, r16
	sei			; enable interrupts

main:
	tst r17 		; waits for a clip index
	breq main		; (no clip playing if looping here)

clip:	rcall getadd		; get start/stop addresses of the clip to play
	clr r24			; clear sample index
	rcall rsamp		; get first sample pair in r19
	mov r3, r17	
	out TCNT0, r0		; timer is running, so reset its value
	out TIFR, r20		; then clear the interrupt flag 
	out TIMSK, r20		; then enable timer 0 OC interrupt
waitpl:	cpi r24, 0x02		; wait for current samples to be played
	brlo waitpl

	cp r29, r31		; check if we are at the end of the samples
	brne nextrd
	cp r28, r30
	brne nextrd
	out TIMSK, r0		; end: disable all timer 0/1 interrupts
	clr r17
	rjmp main

nextrd:	cp r3, r17		; see if we got a higher clip to play
	brlo clip		; yes, start the new one
	adiw r28, 0x01		; otherwise increment sample address
	rcall rsamp		; read a new sample pair in r19
	clr r24	
	rjmp waitpl

; subroutines


rsamp:	movw r26, r28
	rcall romrd
	in r19, PINA
	ret

getadd:				; gets start (Y) and stop (Z) addresses
				; of the clip index in r17
	clr r26
	clr r27
	add r26, r17		; low clip end address at 0x0000 + clip
	rcall romrd		
	in r30, PINA
	dec r26			; low clip start address at 0x0000 + clip - 1
	rcall romrd
	in r28, PINA		
	adiw r26, 0x10		; high clip start address at 0x0010 + clip - 1
	rcall romrd
	in r29, PINA
	inc r26			; high clip end address at 0x0010 + clip
	rcall romrd		
	in r31, PINA
	ret

romrd:				; gets the 16 bit address on r27,r26 and
				; sets the address lines for ROM access
				; needs in rXX, PINA after the call
	out PORTE, r0		; clears A3, A8
	mov r18, r26
	andi r18, 0x07		; lowest three addresses go on PORTD
	out PORTD, r18
	mov r18, r26
	andi r18, 0xf0		; A4 to A7 on PORTC	
	in r16, PORTC		
	andi r16, 0x0f
	or r16, r18
	out PORTC, r16
	sbrc r26, 3
	sbi PORTE, 1		; sets A3
	sbrc r27, 0
	sbi PORTE, 0		; sets A8
	
	ldi r16, 0xfe
	mov r18, r27 		
	tst r1			; check if 2732 mode
	brne haddr		; no, set all higher Axx

	andi r18, 0x30		; 2732 mode, need to assert one enable line
	swap r18
	clr r4
	sec
lop1:	rol r4
	tst r18
	breq end32
	dec r18
	rjmp lop1
end32:	swap r4
	eor r16, r4
	mov r18, r27
	ori r18, 0xf0
haddr:  and r18, r16
	out PORTB, r18
	ret			

