; Y=frame
.heads_plot
{
	lda ptrlo,Y
	sta zpsrc
	lda ptrhi,Y
	sta zpsrc+1
	lda bytestart,Y
	sta zpstart
	lda byteend,Y
	sta zpend
	lda skipptrlo,Y
	sta skipptr+1
	sta skipptr2+1
	lda skipptrhi,Y
	sta skipptr+2
	sta skipptr2+2
	ldy #0
	ldx #0
	beq loop2 ; always
.skip
.skipptr
	lda $EEEE,X
	sta branch+1
	lda #$ff
.branch
	bne branch ; always
FOR i,0,13
	sta DEST+i*LINELEN,X
NEXT
	inx
	cpx #208
	bne loop2
	rts
.loop2
	cpx zpstart
	bcc skip
.loop
	cpx zpend
	bcs skip
.noskip
.skipptr2
	lda $EEEE,X
	sta branch2+1
.branch2
	bpl branch ; always
FOR i,0,13
	lda (zpsrc),Y
	sta DEST+i*LINELEN,X
;IF i<>13
	iny
;ENDIF
NEXT
.continue
	tya
	;clc
	adc zpsrc
	sta zpsrc
	bcc noinc
	inc zpsrc+1
.noinc
	ldy #0
	inx
	cpx #208
	bne loop
	rts
	;bne noinc ; always
}
