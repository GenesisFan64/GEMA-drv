; ===========================================================================
; -------------------------------------------------------------------
; SEGA 32X header
; -------------------------------------------------------------------

		dc.l RAM_Stack		; Stack point
		dc.l $3F0		; Entry point: MUST point to $3F0
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
		dc.b HTAG_SYS_MARS;"SEGA 32X        "
		dc.b HTAG_DATEINFO;"(C)GF64 2024.???"
		dc.b HTAG_NDM_MARS;"Nikona MARS                                     "
		dc.b HTAG_NOV_MARS;"Nikona MARS                                     "
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
; 32X-cartidge jumps
; ----------------------------------------------------------------

		jmp	($FFFD00).l			; Hotstart
		jmp	($880000|MD_ErrBus).l		; Bus error
		jmp	($880000|MD_ErrAddr).l		; Address error
		jmp	($880000|MD_ErrIll).l		; ILLEGAL Instruction
		jmp	($880000|MD_ErrZDiv).l		; Divide by 0
		jmp	($880000|MD_ErrChk).l		; CHK Instruction
		jmp	($880000|MD_ErrTrapV).l		; TRAPV Instruction
		jmp	($880000|MD_ErrPrivl).l		; Privilege violation
		jmp	($880000|MD_Trace).l		; Trace
		jmp	($880000|MD_Line1010).l		; Line 1010 Emulator
		jmp	($880000|MD_Line1111).l		; Line 1111 Emulator
		jmp	($880000|MD_ErrorEx).l		; Error exception
		jmp	($880000|MD_ErrorEx).l
		jmp	($880000|MD_ErrorEx).l
		jmp	($880000|MD_ErrorEx).l
		jmp	($880000|MD_ErrorEx).l
		jmp	($880000|MD_ErrorEx).l
		jmp	($880000|MD_ErrorEx).l
		jmp	($880000|MD_ErrorEx).l
		jmp	($880000|MD_ErrorEx).l
		jmp	($880000|MD_ErrorEx).l
		jmp	($880000|MD_ErrorEx).l
		jmp	($880000|MD_ErrorEx).l
		jmp	($880000|MD_ErrorEx).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	(RAM_ExternalJump).l		; RAM jump for HBlank (JMP xxxx xxxx)
		jmp	($880000|MD_ErrorTrap).l
		jmp	(RAM_HBlankJump).l		; RAM jump for HBlank (JMP xxxx xxxx)
		jmp	($880000|MD_ErrorTrap).l
		jmp	(RAM_VBlankJump).l		; RAM jump for VBlank (JMP xxxx xxxx)
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l
		jmp	($880000|MD_ErrorTrap).l

; ----------------------------------------------------------------

		align $3C0
		dc.b "MARS NIKONA-SDK "			; Module name
		dc.l 0					; Version (always 0)
		dc.l MARS_RAMCODE			; SH2 RAM-code location (Genesis map) | Set to 0 if using ROM
		dc.l 0					; Zero again.
		dc.l MARS_RAMCODE_e-MARS_RAMCODE	; RAM-code size (END-START) | Set to 4 if SH2 code points to ROM
		dc.l SH2_M_Entry			; Master SH2 PC (SH2 map)
		dc.l SH2_S_Entry			; Slave SH2 PC (SH2 map)
		dc.l SH2_Master				; Master SH2 default VBR (SH2 map)
		dc.l SH2_Slave				; Slave SH2 default VBR (SH2 map)
		binclude "system/mars/data/security.bin"; Securty/Boot code

; ====================================================================
; ----------------------------------------------------------------
; Entry point, This MUST be located at $800
;
; Register setup:
;
; d0: %h0000000 rsc000ti
; 	| h - Cold start / Hot Start (SETS RV=1)
; 	| r - SDRAM self check pass or error
; 	| s - Security check pass or error
; 	| c - Checksum pass or error
; 	| t - TV mode pass or error
; 	| i - MARS ID pass or error
;
; d1: %m0000000 jdk0vvv
; 	| m - MARS TV mode
; 	| j - Country: Japan / Overseas
; 	| d - MD TV mode
; 	| k - DISK connected: Yes / No
; 	| v - Version
;
; Carry: "MARS ID" and Self Check result
; 	| bcc: Test passed
; 	| bcs: Test failed**
; ----------------------------------------------------------------

MARS_Entry:
		bcs	MD_MarsError
		bra	MD_Init

; ====================================================================
; ----------------------------------------------------------------
; If 32X is not detected
;
; We MIGHT here if no error happened.
; ----------------------------------------------------------------

