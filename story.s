	INCLUDE "text.h"
	INCLUDE "os.h"
	INCLUDE "files.h"
	INCLUDE "core.s"
chars=$2000
org $1100

.start
	INCLUDE "font.s"

.get_byte
{
	lda page1
	inc get_byte+1
	bne done
	inc get_byte+2
.done
	rts
}
.pal1
	equb 0,7,0,0,0
.pal2
	equb 1,0,0,0,0
.init
{
	_print_string story_window,story_window_end
	jsr setmode0
	DECRUNCH_FILE_TO FILE_font_body_zx02, chars

	; draw dropcap
	ldx #55
caploc=$3518
.caploop
	lda dropcap+0,X
	sta caploc,X
	lda dropcap+56,X
	sta caploc+$280,X
	lda dropcap+112,X
	sta caploc+$500,X
	lda dropcap+168,X
	sta caploc+$780,X
	dex
	bpl caploop

	ldx #3
	stx pageno
.pageloop
	{
	ldx pageno
	lda circletab,X
	sta circptr+1
	ldx #3
.circleloop
	lda opencircle,X
	sta circle1,X
	sta circle2,X
	sta circle3,X
	sta circle4,X
	lda closedcircle,X
.circptr
	sta circle4,X
	dex
	bpl circleloop
}	
	jsr dopage
{
	lda systype
	cmp #SYSTYPE_MASTER
	beq master
.wait
	jsr osrdch
	jmp common
.flip
	jsr osrdch
	lda #19
	jsr osbyte
	lda $fe34
	eor #7
	sta $fe34
	bra common
.master
	lda pageno
	cmp #3 ; first?
	bne flip
	lda #6
	tsb $fe34
	; skip waiting for key
.common
}

	lda #12
	jsr oswrch
	ldx pageno
	lda pagetablo-1,X
	sta get_byte+1
	lda pagetabhi-1,X
	sta get_byte+2
	dec pageno
	bpl pageloop
{
	lda systype
	cmp #SYSTYPE_MASTER
	bne common
.master
	jsr osrdch
	lda #7
	trb $fe34
.common
}
	CHAIN FILE_intro_chain
}
.setmode0
	lda systype
	beq elk
.beeb
	lda #154
	ldx #$9c
	jmp osbyte
.elk
	lda $282
	and #$c7
	jmp $e495

.story_window
	;equb 23,1,0,0,0,0,0,0,0,0
	equb 26,17,128,12
	equb 19,2,0,0,0,0,19,0,7,0,0,0
	equb 19,3,0,0,0,0,19,1,7,0,0,0
.story_window_end

.pagetablo
	equb <page4,<page3,<page2
.pagetabhi
	equb >page4,>page3,>page2
.dropcap
	INCBIN "yrm.beeb"
.page1
	INCBIN "lines1"
.page2
	INCBIN "lines2"
.page3
	INCBIN "lines3"
.page4
	INCBIN "lines4"
.opencircle
	equb %01111110
	equb %11000011
	equb %11000011
.closedcircle
	equb %01111110
	equb %11111111
	equb %11111111
	equb %01111110
circle1=$7c13
circle2=$7c33
circle3=$7c53
circle4=$7c73
.circletab
	equb <circle4,<circle3,<circle2,<circle1
.end

PRINT "load=",~start
PRINT "exec=",~init
SAVE "story", start,end,init
