; map: draw the map screen

; we can either draw it from scratch every time, which is at best expensive
; (because we need to decompress every visited room) and possibly
; super-expensive if we need to fetch the rooms from disc.

; Alternatively, if we have shadow screen we can update the map in the
; background as we visit each room.  Then only the banner needs
; drawing when we actually view the map screen as all the rooms are
; already drawn.  We still need to take care of highlighting the
; current room.

; decrunched level is 40*34*2=2720 bytes
IF SMALL_SCREEN=1
	LINELEN=$230
	MAP_SCRSTART=$3a00
	map_xoffset=0
	map_tiles_temp = $2000
	before_map=*
	ORG $3700
	GUARD $3a00
ELSE
	LINELEN=$280
	MAP_SCRSTART=$3000
	map_xoffset=24
IF SHADOW_MAP
	map_tiles_temp = room
ELSE
	map_tiles_temp = $b000 ; FIXME: not on B+64K
ENDIF
ENDIF
map_tiles_temp_end = map_tiles_temp+40*34*2

zp_tmpchar=$79
zp_screen_hoffset=$7a
zp_linecount=$7b
zp_screenptr=$7c
zp_tmproomno=$7e

IF SHADOW_MAP
.update_map
{
	lda #4
	tsb $fe34
	lda #255
	sta zp_tmproomno ; never highlight
	ldy zp_roomno
	lda level_coordtab,Y
	jsr map_set_screen_address
	jsr draw_room
	lda #4
	trb $fe34
	rts
}
.do_map
{
	lda #6 ; write to shadow RAM
	tsb $fe34
	ldx hwscroll_addr_lo
	lda hwscroll_addr_hi
	pha
	phx
	jsr hwscroll_reset

	jsr map_draw_banner

	ldy zp_roomno
	lda level_coordtab,Y
	sty zp_tmproomno ; highlight

	; note that we are drawing from a non-pristine room
	; but whatever the player has done should not affect
	; the resulting map tile
	jsr map_set_screen_address
	jsr draw_room
	lda #19
	jsr osbyte
	jsr hwscroll_set_6845
	lda #1 ; display shadow RAM
	tsb $fe34
	jsr osrdch
	lda #19
	jsr osbyte
	plx
	pla
	jsr hwscroll_set_start
	jsr hwscroll_set_6845
	lda #1 ; display main RAM
	trb $fe34

	ldy zp_roomno
	lda level_coordtab,Y
	dey
	sty zp_tmproomno ; unhighlight
	jsr map_set_screen_address
	jsr draw_room
	lda #6 ; write to main RAM
	trb $fe34
	rts
}
.init_map
{
	lda #6 ; write to shadow RAM
	tsb $fe34
	ldx #0
.loop
	lda clearmaptab,X
	jsr oswrch
	inx
	cpx #clearmaptab_end-clearmaptab
	bne loop
	lda #6 ; write to main RAM
	trb $fe34
	rts
}

.clearmaptab
	equb 26,17,128+BACKG_COL,12
.clearmaptab_end

