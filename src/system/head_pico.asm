; ===========================================================================
; -------------------------------------------------------------------
; PICO header
; -------------------------------------------------------------------

		dc.l RAM_Stack		; Stack point
		dc.l Pico_Entry		; Entry
		dc.l Pico_ErrBus	; Bus error
		dc.l Pico_ErrAddr	; Address error
		dc.l Pico_ErrIll	; ILLEGAL Instruction
		dc.l Pico_ErrZDiv	; Divide by 0
		dc.l Pico_ErrChk	; CHK Instruction
		dc.l Pico_ErrTrapV	; TRAPV Instruction
		dc.l Pico_ErrPrivl	; Privilege violation
		dc.l Pico_Trace		; Trace
		dc.l Pico_Line1010	; Line 1010 Emulator
		dc.l Pico_Line1111	; Line 1111 Emulator
		dc.l Pico_ErrorEx	; Error exception
		dc.l Pico_ErrorEx
		dc.l Pico_ErrorEx
		dc.l Pico_ErrorEx
		dc.l Pico_ErrorEx
		dc.l Pico_ErrorEx
		dc.l Pico_ErrorEx
		dc.l Pico_ErrorEx
		dc.l Pico_ErrorEx
		dc.l Pico_ErrorEx
		dc.l Pico_ErrorEx
		dc.l Pico_ErrorEx
		dc.l Pico_ErrorEx
		dc.l Pico_Error
		dc.l RAM_ExternalJump	; PICO: User interrupt
		dc.l Pico_PcmInt	; PICO: PCM-is-full interrupt
		dc.l RAM_HBlankJump	; RAM jump for HBlank (JMP xxxx xxxx)
		dc.l Pico_UnkInt	; PICO: Unknown
		dc.l RAM_VBlankJump	; RAM jump for VBlank (JMP xxxx xxxx)
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.l Pico_Error
		dc.b HTAG_SYS_PICO;"SEGA PICO       "
		dc.b HTAG_DATEINFO;"(C)GF64 2024.???"
		dc.b HTAG_NDM_PICO;"Nikona PICO                                     "
		dc.b HTAG_NOV_PICO;"Nikona PICO                                     "
		dc.b HTAG_SERIAL;"GM HOMEBREW-02"
		dc.w 0
		dc.b "                "
		dc.l 0
		dc.l ROM_END
		dc.l $FF0000
		dc.l $FFFFFF
		dc.l $20202020		; PICO can't use SRAM
		dc.l $20202020
		dc.l $20202020
		align $1F0
		dc.b HTAG_REGIONS;"F               "

; ====================================================================
; ----------------------------------------------------------------
; Error handlers
;
; All of these do nothing for now.
; ----------------------------------------------------------------

Pico_ErrBus:				; Bus error
Pico_ErrAddr:				; Address error
Pico_ErrIll:				; ILLEGAL Instruction
Pico_ErrZDiv:				; Divide by 0
Pico_ErrChk:				; CHK Instruction
Pico_ErrTrapV:				; TRAPV Instruction
Pico_ErrPrivl:				; Privilege violation
Pico_Trace:				; Trace
Pico_Line1010:				; Line 1010 Emulator
Pico_Line1111:				; Line 1111 Emulator
Pico_ErrorEx:				; Error exception
Pico_Error:
		rte

; ====================================================================
; ----------------------------------------------------------------
; PICO-specific interrupts
; ----------------------------------------------------------------

Pico_UserInt:
Pico_PcmInt:				; <-- Interrupt when the PCM chip gets full
Pico_UnkInt:
		rte

; ====================================================================
; ----------------------------------------------------------------
; Entry point
; ----------------------------------------------------------------

Pico_Entry:
		move	#$2700,sr		; Disable interrputs
		lea	($800019),a0
		move.l	#"SEGA",d0		; Activate PICO system by
		movep.l	d0,(a0)			; writing this string to $800019 in odd writes
		tst.w	(vdp_ctrl).l		; Test VDP to unlock Video
	; --------------------------------
		moveq	#0,d0
		movea.l	d0,a6
		move.l	a6,usp
		lea	($FFFF0000),a0		; Clean our "work" RAM
		move.l	#sizeof_mdram,d1
		moveq	#0,d0
.loop_ram:	move.w	d0,(a0)+
		cmp.l	d1,a0
		bcs.s	.loop_ram
		lea	(vdp_data),a6
.wait_dma:	move.w	4(a6),d7		; Check if DMA is active.
		btst	#1,d7
		bne.s	.wait_dma
		move.l	#$C0000000,4(a6)	; Clear palette
		moveq	#64-1,d7
		moveq	#0,d6
.palclear:
		move.w	d6,(a6)
		dbf	d7,.palclear
		movem.l	($FF0000),d0-a6		; Clean registers using zeros from RAM
