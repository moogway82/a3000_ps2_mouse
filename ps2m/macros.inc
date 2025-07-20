addfw	macro freg
	addwf	freg, W
	endm

callw	macro target, literal
	movlw	literal
	call	target
	endm

cmplf	macro literal, freg
	movlw	literal
	subwf	freg, W
	endm

comfw	macro freg
	comf	freg, W
	endm

iorfw	macro freg
	iorwf	freg, W
	endm

loop	macro endl, count
	decfsz	count, F
	goto	endl
	endm

movff	macro sfreg, dfreg
	movf	sfreg, W
	movwf	dfreg
	endm

movlf	macro literal, freg
	movlw	literal
	movwf	freg
	endm

rlfw	macro freg
	rlf	freg, W
	endm

rrfw	macro freg
	rrf	freg, W
	endm

; skip if carry
skipc	macro
	btfss	STATUS, C
	endm

; skip if not carry
skipnc	macro
	btfsc	STATUS, C
	endm

; skip if not zero
skipnz	macro
	btfsc	STATUS, Z
	endm

; skip if zero
skipz	macro
	btfss	STATUS, Z
	endm

sublf	macro literal, freg
	movlw	literal
	subwf	freg, F
	endm

swapfw	macro freg
	swapf	freg, W
	endm

xorfw	macro freg
	xorwf	freg, W
	endm
