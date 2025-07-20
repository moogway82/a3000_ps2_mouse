; $VER: 1.5 (08.07.01)
; COPYRIGHT (C) 2001 RDC SOFTWARE
; Distributed under GPL license - see gpl.txt

; This is a part of ps2m package,
; you can obtain latest version at Aminet:

; ftp://ftp.wustl.edu/pub/aminet/hard/hack/ps2m.lha
; ftp://ftp.wustl.edu/pub/aminet/hard/hack/ps2m.readme

; Use mpasm or gpasm to compile. Select appropriate __CONFIG line below (to set fuses).

; ftp://ftp.wustl.edu/pub/aminet/dev/cross/devpic.lha
; ftp://ftp.wustl.edu/pub/aminet/dev/cross/devpic.readme


; processor
	LIST P=16F628A
	#include <p16f628a.inc>
	#include <macros.inc>
	radix dec


; fuses (uncomment depending on assembler):
	; for use with mpasm (_CPD_OFF to disable eeprom code protection)
	__CONFIG _LVP_OFF & _CPD_OFF     & _CP_OFF & _BODEN_ON & _MCLRE_OFF & _PWRTE_OFF & _WDT_ON & _INTRC_OSC_NOCLKOUT
	; for use with gpasm (_DATA_CP_OFF to disable eeprom code protection)
;	__CONFIG _LVP_OFF & _DATA_CP_OFF & _CP_OFF & _BODEN_ON & _MCLRE_OFF & _PWRTE_OFF & _WDT_ON & _INTRC_OSC_NOCLKOUT


; ---------------
; switches/config
; ---------------

POWER	equ	0
SPEED	equ	46

; ---------
; variables
; ---------

	cblock	0x20
		memstart:0	; pointer to start of memory
		count
		recvb
		recvc
		recvd:2
		recvdt
		sendata
		sendetc
		intw
		ints
		wdtp
		wdtm:2
		temp1
		currbyte
		xdif
		ydif
		xdir
		ydir
		xspeed:2
		yspeed:2
		xcount
		ycount
		xtemp
		ytemp
		flags
		extflags

		byte1
		byte2
		byte3
		byte4
		zdif
		zcount

		q0
		q1
		q2
		q3
		q4
		mem_end		; pointer to end of memory (+1 actually)
	endc

; ---------------
; bit definitions
; ---------------

fpkt1	equ	0
fpkt2	equ	1
fpkt3	equ	2
fbyte	equ	3
fnores	equ	4
fnofps	equ	5
fon	equ	6
fwheel	equ	7

ext200	equ	0
extime	equ	1	;ms "intellimouse explorer"
extnso	equ	2	;genius "netscroll optical"
extnof	equ	3
	if	POWER-1
extbut	equ	4
	endif


		org	0x00
; ----------------
; init PIC & mouse
; ----------------

start
	clrf	INTCON
	if	POWER
	movlw	b'10000001'
	else
	movlw	b'00000001'
	endif
	option
	goto	start_a


		org	0x04
; -----------------
; interrupt handler
; -----------------

int
	bcf	INTCON,1
	movwf	intw
	swapfw	STATUS
	movwf	ints
	bcf	recvd+1,2
	btfsc	PORTB,1
	bsf	recvd+1,2
	rrf	recvd+1, F
	rrf	recvd, F
	bsf	wdtp,5		;clear packet bit shift watchdog
	loop	ila,recvc
	movlf	11,recvc
	bsf	flags,fbyte
	movff	recvd,recvdt
ila	swapfw	ints
	movwf	STATUS
	swapf	intw, F
	swapfw	intw
	retfie


; ----------------------------
; init PIC & mouse - continued
; ----------------------------

start_a
	movlf	0xff,0x1f
	clrf	PORTA
	clrf	PORTB
	movlw	b'11111111'
	tris	PORTA
	tris	PORTB


; clear RAM

	movlf	memstart,FSR
	sublw	mem_end
clearam	clrf	INDF
	incf	FSR, F
	addlw	0xff
	bnz	clearam
	movlf	TRISB, FSR

; init variables

	movlf	24,wdtm
	movlf	11,recvc

