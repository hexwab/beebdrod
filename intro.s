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

.load_level
	lda levelno
	clc
	adc #FILE_level01
	tay
	ldx #0
	lda #$80
	jsr load_file_to
	
.run_game
	lda #FILE_code_elk_exo
	clc
	adc systype
	tay
	jmp chain
.level_title_window
	equb 26,17,128,12
	equb 17,131,17,0,28,0,31,37,0,12,31,10,3
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
