; tweakables
LAST_FOUR=1 ; include ASCII 123-126 ("{","|", "}", "~")
WIDE=1 ; allow >256-byte lines
COLOURS=4 ; what screen mode we're targeting
OS_120=0 ; unused
IF PLATFORM_BBCB
MUL17TABLE=$c31f
ELIF PLATFORM_ELK
MUL17TABLE=$c317
ELIF PLATFORM_MASTER
MUL17TABLE=0 ; e013 on MOS 3.20 but e011 on MOS 3.50
ELSE
MUL17TABLE=0
ENDIF
	
VERT_UNALIGNED=1	
zptmp=$80	
zp_mini_chartmp=$80 ; font bitmap
zp_mini_fontptr=$80	
;zp_char=$81 ; char num (ASCII)
zp_mini_outbmp=$82 ; out bitmap
zp_mini_outcount=$83 ; bits remaining to write to zp_outbmp
zp_mini_linecount=$84 ; 0-7
zp_mini_screenptr=$85 ; two bytes
zp_mini_screenoff=$87 ; offset from start position
zp_mini_stringptr=$88

zp_widthlo=$80
zp_widthhi=$81
IF WIDE=1	
zp_mini_screenhi_tmp=$89
ENDIF	
IF COLOURS=2
	OUTCOUNT=7
ELIF COLOURS=4
	OUTCOUNT=3
ELIF COLOURS=16
	OUTCOUNT=1
ENDIF
IF PLATFORM_MASTER
	font=$b800 ; in bank 15
ELSE
	font=$c000
ENDIF
	string=$100
IF 0
	ORG $900
