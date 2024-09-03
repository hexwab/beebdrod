; core: stuff that permanently resides in memory
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

SYSTYPE_ELK=0
SYSTYPE_BBCB=1
SYSTYPE_BEEB=2
SYSTYPE_MASTER=3

; global defines

FANCY_BORDERS=1
IF PLATFORM_BBCB
	SMALL_SCREEN=1 ; saves 1K of screen space, model B only
	DECRUNCH_FROM_RAM=0 ; decompress-from-disc only
	ENTIRE_LEVEL=0 ; store entire level in SWRAM
ELSE
	SMALL_SCREEN=0
	DECRUNCH_FROM_RAM=1
	ENTIRE_LEVEL=1
ENDIF
IF PLATFORM_BBCB
	INLINE_GET_TILE=0 ; +3 bytes, -12 cycles
	UNROLL_PLOT=0 ; +22 bytes, about 20% faster
	UNROLL_MUL=0 ; +8 bytes
	OPAQUE_TAR=1 ; +7 bytes
ELSE
	INLINE_GET_TILE=1
	UNROLL_PLOT=1
	UNROLL_MUL=1
	OPAQUE_TAR=1
ENDIF
IF PLATFORM_MASTER
	TRANSP_HACK=1 ; sweet cthulu these are expensive
	REALLY_FAST_PLOT_INLINE=1
	SHADOW_MAP=1
ELSE
	TRANSP_HACK=0
	REALLY_FAST_PLOT_INLINE=0
	SHADOW_MAP=0
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

BACKG_BYTE=$f0
BACKG_COL=2

	
INPOS = get_crunched_byte+1
	ORG $500
.core_start
	INCLUDE "zx02.s"

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
{	lda #OVERB
.waitloop
.*t2a0_2	cmp $2a0
	bpl waitloop
	rts
}
	INCLUDE "fs.s"
.core_end
