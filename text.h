MACRO _print_string start,end
{	ldx #0
.loop
	lda start,X
	jsr oswrch
	inx
	cpx #end-start
	bne loop
}
ENDMACRO

MACRO _print_packed_string start,end
{	ldx #0
.loop
	lda start,X
	jsr packed_wrch
	inx
	cpx #end-start
	bne loop
}
ENDMACRO
