; ===========================================================================
; -------------------------------------------------------------------
; Genesis header
; -------------------------------------------------------------------

		dc.l RAM_Stack		; Stack point
		dc.l MD_Entry		; Entry point MUST point to $3F0
		dc.l MD_ErrBus		; Bus error
		dc.l MD_ErrAddr		; Address error
		dc.l MD_ErrIll		; ILLEGAL Instruction
		dc.l MD_ErrZDiv		; Divide by 0
		dc.l MD_ErrChk		; CHK Instruction
		dc.l MD_ErrTrapV	; TRAPV Instruction
		dc.l MD_ErrPrivl	; Privilege violation
		dc.l MD_Trace		; Trace
		dc.l MD_Line1010	; Line 1010 Emulator
		dc.l MD_Line1111	; Line 1111 Emulator
		dc.l MD_ErrorEx		; Error exception
		dc.l MD_ErrorEx
		dc.l MD_ErrorEx
		dc.l MD_ErrorEx
		dc.l MD_ErrorEx
		dc.l MD_ErrorEx
		dc.l MD_ErrorEx
		dc.l MD_ErrorEx
		dc.l MD_ErrorEx
		dc.l MD_ErrorEx
		dc.l MD_ErrorEx
		dc.l MD_ErrorEx
		dc.l MD_ErrorEx
		dc.l MD_ErrorTrap
		dc.l RAM_ExternalJump	; RAM jump for External (JMP xxxx xxxx)
		dc.l MD_ErrorTrap
		dc.l RAM_HBlankJump	; RAM jump for HBlank (JMP xxxx xxxx)
		dc.l MD_ErrorTrap
		dc.l RAM_VBlankJump	; RAM jump for VBlank (JMP xxxx xxxx)
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.l MD_ErrorTrap
		dc.b HTAG_SYS_MD;"SEGA GENESIS    "
		dc.b HTAG_DATEINFO;"(C)GF64 2024.???"
		dc.b HTAG_NDM_MD;"Nikona MD                                       "
		dc.b HTAG_NOV_MD;"Nikona GENESIS                                  "
		dc.b HTAG_SERIAL;"GM HOMEBREW-02"
		dc.w 0
		dc.b "J6M             "
		dc.l 0
		dc.l ROM_END
		dc.l $FF0000
		dc.l $FFFFFF
		dc.b "RA",$F8,$20
		dc.l $200001
		dc.l $200001+((SET_SRAMSIZE*2)-2)	;$203FFF
		align $1F0
		dc.b HTAG_REGIONS;"F               "

; ====================================================================
; ----------------------------------------------------------------
; Error handlers
;
; All of these do nothing for now.
; ----------------------------------------------------------------

MD_ErrBus:				; Bus error
MD_ErrAddr:				; Address error
MD_ErrIll:				; ILLEGAL Instruction
MD_ErrZDiv:				; Divide by 0
MD_ErrChk:				; CHK Instruction
MD_ErrTrapV:				; TRAPV Instruction
MD_ErrPrivl:				; Privilege violation
MD_Trace:				; Trace
MD_Line1010:				; Line 1010 Emulator
MD_Line1111:				; Line 1111 Emulator
MD_ErrorEx:				; Error exception
MD_ErrorTrap:
		rte			; Return from Exception

; ====================================================================
; ----------------------------------------------------------------
; Entry point
; ----------------------------------------------------------------

MD_Entry:
		move	#$2700,sr			; Disable interrputs
		move.b	(sys_io).l,d0			; Read IO port
		andi.b	#%00001111,d0			; Get version, right 4 bits
		beq.s	.old_md				; If 0, No TMSS
		move.l	($100).l,(sys_tmss).l		; Write "SEGA" to port sys_tmss
.old_md:
		tst.w	(vdp_ctrl).l			; Test VDP to unlock Video
	; --------------------------------
		moveq	#0,d0
		movea.l	d0,a6
		move.l	a6,usp
		lea	($FFFF0000).l,a0		; Clean our "work" RAM
		move.l	#sizeof_mdram,d1
		moveq	#0,d0
.loop_ram:	move.w	d0,(a0)+
		cmp.l	d1,a0
		bcs.s	.loop_ram
		lea	(vdp_data),a6
.wait_dma:	move.w	4(a6),d7			; Check if DMA is active.
		btst	#1,d7
		bne.s	.wait_dma
		move.l	#$80048104,4(a6)		; Reset these VDP registers
		move.l	#$C0000000,4(a6)		; Clear palette
		moveq	#64-1,d7
		moveq	#0,d6
.palclear:
		move.w	d6,(a6)
		dbf	d7,.palclear
		movem.l	($FF0000).l,d0-a6		; Clean registers using zeros from RAM
		move.w	#$0100,(z80_bus).l		; Get Z80 bus
		move.w	#$0100,(z80_reset).l		; Z80 reset
.wait:
		btst	#0,(z80_bus).l
		bne.s	.wait
