; stuff that permanently resides in memory
rowmult=$380
levelno=$3c0
namestash=$3c1
get_crunched_byte = $44

; values that are overwritten before being used
OVERB = $ee
OVERW = $eeee

; we have four executables for four platforms:
;
; * BBC B (small screen, no hwscroll, assume OS 1.20,
;   anything else we can do for space)
;
; * generic beeb with SWRAM, including B+ (normal screen, hwscroll, no 
;   OS assumptions)
;
; * Electron with SWRAM (normal screen, no hwscroll, assume OS 1.00, anything
;   else we can do for speed, including placing code in SWRAM where possible)
;
; * Master (special provisions for ROM font location, maybe 65SC12 opcodes
;   or more stuff further down the line)

PLATFORM_ELK=?0
PLATFORM_BBCB=?0
PLATFORM_BEEB=?0
PLATFORM_MASTER=?0

; we demand precisely one of the above
ASSERT (PLATFORM_BBCB+PLATFORM_BEEB+PLATFORM_ELK+PLATFORM_MASTER=1)

systype=$fe ; platform is stored here

; global defines
IF PLATFORM_BBCB
	SMALL_SCREEN=1 ; saves 1K of screen space, model B only
ELSE
	SMALL_SCREEN=0
ENDIF
IF PLATFORM_BBCB
	INLINE_GET_TILE=0 ; +3 bytes, -12 cycles
	UNROLL_PLOT=0 ; +22 bytes, about 20% faster
	UNROLL_MUL=0 ; +8 bytes
	FANCY_BORDERS=0 ; +115 code bytes and 16 sprites=256 data bytes: 371 bytes total
	PROPER_PITS=0 ; +46 code bytes and 2 sprites=32 data bytes: 78 bytes total 
	OPAQUE_TAR=0 ; +7 bytes
ELSE
	INLINE_GET_TILE=1
	UNROLL_PLOT=1
	UNROLL_MUL=1
	FANCY_BORDERS=1
	PROPER_PITS=1
	OPAQUE_TAR=1
ENDIF
IF PLATFORM_ELK OR PLATFORM_BBCB
	HWSCROLL=0
ELSE
	HWSCROLL=1
ENDIF
IF PLATFORM_MASTER
	MASTER=1
ELSE
	MASTER=0
ENDIF

	CPU 1 ; always allow 'C02 opcodes

	
INPOS = get_crunched_byte+1
	ORG $400
.core_start
	INCLUDE "exo.s"
	INCLUDE "fs.s"
; initialize waiting for A cs. A<127
.delay_start
	clc
.*t2a0_1	adc $2a0
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
.*t2a0_2	cmp $2a0
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

;	SAVE "core",core_start,core_end