ELSE ; not SHADOW_MAP
.do_map
{
	jsr hwscroll_screen_off
IF HWSCROLL
	jsr hwscroll_reset
	jsr hwscroll_set_linetab
	jsr hwscroll_set_6845
ENDIF

IF SMALL_SCREEN
{
	; stash $300 bytes from $2800-$2b00 to $3400-$3700
	ldx #0
.loop	lda $2800,X
	sta $3400,X
	lda $2900,X
	sta $3500,X
	lda $2a00,X
	sta $3600,X
	inx
	bne loop
.clear
	lda #$cc
	sta $35e
	ldy #$20
	lda #BACKG_BYTE
	jsr $cbdd
}
	lda #$46 ; screen size
	sta $354
	ldx #<MAP_SCRSTART
	lda #>MAP_SCRSTART
	sta $34e
	jsr hwscroll_set_start
	jsr hwscroll_set_6845

	lda #70
	ldy #1
	ldx #93
	jsr $ca2b
	; hack: set line pointers
	lda #$3a
	sta linetab_hi
	lda #$3c
	sta linetab_hi+1
	lda #$30
	sta linetab_lo+1
	sta rowmult+3
ENDIF
	jsr map_draw_banner

IF HWSCROLL OR SMALL_SCREEN
	jsr hwscroll_screen_on
ENDIF
	jsr draw_map_screen
IF PLATFORM_ELK
	jsr hwscroll_screen_on
ENDIF
IF SMALL_SCREEN
{
	; unstash $300 bytes from  $3400-$3700 to $2800-$2b00
	ldx #0
.loop	lda $3400,X
	sta $2800,X
	lda $3500,X
	sta $2900,X
	lda $3600,X
	sta $2a00,X
	inx
	bne loop
	; reload tiles
	ldy #FILE_tiles_exo
	jsr load_and_init_decrunch
	jsr fs_get_byte ; skip header
	jsr fs_get_byte
	lda #>(SPRTAB+$800)
	sta zp_exo_dest_hi
	lda #<(SPRTAB+$800)
	sta zp_exo_dest_lo
	ldx #1
	jsr decrunch2
}
ENDIF
	jsr osrdch ; wait for key
IF SMALL_SCREEN
	ldx #<SCRSTART
	lda #>SCRSTART
	jsr hwscroll_set_start
	jsr hwscroll_set_6845
	lda #$4c ; screen size
	sta $354
	lda #76
	ldy #1
	ldx #96
	jsr $ca2b
	; hack: set line pointers
	lda #$34
	sta linetab_hi
	lda #$36
	sta linetab_hi+1
	lda #$60
	sta linetab_lo+1
	sta rowmult+3
	jsr hwscroll_screen_off
ENDIF

IF PLATFORM_ELK
	jsr hwscroll_screen_off
	jsr plot_entire_room
	jmp hwscroll_screen_on
ELSE
	jmp plot_entire_room
ENDIF
}

.exit rts
; we only need 280x256 pixel screen = 17920 bytes
; rooms are 40x34 pixels (38x32 plus border)
; max 7x7 map area (FIXME: level 8 is 8 high)

.draw_map_screen
{
IF ENTIRE_LEVEL
	; iterate over each room
	ldy level_nrooms
.roomloop
	dey
	bmi exit
	lda level_coordtab,Y
	bpl roomloop ; skip unexplored rooms
	sty zp_tmproomno


	jsr map_set_screen_address
{	
	; decompress tiles to temporary storage
	; we start from the end and decompress backwards
	lda #>map_tiles_temp_end
	sta zp_exo_dest_hi
	ldx zp_tmproomno
IF level<>$8000
	lda level_roomptrhi,X
	sec
	sbc #($80->level)
	tay
ELSE
	ldy level_roomptrhi,X
ENDIF
	lda level_roomptrlo,X
	clc
	adc level_orblen,X
	bcc noinc
	iny
.noinc
	tax
	lda #<map_tiles_temp_end
	jsr decrunch_to_no_header
}
	jsr draw_room

.room_done
	ldy zp_tmproomno
	jmp roomloop
ELSE ; not ENTIRE_LEVEL
	; we read through rooms in order, to minimise seeking.
	; drawing a room automatically sets the seek pointer to the next room.
	; whenever we draw a room we seek forward to compensate for any rooms
	; we skipped drawing. this way we only load rooms we actually draw.
	jsr seek_level
	lda #LEVELHEADLEN
	jsr fs_skip
	ldy #0
	sty zp_tmproomno
	equb $30 ; skip (BMI never taken)
.roomloop
	iny
	cpy level_nrooms
	beq exit
	lda level_coordtab,Y
	bpl roomloop ; skip unexplored rooms

	cpy zp_tmproomno
	beq skipcatchup
	; catch up
	ldx zp_tmproomno
	sty zp_tmproomno
	lda level_roomptrlo,Y
	sec
	sbc level_roomptrlo,X
	pha
	lda level_roomptrhi,Y
	sbc level_roomptrhi,X
	tax
	pla
        jsr fs_skip_word
	ldy zp_tmproomno
	lda level_coordtab,Y
.skipcatchup
	jsr map_set_screen_address

	ldy zp_tmproomno
	lda level_orblen,Y
	jsr fs_skip
	jsr get_sector
	lda #>map_tiles_temp_end
	sta zp_exo_dest_hi
	lda #<map_tiles_temp_end
	sta zp_exo_dest_lo
	lda #1
	jsr continue_decrunching
	jsr draw_room

.room_done
	ldy zp_tmproomno
	inc zp_tmproomno ; room seek pointer is currently at
	jmp roomloop
ENDIF

}	
ENDIF ; not SHADOW_MAP

