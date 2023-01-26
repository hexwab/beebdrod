DEBUG=1

INCLUDE "text.h"
INCLUDE "core.s"
INCLUDE "files.h"
INCLUDE "os.h"

IF SMALL_SCREEN
	XRES=38
	YRES=32
	SCRSTART=$3400
ELSE
	XRES=40
	YRES=32
	SCRSTART=$3000
ENDIF


IF PLATFORM_BBCB
SPRTAB=$2000 ; must be 4K-aligned
ELSE
SPRTAB=$A000 ; must be 4K-aligned
ENDIF
; 256 non-masked sprites
; sprites are 16 bytes (8x8x2bpp)
; sprite 0 at SPRTAB+0
; sprite 1 at SPRTAB+$100
; ...
; sprite 15 at SPRTAB+$f00
; sprite 16 at SPRTAB+$10
; sprite 17 at SPRTAB+$110
; ...

; playing area size
XSIZE=38
YSIZE=32
; opaque layer:
; 01 blank
; 02 pit
; 04 wall
; 07 green door
; 09 yellow door closed
; 0a yellow door open
; 0c wall 2

;transparent layer
; 00 blank
; 09-14 force arrow
; 18 orb

LEVEL_HEADER_SIZE=5	
MAXROOMS=25
IF ENTIRE_LEVEL	
IF PLATFORM_ELK
level		= $1100
ELSE
level		= $8000
ENDIF
ELSE	
level		= $690
ENDIF	
level_nrooms    = level+0
level_startroom = level+1
level_startx    = level+2
level_starty    = level+3
level_startdir  = level+4
level_tables    = level+LEVEL_HEADER_SIZE
level_coordtab  = level_tables
level_roomptrlo = level_tables+MAXROOMS
level_roomptrhi = level_tables+MAXROOMS*2
level_orblen    = level_tables+MAXROOMS*3
LEVELHEADLEN	= level_tables+MAXROOMS*4-level

IF PLATFORM_ELK
room		= $9400
ELIF PLATFORM_BBCB
room		= $2800
ELSE
room		= $2300
ENDIF
room_end	= room+$aa0
orbs		= room_end

zp_tileptr	= $6e
zp_tmpx 	= $70
zp_tmpy 	= $71
zp_roomno	= $72

zp_playerx 	= $73
zp_playery 	= $74
zp_playerdir	= $75
zp_tmpdir	= $76
zp_currentforce	= $77 ; what directions any force tile under the player permits
zp_tmpindex	= $78
zp_tmpx2 	= $79
zp_tmpy2 	= $7a
zp_dxdy 	= $7b
zp_temp		= $7c
zp_temp2	= $7d
zp_moved_dir	= $7e ; what direction the player moved last
zp_tmpmask	= $7f ; sprite plotter
; pre-initialized zero page
IF EXO_FROM_RAM
zp=$44
ELSE
zp=$44+$a
ENDIF	
;tilelinetab_zp=zp+0 ; must be 32-byte aligned
zp_dirtablex = $4e
zp_dirtabley = $57
;zp_dir2_to_offset = zp+$60

IF PLATFORM_MASTER
	ORG $e00
	GUARD $2300
ELIF PLATFORM_ELK
	ORG $8000
	GUARD $9300
ELIF PLATFORM_BBCB
	ORG $1100
	GUARD $2000
ELSE
	ORG $1100
	GUARD $2300
ENDIF
.start
IF PLATFORM_BBCB
	; load sprites over init code
	jsr decrunch2
ENDIF
	jsr init_level
.mainloop
	jsr keys
	jmp mainloop

