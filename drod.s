;; sprites are 16 bytes (8x8x2bpp)
;; 42x32? XRES gotta be multiple of 2
XRES=40
YRES=32
SCRSTART=$3000
SPRTAB=$2000 ; must be 4K-aligned

LEVEL_HEADER_SIZE=5	
MAXROOMS=30
level		= $8000
level_nrooms    = level+0
level_startroom = level+1
level_startx    = level+2
level_starty    = level+3
level_unknownO  = level+4
level_tables    = level+LEVEL_HEADER_SIZE
level_coordtab  = level_tables
level_roomptrlo = level_tables+MAXROOMS
level_roomptrhi = level_tables+MAXROOMS*2

room		= $1600 	; $980 bytes, to $1f80

zp_xcoord 	= $50
zp_ycoord 	= $51
zp_roomno	= $52
	
; pre-initialized zero page
zp=$60
tilelinetab_zp=zp+0 ; must be 32-byte aligned
get_crunched_byte = zp+$20
INPOS = get_crunched_byte+1

osrdch = $ffe0	
oswrch = $ffee
osbyte = $fff4
	
org $1200
.start
	lda #4
	sta $f4
	sta $fe30
	ldx #1
	jsr $fff4
	jsr init_zp
	jsr init_level
.mainloop
	jsr keys
	jmp mainloop

.keys
{
	jsr osrdch
	cmp #136
	bne notleft
.left
	lda #$ff
	jmp traverse
.notleft
	cmp #137
	bne notright
.right
	lda #$01
	jmp traverse
.notright
	cmp #138
	bne notdown
.down
	lda #$10
	jmp traverse
.notdown
	cmp #139
	bne notup
.up
	lda #$f0
	jmp traverse
	
.notup
	rts
}
	
.init_zp
{
	ldy #zp_stuff_end-zp_stuff-1
.loop	lda zp_stuff,Y
	sta zp,Y
	dey
	bpl loop
	rts
}

; move one room, direction in A 
.traverse
{
	clc
	ldx zp_roomno
	adc level_coordtab,X
	ldx #0
.loop
	cmp level_coordtab,X
	beq gotit
	inx
	cpx #MAXROOMS
	bne loop
.fail
	lda #7
	jmp oswrch
.gotit
	stx zp_roomno
	jmp init_room
}
	
.init_level
	ldy level_startroom
	sty zp_roomno
	jmp init_room

.init_room
	ldy zp_roomno
	ldx level_roomptrlo,Y
	lda level_roomptrhi,Y
	tay
	jsr decrunch
	
	jsr plotroom
	rts

.plotroom
{	
	ldy #37
	sty zp_xcoord
.xloop
	ldx #31
	stx zp_ycoord	
.yloop
	ldy zp_xcoord
	ldx zp_ycoord	
	jsr get_tile
	bne not_transp
	txa
.not_transp
	ldx zp_xcoord
	ldy zp_ycoord	
	jsr plot
	dec zp_ycoord
	bpl yloop
	dec zp_xcoord
	bpl xloop
	rts
}
; X,Y reversed coords. returns: ptr to zp table in A, index into table in Y
.get_tile_ptr_and_index
{
	;bmi outside
	;cmp #38
	;bcs outside
	tya
	asl a
	tay
	txa
	lsr a
	bcc even
	tya
	adc #38*2-1 ; carry is set
	tay
	txa
	lsr a
.even
	asl a
	ora #tilelinetab_zp
	rts
}

; X,Y reversed coords. returns: opaque layer in X, transparent layer in A, Z set if A zero
.get_tile
{
	jsr get_tile_ptr_and_index
	sta tmp+1
	sta tmp2+1
.tmp	lda ($00),Y
	iny
	tax
.tmp2	lda ($00),Y
	rts
}
	; X,Y coords, A sprite number
.plot
{
	sta tmp+1
	and #$0f
	ora #>SPRTAB
	sta src1+2
.tmp
	lda #$00
	and #$f0
	sta src1+1
	lda linetab_lo,Y
	clc
	adc mul16_lo,X
	sta dst1+1
	lda linetab_hi,Y
	adc mul16_hi,X
	sta dst1+2
	ldx #15
.loop
.src1
	lda $ee00,X
.dst1
	sta $ee00,X
	dex
	bpl loop
	rts
}
.linetab_lo
FOR I,0,32,1
    EQUB <(I*XRES*16+SCRSTART)
NEXT
.linetab_hi
FOR I,0,32,1
    EQUB >(I*XRES*16+SCRSTART)
NEXT
.mul16_lo
FOR I,0,42,1
    EQUB <(I*16)
NEXT
.mul16_hi
FOR I,0,42,1
    EQUB >(I*16)
NEXT
.zp_stuff
.tilelinetab_copy
; only even lines get a table entry
FOR I,0,30,2
    EQUW (I*38*2+room)
NEXT
.get_crunched_byte_copy
{
	lda $eeee
        inc INPOS
        bne s0a
        inc INPOS+1
.s0a    rts
}
.zp_stuff_end
INCLUDE "exo.s"
.end
	
SAVE "code", start, end
PUTBASIC "drod.bas", "D"
PUTFILE "level01", "level01", $8000, $8000
PUTFILE "level02", "level02", $8000, $8000
PUTFILE "level03", "level03", $8000, $8000
PUTFILE "level04", "level04", $8000, $8000
PUTFILE "level05", "level05", $8000, $8000
PUTFILE "level06", "level06", $8000, $8000
PUTFILE "level07", "level07", $8000, $8000
PUTFILE "level08", "level08", $8000, $8000
PUTFILE "level09", "level09", $8000, $8000
PUTFILE "level10", "level10", $8000, $8000
PUTFILE "level11", "level11", $8000, $8000
PUTFILE "level12", "level12", $8000, $8000
PUTFILE "level13", "level13", $8000, $8000
PUTFILE "level14", "level14", $8000, $8000
PUTFILE "level15", "level15", $8000, $8000
PUTFILE "level16", "level16", $8000, $8000
PUTFILE "level17", "level17", $8000, $8000
PUTFILE "level18", "level18", $8000, $8000
PUTFILE "level19", "level19", $8000, $8000
PUTFILE "level20", "level20", $8000, $8000
PUTFILE "level21", "level21", $8000, $8000
PUTFILE "level22", "level22", $8000, $8000
PUTFILE "level23", "level23", $8000, $8000
PUTFILE "level24", "level24", $8000, $8000
PUTFILE "boot", "!BOOT", 0, 0
