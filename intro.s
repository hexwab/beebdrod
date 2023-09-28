loc=$1100 ; where we decompress to
headlo=loc
headhi=loc+9
nameidx=loc+18
nameptr=loc+27
ptr=$81
levelidx=$83
	INCLUDE "os.h"
	INCLUDE "text.h"
	INCLUDE "files.h"
	INCLUDE "core.s"
chars=$2000
	org $2800
.start
	INCLUDE "font.s"
.init
{	; split levelno into file and index
	lda levelno
	cmp #18-1
	bcs ge18
	cmp #10-1
	bcs ge10
.lt10
	ldy #FILE_intro1_9
	bpl done
.ge10
	ldy #FILE_intro10_17
	sbc #10-1
	bpl done
.ge18
	ldy #FILE_intro18_25
	sbc #18-1
.done
}
	sta levelidx
	jsr load_and_decrunch
	lda #21
	ldx #0
	jsr osbyte ; flush keyboard buffer
	ldy #FILE_font_headline_exo
	jsr load_and_decrunch
.draw_title
	lda systype
	cmp #1 ;PLATFORM_BBCB
	bne notbbcb
.bbcb
	; reset small screen
	ldy #8
	lda #$f0
	jsr $c985
	ldy #1
	lda #80
	sta $354
	jsr $c985
	lda #$30
	sta $34e
	;ldx #0
	;jsr $c9b3
	lda #$75
	sta $e0
	lda #$c3
	sta $e1
.notbbcb
	_print_string level_title_window,level_title_window_end
	jsr setmode0

.stash_and_print_name
{
	ldx levelidx
	ldy nameidx,X
	ldx #255
.nameloop
	iny
	inx
	lda nameptr+4,Y
	sta namestash,X
	;php
	;jsr packed_wrch
	;plp
	bpl nameloop

	ldx levelidx
	lda #<(nameptr)
	clc
	adc nameidx,X
	sta get_byte+1
	jsr dopage
	lda #20
	jsr moveright
{
	ldx #4
.loop
	stx xtmp+1
	lda level_string,X
	jsr plot
.xtmp
	ldx #OVERB
	dex
	bpl loop
}
}

IF 0
{
	ldx levelidx
	ldy nameidx,X
.nameloop
	lda nameptr,Y
	beq done
	jsr packed_wrch
	iny
	bpl nameloop ;always
.done
}
ENDIF

.draw_intro_window
	_print_string level_intro_window,level_intro_window_end

.print_intro
{
	ldy #FILE_font_body_exo
	jsr load_and_decrunch
	ldx levelidx
	lda headlo,X
	sta get_byte+1
	lda headhi,X
	sta get_byte+2
	jsr dopage
}

.run_game
	lda #FILE_code_elk_exo
	clc
	adc systype
	tay
	jmp chain

.get_byte
{
	lda nameptr
	inc get_byte+1
	bne done
	inc get_byte+2
.done
	rts
}

.setmode0
	lda systype
	beq elk
.beeb
	lda #8
	sta $fe00
	lda #0
	sta $fe01
	lda #154
	ldx #$9c
	jmp osbyte
.elk
	lda $282
	and #$c7
	jmp $e495

.common

.level_string
	equb "leveL"

.level_title_window
	;equb 19,1,1,0,0,0,19,2,4,0,0,0
	;equb 19,0,4,0,0,0,19,1,1,0,0,0
	;equb 19,2,0,0,0,0,19,3,7,0,0,0
	;equb 26,17,128+BACKG_COL,12
	;equb 17,131,17,BACKG_COL
	equb 23,1,0,0,0,0,0,0,0,0
	equb 19,2,0,0,0,0,19,0,7,0,0,0
	equb 19,3,0,0,0,0,19,1,7,0,0,0
	equb 26,17,128,12
	;28,0,31,37,0,
	equb 31,10,3
	equb 23,0,2,98,0,0,0,0,0,0
.level_title_window_end

.level_intro_window
	equb 28,1,31,36,6,30
.level_intro_window_end

PRINT "load=",~start
PRINT "exec=",~init

;INCLUDE "exo.s"
.end
SAVE "dointro",start,end,start