.keys
{
	jsr osrdch
	cmp #96
	bcc nosmash
	eor #$20
.nosmash
	cmp #'Q'
	bne notturnleft
.turnleft
{
	jsr erase_sword
	dec zp_playerdir
	bpl ok
	lda #7
	sta zp_playerdir
.ok	jsr check_sword
	jmp end_turn
}
.notturnleft
	cmp #'W'
	bne notturnright
.turnright
{
	jsr erase_sword
	inc zp_playerdir
	lda #8
	bit zp_playerdir
	beq ok
IF MASTER
	stz zp_playerdir
ELSE
	lda #0
	sta zp_playerdir
ENDIF	
.ok	jsr check_sword
	jmp end_turn
}
.notturnright
	cmp #'R'
	bne notrestart
.do_restart
	jmp restart_room
.notrestart
; check directions
{
  	ldx #7
.dirloop
	cmp keytab1,X
	beq yep
	cmp keytab2,X
	beq yep
	dex
	bpl dirloop

	cmp #'M'
	bne notmap
IF SMALL_SCREEN
	jsr hwscroll_screen_off
	ldy #FILE_map_overlay_exo
	jsr chain
	jmp hwscroll_screen_on
ELSE
	jmp do_map
ENDIF
.notmap

IF DEBUG
; cursors move to next room
;{
	cmp #$AB
	bne notup
	jmp movenorth_d
.notup
	cmp #$AA
	bne notdown
	jmp movesouth_d
.notdown
	cmp #$A9
	bne notright
	jmp moveeast_d
.notright
	cmp #$A8
	bne notleft
	jmp movewest_d
.notleft
;}
ENDIF	
	rts
.yep	jmp move_player
}
.done
	rts
}
.keytab1 ; numpad
	EQUS "78963214"
.keytab2 ; vi-style
	EQUS "YKULNJBH"

.init_level
	lda level_startx
	sta zp_playerx
	lda level_starty
	sta zp_playery
	lda level_startdir
	sta zp_playerdir
	lda #255
	sta zp_currentforce
	ldy level_startroom
	sty zp_roomno
IF HWSCROLL
	lda #0
	sta came_from+1
ENDIF
IF SHADOW_MAP
	jsr init_map
ENDIF
	jmp init_room

.restart_room
.restartx
	lda #OVERB
	sta zp_playerx
.restarty
	lda #OVERB
	sta zp_playery
.restartdir
	lda #OVERB
	sta zp_playerdir
IF HWSCROLL
	lda #0
	sta came_from+1
ENDIF

.init_room
{
IF PLATFORM_ELK
	jsr hwscroll_screen_off
ENDIF
	ldx zp_roomno
	; mark room as explored
	lda level_coordtab,X
	ora #$80
	sta level_coordtab,X
IF ENTIRE_LEVEL
IF level<>$8000
	lda level_roomptrhi,X
	sec
	sbc #($80->level)
	tay
ELSE
	ldy level_roomptrhi,X
ENDIF
	lda level_roomptrlo,X
	sta orbptr+1
	sty orbptr+2
	clc
	adc level_orblen,X
	bcc noinc
	iny
.noinc
	tax
	lda #>room_end
	sta zp_exo_dest_hi
	lda #<room_end
	jsr decrunch_to_no_header ; decompress room
ELSE ; not ENTIRE_LEVEL
	jsr seek_level
	ldy zp_roomno
	jsr seek_room
{
	; copy orbs
	ldy zp_roomno
	lda level_orblen,Y
	beq orbdone
	sta tmp+1
	ldx #0
.orbloop
.orbptr	jsr fs_get_byte
	sta orbs,X
	inx
.tmp	cpx #OVERB
	bne orbloop
.orbdone
}
	lda #>room_end
	sta zp_exo_dest_hi
	lda #<room_end
	sta zp_exo_dest_lo
	lda #1
	jsr continue_decrunching
ENDIF

	ldy zp_playerx
	sty restartx+1
	ldx zp_playery
	stx restarty+1
	lda zp_playerdir
	sta restartdir+1
	; ensure player is standing on empty floor
	; this may not otherwise be the case if there was a
	; crumbly wall on the border
	jsr get_tile_ptr_and_index
	lda #$01
	sta (zp_tileptr),Y

	jsr wallpit_room
IF HWSCROLL
	jsr hwscroll
ELSE
	jsr plot_entire_room
ENDIF

IF ENTIRE_LEVEL
	; copy orbs
	; do this *after* hwscroll as orb buffer and scroll buffer overlap
	ldy zp_roomno
	ldx level_orblen,Y
	beq orbdone
.orbloop
	dex
.orbptr	lda OVERW,X
	sta orbs,X
	cpx #0
	bne orbloop
.orbdone
ENDIF

IF PLATFORM_ELK
	jsr hwscroll_screen_on
ENDIF

IF SHADOW_MAP
	jsr update_map
ENDIF
	jsr check_sword
	jsr draw_player
	rts
}
.draw_player
{
IF 0
	ldx zp_playerx
	ldy zp_playery
	lda #$40 ; FIXME
	ora zp_playerdir
	jsr plot
ELSE
	jsr get_player_tile
	stx background_sprite+1
	ldx zp_playerx
	ldy zp_playery
	lda #$40 ; FIXME
	ora zp_playerdir
	jsr plot_masked_inline_with_background
ENDIF

.*draw_sword
	ldy zp_playerdir
	lda zp_playerx
	clc
	adc zp_dirtablex,Y
	bmi off
	cmp #XSIZE
	beq off
	tax
	lda zp_playery
	clc
	adc zp_dirtabley,Y
	tay
	bmi off
	cmp #YSIZE
	beq off
	lda #$48 ; sword
	ora zp_playerdir
	jmp plot_masked_inline
.off	rts
}

