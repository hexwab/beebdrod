IF MINI=1
.mini_oswrch
	cmp #13
	bne mini_real_oswrch
.mini_newl
	lda #32 ; padding hack
	jsr mini_real_oswrch
	lda #13
	jsr mini_real_oswrch
	bne mini_do_line ; always
.mini_real_oswrch
.stringptr
	sta $100
	inc stringptr+1
	rts
.mini_do_line
{
	stx xtmp+1
	sty ytmp+1
	ldx $318
IF PLATFORM_ELK
	dex
ENDIF
	ldy $319
	lda linetab_lo,Y
	clc
	adc mul16_lo,X
	sta zp_mini_screenptr
	lda linetab_hi,Y
	adc mul16_hi,X
	sta zp_mini_screenptr+1
.*mini_write_line_with_reset
	jsr mini_write_line
	lda #0
	sta stringptr+1
	inc $319
.xtmp	ldx #OVERB
.ytmp	ldy #OVERB
	rts
}
ENDIF
; A,X,Y preserved
.packed_wrch
{
	bpl notspace
	pha
	lda #32
IF MINI=1
	jsr mini_oswrch
ELSE
	jsr oswrch
ENDIF
	pla
.notspace
	and #$7f
	cmp #13
	beq do_osasci
	cmp #31
	bcc token
.do_osasci
IF MINI=1
	jmp mini_oswrch
ELSE
	jmp osasci
ENDIF
.token
	sty ytmp+1
	tay
	lda tokentable,Y
	tay
.tokloop
	lda tokens,Y
	php
	iny
	jsr packed_wrch
	plp
	bpl tokloop
.ytmp	ldy #0
	rts
.tokentable
	equb t0-tokens,t1-tokens,t2-tokens,t3-tokens
	equb t_septen-tokens
	equb t_sen-tokens
	equb t_quin-tokens
	equb t_quar-tokens
	equb t_thri-tokens
	equb t_twi-tokens
	equb t_on-tokens
	equb t_ce-tokens
	equb t_entran-tokens,0 ;skip nl
	equb t_south-tokens,t_north-tokens
	equb t_east-tokens,t_west-tokens
	equb t_the-tokens
	equb t_dot_nl-tokens

.tokens
.t0	equb "Ope",'n'+$80
.t1	equb "Clos",'e'+$80
.t2	equb "Toggl",'e'+$80
.t3	equb "Leve",'l'+$80
;.t3	equb " the",160
;.t4	equb " yo",u+128
;.t5	equb " o",'f'+128
.t_on ;4
	equb "O",'n'+$80
.t_twi ;5
	equb "Tw",'i'+$80
.t_thri ;6
	equb "Thr",'i'+$80
.t_quar ;7
	equb "Qua",'r'+$80
.t_quin ;8
	equb "Qui",'n'+$80
.t_sen ;9
	equb "Se",'n'+$80
.t_septen ;10
	equb "Septe",'n'+$80
.t_ce ;11
	equb "ce",' '+$80
.t_entran ;12
	equb " Entra",'n'+$80
tok_the_entran=12
.t_north ;14
	equb "Nort",'h'+$80
.t_south ;15
	equb "Sout",'h'+$80
.t_east ;16
	equb "Eas",'t'+$80
.t_west ;17
	equb "Wes",'t'+$80
.t_the ;18
	equb "Th",'e'+$80
.t_dot_nl ;19
	equb ".",13+$80
}
