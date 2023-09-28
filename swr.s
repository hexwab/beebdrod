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
	bne find_swram ; always
}
.notelectron
.common
	lda #1
	sta $291 ; turn interlace off: required for hwscroll
	cpx #2
	beq bplus
	bcs find_swram
	ldx #2 ; PLATFORM_BEEB

.find_swram
	ldy #15
.loop
	
.romtable
	lda $2a1,Y ; skip active ROMs
	bne skip
.pageloc
	jsr page
	LDA &8008:EOR #&AA:STA &8008       :\ Modify version byte
	CMP &AAAA:CMP &8008:BNE no 	   :\ NE=ROM or empty
;	EOR #&AA:STA &8008                 :\ Restore byte
	; got one!
	rts
.no
.skip
	dey
	bpl loop
	txa
	bne beeb
	; electrons need SWRAM
	brk
	equb 0,"No SWRAM detected :(",0
.beeb
	dex ; downgrade to PLATFORM_BBCB
	rts
.bplus
	; we perform the usual SWRAM check, but
	; additionally page in the 12K shadow RAM.
	; since we don't have a separate PLATFORM for B+
	; we store the result in $F4:
	; <$80: model B (no shadow screen available)
	; $80-$8F: B+ with 16K of SWRAM (plus more paged out)
	; $FF: B+ with 12K of SWRAM
	jsr find_swram
	ldx #2 ; restore PLATFORM_BEEB even if no SWRAM
	tya
	ora #128
.page
	lda #12:JSR SelectROM2:TYA ; electrons require this dance
.SelectROM2
	sta &F4
.romsel sta ROMSEL
	RTS
}