.erase_player
{
	ldy zp_playerx
	ldx zp_playery
	jsr draw_tile
.*erase_sword
	ldx zp_playerdir
	lda zp_playerx
	clc
	adc zp_dirtablex,X
	bmi off
	cmp #XSIZE
	beq off
	tay
	lda zp_playery
	clc
	adc zp_dirtabley,X
	bmi off
	cmp #YSIZE
	beq off
	tax
	jmp draw_tile
.off	rts
}
.fail_early
	jmp end_turn
; dir in X
.move_player
{
	stx zp_tmpdir
	lda bitmasktab,X
	bit zp_currentforce
	beq fail_early
	jsr erase_player
	lda zp_playerx
	sta tmp_playerx+1
	ldx zp_tmpdir
	stx zp_moved_dir
	clc
	adc zp_dirtablex,X
	sta zp_playerx
	lda zp_playery
	sta tmp_playery+1
	clc
	adc zp_dirtabley,X
	sta zp_playery

.check_contents
{
	jsr get_player_tile
	sty zp_tmpindex
	cpx #$04 ; wall
	beq fail
	cpx #$64 ; wall
	beq fail
	cpx #$02 ; pit
	beq fail
	cpx #$60 ; pit
	beq fail
	cpx #$61 ; pit
	beq fail
	cpx #$05 ; crumbly
	beq fail
	cpx #$65 ; crumbly
	beq fail
	cpx #$0c ; wall2
	beq fail
	cpx #$70 ; 70-72 is pillar 
	bcc notpillar
	cpx #$73
	bcc fail
.notpillar
	cpx #$09 ; closed yellow door
	beq fail
	cpx #$18 ; orb
	beq fail
	cmp #$23 ; tar
	beq fail
	cpx #$03 ; stairs
	bne notstairs
	jmp dostairs
.notstairs
	; check scroll
	cpx #$17
	bne notscroll
.scroll
	lda zp_playerx
	sta zp_tmpx
	lda zp_playery
	sta zp_tmpy
	jsr orb 
	jmp ok
.notscroll
	; check force tiles
	cpx #$0d
	bcc notforce
	cpx #$15
	bcs notforce
.force
	ldy zp_tmpdir
	lda bitmasktab,Y
	sta zp_tmpdir
	lda forcetab-$0d,X
	bit zp_tmpdir
	beq fail
	sta zp_currentforce
	bne ok ; always
}
.notforce
	lda #255
	sta zp_currentforce
.ok
	lda zp_playery
	bmi movenorth
	cmp #YSIZE
	beq movesouth
	lda zp_playerx
	bmi movewest
	cmp #XSIZE
	beq moveeast
	jsr check_sword
	jmp end_turn
.fail
.tmp_playerx
	lda #OVERB
	sta zp_playerx
.tmp_playery
	lda #OVERB
	sta zp_playery
	lda #255 ; no movement
	sta zp_moved_dir
	jmp end_turn

.movenorth
	lda #YSIZE-1
	sta zp_playery
.*movenorth_d
	lda #$f8 ;#$f0
	bne traverse ;always
.movesouth
IF MASTER
	stz zp_playery
ELSE
	lda #0
	sta zp_playery
ENDIF
.*movesouth_d	
	lda #8 ;#$10
	bne traverse ;always
.movewest
	lda #XSIZE-1
	sta zp_playerx
.*movewest_d
	lda #$ff
	bne traverse ;always
.moveeast
IF MASTER
	stz zp_playerx
ELSE
	lda #0
	sta zp_playerx
ENDIF
.*moveeast_d
	lda #$01
}

