; ===========================================================================
; -------------------------------------------------------------------
; 32X BOOT FOR SEGA CD, modified from original.
;
; SH2 CODE MUST BE ALREADY LOADED ON WORD-RAM AND WITH
; PERMISSION SET TO MAIN.
; -------------------------------------------------------------------

		lea	(sysmars_reg).l,a5
		cmp.l	#"MARS",(sysmars_id).l	; Check MARS ID
		bne	MarsError
.sh_wait:
		moveq	#0,d0
		btst.b	#7,adapter+1(a5)	; Wait for SH2 reset
		beq.b	.sh_wait
		btst.b	#0,adapter+1(a5)	; Check Adapter mode
		bne	Hot_Start		; If already enabled, it's a Hot Start
.cold_start:
		move.b	#%01,adapter+1(a5)	; Turn ON the 32X and Reset SH2
		move.w	#19170,d7		; 8
.res_wait:
		dbra	d7,.res_wait		; 12*d7+10
		move.l	d0,comm0(a5)
		move.l	d0,comm4(a5)
		move.b	#%11,adapter+1(a5)	; Adapter enable + Cancel/Stop SH2 Reset
; 		vdp_showme $0EE
.fm3
		bclr.b	#7,(a5)			; Set SVDP to Genesis
		bne.b	.fm3
		move.w	d0,$02(a5)		; Interrupt Reg.
		move.w	d0,$04(a5)		; Bank Reg.
		move.w	d0,$06(a5)		; DREQ Control Reg.
		move.l	d0,$08(a5)		; DREQ Source Address Reg.
		move.l	d0,$0C(a5)		; DREQ Destination Address Reg.
		move.w	d0,$10(a5)		; DREQ Length Reg.
		move.w	d0,$30(a5)		; PWM Control
		move.w	d0,$32(a5)		; PWM fs Reg.
		move.w	d0,$38(a5)		; PWM Mono Reg.
		move.w	d0,$80(a5)		; SVDP: Bitmap Mode Reg
		move.w	d0,$82(a5)		; SVDP: Shift Reg
.fs0:
		bclr.b	#0,$8B(a5)		; FS = 0
		bne.b	.fs0
		bsr	FrameClear
.fs1:
		bset.b	#0,$8B(a5)		; FS = 1
		beq.b	.fs1
		bsr	FrameClear
		bclr.b	#0,$8B(a5)		; FS = 0
		bsr	PaletteClear		; ----	Palette RAM Clear
		move	#$80,d0			; ----	SH2 Check
		move.l	$20(a5),d1		; SDRAM Self Check
		cmp.l	#"SDER",d1
		beq	MarsError
		moveq	#0,d0			; ----	Communication Reg. Clear
		move.l	d0,$28(a5)		; 8
		move.l	d0,$2C(a5)		; 12
		move	#0,ccr			; Complete
		bra.s	IcdAllEnd
Hot_Start:
		move.w	d0,6(a5)		; DREQ Control Reg.
		move.w	#$8000,d0
		bra.s	IcdAllEnd

; ----------------------------------------------------------------
; No 32X detected
; ----------------------------------------------------------------

MarsError:
		move	#1,ccr			; Return error carryflag
		rts

; ----------------------------------------------------------------
; Clear framebuffer
; ----------------------------------------------------------------

		align 4
FrameClear:
		movem.l	d0/d1/d7/a1,-(a7)
		lea	($A15180).l,a1
.fm1
		bclr.b	#7,-$80(a1)		; MD access
		bne.b	.fm1
		move.w	#($20000/$200-1),d7
		moveq	#0,d0
		moveq	#0,d1
		move.w	#-1,$4(a1)		; Fill Length Reg.
.fill0:
		move.w	d1,$6(a1)		; Fill Start Address Reg.
		move.w	d0,$8(a1)		; Fill Data Reg.
		nop
.fen0:
		btst.b	#1,$B(a1)		; FEN = 0 ?
		bne.b	.fen0
		add.w	#$100,d1		; Address = +200H
		dbra	d7,.fill0
		movem.l	(a7)+,d0/d1/d7/a1
		rts

; ----------------------------------------------------------------
; Palette RAM Clear
; ----------------------------------------------------------------

PaletteClear:
		movem.l	d0/d7/a0,-(a7)
		lea	($A15200).l,a0
.fm2
		bclr.b	#7,-$100(a0)		; MD access
		bne.b	.fm2
		move.w	#(256/2/4-1),d7
