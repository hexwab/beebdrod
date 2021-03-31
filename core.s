; stuff that permanently resides in memory
rowmult=$380
levelno=$3c0
namestash=$3c1
get_crunched_byte = $22

; global defines
SMALL_SCREEN=0 ; saves 1K of screen space, model B only

INPOS = get_crunched_byte+1
	ORG $400
.core_start
	INCLUDE "exo.s"
; initialize waiting for A cs. A<127
.delay_start
	clc
	adc $2a0
	sta delexp+1
	rts
; wait for at least A cs
.delay
	jsr delay_start
; wait for at least the specified time since delay_start
.delay_end
.delexp
{	lda #$ee
.waitloop
	cmp $2a0
	bpl waitloop
	rts
}
IF 0 ;SMALL_SCREEN
	
.rowmult
	; bizarrely this is big-endian
	FOR i,0,31,1
	EQUB >(38*16*i), <(38*16*i)
	NEXT
ENDIF

.core_end

	SAVE "core",core_start,core_end