; move one room, direction in A (3:3)
.traverse
{
IF HWSCROLL
	sta came_from+1
ENDIF
	ldx zp_roomno
	clc
	adc level_coordtab,X
	tay
	ldx #0
.loop
	tya
	eor level_coordtab,X
	and #$3f ; mask off explored/conquered flags
	beq gotit
	inx
IF DEBUG
	cpx #MAXROOMS
ENDIF
	bne loop
IF DEBUG
.fail	rts;equb $2c
ENDIF
.gotit
	stx zp_roomno
	jmp init_room
}
; direction in X
.get_player_tile_with_direction
{	
	lda zp_playerx
	clc
	adc zp_dirtablex,X
	tay
	lda zp_playery
	clc
	adc zp_dirtabley,X
	tax
	sty zp_tmpx
	stx zp_tmpy
	jmp get_tile
}
.check_sword
	ldx zp_playerdir
	jsr get_player_tile_with_direction
	cpx #$18
	beq orb
.notorb
	cpx #$05
	beq crumbly
	cpx #$65
	bne notcrumbly
.crumbly
{
	ldy zp_tmpx
	ldx zp_tmpy
	jsr get_tile_ptr_and_index
	lda #$01
	sta (zp_tileptr),Y
	lda zp_tmpy
	pha
	jsr wallpit_col
	pla
	sta zp_tmpy
	; redraw tile and the one above
	jsr plot_bounds_from_tmpxy
	dec zp_tmpy
	jmp plot_bounds_from_tmpxy
}
.notcrumbly
	cmp #$66 ; FIXME
	bne notmonster
.monster
.kill_tile
{
	; replace transp with empty
	ldy zp_tmpx
	ldx zp_tmpy
	jsr get_tile
	lda #$00
.tmp	sta (zp_tileptr),Y
	jmp plot_from_tile_with_special
}
	
.notmonster
	cmp #$3c ; baby
	beq monster
	cmp #$23
	bne nottar
	; kill tar
	jsr tar_get_corner
	bcc nottar
	jsr kill_tile
IF 0
	dec zp_tmpx
	jsr tar_update ; left
	inc zp_tmpx
	inc zp_tmpy
	jsr tar_update ; up
	dec zp_tmpy
	inc zp_tmpx
	jsr tar_update ; right
	dec zp_tmpx
	dec zp_tmpy
	jmp tar_update ; down
ELSE
	dec zp_tmpx
	jsr tar_real_update ; do it twice
.tar_real_update
{	jsr tar_update ; W
	inc zp_tmpy
	jsr tar_update ; NW
	inc zp_tmpx
	jsr tar_update ; N
	inc zp_tmpx
	jsr tar_update ; NE
	dec zp_tmpy
	jsr tar_update ; E
	dec zp_tmpy
	jsr tar_update ; SE
	dec zp_tmpx
	jsr tar_update ; S
	dec zp_tmpx
	jsr tar_update ; SW
	inc zp_tmpy
	rts
}
ENDIF	
.nottar
	rts

; skip past scroll text (stored along with the orbs)
.skip_scroll
	lda orbs+2,Y
	bne orb_skip_a ;always
	INCLUDE "orb.s"	
	INCLUDE "scroll.s"

	
