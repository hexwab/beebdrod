; boot code
	include "os.h"
	include "files.h"
	include "text.h"
	org $400
.boot_start
	
	include "core.s"
.boot_init
	cli
	_print_string screen_setup,screen_setup_end
	ldy #FILE_title_exo
	jsr load_and_decrunch
	lda #4
	sta $f4
	sta $fe30
	lda #11
	ldx #25
	jsr osbyte
	lda #12
	ldx #4
	jsr osbyte
	ldy #FILE_tiles_exo
	jsr load_and_decrunch
	jsr osrdch
	ldy #FILE_intro_exo
	jsr load_and_decrunch
	jmp $2500
.screen_setup
	equb 22,1,19,2,5,0,0,0,23,1,0,0,0,0,0,0,0,0
.screen_setup_end
.boot_end
	
SAVE "!BOOT",boot_start,boot_end,boot_init
	