.pl:
		move.l	d0,(a0)+
		move.l	d0,(a0)+
		move.l	d0,(a0)+
		move.l	d0,(a0)+
		dbra	d7,.pl
		movem.l	(a7)+,d0/d7/a0
		rts

; ===================================================================
; Start
;
; bcc  | 32X active
; bcs  | No 32X detected
; d0.w | %h0000000 00000000
;         h - Cold Start / Hot Start
; ===================================================================

IcdAllEnd:
		bcs	*				; <-- Nothing
		tst.w	d0
		bmi	.soft_reset

	; ------------------------------------------------
	; Send the entire SH2 code in split sections
	; ------------------------------------------------
		lea	(sysmars_reg).l,a6
.wait_fb:
		bclr	#7,(a6)				; Set FM bit to MD
		bne.s	.wait_fb			; Wait until it accepts.
	; --------------------------------
	; FRAMEBUFFER 1
.wait_f1fb:	btst	#7,$80+$0A(a6)			; Wait for SVDP's VBlank
		beq.s	.wait_f1fb
.wait_f1:	bset	#0,$80+$0B(a6)			; Set BUFFER 1
		beq.s	.wait_f1
		lea	($200000+($20000-$38)).l,a0	; Read SECOND half of SH2 code
		lea	($840000).l,a1
		move.l	#(($20000)/4)-1,d7		; Thie size for this section
.send_half:
		move.l	(a0)+,(a1)+
		dbf	d7,.send_half
	; --------------------------------
	; FRAMEBUFFER 0
.wait_f0fb:	btst	#7,$80+$0A(a6)			; Wait for SVDP's VBlank
		beq.s	.wait_f0fb
.wait_f0:	bclr	#0,$80+$0B(a6)			; Set BUFFER 0
		bne.s	.wait_f0
		lea	MarsInitHeader(pc),a0		; Read Module
		lea	($840000).l,a1
		move.w	#$0E-1,d7
.send_head:
		move.l	(a0)+,(a1)+
		dbf	d7,.send_head
		lea	($200000).l,a0			; Read the FIRST half of SH2
		move.l	#(($20000-$38)/4)-1,d7		; Size for this section
.send_code:
		move.l	(a0)+,(a1)+
		dbf	d7,.send_code
	; --------------------------------
.wait_cdfb:	btst	#7,$80+$0A(a6)			; Wait for SVDP's VBlank
		beq.s	.wait_cdfb
.wait_adapter:	bset	#7,(a6)				; Set FM bit to 32X
		beq.s	.wait_adapter
		lea	($A15100).l,a6
		move.l	#"_CD_",$20(a6)			; Write CD boot flag
.master:	cmp.l	#"M_OK",$20(a6)			; Check _OK flags
		bne.s	.master
.slave:		cmp.l	#"S_OK",$24(a6)
		bne.s	.slave
.wait_mstr:	move.l	$20(a6),d0			; Status tags cleared?
		bne.s	.wait_mstr
.wait_slv:	move.l	$24(a6),d0
		bne.s	.wait_slv
		moveq	#0,d0				; Clear both Master and Slave comm's
		move.l	d0,comm12(a6)
.soft_reset:
		lea	(vdp_ctrl).l,a6
		move.l	#$80048104,(a6)			; Default top VDP regs
	if EMU=0
		move.w	#$1FF,d7			; Delay until SH2 gets first.
.wait_sh2:
		move.w	#$FF,d6
		dbf	d6,*
		dbf	d7,.wait_sh2
	endif
; 		vdp_showme $000
		bra	MarsJumpHere

; ----------------------------------------------------------------
; MARS CD header
; ----------------------------------------------------------------
MarsInitHeader:
		dc.b "MARS NIKONA-SDK "			; Module name
		dc.l $00000000				; Version
		dc.l $00000000				; Not Used
		dc.l $06000000				; SDRAM area
	if EMU
		dc.l $200000				; DUMMY size for emulation
	else
		dc.l $1FFC8				; SDRAM code size (MAXIMUM: $1FFC8)
	endif
		dc.l SH2_M_Entry			; Master SH2 PC (SH2 area)
		dc.l SH2_S_Entry			; Slave SH2 PC (SH2 area)
		dc.l SH2_Master				; Master SH2 default VBR
		dc.l SH2_Slave				; Slave SH2 default VBR
		dc.l $00000000				; Not Used
		dc.l $00000000				; Not Used
		align 2
; ----------------------------------------------------------------
MarsJumpHere:
		bset	#0,(sysmars_reg+dreqctl+1).l	; Permanent RV=1
