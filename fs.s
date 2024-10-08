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

SECBUF=$400
CATBUF=$af00
CATLO=SECBUF+CAT_LO_OFFSET
CATHI=SECBUF+CAT_HI_OFFSET
zp_fs_tmphi=$9f
	;INCLUDE "os.h"
	;ORG $400
.fs_start

MACRO INIT_DECRUNCH_TO loc
	ldx #>loc
	lda #<loc
ENDMACRO

MACRO INIT_DECRUNCH_FILE_TO file,loc
	ldy #file
	jsr load_and_init_decrunch
	INIT_DECRUNCH_TO loc
ENDMACRO

MACRO DECRUNCH_TO loc
	INIT_DECRUNCH_TO loc
	jsr decrunch_to
ENDMACRO

MACRO DECRUNCH_FILE_TO file,loc
	INIT_DECRUNCH_FILE_TO file,loc
	jsr decrunch_to
ENDMACRO

MACRO CHAIN file
	ldy #file
	jmp chain
ENDMACRO

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
.xtmp	ldx #OVERB
.ytmp	ldy #OVERB
	plp
	pla
	rts
}
BUFOFF=secbufptr+1

.chain
	jsr load_and_init_decrunch
	; exec address
	jsr fs_get_byte
	pha
	jsr fs_get_byte
	pha
	; load address
	jsr fs_get_byte
	tax
	jsr fs_get_byte
	jmp decrunch_to
	
	; cat in Y
.load_and_init_decrunch
.get_cat_and_sector
	jsr get_from_cat
	jmp get_sector

; parameter block for OSWORD $7F
.diskblk
.diskblk_drive
	equb 0 ; drive number
	equw SECBUF ; buffer address
	equw $ffff ; I/O space
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
.*get_from_cat
{
	sty cat_entry+1

	; load catalogue from track 0 sector 1
	ldy #0
	sty diskblk_track
	iny
	sty diskblk_sector
.*get_cat_sector_fixup
	jsr get_sector
	ldy #0
	sty diskblk_sector
	sty BUFOFF

	; loop over all catalogue entries in turn, incrementing the
	; offset as we go
	;ldy #0
.*cat_entry
	cpy #OVERB
	beq done
.loop
	lda BUFOFF ; lo byte
	clc
.*cat_fixup_1
	adc CATLO,Y
	sta BUFOFF
	lda diskblk_sector ; hi byte
.*cat_fixup_2
	adc CATHI,Y
	jsr possibly_inc_track
	iny
	bne cat_entry ; always
.done
	rts
}

;; ; Y=catalogue entry
;; .get_cat_length
;; {
;; .*cat_fixup_3
;; 	lda CATHI,Y
;; .*cat_fixup_4
;; 	ldx CATLO,Y
;; 	rts
;; }

	; skip forward XA bytes
.fs_skip_word
{
	pha
	txa
	clc
	adc diskblk_sector
	jsr possibly_inc_track
	pla
}
	; skip forward A bytes
.fs_skip
{
	clc
	adc BUFOFF
	sta BUFOFF
	bcc fs_exit
}

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
	sbc #SECTORS_PER_TRACK
	bpl incloop ; always
.noinc
	sta diskblk_sector
.*fs_exit
	rts
}

.get_next_sector
	jsr inc_sector
.get_sector
	ldx #<diskblk
	ldy #>diskblk
	lda #$7f
	jsr osword
	lda diskblk+10 ; result
	bne get_sector
	rts
;.error	brk
;	jmp osword


; this too can be overwritten if unneeded
; Y=catalogue entry, AX=location
.load_file_to
{
	stx dst+1
	sta dst+2
	jsr get_from_cat
.*cat_fixup_3
 	lda CATHI,Y
	sta zp_fs_tmphi
.*cat_fixup_4
 	lda CATLO,Y
	pha
	jsr get_sector
	pla
	tax
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
	ora #$20
	sta diskblk_drive

.restore_getbyte_func
	ldx #<fs_get_byte
	lda #>fs_get_byte
.set_getbyte_func
{	ldy #1
.loop
	sta getbyte_fixup1+1,Y
	sta getbyte_fixup2+1,Y
	sta getbyte_fixup3+1,Y
	txa
	dey
	bpl loop
	rts
}
.set_mem_getbyte_func
	ldx #<get_crunched_byte
	lda #>get_crunched_byte
	bpl set_getbyte_func ; always

.gbpb_block
	equw gbpb_block
	equw $ffff ; I/O space

.fs_end
