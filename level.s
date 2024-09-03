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
.level_loc_stash1
	lda #OVERB
	sta BUFOFF
.level_loc_stash2
	lda #OVERB
	sta diskblk_sector
.level_loc_stash3
	lda #OVERB
	sta diskblk_track
	rts
.load_level
	lda levelno
	clc
	adc #FILE_level01
	tay
	jsr load_and_init_decrunch
	lda BUFOFF
	sta level_loc_stash1+1
	lda diskblk_sector
	sta level_loc_stash2+1
	lda diskblk_track
	sta level_loc_stash3+1
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
ENDIF
