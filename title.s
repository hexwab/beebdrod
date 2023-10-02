	INCLUDE "os.h"
	INCLUDE "text.h"
	INCLUDE "files.h"
	INCLUDE "hw.h"
	INCLUDE "core.s"
	DELAY=6 ; animation delay, frames
	DEST=$32b0
	LINELEN=640
	zpsrc=$70
	zpstart=$72
	zpend=$73
	timer_flag=$74
	ORG $8000
	INCLUDE "heads.out.s"
	ORG $2000
	INCLUDE "heads.ptrs.s"
	
	ORG $1100
.start
.beeb
	; we only have enough memory for one frame
	FRAME=2 ; which single frame we plot
IF 0
	ldy #FILE_heads_exo
	jsr load_and_init_decrunch
	jsr fs_get_byte
	eor #$d0 ; load at $5000 instead of $8000
	sta zp_dest_hi
	ldx #2
	jsr decrunch2

	; fixup pointers
	lda ptrhi+FRAME
	eor #$d0
	sta ptrhi+FRAME
ENDIF
	ldy #FRAME ; plot a single frame
	jsr heads_plot

	jmp common

.init
IF PLATFORM_ELK
	lda $282
	eor #%111000
	jsr $e495
ENDIF
	_print_string screen_blank_clear_white,screen_blank_clear_white_end
	; print systype
{	ldx systype
	ldy systype_ptr,X
.loop
	lda systype_text,Y
	beq done
	jsr oswrch
	iny
	bne loop ; always
.done
}
	ldy #FILE_headsptrs_exo
	jsr load_and_decrunch
	ldx systype
	dex
	beq beeb ; PLATFORM_BBCB
	ldy #FILE_heads_exo
	jsr load_and_decrunch
.common
	ldy #FILE_title_exo
	jsr load_and_decrunch
	lda #4
	ldx #1
	jsr osbyte
	lda #9
	ldx #DELAY
	jsr osbyte
	lda #10
	ldx #DELAY
	jsr osbyte
	jsr init_timer
	lda #19
	jsr osbyte
	_print_string screen_set,screen_set_end
	lda levelno
	bne no
	dec levelno
.no	jsr set_level
.restart
	ldy #0
.mainloop
	sty ytmp+1
	ldx systype
	dex
	beq wait ; PLATFORM_BBCB
	jsr heads_plot
	;lda #$f0
	;sta $fe21
	lda #19
	jsr osbyte
.wait
	lda #$81
	ldx #0
	ldy #0
	jsr osbyte
	bcc dokey
.donekey
	lda timer_flag
	beq wait
	lda #DELAY
	cmp $251
	bne wait
.ytmp	ldy #$ee
	iny
	cpy #8
	beq restart
	bne mainloop
.dokey
{	
	cpx #$8B
	beq up
	cpx #$89
	beq up
	cpx #'.'
	beq up
	cpx #'>'
	bne notup
.up
	jsr inc_level
	jmp donekey
.notup
	cpx #$8A
	beq down
	cpx #$88
	beq down
	cpx #','
	beq down
	cpx #'<'
	bne notdown
.down
	jsr dec_level
	jmp donekey
}
.notdown	
.done
	lda #19
	jsr osbyte
	jsr deinit_timer
	_print_string screen_clear_2,screen_clear_2_end
	ldy levelno
	bmi story
	ldy #FILE_intro_exo
	jmp chain
.story
	inc levelno
	ldy #FILE_story_exo
	jmp chain
.screen_blank_clear_white
	equb 19,3,0,0,0,0,19,2,0,0,0,0,19,1,0,0,0,0,17,131,12
	equb 31,20,4,17,0
.screen_blank_clear_white_end
.screen_clear_2
	equb 19,0,7,0,0,0,19,2,7,0,0,0,19,1,7,0,0,0
