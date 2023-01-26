; boot code
	include "os.h"
	include "files.h"
	include "text.h"
	org $400
.boot_start
	
	include "core.s"
.boot_init
	sec
	ror $ff
	lda #126
	jsr osbyte
	cli
	jsr getswr
	stx systype
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
	lda #234
	ldx #0
	jsr osbyte
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
	jmp chain
.screen_setup
	equb 22,1,19,2,5,0,0,0,23,1,0,0,0,0,0,0,0,0,23,0,5,1,0,0,0,0,0,0
.screen_setup_end
	include "swr.s"
.boot_end
	
SAVE "!BOOT",boot_start,boot_end,$ff0000+boot_init,$ff0000+boot_start