; delay before turn mouse on

	callw	delayms,0
	if	POWER
	movlw	b'00001111'	;turn on mouse
	tris	PORTA
	callw	delayms,100
	movlw	b'00000001'	;enable pull-up
	option
	movlf	8,temp1
sla	callw	delayms,0
	loop	sla,temp1
	endif

; wait for mouse

	bcf	INDF,0		;inhibit I/O
	bsf	INDF,1
	callw	delayms,50
	callw	send,0xE8
	callw	send,3
	callw	send,0xE6
	callw	send,0xE6
	callw	send,0xE6
	callw	send,0xE9
	call	bwait		;receive status byte
	call	bwait		;receive resolution (value ignored)
	movwf	temp1		;0x33
	call	bwait		;receive reports per second
	sublw	0x55
	bnz	lms
	cmplf	0x33,temp1
	bnz	lms
	bsf	extflags,extnso
	goto	lwheel
lms	call	testms		;i.m.explorer compatible?
	bz	lh		;yes
	sublw	1		;intellimouse compatible?
	bnz	li		;no
	bsf	extflags,ext200
	call	testms		;i.m.explorer compatible?
	skipnz
lh	bsf	extflags,extime	;i.m.explorer compatible
lwheel	bsf	flags,fwheel	;intellimouse compatible
li	callw	send,0xe8	;set resolution
	callw	send,3		;8/mm
	callw	send,0xe6	;scaling 1:1
	callw	send,0xf3	;set 200fps
	callw	send,200
	callw	send,0xf4	;enable mouse in streaming mode
	call	cpoff


; -----------
; check mouse
; -----------

m_check	callw	send,0xE9
	bc	start		;no response? init mouse again
	sublw	0xFA		;ACK?
	bnz	start		;no ACK - init mouse again...
	call	bwait		;receive status byte
	bc	start
	andlw	b'01100000'	;leave only stream & enable flags
	sublw	b'00100000'	;must be stream and enabled
	bnz	start
	btfsc	flags,fnores
	goto	p_init
	call	bwait		;receive resolution (value ignored)
	bc	nores		;no resolution...
	btfsc	flags,fnofps
	goto	p_init
	call	bwait		;receive reports per second
	bc	nofps		;no fps
	goto	p_init

; no resolution & fps report

nores	bsf	flags,fnores
nofps	bsf	flags,fnofps

; ---------------------
; sync serial port init
; ---------------------

p_init
	movlf	3,recvb
	btfsc	flags,fwheel
	incf	recvb, F
	clrf	currbyte
	movfw	INDF
	xorfw	PORTB
	andlw	b'00000100'
	btfss	extflags,extnof
	skipnz
	goto	plb
	btfsc	INDF,3
	goto	pla
	bsf	extflags,extnof
	goto	plb
pla	bcf	flags,fon	;mouse off
	if	POWER
	movlw	b'11101111'	;XxYy off, power on
	tris	PORTA
	movlw	b'11111111'	;buttons and wheels off
	else
	movlw	b'11111111'	;buttons, wheels, XxYy off
	tris	PORTA
	endif
	tris 	PORTB
plb	bsf	INTCON,7	;global interrupt enable
	bsf	INTCON,4	;enable RB0 interrupt


; check shift flag - byte received

schk	btfss	flags,fbyte
	goto	pchk1
	bcf	flags,fbyte
	movfw	currbyte
	addlw	byte1
	movwf	FSR
	movff	recvdt,INDF
	movlf	TRISB, FSR
	incf	currbyte, F
	loop	tchk,recvb
	movlf	3,recvb
	btfsc	flags,fwheel
	incf	recvb, F
	clrf	currbyte
	bsf	flags,fpkt1
	movlf	24,wdtm
	goto	tchk

; check packet flag - packet received

pchk1	btfss	flags,fpkt1
	goto	pchk2
	bcf	flags,fpkt1
	bsf	flags,fpkt2
	clrf	xdir
	movlw	1
	btfsc	byte1,4
	movlw	255
	movf	byte2, F
	btfss	STATUS,Z
	movwf	xdir
	movfw	byte2
	btfsc	byte1,4
	sublw	0
	addfw	xdif
	btfsc	STATUS,C
	movlw	255
	movwf	xdif
	movwf	xspeed
	addwf	xspeed, F
	skipc
	addwf	xspeed, F
	skipc
	goto	tchk
	movlf	255,xspeed
	goto	tchk

