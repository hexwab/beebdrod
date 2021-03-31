loc=$1100 ; where we decompress to
headlo=loc
headhi=loc+25
nameidx=loc+50
nameptr=loc+75	
ptr=$81
	INCLUDE "os.h"
	INCLUDE "text.h"
	INCLUDE "core.s"
	org $2500
.start
.load_core
	ldx #<load_core_cmd
	ldy #>load_core_cmd
	jsr oscli
{	ldx #get_crunched_byte_copy_end-get_crunched_byte_copy
.loop
	lda get_crunched_byte_copy,X
	sta get_crunched_byte,X
	dex
	bpl loop
}
	ldx #<intro_crunched
	ldy #>intro_crunched
	jsr decrunch

	lda #10
	sta $fe00
	sta $fe01 ; cursor off
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
	; set filename
	lda levelno
	clc
	adc #1
{
.loop
	cmp #10
	bcc done
	inc level_file
	sec
	sbc #10
	bpl loop ; always
}
.done
	clc
	adc #$30
	sta level_file+1
	ldx #<load_level_cmd
	ldy #>load_level_cmd
	jsr oscli

.run_game
	ldx #<run_game_cmd
	ldy #>run_game_cmd
	jmp oscli

.level_title_window
	equb 26,17,128,12
	equb 17,131,17,0,28,0,31,37,0,12,31,10,3
.level_title_window_end

.level_intro_window
	equb 28,1,31,36,6,30
.level_intro_window_end

.load_level_cmd
	equs "SRL.level"
.level_file
	equs "00 8000 4",13

.load_core_cmd
	equs "L.core",13
.run_game_cmd
	equs "/code",13
.get_crunched_byte_copy
{
	lda $eeee
        inc INPOS
        bne s0a
        inc INPOS+1
.s0a    rts
}
.get_crunched_byte_copy_end
	
INCLUDE "text.s"

.intro_crunched
	INCBIN "intro"


;INCLUDE "exo.s"
.end
SAVE "dointro",start,end,start
