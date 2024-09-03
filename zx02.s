; De-compressor for ZX02 files
; ----------------------------
;
; Decompress ZX02 data (6502 optimized format), optimized for minimal size:
;  130 bytes code, 72.6 cycles/byte in test file.
;
; Compress with:
;    zx02 input.bin output.zx0
;
; (c) 2022 DMSC
; Code under MIT license, see LICENSE file.


zp_zx02=$97

ZX0_dst         = zp_zx02+0

{
offset          = zp_zx02+2
pntr            = zp_zx02+4
bitr            = zp_zx02+6

.*decrunch_to
	sta ZX0_dst
        stx ZX0_dst+1

;--------------------------------------------------
; Decompress ZX0 data (6502 optimized format)

.*decrunch
	; Get initialization block
        ldy #5
	lda #$80
.copy_init
        sta offset-1, y
	asl A
        dey
        bne copy_init

; Decode literal: Ccopy next N bytes from compressed file
;    Elias(length)  byte[1]  byte[2]  ...  byte[N]
.decode_literal
        jsr   get_elias

.cop0
.*getbyte_fixup1
        jsr   fs_get_byte
{	sta (ZX0_dst),Y
	iny
	bne skip
	inc ZX0_dst+1
.skip	dex
}
        bne   cop0

        asl   bitr
        bcs   dzx0s_new_offset

; Copy from last offset (repeat N bytes from last offset)
;    Elias(length)
        jsr   get_elias
.dzx0s_copy
        lda   ZX0_dst
        sbc   offset  ; C=0 from get_elias
        sta   pntr
        lda   ZX0_dst+1
        sbc   offset+1
        sta   pntr+1

.cop1
{        lda   (pntr),Y
	sta (ZX0_dst),Y
	iny
	bne skip
	inc ZX0_dst+1
	inc pntr+1
.skip	dex
        bne   cop1
}
        asl   bitr
        bcc   decode_literal

; Copy from new offset (repeat N bytes from new offset)
;    Elias(MSB(offset))  LSB(offset)  Elias(length-1)

.dzx0s_new_offset
; Read elias code for high part of offset
        jsr   get_elias
        beq   exit  ; Read a 0, signals the end
	; Decrease and divide by 2
        dex
        txa
        lsr   A
        sta   offset+1

	; Get low part of offset, a literal 7 bits
.*getbyte_fixup2
        jsr   fs_get_byte

	; Divide by 2
        ror   A
        sta   offset

	; And get the copy length.
	; Start elias reading with the bit already in carry:
        ldx   #1
        jsr   elias_skip1

        inx
        bcc   dzx0s_copy

; Read an elias-gamma interlaced code.
; ------------------------------------
.get_elias
	; Initialize return value to #1
        ldx   #1
        bne   elias_start

.elias_get     ; Read next data bit to result
        asl   bitr
        rol   A
        tax

.elias_start
	; Get one bit
        asl   bitr
        bne   elias_skip1

	; Read new bit from stream
.*getbyte_fixup3
        jsr   fs_get_byte
	;sec   ; not needed, C=1 guaranteed from last bit
        rol   A
        sta   bitr

.elias_skip1
        txa
        bcs   elias_get
	; Got ending bit, stop reading
.exit   rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Initial values for offset, source, destination and bitr
;.zx0_ini_block
;	equb $00, $00, $80, $00, $00
}
