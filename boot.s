; boot code
	include "os.h"
	include "files.h"
	include "text.h"
	org $400
.boot_start
	
	include "core.s"
.boot_init
	cli
	jsr getswr
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
	ldy #FILE_titlecode_exo
	lda systype
	bne notelk
	iny
.notelk
	jmp chain
.screen_setup
	equb 22,1,19,2,5,0,0,0,23,1,0,0,0,0,0,0,0,0
.screen_setup_end
	include "swr.s"
.boot_end
	
SAVE "!BOOT",boot_start,boot_end,boot_init
