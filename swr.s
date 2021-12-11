;systype=$
	; find a page of spare SWRAM and page it in

	; see https://stardot.org.uk/forums/viewtopic.php?p=274449#p274449
	; and http://beebwiki.mdfs.net/Testing_for_sideways_RAM
.getswr
{
	lda #0
	tax
	inx
	jsr osbyte
;	sta systype
	cpx #3
	bcc notmaster
.master
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
.notmaster
	cpx #0
	bne common
.iselectron
{
	lda #5
	sta romsel+1 ; romsel lives at fe05
	dec romtable+1 ; romtable lives at 2a0
	; patch core for electron-specific stuff
	dec t2a0_1+1
	dec t2a0_2+1
}
.common	
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
	brk
	equb 0,"No SWRAM detected :(",0
.page
	lda #12:JSR SelectROM2:TXA
.SelectROM2
	sta &F4
.romsel sta $FE30
	RTS
}