; won level. draw animation and load next level
.dostairs
{	
.stairloop
	jsr draw_player
	lda #30
	jsr delay
	jsr erase_player
	inc zp_playery
	jsr get_player_tile
	cpx #$03
	beq stairloop
.done
	inc levelno
	ldy #FILE_intro_exo
	jmp chain
}
MINI=1	
	INCLUDE "sprite.s"
	INCLUDE "minifont.s"
	INCLUDE "text.s"
	INCLUDE "map.s"
	INCLUDE "zap.s"
	INCLUDE "tar.s"
	INCLUDE "wallpit.s"
; this is for orbs adjusting doors
; X,Y reversed coords
.fill
{
FILL_STACK_SIZE=$60
set_array_x=$100
set_array_y=$100+FILL_STACK_SIZE
	; zp_temp is last array index used
	sty set_array_x
	stx set_array_y
	lda #$ff
	sta zp_temp
	bne skip ;always
.loop
	; pos = open_set.pop()
	ldx zp_temp
	bmi done
	dec zp_temp
	ldy set_array_x,X
	lda set_array_y,X
	tax
	sty zp_tmpx
	stx zp_tmpy
.skip
	; fb[pos] = b
	jsr get_tile_ptr_and_index
	sty ytmp+1
.*fill_to
	lda #OVERB
	sta (zp_tileptr),Y
	jsr get_last_tile
	jsr plot_from_tile_with_special
	; for npos in neighbours(pos):
	ldx #7
.neighloop
	; if fb[npos] == a:
.ytmp
	lda #OVERB
	clc
	adc dirtable_offset,X
	tay
	lda (zp_tileptr),Y
.*fill_from
	cmp #OVERB
	bne no

	lda fill_to+1
.tmp4	sta (zp_tileptr),Y
	; open_set.append(npos)
	inc zp_temp
	ldy zp_temp
	lda zp_tmpx
	clc
	adc zp_dirtablex,X
	sta set_array_x,Y
	lda zp_tmpy
	clc
	adc zp_dirtabley,X
	sta set_array_y,Y
.no
	dex
	bpl neighloop
	bmi loop ; always

.done
	rts
}

.end_turn
	;lda #7
	;jsr oswrch
	;jsr move_monsters
	jsr check_trapdoor
	jsr redraw_roaches
	jmp draw_player

.move_monsters
{
	lda #31
	sta zp_tmpy2
	ldx #1
	stx zp_tmpy
.lineloop
	lda #37
	sta zp_tmpx2
	ldy #1
	sty zp_tmpx
	jsr get_tile_ptr_and_index
	iny
	sty zp_tmpindex
.loop
.tmp
	lda (zp_tileptr),Y
	;sta $ffff
	cmp #$66 ; FIXME
	bne no
	; got one!
	;lda #7
	;jsr oswrch

{	; get dx
	lda zp_playerx
	cmp zp_tmpx
	beq zero
	bcc less
.more
	lda #1
	bne done ;always
.zero
	lda #0
	;beq done ;always
	equb $2c
.less
	lda #2
.done
}
{	; get dy
	ldx zp_playery
	cpx zp_tmpy
	beq zero
	bcc less
.more
	ora #4
	bne done ;always
.less
	ora #8
.zero
.done
}
	;ora #$40
	;jsr oswrch
	tax
	beq nodxdy
	stx zp_dxdy
	
	lda dir2_to_offset,X
	clc
	adc zp_tmpindex
	tay
	lda (zp_tileptr),Y
	cmp #0
	bne no

	tya
	tax
	ldy zp_tmpindex
	lda tmp+1
	jsr move_monster
	
.redraw_moved
	ldx zp_tmpx
	ldy zp_tmpy
	lda #$88 ; FIXME
	jsr plot
	ldx zp_dxdy
	lda dir2_to_dir,X
	tay
	lda zp_tmpx
	clc
	adc zp_dirtablex,Y
	tax
	lda zp_tmpy
	clc
	adc zp_dirtabley,Y
	tay
	lda #$44
	jsr plot

.nodxdy
	
.no
	dec zp_tmpx2
	bmi linedone
	inc zp_tmpx
	ldy zp_tmpindex
	iny
	iny
	sty zp_tmpindex
	bne loop ;always
.linedone
	dec zp_tmpy2
	bmi done
	inc zp_tmpy
	ldx zp_tmpy
	jmp lineloop
.done
	rts
}
	rts