pchk2	btfss	flags,fpkt2
	goto	pchk3
	bcf	flags,fpkt2
	bsf	flags,fpkt3
	clrf	ydir
	movlw	1
	btfsc	byte1,5
	movlw	255
	movf	byte3, F
	btfss	STATUS,Z
	movwf	ydir
	movfw	byte3
	btfsc	byte1,5
	sublw	0
	addfw	ydif
	btfsc	STATUS,C
	movlw	255
	movwf	ydif
	movwf	yspeed
	addwf	yspeed, F
	skipc
	addwf	yspeed, F
	skipc
	goto	tchk
	movlf	255,yspeed
	goto	tchk

pchk3	btfss	flags,fpkt3
	goto	tchk
	bcf	flags,fpkt3
	rlfw	byte1
	movwf	temp1
	rlf	temp1, F
	comfw	temp1
	andlw	b'00011100'

	movwf	temp1
	sublw	b'00011100'
	skipz
	call	cpoff
	btfss	flags,fon
	goto	p3lc
	movfw	INDF
	andlw	b'11100011'
	iorfw	temp1
	movwf	INDF
	btfss	flags,fwheel
	goto	p3lc
	btfss	extflags,extnso
	goto	p3la
	if	POWER
	movfw	byte1
	andlw	b'11000000'
	skipz
	bcf	INDF,5
	skipnz
	bsf	INDF,5
	else
	btfsc	byte1,6
	bcf	INDF,5
	btfss	byte1,6
	bsf	INDF,5
	bcf	extflags,extbut
	btfsc	byte1,7
	bsf	extflags,extbut
	endif
p3la	movfw	byte4
	btfss	extflags,extime
	goto	p3lb
	if	POWER
	andlw	b'00110000'
	skipz
	bcf	INDF,5
	skipnz
	bsf	INDF,5
	movfw	byte4
	else
	btfsc	byte4,5
	bcf	INDF,5
	btfss	byte4,5
	bsf	INDF,5
	bcf	extflags,extbut
	btfsc	byte4,4
	bsf	extflags,extbut
	endif
	andlw	b'00001111'
	btfsc	byte4,3
	iorlw	b'11110000'
p3lb	addwf	zdif, F
p3lc	;....


; check time to move

tchk	btfss	TMR0,7
	goto	schk
	sublf	SPEED,TMR0

; CPU watchdog

	clrwdt

; check mouse

mchk	loop	xchk,wdtm+1
	loop	xchk,wdtm
	movlf	24,wdtm
	bcf	INTCON,4	;disable RB0 interrupt
	movfw	recvb
	btfsc	flags,fwheel
	addlw	255
	sublw	3		;packet receive started?
	btfss	STATUS,Z
	goto	mchk_e		;yes
	movfw	recvc
	sublw	11		;byte receive started?
	btfss	STATUS,Z
	goto	mchk_e		;yes
	btfsc	PORTB,0		;bit receive started?
	goto	m_check		;no
mchk_e	bsf	INTCON,4	;enable RB0 interrupt

; check X movement

xchk	movfw	xspeed
	addwf	xspeed+1, F
	btfss	STATUS,C
	goto	ychk
	movf	xdif, F
	btfsc	STATUS,Z
	goto	ychk
	decf	xdif, F
	movfw	xdir
	subwf	xcount, F
	rrfw	xcount
	andlw	1
	xorfw	xcount
	andlw	3
	movwf	xtemp

; check Y movement

ychk	movfw	yspeed
	addwf	yspeed+1, F
	btfss	STATUS,C
	goto	zchk
	movf	ydif, F
	btfsc	STATUS,Z
	goto	zchk
	decf	ydif, F
	movfw	ydir
	addwf	ycount, F
	rrfw	ycount
	andlw	1
	xorfw	ycount
	andlw	3
	movwf	ytemp

; check wheel movement

zchk
	btfsc	extflags,extnof
	goto	zla
	if	POWER
	btfsc	PORTB,5
	goto	zla
	btfss	INDF,5
	goto	zla
	else
	btfsc	PORTA,4
	goto	zla
	decf	FSR, F
	movfw	INDF
	incf	FSR, F
	andlw	b'00010000'
	btfsc	STATUS,Z
	goto	zla
	endif
	movlf	2,zcount
	bsf	INDF,6
	bsf	INDF,7
	clrf	zdif
