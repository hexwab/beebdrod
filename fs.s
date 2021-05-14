; filesystem driver

; Design goals:
; small and simple as possible
; many files on a disc (~100)
; no sector padding
; index files by number not by name
; no load/exec addresses, maybe not even lengths
; filesize up to 32K/64K
; can handle arbitrary sector counts (and sizes?)
; need to be able to write (but not allocate) files
;
; Non-goals:
; Asynchronous operation

; API
; set sector from catalogue entry along with byte ptr
; get next sector
; get next byte

; disc format:
; catalogue in sector 1 (using all the space unused by DFS)
; table of hi/lo lengths for 


SECTORS_PER_TRACK=10 ; maybe 11 if we need more space?
;CAT_LO_OFFSET=$20 ; leave two files for DFS, 112 for us
;CAT_HI_OFFSET=$90 ; $20+($100-$10)/2
CAT_LO_OFFSET=$30 ; leave four files for DFS, 104 for us
CAT_HI_OFFSET=$98 ; $30+($100-$30)/2
START_TRACK=1 ; where data starts. this gives us 2K for boot code
NEED_LOAD_FILE_TO=1

SECBUF=$700
CATBUF=SECBUF
SEPARATE_CATBUF=0
CATLO=CATBUF+CAT_LO_OFFSET
CATHI=CATBUF+CAT_HI_OFFSET
zp_fs_tmpcount=$9f
zp_fs_tmphi=$9f
	;INCLUDE "os.h"
	;ORG $400
.fs_start

; for exo. must preserve A,X,Y,C
.fs_get_byte
{
.*secbufptr
	lda SECBUF
	inc secbufptr+1
	beq get_next_sector_and_byte
	rts
.*get_next_sector_and_byte
	pha
	php
	stx xtmp+1
	sty ytmp+1
	jsr get_next_sector
.xtmp	ldx #$ee
.ytmp	ldy #$ee
	plp
	pla
	rts
}
BUFOFF=secbufptr+1

MACRO _chain file,addr
	ldy #file
	lda #>(addr-1)
	pha
	lda #<(addr-1)
	pha
	jmp load_and_decrunch
ENDMACRO
	; cat in Y
.load_and_decrunch
	jsr load_and_init_decrunch
	ldx #3
	jmp decrunch2
	
.load_and_init_decrunch
{
	jsr get_from_cat
	jsr get_next_sector
}
.init_get_byte_for_exo
{
IF 1
	; 12 bytes
	lda #$4C ; JMP
	sta get_crunched_byte
	lda #<fs_get_byte
	sta get_crunched_byte+1
	lda #>fs_get_byte
	sta get_crunched_byte+2
	rts
ELSE
	; 13 bytes
	ldy #2
.loop
	lda igbfe_tab,Y
	sta get_crunched_byte,Y
	dey
	bpl loop
	rts
.igbfe_tab
	equb $4C
	equw fs_get_byte
ENDIF
}

; parameter block for OSWORD $7F
.diskblk
.diskblk_drive
	equb 0 ; drive number
	equw SECBUF ; buffer address
	equw $ffff
	equb 3 ; 3 command parameters
	equb &53 ; read data multi-sector
.diskblk_track
	equb 0 ; track
.diskblk_sector
	equb 0 ; sector
	equb 1*32+1 ; sector size/count (size 1=256, count=1)
.diskblk_result
	equb 0 ; result

; Y=catalogue entry. Y preserved
; track,sector,offset set
.get_from_cat
{
	sty cat_entry+1

IF SEPARATE_CATBUF=0
	; load catalogue from track 0 sector 1
	ldy #0
	sty diskblk_track
	iny
	sty diskblk_sector
	jsr do_osword
ELSE
	; assume it's already loaded (at F00?)
ENDIF
	; data starts at track 1 sector 0
IF 1
	ldy #0
	sty diskblk_sector
	sty BUFOFF
	iny
	sty diskblk_track
ELSE
	dec diskblk_sector ; 1->0
	inc diskblk_track  ; 0->1
	; FIXME: still need to zero bufptr offset
ENDIF


	; loop over all catalogue entries in turn, incrementing the
	; offset as we go
	ldy #0
.cat_entry
	cpy #$ee
	beq done
.loop
	lda BUFOFF ; lo byte
	clc
	adc CATLO,Y
	sta BUFOFF
	lda diskblk_sector ; hi byte
	adc CATHI,Y
	jsr possibly_inc_track
	iny
	bne cat_entry ; always
.done
	rts
}

; Y=catalogue entry
.get_cat_length
{
	lda CATHI,Y
	ldx CATLO,Y
	rts
}

IF NEED_LOAD_FILE_TO=1
; Y=catalogue entry, AX=location
.load_file_to
{
	stx dst+1
	sta dst+2
	jsr get_from_cat
	jsr get_cat_length
	sta zp_fs_tmphi
	jsr get_next_sector_and_byte ; byte is unused here
	ldy #0
.loop
	jsr fs_get_byte
.dst
	sta $ee00,Y
	iny
	bne noinc
	inc dst+2
.noinc
	dex
	bne loop
	dec zp_fs_tmphi
	bpl loop
	rts
}	
ENDIF

	; skip forward A bytes
.fs_skip
{
	clc
	adc secbufptr+1
	sta secbufptr+1
	bcs get_next_sector
	rts
}	

.get_next_sector
	jsr do_osword
.inc_sector
{
	ldx diskblk_sector
	inx
	txa
}

; sector number in A	
.possibly_inc_track
{
.incloop
	cmp #SECTORS_PER_TRACK
	bcc noinc
	inc diskblk_track
	;sec
	sbc #SECTORS_PER_TRACK
	bpl incloop ; always
.noinc
	sta diskblk_sector
	rts
}

.do_osword
	ldx #<diskblk
	ldy #>diskblk
	lda #$7f
	jsr osword
	lda diskblk+10 ; result
	bne error
	rts
.error	brk

IF 0
.get_next_sector
	jsr do_osword
	; A=0 for success
	inc diskblk_sector
	ldx #SECTORS_PER_TRACK
	cmp diskblk_sector
	bne noinc
	sta diskblk_sector ; reset to zero
	inc diskblk_track
.noinc
	rts
ENDIF

; initialization (can be overwritten)
.fs_init
	; init current drive number
	; we cannot rely on this being at $10CB
	lda #6
	ldx #<(gbpb_block-1)
	ldy #>(gbpb_block-1)
	jsr osgbpb ; read drive+dir
	lda gbpb_block+1
	and #3
	sta diskblk_drive
	rts
.gbpb_block
	equd gbpb_block
	
.fs_end
;PUTBASIC "fstest.bas","fstest"
;SAVE "fs",fs_start,fs_end