MD_MarsError:
		btst	#5,d0			; Checksum is already good?
		beq	MD_Init			; the get out of here.
		move.w	#$2700,sr		; Disable interrupts
		move.l	#$C0000000,(vdp_ctrl).l	; VDP: Point to Color 0
		move.w	#$0E00,(vdp_data).l	; BLUE screen
		bra.s	*			; Infinite loop.

; ====================================================================
; ----------------------------------------------------------------
; 68k's Error handlers
;
; HBlank and VBlank jump to RAM
; ----------------------------------------------------------------

MD_ErrBus:		; Bus error
MD_ErrAddr:		; Address error
MD_ErrIll:		; ILLEGAL Instruction
MD_ErrZDiv:		; Divide by 0
MD_ErrChk:		; CHK Instruction
MD_ErrTrapV:		; TRAPV Instruction
MD_ErrPrivl:		; Privilege violation
MD_Trace:		; Trace
MD_Line1010:		; Line 1010 Emulator
MD_Line1111:		; Line 1111 Emulator
MD_ErrorEx:		; Error exception
MD_ErrorTrap:
		move.w	#$2700,sr			; Disable interrupts
		move.l	#$C0000000,(vdp_ctrl).l		; RED screen
		move.w	#$000E,(vdp_data).l
		bra.s	*

; ====================================================================
; ----------------------------------------------------------------
; HOT START RAM-CODE
; ----------------------------------------------------------------

MD_HotStRam:
		move.w	#$2700,sr
		lea	(RAM_Stack),sp		; HW: Set STACK manually, Pressing RESET moves it to 0
		lea	(vdp_data).l,a6
		lea	(sysmars_reg).l,a5
	; ------------------------------------------------
	; If the 32X get overloaded with interrupts
	; it shuts itself OFF on reset, The SVDP will
	; remain visible though.
	; ------------------------------------------------
		btst	#0,adapter+1(a5)	; 32X STILL enabled?
		bne.s	MD_MarsStartOk
		move.b	#%01,adapter+1(a5)	; Re-enable and Reset SH2
MD_MarsRestart:
		lea	($A10000).l,a5
		move.l	#-64,a4
		move.w	#3900,d7
		lea	($880000+$6E4).l,a1	; Do the boot sequence again
		jmp	(a1)			; starting from ?res_wait (icd_mars.prg)
MD_MarsStartOk:
		move.w	#%000,dreqctl(a5)	; Reset RV
		move.w	#0,bankset(a5)		; Set $900000 block Bank 0
; .wait_mstr:	cmp.l	#"M_OK",comm0(a5)
; 		bne.s	.wait_mstr
; .wait_slv:	cmp.l	#"S_OK",comm4(a5)
; 		bne.s	.wait_slv
		jmp	($880000|MD_HotStart).l	; Jump to Hot start as normal
MD_HotStRam_e:
		align 2

; ====================================================================
; ----------------------------------------------------------------
; COLD START
; ----------------------------------------------------------------

MD_Init:
		move.w	#$2700,sr
		lea	MD_HotStRam(pc),a0		; Copy HotStart RAM jump
		lea	($FFFFFD00).w,a1		; <-- RAM section used in SegaCD
		move.w	#((MD_HotStRam_e-MD_HotStRam)/2)-1,d0
.copy_code:
		move.w	(a0)+,(a1)+
		dbf	d0,.copy_code
		lea	(vdp_data).l,a6
		lea	(sysmars_reg).l,a5
.wait_dma:	move.w	4(a6),d7			; Check if DMA is active.
		btst	#1,d7
		bne.s	.wait_dma

; ====================================================================
; ----------------------------------------------------------------
; COLD Init
; ----------------------------------------------------------------

MD_HotStart:
		lea	($FFFF0000).l,a0		; Clean our "work" RAM
		move.l	#sizeof_mdram,d1
		moveq	#0,d0
.loop_ram:	move.w	d0,(a0)+
		cmp.l	d1,a0
		bcs.s	.loop_ram
		move.l	#$80048104,4(a6)		; Reset these VDP registers
		move.l	#$C0000000,4(a6)		; Clear palette
		moveq	#64-1,d7
		moveq	#0,d6
.palclear:	move.w	d6,(a6)
		dbf	d7,.palclear
		moveq	#0,d0				; Clear both Master and Slave comm's
		move.l	d0,comm12(a5)
; 	if EMU=0
		move.w	#$1FF,d7			; Delay until SH2 gets first.
.wait_sh2:
		move.w	#$FF,d6
		dbf	d6,*
		dbf	d7,.wait_sh2
		move.w	#$0100,(z80_bus).l		; Get Z80 bus
		move.w	#$0100,(z80_reset).l		; Z80 reset
.wait:
		btst	#0,(z80_bus).l
		bne.s	.wait
		movem.l	($FF0000).l,d0-a6		; Clear all registers using zeros from RAM