.start
ENDIF
.mini_write_line
{
IF PLATFORM_MASTER
	lda $f4
	pha
	lda #15
	sta $f4
	sta $fe30
ENDIF
IF WIDE=1
	lda zp_mini_screenptr+1
	sta zp_mini_screenhi_tmp
ENDIF
	ldx #0
.lineloop
	stx zp_mini_linecount
IF WIDE=1
	lda zp_mini_screenhi_tmp
	sta zp_mini_screenptr+1
ENDIF
	ldx #0
IF COLOURS<>2
	stx zp_mini_outbmp
ENDIF
	stx zp_mini_stringptr
	stx zp_mini_screenoff
	ldy #OUTCOUNT ; FIXME? allow plotting at subchar positions horizontally?
.rowdone
	sty zp_mini_outcount
	;lda zp_mini_outbmp
	;ldy zp_mini_screenoff
	;sta (zp_mini_screenptr),Y
.rowskip
.charloop
	ldy zp_mini_stringptr
	lda string,Y
	inc zp_mini_stringptr

.plot
IF PLATFORM_MASTER
	bit #$e0
	beq linedone
	tax
;	tay
;	sec
;	sbc #32
;	bmi linedone
;	tax
;	tya
ELSE
	sec
	sbc #32
	bmi linedone
	tax
ENDIF
{
	; fontptr=$C000+A*8
	ldy #>font/8
	sty zp_mini_fontptr+1
        clc
        rol A
        rol zp_mini_fontptr+1
        rol A
        rol zp_mini_fontptr+1
        rol A
        rol zp_mini_fontptr+1
	
	sta zp_mini_fontptr
}
	
	; X is line count
	; Y is char num
	ldy zp_mini_linecount
	lda (zp_mini_fontptr),Y
	sta zp_mini_chartmp
IF PLATFORM_MASTER
	lda charbitmap-32,X ; bitmask
ELSE
	lda charbitmap,X ; bitmask
ENDIF
	ldy zp_mini_outcount
	bpl rowloop ; always
.skip
	beq rowdone ; no bitmask bits left?
	asl zp_mini_chartmp ; shift out and ignore this bit
.rowloop
	lsr a
	bcc skip ; skip 0 bits in bitmask
	asl zp_mini_chartmp ; shift a bit from char bitmap
	rol zp_mini_outbmp ; into output bitmap
	dey ; out count
	bpl rowloop

	pha
IF COLOURS=2
	lda zp_mini_outbmp
ELIF COLOURS=4
{
IF MUL17TABLE
	ldy zp_mini_outbmp
	lda MUL17TABLE,Y
ELSE
	lda zp_mini_outbmp
	asl a
	asl a
	asl a
	asl a
	adc zp_mini_outbmp
ENDIF
	and #255-BACKG_BYTE
}
ELIF COLOURS=16
	ldy zp_mini_outbmp
IF OS_120=1
	lda $c32f,Y
ELSE
	lda masktab,Y
ENDIF
ENDIF
	ldy zp_mini_screenoff
	eor #$ff
	sta (zp_mini_screenptr),Y
	tya
	clc
	adc #8
	sta zp_mini_screenoff
IF WIDE=1
{
	bcc noinc
	inc zp_mini_screenptr+1
.noinc
}
ENDIF
IF COLOURS<>2
	lda #0
	sta zp_mini_outbmp
ENDIF
	pla
	ldy #OUTCOUNT ; out count
	bne rowloop ;skip2 ; always

.linedone
	; next line
	inc zp_mini_screenptr
	ldx zp_mini_linecount
	inx
IF VERT_UNALIGNED
	bne fixup_alignment ;always
.aligned
ENDIF
	cpx #8
	bne lineloop
IF PLATFORM_MASTER
	pla
	sta $f4
	sta $fe30
ENDIF
.done
	rts

.fixup_alignment
{
	lda zp_mini_screenptr
	and #7
	bne aligned
	lda zp_mini_screenptr
	clc
	adc #<(LINELEN-8)
	sta zp_mini_screenptr
	lda zp_mini_screenhi_tmp
	adc #>(LINELEN-8)
	sta zp_mini_screenhi_tmp
	bcc aligned ;always
}

.*mini_get_width
{
	lda #0
	sta zp_widthlo
	sta zp_widthhi
	ldx #0
.loop
	lda string,X
	;sec
	;sbc #32
	;bmi done
	beq done
	inx
	tay
	lda charbitmap-32,Y
	; popcount
	ldy #0
.poploop
	lsr A
	bcc no
	iny
.no	bne poploop ; always
	tya
	; C always clear here
	adc zp_widthlo
	sta zp_widthlo
	bcc loop
	inc zp_widthhi
	bne loop ; always
}	

.charbitmap
	equb %00000111 ;  
	equb %00001100 ; !
	equb %00101011 ; "
	equb %11011011 ; #
	equb %11101111 ; $
	equb %00111101 ; %
	equb %11101011 ; &
	equb %00010101 ; '
	;equb %01011001 ; (
	equb %00010101 ; (
	equb %00101001 ; )
	equb %01101111 ; *
	equb %01110111 ; +
	equb %00110101 ; ,
	equb %00011111 ; -
	equb %00011100 ; .
	equb %01111111 ; /
	equb %01011011 ; 0
	equb %00101101 ; 1
	equb %01011011 ; 2
	equb %01011011 ; 3
	equb %01011011 ; 4
	equb %01011011 ; 5
	equb %01011011 ; 6
	equb %01010111 ; 7
	equb %01011011 ; 8
	equb %01011011 ; 9
	equb %00001001 ; :
	equb %00010101 ; ;
	equb %00111111 ; <
	equb %01110011 ; =
	equb %01111101 ; >
	equb %01101111 ; ?
	equb %01111011 ; @
	equb %01011011 ; A
	equb %01011011 ; B
	equb %01011011 ; C
	equb %01011101 ; D
	equb %01011011 ; E
	equb %01011011 ; F
	equb %01011011 ; G
	equb %01011011 ; H
	equb %01001101 ; I
	equb %01101011 ; J
	equb %01101101 ; K
	equb %00111101 ; L
	equb %10111101 ; M
	equb %00111101 ; N
	equb %01011011 ; O
	equb %01011101 ; P
	equb %01011011 ; Q
	equb %01011101 ; R
	;equb %00111101 ; S SQUARE
	equb %01011011 ; S
	equb %01101111 ; T
	equb %01011011 ; U
	equb %01011011 ; V
	equb %10111101 ; W
	equb %01101111 ; X
	equb %01110111 ; Y
	equb %00111101 ; Z
	equb %00011101 ; [
	equb %01111111 ; \
	equb %00111001 ; ]
	equb %01110111 ; ^
	equb %00011111 ; _
	equb %01011011 ; £
	;equb %01011111 ; a
	equb %01011011 ; a
	equb %01011101 ; b
	equb %01011011 ; c
	equb %00111011 ; d
 	;equb %00111101 ; e SQUARE
	equb %01011011 ; e
	equb %00110111 ; f
	equb %01011011 ; g
	equb %01011101 ; h
	equb %00110101 ; i
	equb %00110111 ; j
	equb %01011101 ; k
	equb %00101101 ; l
	equb %10111011 ; m
	equb %01011101 ; n
	equb %01011011 ; o
	equb %01011011 ; p
	equb %11011011 ; q
	equb %01011011 ; r
	equb %01011011 ; s
	equb %00110111 ; t
	equb %01011011 ; u
	equb %01011011 ; v
	equb %10111011 ; w
	equb %01101111 ; x
	;equb %01011101 ; y
	equb %01011011 ; y
	equb %01101101 ; z
IF LAST_FOUR=1
	equb %00101101 ; {
	equb %00101101 ; |
	equb %00110101 ; }
	equb %10111011 ; ~
ENDIF
IF COLOURS=16 AND OS_120=0
.masktab
	equb $00,$55,$aa,$ff
ENDIF
}	
IF 0
.end

PUTTEXT "miniboot","!BOOT",2
PUTBASIC "minitest.bas","DEMO"
SAVE "font",start,end
ENDIF