.initmaptab
{
IF SMALL_SCREEN
	xpos=1
ELSE
	xpos=3
ENDIF
	equb 26,17,128+BACKG_COL
IF SHADOW_MAP=0 AND SMALL_SCREEN=0
	equb 12
ELSE
	equb 30
ENDIF
	equb 17,3
	equb 31,xpos,0
	equb 23,255,$07,$01,$07,$0f,$07,$0f,$07,$03,255
	equb 10,8
	equb 23,255,$01,$03,$07,$01,$00,$01,$03,$01,255
	equb 31,xpos+31,0
	equb 23,255,$e0,$f0,$f0,$e0,$f0,$80,$00,$c0,255
	equb 10,8
	equb 23,255,$e0,$f0,$f0,$e0,$80,$e0,$c0,$e0,255
	equb 28,xpos+1,1,xpos+30,0,17,131,12
	; blank two bottom rows, leaving 14 filled
	equb 18,0,131,18,0,BACKG_COL
	equb 25,77,<640,>640,<960,>960
	equb 25,77,<640,>640,<964,>964
}
.initmaptab_end

.map_set_screen_address
{
	; coords in A (3:3)
	jsr split_coord
	tay
	lda gridx_lo,X
	clc
	adc gridy_lo,Y
	sta zp_screenptr
	lda gridx_hi,X
	adc gridy_hi,Y
	sta zp_screenptr+1
	rts
}

.map_draw_banner
{
	ldx #0
.loop
	lda initmaptab,X
	jsr oswrch
	inx
	cpx #initmaptab_end-initmaptab
	bne loop
	jsr print_level_name
	lda #':'
	ldy #' '
	jsr print_a_y
	ldx zp_roomno
	lda level_coordtab,X
	jsr print_map_offset
IF FANCY_BORDERS
MAP_TEXT_POS = MAP_SCRSTART + LINELEN/2 ; middle of top line
	
.centre_map_text
	; finish text, with padding hack
	lda #32
	jsr mini_real_oswrch
	lda #0
	jsr mini_real_oswrch
	
	; centre text	
	jsr mini_get_width
	; width{lo,hi} contain the width in pixels
	; we want half that (/2) in bytes (/4) so divide by 8.
	; but then each char is 8
	lda #<MAP_TEXT_POS
	sec
	sbc zp_widthlo
	and #$f8
	ora #3 ; 3 pixels down
	sta zp_mini_screenptr
	lda #>MAP_TEXT_POS
	sbc zp_widthhi
	sta zp_mini_screenptr+1
	jmp mini_write_line_with_reset
ELSE
	lda #13
	jmp packed_wrch ; hack to force write
ENDIF
}

.print_level_name
{	
	ldx #0
.loop	
	lda namestash,X
	php
	jsr packed_wrch
	inx
	plp
	bpl loop
	rts
}

; A=zzyyyxxx -> A=yyy X=xxx
.split_coord
{
	pha
	and #$07
	tax
	pla
	lsr A
	lsr A
	lsr A
	and #$07
	rts
}

