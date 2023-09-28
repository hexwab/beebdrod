; font.s: an old, buggy, over-complicated 1bpp font plotter I had lying around
; restrictions: glyphs <=32px wide, font data <=2KiB 

zptmp1=&70
zptmp2=&71
zptmp=&72
;revmask=&73 ; for inverse
ptr1=&74
ptr2=&76
ptr3=&86
zptmp3=&88
lmask=&78
rmask=&79
fontwidth=&7A ; width of current character
xoffset=&7B
fontptr=&7C
height=&80
drawnlines=&81
screenptr=&84
fontptr2=&8A

charcount=$8C
pageno=$8F
linelen=$280

; header: 1 byte nchars, 1 byte height	
fontheight=chars+1	
nchars=91 ; FIXME
widthlo=chars+2
widthhi=chars+2+nchars

{
.lmasks
;	7F BF DF EF F7 FB FD FE
;	3F 9F CF E7 F3 F9 FC FE
;	1F 8F C7 E3 F1 F8 FC FE
;	0F 87 C3 E1 F0 F8 FC FE
;	07 83 C1 E0 F0 F8 FC FE
;	03 81 C0 E0 F0 F8 FC FE
;	01 80 C0 E0 F0 F8 FC FE
;	00 80 C0 E0 F0 F8 FC FE
	equd &E0C08000: equd &FEFCF8F0 ; width >=8
	equd &EFDFBF7F: equd &FEFDFBF7 ; width 1
	equd &E7CF9F3F: equd &FEFCF9F3 ; width 2
	equd &E3C78F1F: equd &FEFCF8F1 ; width 3
	equd &E1C3870F: equd &FEFCF8F0 ; width 4
	equd &E0C18307: equd &FEFCF8F0 ; width 5
	equd &E0C08103: equd &FEFCF8F0 ; width 6
	equd &E0C08001: equd &FEFCF8F0 ; width 7
;	equd &E0C08000: equd &FEFCF8F0 ; width 8
; width >8 are all the same as 8

;if width+offset<=8 rmask=FF
.rmasks
	equb &7F
	equb &3F
	equb &1F
	equb &0F
	equb &07
	equb &03
	equb &01
	equb &00 ; width 9

;7654321076543210
;  vvvvvvvv

;tmp1 is left byte mask
;zptmp2 is right byte mask
;zptmp is right byte data to plot

.branches1 ; PC+2+off
	equb b1_0-b1_ ; unused
	equb b1_1-b1_
	equb b1_2-b1_
	equb b1_3-b1_
	equb b1_4-b1_
	equb b1_5-b1_
	equb b1_6-b1_
	equb b1_7-b1_

.branches2byte
	equb twoblank-branch2_
	equb b2_1-branch2_
	equb b2_2-branch2_
	equb b2_3-branch2_
	equb b2_4-branch2_
	equb b2_5-branch2_
	equb b2_6-branch2_
	equb b2_7-branch2_

.*dopage
	jsr get_byte
	sta tmp+1
.lineloop
.tmp
	lda #$ee
	sta xoffset
	jsr get_byte
	sta spacewidth+1
	cmp #0
	beq pagedone
	bmi pagedone
	jsr get_byte
	sta screenptr
	jsr get_byte
	sta screenptr+1
	jsr get_byte
	sta charcount
.charloop
	jsr get_byte
	tax
	bpl notspacefirst
.spacefirst
	pha
.spacewidth
	lda #$ee
	jsr moveright
	;lda #32
	;jsr plot
	pla
	and #$7f
.notspacefirst
	jsr plot
	dec charcount
	bne charloop
	beq lineloop ; always
.pagedone
	rts

.ge16
	; split into two separate plots
	sta atmp+1
	lda fontptr
	sta ptrtmp+1
	lda fontptr+1
	sta ptrtmp2+1
	lda #16 ; first 16 pixels
	jsr redo

	; skip 2*height bytes
	lda fontheight
	asl a
	clc
.ptrtmp
	adc #$ee
	sta fontptr
.ptrtmp2
	lda #$ee
	adc #0
	sta fontptr+1
.atmp
	lda #$ee ; and the rest
	and #$0f
	bpl redo ; always
.bad
	brk
.*plot
	tax

	sec
	sbc #32 ; charset starts at 32
	tax
	lda widthlo,X
	sta fontptr
	lda widthhi,X
	beq bad
	and #&07
	clc
	adc #>chars
	sta fontptr+1
	lda widthhi,X
	adc #8
	lsr a
	lsr a
	lsr a
	;clc
	;adc #1
	cmp #16
	bcs ge16
.redo
	sta fontwidth
	lda fontheight
	sta height

	;copy screenptr to ptr1
	lda screenptr
	sta ptr1
	lda screenptr+1
	sta ptr1+1

.doplot
	lda ptr1
	and #7
	eor #7
	clc
	adc #1
; A is how many lines we can draw
	cmp height
	bcc drawsome ; >= height?
	beq drawsome
.drawall
	lda height
.drawsome
	tay
	sty drawnlines
	dey
	;sta zptmp
	;lda height
	;sec
	;sbc zptmp
	;sta height
	tya
	eor #&FF
	clc
	adc height
	sta height

.draw
	; put ptr1+8 in ptr2
	clc
	lda ptr1
	adc #8
	sta ptr2
	lda ptr1+1
	adc #0
	sta ptr2+1

	;get lmask
	lda fontwidth
	cmp #9
	bcc widthle8 ; <= 8

;set fontptr2 to second byte by adding height
	lda fontheight
	clc
	adc fontptr
	sta fontptr2
	lda fontptr+1
	adc #0
	sta fontptr2+1
	ldx xoffset
	bpl getlmask ; always
	brk
.widthle8
	;lda fontwidth
	;asl a
	;asl a
	;asl a
	;ora xoffset
	;tax
	ldx #7 ; ???????????
	lda #<blank
	sta fontptr2
	lda #>blank
	sta fontptr2+1

.getlmask
	lda lmasks,X ; 8 bytes each, 1-indexed
	sta lmask

	;get rmask if needed
	lda fontwidth
	clc
	adc xoffset
	cmp #9
	bcc onebyte ; width+offset<=8 -> one byte
	tax
	cpx #17
	bcc twobytes

.threebytes
	lda rmasks-17,X
	sta rmask
	jmp threebytesreal

.onebyte
	ldx xoffset
	; check for no shifting required
	beq noshift
	lda branches1,X
	sta loop11branch+1
	clc
.loop1byte
	lda (ptr1),Y
	and lmask
	sta zptmp1
	lda (fontptr),Y
	;eor revmask
.loop11branch
	bcc loop11branch
.b1_
.b1_7
	lsr a
.b1_6
	lsr a
.b1_5
	lsr a
.b1_4
	lsr a
.b1_3
	lsr a
.b1_2
	lsr a
.b1_1
	lsr a
.b1_0
	ora zptmp1
	sta (ptr1),Y
	dey
	bpl loop1byte
	jmp done

.twobytes
	lda rmasks-9,X
	sta rmask
	ldx xoffset
	lda branches2byte,X
	sta branch2+1
.loop1
	lda (fontptr2),Y
	sta zptmp
	lda (ptr1),Y
	and lmask
	sta zptmp1
	lda (ptr2),Y
	and rmask
	sta zptmp2
	lda (fontptr),Y
	;eor revmask
.branch2
	;bne branch2
	bvc branch2 ; always
.branch2_
	;brk;beq twoblank2
.b2_7
	;asl a
	;sta zptmp
	;lda #0
	;adc #0
	;bcc twoblank ; always
	lsr a
	ror zptmp
.b2_6
	lsr a
	ror zptmp
.b2_5
	lsr a
	ror zptmp
.b2_4
	lsr a
	ror zptmp
.b2_3
	lsr a
	ror zptmp
.b2_2
	lsr a
	ror zptmp
.b2_1
	lsr a
	ror zptmp
.twoblank
	ora zptmp1
	sta (ptr1),Y
	lda zptmp2
	ora zptmp
	sta (ptr2),Y
	dey
	bpl loop1
	jmp done
;.twoblank2
;	lsr zptmp
;	dex
;	bpl twoblank2
;	jmp twoblank
.noshift
	bit lmask
	bmi noshiftnomask
.loopnoshift
	lda (ptr1),Y
	and lmask
	ora (fontptr),Y
	sta (ptr1),Y
	dey
	bpl loopnoshift
	jmp done

.noshiftnomask
.loopnsnm
	lda (fontptr),Y
	sta (ptr1),Y
	dey
	bpl loopnsnm
	;jmp done

.done
	lda height
	beq reallydone
.add2802
	clc
	lda ptr1
	adc #linelen MOD256
	and #&F8
	sta ptr1
	lda ptr1+1
	adc #linelen DIV256
	sta ptr1+1
	;no need for clc
	lda fontptr
	adc drawnlines
	sta fontptr
	lda fontptr+1
	adc #0
	sta fontptr+1
	jmp doplot

.reallydone
	lda fontwidth
.*moveright
	clc
	adc xoffset
	sta zptmp
	and #7
	sta xoffset
	lda zptmp
	and #&F8
	beq noscreeninc
	sta zptmp
	;no need for clc
	lda zptmp
	adc screenptr
	sta screenptr
	bcc noscreeninc
	inc screenptr+1
.noscreeninc
	rts

.threebytesreal
{
	lda ptr1
	clc
	adc #16
	sta ptr3
	lda ptr1+1
	adc #0
	sta ptr3+1
.loop3
	lda (fontptr2),Y
	sta zptmp
	lda #0
	sta zptmp3
	lda (ptr1),Y
	and lmask
	sta zptmp1
	lda (ptr3),Y
	and rmask
	sta zptmp2
	lda (fontptr),Y
	ldx xoffset
	beq noshift
.loop
	lsr a
	ror zptmp
	ror zptmp3
	dex
	bne loop
.noshift
	ora zptmp1
	sta (ptr1),Y
	lda zptmp
	sta (ptr2),Y
	lda zptmp3
	ora zptmp2
	sta (ptr3),Y
	dey
	bpl loop3
	jmp done
}
.blank
	equw 0:equw 0:equw 0:equw 0
}