; in: zp_tmpx/zp_tmpy
; out: A dir 0-7
.get_dir_to_player
{	
{	; get dx
	lda zp_playerx
	cmp zp_tmpx
	beq zero
	bcc less
.more
	lda #1
	bne done ;always
.zero
	lda #0
	;beq done ;always
	equb $2c
.less
	lda #2
.done
}
{	; get dy
	ldx zp_playery
	cpx zp_tmpy
	beq zero
	bcc less
.more
	ora #4
	bne done ;always
.less
	ora #8
.zero
.done
}
	tax
	lda dir2_to_dir,X
	rts
}
	
IF 0
; coords in tmpx,tmpy, A dir
.move_monster_full
{
	sta tmp+1
	ldy zp_tmpx
	ldx zp_tmpy
	jsr get_tile
	clc
.tmp	ldx #0
	adc dir2_to_offset,X
}
ENDIF	

; A ptr, Y old index, X new index
.move_monster
{
.tmp	lda (zp_tileptr),Y
	sta tmp3+1
	lda #0
.tmp2	sta (zp_tileptr),Y
	txa
	tay
.tmp3	lda #OVERB
.tmp4	sta (zp_tileptr),Y
	rts
}

.plot_entire_room
{
	ldx #0
	stx zp_tmpy
	lda #38
	ldy #32
; X: x start. A: x end. zp_tmpy: y start. Y: y end
.*plot_some_room
	stx xstart+1
	sta xend+1
	sty yend+1
	;lda #19
	;jsr $fff4
	ldx zp_tmpy
.yloop
.xstart
	ldy #OVERB
	sty zp_tmpx
	jsr get_tile
	sty zp_tmpindex ; +1
	;cmp #0 ; skip get_last_tile 
	bcc skip ;always
IF DEBUG
	brk
ENDIF
.xloop
	; next tile
	ldy zp_tmpindex
	iny
	sty zp_tmpindex
	inc zp_tmpindex
IF INLINE_GET_TILE
	lda (zp_tileptr),Y
	iny
	tax
	lda (zp_tileptr),Y
ELSE
	jsr get_last_tile
ENDIF
.skip
	jsr plot_from_tile_with_special
	
	inc zp_tmpx
	ldy zp_tmpx
.xend	cpy #OVERB
	bcc xloop
	inc zp_tmpy
	ldx zp_tmpy
.yend	cpx #OVERB
	bcc yloop
IF 0
; print room number, @-Z
	lda #31
	jsr oswrch
	lda #38
	jsr oswrch
	lda #0
	jsr oswrch
	lda zp_roomno
	ora #$40
	jsr oswrch
ENDIF
	rts
}
IF 1
.get_tile_ptr_and_index_with_bounds
{
	; n=0, m=37 => 0<=X<=37?
	clc
	txa
	adc #$FF-37
	adc #37-0+1
	bcs outside
	; n=0, m=31 => 0<=Y<=31?
	tya
	adc #$FF-31
	adc #31-0+1
	bcs outside
	
	jsr get_tile_ptr_and_index
	clc
.outside
	rts
}
ENDIF
; X,Y reversed coords. returns: zp_tileptr set, index into table in Y
; No bounds checking.
; The idea here is that Y is close-ish to 128 (specifically between 80 and 160),
; allowing you to investigate any of the eight surrounding tiles by modifying
; Y rather than having to call a function multiple times.
; Why reversed coords?  Otherwise the index we need in Y would end up in X.

.get_tile_ptr_and_index
{
	;bmi outside
	;cmp #38
	;bcs outside
	tya
	asl a
	adc #40*2+2 ; carry always clear
	tay
	inx
	lda tileptr_lo,X
	sta zp_tileptr
	lda tileptr_hi,X
	sta zp_tileptr+1
	rts
}

