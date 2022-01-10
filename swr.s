INCLUDE "hw.h"

	; find a page of spare SWRAM and page it in

	; see https://stardot.org.uk/forums/viewtopic.php?p=274449#p274449
	; and http://beebwiki.mdfs.net/Testing_for_sideways_RAM
.getswr
{
	lda #0
	tax
	inx
	jsr osbyte
	cpx #3
	bcc notmaster
.master
	; all masters have systype 3
	ldx #3 ; PLATFORM_MASTER
IF 0
	; copy font back to $C000 from F:B900
	; FIXME: need to fix up font properly
	; FIXME: font must live elsewhere as DFS corrupts $C2xx
	lda #15
	jsr SelectROM2
	ldy #0
.fontloop
	lda $b900,Y
	sta $c000,Y
	lda $ba00,Y
	sta $c100,Y
	lda $bb00,Y
	sta $c200,Y
	dey
	bne fontloop
ENDIF
	lda #1
	sta $291 ; turn interlace off: required for hwscroll
	bra common
.notmaster
	cpx #0
	bne notelectron
.iselectron
{
	stx systype ; 0, PLATFORM_ELK
	lda #LO(ROMSEL_ELK)
	sta romsel+1 ; romsel lives at fe05
	dec romtable+1 ; romtable lives at 2a0
	; patch core for electron-specific stuff
	dec t2a0_1+1
	dec t2a0_2+1
	bne common ; always
}
.notelectron
	lda #1
	sta $291 ; turn interlace off: required for hwscroll
	ldx #2 ; PLATFORM_BEEB
.common	
	stx systype
	ldx #15
.loop
;{	txa
;	ora #$40
;	jsr oswrch
;}
	
.romtable
	lda $2a1,X ; skip active ROMs
	bne skip
;{	txa
;	ora #$40
;	jsr oswrch
;}
.pageloc
	jsr page
	LDA &8008:EOR #&AA:STA &8008       :\ Modify version byte
	CMP &AAAA:CMP &8008:BNE no 	   :\ NE=ROM or empty
;	EOR #&AA:STA &8008                 :\ Restore byte
				; got one!
	rts
.no
.skip
	dex
	bpl loop
	; FIxME: run with PLATFORM_BBCB
	brk
	equb 0,"No SWRAM detected :(",0
.page
	lda #12:JSR SelectROM2:TXA
.SelectROM2
	sta &F4
.romsel sta ROMSEL
	RTS
}