; offset (3:3) in A
.print_map_offset
{
	tay
	ldx level_startroom
	lda level_coordtab,X
	jsr split_coord
	sta tmp+1
	stx tmp2+1
	tya
	jsr split_coord
	stx tmp3+1
	ldy #14 ; tok_north
	sec
.tmp
	sbc #$00
	sta zp_tmpx
	beq done
	jsr print_dir_offset
.done
.tmp3
	lda #$00
	ldy #16 ;tok_east
	sec
.tmp2
	sbc #$00
	beq done2
	
	; maybe print a comma
	php
	pha
	lda zp_tmpx
	beq skip
	lda #','
	ldy #' '
	jsr print_a_y
	ldy #16 ;tok_east
.skip
	pla
	plp
	
.print_dir_offset
	bpl north ; carry is set if taken
.south
	iny
	equb $2c ; skip
	; carry is clear here
.north
	eor #$ff
	adc #11
.*print_a_ce_y
	ldx #11 ;tok_ce
.*print_a_x_y
	jsr packed_wrch
	txa
.*print_a_y
	jsr packed_wrch
	tya
	jmp packed_wrch
.done2
	lda zp_tmpx
	bne done3
.entrance
	lda #18;tok_the
	ldx #12;tok_entran
	ldy #11;tok_ce
	bne print_a_x_y ;always
.done3
	rts
}

; draw map of one room
.draw_room
{
	lda #>(map_tiles_temp+40*2)
	sta tileptr+2

	lda #32
	sta zp_linecount
	ldx #0 ; offset into map tiles
.do_line
	lda #0
	sta zp_screen_hoffset
	
.check_tile

.tileptr
	lda map_tiles_temp+40*2,X ; start one line down
	cmp #$01
	beq notblank
.blank
	lda #$00
.notblank
{	
	ror a
	rol zp_tmpchar
	inx
	inx
	bne noincx
	inc tileptr+2
;	lda #>(map_tiles_temp+33*40*2)
;	cmp tileptr+2
;	beq done
.noincx
	txa
	and #7 ; 4 pixels
	bne check_tile
}
.done_collecting_pixels
	; now zp_tmpchar has 4 bits of pixel data in 3:0
	lda zp_tmpchar
	and #$0f
	tay
	lda MUL17TABLE,Y
	ldy zp_tmproomno
	cpy zp_roomno
	php
	ldy zp_screen_hoffset
	; fixup left/right borders (present in map, but we don't want them)
	bne notzero
	; remove left border
	ora #$88
.notzero
	cpy #72
	bne not72
	; remove right border
	ora #$11 
.not72
	plp
	beq h
	and #$0f
	eor #$ff
	jmp j
.h
	; highlighted room
	and #$ff
	eor #$0f
.j

	
.screenptr
	sta (zp_screenptr),Y
	tya
	clc
	adc #8
	sta zp_screen_hoffset

	; more this line?
	cmp #8*10
	bne check_tile
{
	; move one line down
	inc zp_screenptr
	bne noinc
	inc zp_screenptr+1
.noinc
	lda #7
	and zp_screenptr
	bne noincline
	lda zp_screenptr
	clc
	adc #<(LINELEN-8)
	sta zp_screenptr	
	lda zp_screenptr+1
	adc #>(LINELEN-8)
	sta zp_screenptr+1
.noincline
}
	dec zp_linecount
	bne do_line
	rts
}

.gridx_lo
	FOR i,0,6,1
	EQUB <(i*10*8)
	NEXT
.gridx_hi
	FOR i,0,6,1
	EQUB >(i*10*8)
	NEXT
.gridy_lo
	FOR i,0,6,1
	EQUB <(MAP_SCRSTART+(((i*34+16) AND 7)+((i*34+16) DIV 8)*LINELEN)+map_xoffset)
	NEXT
.gridy_hi
	FOR i,0,6,1
	EQUB >(MAP_SCRSTART+(((i*34+16) AND 7)+((i*34+16) DIV 8)*LINELEN)+map_xoffset)
	NEXT

IF SMALL_SCREEN
	PRINT "mapload=",~do_map
	PRINT "mapexec=",~do_map
	SAVE "map_overlay",do_map,P%
	ORG before_map
ENDIF
