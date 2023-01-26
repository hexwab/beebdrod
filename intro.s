loc=$1100 ; where we decompress to
headlo=loc
headhi=loc+25
nameidx=loc+50
nameptr=loc+75	
ptr=$81
	INCLUDE "os.h"
	INCLUDE "text.h"
	INCLUDE "files.h"
	INCLUDE "core.s"
	org $2500
.start
.init
	ldy #FILE_intro
	jsr load_and_decrunch
	lda #21
	ldx #0
	jsr osbyte ; flush keyboard buffer
.draw_title
	_print_string level_title_window,level_title_window_end

.stash_and_print_name
{
	ldx levelno
	ldy nameidx,X
	ldx #255
.nameloop
	iny
	inx
	lda nameptr-1,Y
	sta namestash,X
	php
	jsr packed_wrch
	plp
	bpl nameloop
}
	
IF 0
{
	ldx levelno
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
	ldx levelno
	lda headlo,X
	sta ptr
	lda headhi,X
	sta ptr+1
	ldy #0
.loop
	lda (ptr),Y
	beq done
	jsr packed_wrch
	iny
	bne loop
	inc ptr+1
	bne loop ;always
.done
}

.run_game
	lda #FILE_code_elk_exo
	clc
	adc systype
	tay
	jmp chain
	
.level_title_window
	;equb 19,1,1,0,0,0,19,2,4,0,0,0
	equb 19,0,4,0,0,0,19,1,1,0,0,0
	equb 19,2,0,0,0,0,19,3,7,0,0,0
	equb 26,17,128+BACKG_COL,12
	equb 17,131,17,BACKG_COL,28,0,31,37,0,12,31,10,3
	equb 23,0,2,96,0,0,0,0,0,0
.level_title_window_end

.level_intro_window
	equb 28,1,31,36,6,30
.level_intro_window_end
MINI=0	
INCLUDE "text.s"

.intro_crunched
	;INCBIN "intro"

PRINT "load=",~start
PRINT "exec=",~init

;INCLUDE "exo.s"
.end
SAVE "dointro",start,end,start