zla	movf	zdif, F
	bz	xyout
	movlw	1
	btfss	zdif,7
	sublw	0
	addwf	zdif, F
	addwf	zcount, F
	rrfw	zcount
	andlw	1
	xorfw	zcount
	movwf	temp1
	movfw	INDF
	andlw	b'00111111'
	btfsc	temp1,0
	iorlw	b'01000000'
	btfsc	temp1,1
	iorlw	b'10000000'
	btfsc	flags,fon
	movwf	INDF


; XY movement out

xyout	bcf	STATUS,C
	rlfw	xtemp
	addfw	xtemp
	addfw	xtemp
	iorfw	ytemp
	if	POWER-1
	btfss	extflags,extbut
	iorlw	b'00010000'
	endif
	iorlw	b'11000000'
	btfsc	flags,fon
	tris	PORTA

; packet bit shift watchdog

wchk
	loop	schk,wdtp
	bcf	INTCON,4	;disable RB0 interrupt
	movf	wdtp, F
	btfss	STATUS,Z
	goto	wla
	movlf	11,recvc
	bsf	wdtp,5
	goto	p_init
wla	bsf	INTCON,4	;enable RB0 interrupt
	goto	schk


; check power off

cpoff	btfsc	flags,fon
	return
	comfw	PORTA
	andlw	b'00001111'
	btfsc	STATUS,Z
	btfss	PORTB,2
	return
	bsf	flags,fon
	movlf	3,xtemp
	movwf	ytemp
	movlf	2,xcount
	movwf	ycount
	movwf	zcount
	return

; try to switch to MS-like wheel mode

testms	callw	send,0xf3
	callw	send,200
	callw	send,0xf3
	movlw	100
	btfsc	extflags,ext200
	movlw	200
	call	send
	callw	send,0xf3
	callw	send,80
	callw	send,0xF2	;read mouse ID
	call	bwait
	sublw	4
	return

; ------------------
; send byte to mouse
; ------------------

send
	clrf	INTCON
	movwf	temp1
	movwf	sendata
	clrf	sendetc
	comf	sendetc, F
	bcf	INDF,0		;inhibit I/O
	callw	delayus,100
	movlf	8,count
	movlw	1
s2la	rrf	temp1, F		;calculate parity
	skipnc
	xorwf	sendetc, F
	loop	s2la,count
	movlf	11,count
	bsf	INDF,0
	bcf	INDF,1		;initiate send
s2lb	clrwdt
s2lc	btfsc	PORTB,0		;wait for 0
	goto	s2lc
	rrf	sendetc, F
	rrf	sendata, F
	btfss	STATUS,C
	bcf	INDF,1
	btfsc	STATUS,C
	bsf	INDF,1
s2ld	btfss	PORTB,0		;wait for 1
	goto	s2ld
	loop	s2lb,count
	clrf	INTCON

	; to be continued

; -----------------------
; receive byte from mouse
; -----------------------

bwait
	bsf	INTCON,7	;global interrupt enable
	bsf	INTCON,4	;enable RB0 interrupt
	movlf	40,count
bla	clrwdt
	callw	delayus,100
	btfss	flags,fbyte
	goto	blb
	bcf	flags,fbyte
	movfw	recvdt
	bcf	STATUS,C
	return
blb	loop	bla,count
	setc
	return


; ------
; delays
; ------

delayms
	movwf	count
dla	clrwdt
	movlw	249
dlb	addlw	0xff
	bnz	dlb
	loop	dla,count
	return


delayus	addlw	0xff
	bnz	delayus
	return

dprint	movwf	temp1
	movlw	b'01111111'
	tris	PORTB
	movlw	9
	movwf	count
dp_a	clrwdt
	btfsc	PORTB,6
	goto	dp_a
	movlw	b'01111111'
	bsf	STATUS,C
	rlf	temp1, F
	btfsc	STATUS,C
	movlw	b'11111111'
	tris	PORTB
dp_b	clrwdt
	btfss	PORTB,6
	goto	dp_b
	decfsz	count, F
	goto	dp_a
	return

	end
