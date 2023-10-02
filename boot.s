; boot code
	include "os.h"
	include "files.h"
	include "text.h"
	org $400
.boot_start
	
	include "core.s"
.boot_init
	; disable tube
	lda #234
	ldx #0
	jsr osbyte
	; implode charset
	lda #20
	ldx #0
	jsr osbyte
	; ack escape
	sec
	ror $ff
	lda #126
	jsr osbyte
	cli
	jsr getswr
	stx systype
	; clear screen memory
	lda #0
	ldx #0
.clear_loop
	sta $3000,x
	inx
	bne clear_loop
	inc clear_loop+2
	bpl clear_loop
	_print_string screen_setup,screen_setup_end
	lda #16
	ldx #0
	jsr osbyte
	lda #11
	ldx #25
	jsr osbyte
	lda #12
	ldx #4
	jsr osbyte
	lda #200
	ldx #1
	jsr osbyte
	jsr fs_init
	ldy #FILE_titlecode_exo
	lda systype
	bne notelk
	lda $282
	eor #%111000
	jsr $e495
;	lda #0
;	sta $242
	iny
.notelk
{
	ldx systype
	dex
	beq bbcb
	; we have the memory for a separate catbuf
	sty ytmp+1
	; load catbuf
	jsr get_from_cat
	; copy it
.loop
	lda SECBUF,X
	sta CATBUF,X
	inx
	bne loop
	; nop out future catbuf loads
	lda #$2c
	sta get_cat_sector_fixup
	; and refer to the copy instead
	lda #>CATBUF
	sta cat_fixup_1+2
	sta cat_fixup_2+2
	sta cat_fixup_3+2
	sta cat_fixup_4+2
	ldx #0
.ytmp
	ldy #OVERB
	jmp chain
.bbcb
	; we don't need init_get_byte_for_exo, avoid calling it so
	; it can be overwritten
	lda #$2c
	sta init_exo_fixup
}
	jmp chain
.screen_setup
	equb 22,1,19,2,5,0,0,0,23,1,0,0,0,0,0,0,0,0,23,0,5,1,0,0,0,0,0,0
.screen_setup_end
	include "swr.s"
.boot_end
	
SAVE "!BOOT",boot_start,boot_end,$ff0000+boot_init,$ff0000+boot_start