.screen_clear_2_end
.screen_set
	equs " version"
	equb 19,1,1,0,0,0,19,2,5,0,0,0,19,3,7,0,0,0
	equb 31,20,8
	equb 23,255,$0c,$18,$30,$7f,$30,$18,$0c,$00,255
	equb 31,36,8
	equb 23,255,$30,$18,$0c,$fe,$0c,$18,$30,$00,255
.screen_set_end
.level_start
	equb 31,22,8,"   Level",32
.level_end
.story_start
	equb 31,22,8,"The Beginning"
.story_end

.dec_level
	dec levelno
	jmp set_level
.inc_level
	inc levelno
.set_level
	lda levelno
	cmp #254
	beq inc_level
	cmp #255
	beq beginning
	cmp #25
	beq dec_level
	_print_string level_start,level_end
	lda levelno
	clc
	adc #1
	cmp #20
	bcc not20
	sbc #20
	pha
	lda #'2'
	jsr oswrch
	pla 
.not20
	cmp #10
	bcc not10
	sbc #10
	pha
	lda #'1'
	jsr oswrch
	pla
.not10
	clc
	adc #48
	jsr oswrch
	lda #32
	ldx #3
.loop
	jsr oswrch
	dex
	bne loop
	rts
.beginning
	_print_string story_start,story_end
	rts

.systype_ptr
{
	equb elk-systype_text
	equb bbcb-systype_text
	equb beeb-systype_text
	equb master-systype_text
.*systype_text
.elk	equs "Electron",0
.bbcb	equs "  BBC B",0
.beeb	equs "Enhanced",0
.master	equs " Master",0
}

VSYNC=$4e3c
TIMER1=$2500
TIMER2=VSYNC-TIMER1
.init_timer
{
	sei
IF PLATFORM_ELK=0
	lda #2
.l	bit SYSVIA_IFR
	beq l
	lda #LO(TIMER1)
	sta USERVIA_T1CL
	lda #HI(TIMER1)
	sta USERVIA_T1CH
	lda #LO(TIMER2)
	sta USERVIA_T1LL
	lda #HI(TIMER2)
	sta USERVIA_T1LH
	lda #%01000000
	sta USERVIA_ACR
	lda #%11000000
	sta USERVIA_IER
ENDIF
	lda #0
	sta timer_flag
	lda $204
	sta oldirq+1
	lda $205
	sta oldirq+2
        lda #<irq
        ldx #>irq
	bne set_irq1v ; always
}
.deinit_timer
{
IF PLATFORM_ELK=0
	lda #%01000000
	sta USERVIA_IER
ENDIF
	lda oldirq+1
	ldx oldirq+2
	; fall-through
}
.set_irq1v
{
	sei
        sta $204
        stx $205
	cli
	rts
}
.irq
{
IF PLATFORM_ELK
	lda $fe00
	bit four
	bne vsync
	bit eight
	bne rtc
.*oldirq
	jmp $ffff
.vsync
	lda #0
	sta timer_flag
	lda #$d1
	sta $fe09
	bne oldirq ;always
.rtc
	lda #1
	sta timer_flag
	lda #$f1
	sta $fe09
	bne oldirq ;always
.four	equb 4
.eight	equb 8
ELSE
	lda USERVIA_IFR
        bmi uservia
.*oldirq
	jmp $ffff
.uservia
	;lda USERVIA_T1CL ; clear interrupt
	lda timer_flag
	bne vsync
.timer
	lda #LO(TIMER1)
	sta USERVIA_T1LL
	lda #HI(TIMER1)
	sta USERVIA_T1LH
	lda #$26
.setpal
	sta $fe21
	ora #$10
	sta $fe21
	ora #$40
	sta $fe21
	and #$ef
	sta $fe21
	and #2
	sta timer_flag
	lda $fc
	rti
.vsync
	lda #LO(TIMER2)
	sta USERVIA_T1LL
	lda #HI(TIMER2)
	sta USERVIA_T1LH
	lda #$24
	bne setpal
ENDIF
}
	INCLUDE "heads.s"
.end
	
	PRINT "load=",~start
	PRINT "exec=",~init
	SAVE "titlecode",start,end
	