.get_player_tile
{
	ldy zp_playerx
	ldx zp_playery
	; fall through
}	
; X,Y reversed coords. returns: opaque layer in X, transparent layer in A, Z set if A zero
.get_tile
{
IF INLINE_GET_TILE
	tya
	asl a
	adc #40*2+2 ; carry always clear
	tay
	inx
	lda tileptr_lo,X
	sta zp_tileptr
	lda tileptr_hi,X
	sta zp_tileptr+1
ELSE
	jsr get_tile_ptr_and_index
ENDIF
.*get_last_tile
	lda (zp_tileptr),Y
	iny
	tax
	lda (zp_tileptr),Y
	rts
}
;UNUSED FIXME
; in: tmpx, tmpy, tmpdir. out: C set if blocked
.blocked_by_arrow
{	; first check start tile
	ldy zp_tmpx
	ldx zp_tmpy
	jsr get_tile
	sty zp_tmpindex
	ldy zp_tmpdir
	cpx #$0d
	bcc notforce
	cpx #$15
	bcs notforce
.force
	lda bitmasktab,Y
	and forcetab-$0d,X
	beq fail
.ok
.notforce
	; then check dest tile
	lda dirtable_offset,Y
.tmp	ldy #0
	
	
.fail
	sec
	rts
}

.redraw_roaches
{
	;; redraw roaches around the player, so that they face the correct direction:
	;       YYY
	;       YYY
	; XXXXXXZZZXXXXXX
	; XXXXXXZ@ZXXXXXX
	; XXXXXXZZZXXXXXX
	;       YYY
	;       YYY
	; Z's get plotted twice, oh well
; three Y rows
{
	ldx #31
	stx zp_tmpy
.yloop2
	ldx zp_tmpy
	ldy zp_playerx
	dey
	sty zp_tmpx
	jsr get_tile_ptr_and_index ;_with_bounds
	;bcs skip
	iny
	ldx #2
.yloop1
	lda (zp_tileptr),Y
	cmp #$66 ; roach? (FIXME)
	bne no
	jsr do_roach
.no
	iny
	iny
	inc zp_tmpx
	dex
	bpl yloop1
.skip	
	dec zp_tmpy
	bpl yloop2
}
; 3 X rows
{
	ldx zp_playery
	dex
	lda #2
	sta zp_temp
.xloop2
	stx zp_tmpy
	ldy #0
	sty zp_tmpx
	jsr get_tile_ptr_and_index ;_with_bounds
	;bcs skip
	iny
	ldx #37
.xloop1
	lda (zp_tileptr),Y
	cmp #$66 ; roach? (FIXME)
	bne no
	jsr do_roach
.no
	iny
	iny
	inc zp_tmpx
	dex
	bpl xloop1
.skip
	ldx zp_tmpy
	inx
	dec zp_temp
	bpl xloop2
}
	rts
.do_roach
	stx xtmp+1
	sty ytmp+1
	dey
	jsr get_last_tile
	jsr plot_from_tile_with_special
.xtmp	ldx #OVERB
.ytmp	ldy #OVERB
	rts
}

.check_trapdoor
{
	lda zp_moved_dir ; which direction we came from
	bmi no
	eor #4 ; rotate 180 degrees
	tax
	jsr get_player_tile_with_direction
	cpx #$0b ; trapdoor
	bne no
	dey
	lda #$02
	sta (zp_tileptr),Y ; replace with pit
	lda zp_tmpy
	pha
	jsr wallpit_col
	pla
	sta zp_tmpy
	; redraw tile and the two below
	jsr redraw
	inc zp_tmpy
	jsr redraw
	inc zp_tmpy
.redraw	
	ldx zp_tmpy
	ldy zp_tmpx
	jmp plot_tile_with_special
.no	rts
}
	
.bitmasktab
	EQUB $80,$40,$20,$10,$08,$04,$02,$01
.forcetab
	EQUB %11110001, %11111000, %01111100, %00111110
	EQUB %00011111, %10001111, %11000111, %11100011
