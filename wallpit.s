; wallpit: fixup walls and pits to display nicely
;
; We have the following rules:
; 1. a wall (tile 04) with a wall below it becomes tile 64
; 2. a crumbly wall (tile 05) with a wall below it becomes tile 65
; crumbly walls are walls for the purposes of rule 1.
; 3. a pit (tile 02) with a pit below it becomes tile 60
; 4. with two pits below it becomes tile 61
;
; We do this at runtime because (a) crumbly walls and pits are malleable
; (crumblies can be destroyed, pits are created by trapdoors), and
; because storing this information in the level data bloats it significantly.
; 
; Having this be a separate step keeps the plotting code fast.

zp_wallcount = zp_tmpx2
zp_pitcount = zp_tmpy2


; fixup an entire room. called on loading
.wallpit_room
{	
	; iterate each column
	ldx #37
	stx zp_tmpx
.loop
	jsr wallpit_col
	dec zp_tmpx
	bpl loop
	rts
}

.wallpit_col
{
	; iterate a row, top to bottom
	lda #0
	sta zp_tmpy
	sta zp_wallcount
	lda #2
	sta zp_pitcount
.loop
	ldx zp_tmpy
	ldy zp_tmpx
	jsr get_tile_ptr_and_index
	lda (zp_tileptr),Y
	; pit?
	cmp #2
	beq pit
	cmp #$60
	beq pit
	cmp #$61
	beq pit
; not a pit: reset the count
	ldx #0
	stx zp_pitcount
	; wall?
	cmp #4
	beq wall
	cmp #$64
	beq wall
	cmp #5
	beq wall
	cmp #$65
	beq wall
.notwall
; not a wall
; was there a wall above? fix it up
	ldx zp_wallcount
	bne do_wall
; reset the count
.wall_reset
	ldx #0
	stx zp_wallcount
.skip
	inc zp_tmpy
	ldx zp_tmpy
	cpx #32
	bne loop
	rts
.pit
{
	lda #2 ; default
	ldx zp_pitcount
	beq no
	lda #$61
	cpx #1
	bne no
	lda #$60
.no
	sta (zp_tileptr),Y ; replace
	inc zp_pitcount
	; now skip the wall stuff
	bne wall_reset ; always
}
.wall
{
	ora #$60
	sta (zp_tileptr),Y ; replace
	inc zp_wallcount
	bne skip ; always
}
.do_wall
{
	tya
	clc
	adc dirtable_offset+1
	tay
	lda (zp_tileptr),Y
	and #$5
	sta (zp_tileptr),Y	
	bpl wall_reset ; always
}
}
