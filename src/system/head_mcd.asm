; ===========================================================================
; -------------------------------------------------------------------
; SEGA CD header
;
; Header shared for both CD and CD32X
; -------------------------------------------------------------------

		dc.b "SEGADISCSYSTEM  "			; Disc Type (Must be SEGADISCSYSTEM)
	if MARSCD
		dc.b HTAG_DISCID_M,0			; Volume Name
	else
		dc.b HTAG_DISCID,0			; Volume Name
	endif
		dc.w HTAG_CDVER				; Volume Version
		dc.w $0001				; Volume Type
		dc.b HTAG_SYSNAME,0			; System Name
		dc.w 0					; System Version, Type
		dc.w 0
		dc.l IP_Start
		dc.l IP_End
		dc.l 0
		dc.l 0
		dc.l SP_Start
		dc.l SP_End
		dc.l 0
		dc.l 0
		align $100
		dc.b HTAG_SYS_MCD;"SEGA GENESIS    "			; Stays same as Genesis
		dc.b HTAG_DATEINFO;"(C)GF64 2024.???"
	if MARSCD
		dc.b HTAG_NDM_MARSCD;"Nikona CD32X                                    "
                dc.b HTAG_NOV_MARSCD;"Nikona CD32X                                    "
	else
		dc.b HTAG_NDM_MCD;"Nikona MCD                                      "
                dc.b HTAG_NOV_MCD;"Nikona SCD                                      "
	endif
		dc.b HTAG_SERIAL;"GM HOMEBREW-02  "
		dc.b "J6M             "
		align $1F0
		dc.b HTAG_REGIONS;"F               "

; ====================================================================
; ----------------------------------------------------------------
; IP
; ----------------------------------------------------------------

IP_Start:
	if CDREGION == 0
		binclude "system/mcd/region/jap.bin"
	elseif CDREGION == 2
		binclude "system/mcd/region/eur.bin"
	else
		binclude "system/mcd/region/usa.bin"	; <-- Default
	endif
		move.w	#$0100,(z80_bus).l		; Get Z80 bus
		move.w	#$0100,(z80_reset).l		; Z80 reset
.wait:
		btst	#0,(z80_bus).l
		bne.s	.wait
		lea	(vdp_data).l,a6
.wait_vint:	move.w	4(a6),d0
		btst	#3,d0
		beq.s	.wait_vint
		move.w	#$FD0C,(sysmcd_reg+mcd_hint).l	; Relocate HBlank jump
		jmp	($FF0600+MCD_Main).l
		align $800
IP_End:
		ds.b $260

; ====================================================================
; ----------------------------------------------------------------
; SP
; ----------------------------------------------------------------

		align $800
SP_Start:
		include "system/mcd/subcpu.asm"
SP_End:
		align 2

; ====================================================================
; ----------------------------------------------------------------
; Super-jump
; ----------------------------------------------------------------

		align $2800
MCD_Main:
	; --------------------------------
	; Copy colors
	; --------------------------------
		lea	(vdp_data),a6
		move.l	#$00000020,4(a6)		; Copy ALL palette colors
; 		lea	(RAM_Palette).w,a5		; <-- Current palette
		lea	($FFFFFF80).w,a5
		move.l	a5,a0
		move.w	#64-1,d1
.copy_colors:
		move.w	(a6),(a0)+
		dbf	d1,.copy_colors
	; --------------------------------
	; Quick fade-out
	; --------------------------------
.fade_out:
		move.w	4(a6),d0		; Wait VBlank
		btst	#3,d0
		beq.s	.fade_out
		move.l	a5,a0
		move.w	#64-1,d6		; Check all 64 colors
		moveq	#0,d7			; Exit flag
.next_color:
		move.w	(a0),d0
		beq.s	.nothing
		move.w	d0,d1
		andi.w	#$EE0,d0
		andi.w	#$00E,d1
		beq.s	.no_red
		subq.w	#2,d1
		addq.w	#1,d7
.no_red:
		or.w	d1,d0
		move.w	d0,d1
		andi.w	#$E0E,d0
		andi.w	#$0E0,d1
		beq.s	.no_green
		subi.w	#$020,d1
		addq.w	#1,d7
.no_green:
		or.w	d1,d0
		move.w	d0,d1
		andi.w	#$0EE,d0
		andi.w	#$E00,d1
		beq.s	.no_blue
		subi.w	#$200,d1
		addq.w	#1,d7
.no_blue:
		or.w	d1,d0
		move.w	d0,(a0)
.nothing:
		adda	#2,a0
		dbf	d6,.next_color
		move.l	#$C0000000,4(a6)
		move.w	#64-1,d6
		move.l	a5,a0
.copy_new:
		move.w	(a0)+,(a6)
		dbf	d6,.copy_new
.wait_next:
		move.w	4(a6),d0
		btst	#3,d0
		bne.s	.wait_next
	; --------------------------------
		tst.w	d7
		bne.s	.fade_out
		move.l	a5,a0
		moveq	#0,d6
		moveq	#64-1,d7
.cleanup:
		move.w	d6,(a0)+
		dbf	d7,.cleanup
