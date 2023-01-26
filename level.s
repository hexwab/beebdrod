; level helpers
; there are two ways we can do this:
; (a) we load the entire level in SWRAM
; (b) we load only the header, and load rooms on demand

IF ENTIRE_LEVEL
.load_level
	lda levelno
	clc
	adc #FILE_level01
	tay
	ldx #<level
	lda #>level
	jmp load_file_to
ELSE
.seek_level
	lda level_loc_stash
	ldx level_loc_stash+1
	ldy level_loc_stash+2
	jmp fs_set_loc
.load_level
	lda levelno
	clc
	adc #FILE_level01
	tay
	jsr get_from_cat
	jsr get_sector
	jsr fs_get_loc
	sta level_loc_stash
	stx level_loc_stash+1
	sty level_loc_stash+2
	ldy #0
.loop
	jsr fs_get_byte
	sta level,Y
	iny
	cpy #LEVELHEADLEN
	bne loop
	rts

	;room in Y
.seek_room
{
	lda level_roomptrhi,Y
	and #$7f
	tax
	lda level_roomptrlo,Y
	jsr fs_skip_word
	jmp get_sector
}
.level_loc_stash
	equb 0
	equb 0
	equb 0
ENDIF