.dirtable_offset
	;EQUB (-40-1)*2-1,(-40)*2-1, (-40+1)*2-1, (1)*2-1
	;EQUB (+40+1)*2-1,(+40)*2-1, (+40-1)*2-1, (-1)*2-1
	EQUB (-40-1)*2,(-40)*2, (-40+1)*2, (1)*2
	EQUB (+40+1)*2,(+40)*2, (+40-1)*2, (-1)*2
.dir2_to_dir
	EQUB 99,3,7,99, 5,4,6,99, 1,2,0
.dir2_to_offset
	EQUB 0,2,-2,0, 80,82,78,0, -80,-78,-82 

.tileptr_lo
	FOR I,0,33,1
	EQUB <((I-1)*40*2+room)
	NEXT
.tileptr_hi
	FOR I,0,33,1
	EQUB >((I-1)*40*2+room)
	NEXT
	

;INCLUDE "exo.s"
INCLUDE "hwscroll.s"
INCLUDE "level.s"
.abort
{
	cli
	ldx #<flash
	ldy #>flash
	lda #12
	jsr osword
.halt	bne halt
.flash	equb 2,10,0,0,0
}
	CLEAR $2300,$3000
	GUARD $3000
; this can be overwritten at runtime
.init
{
	ldx #$ff
	txs
	; setup brk vector
	lda #<abort
	sta $202
	lda #>abort
	sta $203
IF PLATFORM_BBCB=0
	ldy #FILE_tiles_exo
	jsr load_and_decrunch
ENDIF
	jsr load_level

.init_zp
{
	ldy #zp_stuff_end-zp_stuff-1
.loop	lda zp_stuff,Y
	sta zp,Y
	dey
	bpl loop
}

	_print_string space,space_end
IF SMALL_SCREEN
	lda #<rowmult
	sta $e0
	lda #>rowmult
	sta $e1 ; tell OS about new line spacing
	; this is model B only
	lda #1
	sta $fe00
	lda #76
	sta $fe01 ; R1 (chars per line)=76
	lda #13
	sta $fe00
	lda #$80
	sta $fe01 ; R13=$80, set screen start address to $3400
	;lda #2
	;sta $fe00
	;lda #96
	;sta $fe01 ; R2=96, shift screen right
	lda #$34 ; screen start hi
	sta $34e ; tell OS where screen starts
	sta $351
	lda #$60 ; low byte of bytes per line
	sta $352
	lda #$4c ; screen size: only needed for hw scrolling
	sta $354
IF 1
.makerowmult
{
	ldx #0
	lda #0
	sta rowmult,X
	sta rowmult+1,X
	clc
.loop
	lda rowmult+1,X
	adc #$60
	sta rowmult+3,X
	lda rowmult,X
	adc #$2
	sta rowmult+2,X	
	inx
	inx
	cpx #62
	bne loop
}
ENDIF
ENDIF

IF PLATFORM_BBCB
.load_tiles
	ldy #FILE_tiles_exo
	jsr load_and_init_decrunch
	jsr fs_get_byte ; skip header
	jsr fs_get_byte
	lda #>(SPRTAB+$800)
	sta zp_exo_dest_hi
	lda #<(SPRTAB+$800)
	sta zp_exo_dest_lo
	ldx #1
ENDIF
	jsr osrdch ;wait for key
	jmp start
.space
	equb 26,31,13,28,"[Press SPACE]"
.space_end
}

.zp_stuff
IF EXO_FROM_RAM	
.get_crunched_byte_copy
{
	lda OVERW
        inc INPOS
        bne s0a
        inc INPOS+1
.s0a    rts
}
ENDIF	
; NW,N,NE,E,SE,S,SW,W,centre
.dirtablex_copy
	EQUB -1,0,1,1,1,0,-1,-1,0
.dirtabley_copy
	EQUB -1,-1,-1,0,1,1,1,0,0
	
.zp_stuff_end
.end

PRINT "load=",~start
PRINT "exec=",~init
SAVE "code", start, end, init
