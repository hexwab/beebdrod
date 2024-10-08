; intro.s: level intro screen

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
	jsr load_and_init_decrunch
	DECRUNCH_TO loc
	lda #21
	ldx #0
	jsr osbyte ; flush keyboard buffer
	DECRUNCH_FILE_TO FILE_font_headline_zx02, chars
.draw_title
	lda #19
	jsr osbyte
	lda systype
	cmp #SYSTYPE_BBCB ;1
	bne notbbcb
.bbcb
	; reset small screen
	ldy #1
	lda #80 ; displayed chars
	ldx #98 ; hsync pos
	sta $354
	jsr $ca2b ; set two regs
	lda #$30
	sta $34e
	;ldx #0 ; 6845 address will be set elsewhere
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
	; stash level name for map screen
.nameloop
	iny
	inx
	lda nameptr+4,Y
	sta namestash,X
	bpl nameloop
	; print level name
	ldx levelidx
	lda #<(nameptr)
	clc
	adc nameidx,X
	sta get_byte+1
	jsr dopage
	; space before "Level"
	lda #20
	jsr moveright

	; print "Level"
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

.draw_intro_window
	_print_string level_intro_window,level_intro_window_end

.print_intro
{
	DECRUNCH_FILE_TO FILE_font_body_zx02, $2000
	ldx levelidx
	lda headlo,X
	sta get_byte+1
	lda headhi,X
	sta get_byte+2
	jsr dopage
}

.run_game
	lda #FILE_code_elk_chain
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

; set the screen up for MODE 0. no clearing, no palette changes
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
	;equb 23,1,0,0,0,0,0,0,0,0
	equb 19,2,7,0,0,0,19,0,7,0,0,0
	equb 19,3,7,0,0,0,19,1,7,0,0,0
	equb 26,17,128,12
	equb 19,2,0,0,0,0,19,3,0,0,0,0
	;28,0,31,37,0,
	equb 31,10,3
.level_title_window_end

.level_intro_window
	equb 28,1,31,36,6,30
.level_intro_window_end

PRINT "load=",~start
PRINT "exec=",~init

;INCLUDE "exo.s"
.end
SAVE "dointro",start,end,start
