INCLUDE "os.h"
	DELAY=10 ; cs
	DEST=$5880
	LINELEN=640
	zpsrc=$70
	zpstart=$72
	zpend=$73
	org $1500
.start
.main
	;lda #22
	;jsr $ffee
	;lda #1
	;jsr $ffee
.restart
	ldy #0
.mainloop
	sty ytmp+1
	;lda #12
	;jsr $ffee
	jsr heads_plot
	lda #$81
	ldx #<DELAY
	ldy #>DELAY
	jsr osbyte
.ytmp	ldy #$ee
	iny
	cpy #8
	beq restart
	bne mainloop
	INCLUDE "heads.s"
	INCLUDE "heads.out.s"
.end
	
SAVE "heads",start,end,main
