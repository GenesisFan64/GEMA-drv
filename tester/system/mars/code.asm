; ===========================================================================
; -------------------------------------------------------------------
; MARS SH2 SDRAM section, CODE is shared for both SH2 CPUs
;
; comm port setup:
; comm0-comm7  | FREE to USE
;                If any ERROR occurs: the ports comm2 and comm4
;                will return the a error number and the CPU
;                who got the error.
; comm8-comm11 | Reserved to Z80 for reading the PWM table
; comm12       | Master CPU control (see master_loop)
; comm14       | Slave CPU control (see slave_loop)
; -------------------------------------------------------------------

		phase CS3	; We are at SDRAM
		cpu SH7600

; ====================================================================
; --------------------------------------------------------
; Settings
; --------------------------------------------------------

SH2_DEBUG		equ 1			; Set to 1 too see if CPUs are active using comm's 0 and 1
STACK_MSTR		equ $C0000800		; !! Master's STACK point (OLD: CS3|$40000)
STACK_SLV		equ $C0000800		; !! Slave's STACK point (OLD: CS3|$3F800)

; ====================================================================
; ----------------------------------------------------------------
; Macros
; ----------------------------------------------------------------

cpu_me macro color
	if MARSCD=0	; <-- Doesn't work on FUSION
		mov	#color,r1
		mov	#_vdpreg,r2
		mov	#_vdpreg+bitmapmd,r3
.hblk:		mov.b	@(vdpsts,r2),r0
		tst	#HBLK,r0
		bt	.hblk
		mov.b	r1,@r3
		nop
	endif
	endm

; ====================================================================
; ----------------------------------------------------------------
; MASTER CPU VECTOR LIST (vbr)
; ----------------------------------------------------------------

		align 4
SH2_Master:
		dc.l SH2_M_Entry,STACK_MSTR	; Power PC, Stack
		dc.l SH2_M_Entry,STACK_MSTR	; Reset PC, Stack
		dc.l SH2_M_ErrIllg		; Illegal instruction
		dc.l 0				; Reserved
		dc.l SH2_M_ErrInvl		; Invalid slot instruction
		dc.l $20100400			; Reserved
		dc.l $20100420			; Reserved
		dc.l SH2_M_ErrAddr		; CPU address error
		dc.l SH2_M_ErrDma		; DMA address error
		dc.l SH2_M_ErrNmi		; NMI vector
		dc.l SH2_M_ErrUser		; User break vector
		dc.l 0,0,0,0,0,0,0,0,0		; Reserved
		dc.l 0,0,0,0,0,0,0,0,0
		dc.l 0
		dc.l SH2_M_Error		; Trap user vectors
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
		dc.l SH2_M_Error
 		dc.l master_irq			; Level 0 & 1 IRQ
		dc.l master_irq			; Level 2 & 3 IRQ
		dc.l master_irq			; Level 4 & 5 IRQ
		dc.l master_irq			; Level 6 & 7 IRQ: PWM interupt
		dc.l master_irq			; Level 8 & 9 IRQ: Command interupt
		dc.l master_irq			; Level 10 & 11 IRQ: H Blank interupt
		dc.l master_irq			; Level 12 & 13 IRQ: V Blank interupt
		dc.l master_irq			; Level 14 & 15 IRQ: Reset Button
	; Extra ON-chip interrupts (vbr+$120)
		dc.l master_irq			; Watchdog
		dc.l master_irq			; DMA

; ====================================================================
; ----------------------------------------------------------------
; SLAVE CPU VECTOR LIST (vbr)
; ----------------------------------------------------------------

		align 4
SH2_Slave:
		dc.l SH2_S_Entry,STACK_SLV	; Cold PC,SP
		dc.l SH2_S_Entry,STACK_SLV	; Manual PC,SP
		dc.l SH2_S_ErrIllg		; Illegal instruction
		dc.l 0				; Reserved
		dc.l SH2_S_ErrInvl		; Invalid slot instruction
		dc.l $20100400			; Reserved
		dc.l $20100420			; Reserved
		dc.l SH2_S_ErrAddr		; CPU address error
		dc.l SH2_S_ErrDma		; DMA address error
		dc.l SH2_S_ErrNmi		; NMI vector
		dc.l SH2_S_ErrUser		; User break vector
		dc.l 0,0,0,0,0,0,0,0,0		; Reserved
		dc.l 0,0,0,0,0,0,0,0,0
		dc.l 0
		dc.l SH2_S_Error		; Trap user vectors
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
		dc.l SH2_S_Error
 		dc.l slave_irq			; Level 0 & 1 IRQ
		dc.l slave_irq			; Level 2 & 3 IRQ
		dc.l slave_irq			; Level 4 & 5 IRQ
		dc.l slave_irq			; Level 6 & 7 IRQ: PWM interupt
		dc.l slave_irq			; Level 8 & 9 IRQ: Command interupt
		dc.l slave_irq			; Level 10 & 11 IRQ: H Blank interupt
		dc.l slave_irq			; Level 12 & 13 IRQ: V Blank interupt
		dc.l slave_irq			; Level 14 & 15 IRQ: Reset Button
	; Extra ON-chip interrupts (vbr+$120)
		dc.l slave_irq			; Watchdog
		dc.l slave_irq			; DMA

; ====================================================================
; ----------------------------------------------------------------
; IRQ on both SH2's
;
; r0-r1 are saved
; ----------------------------------------------------------------

; sr: %xxxxMQIIIIxxST

		align 4
master_irq:
		mov	r0,@-r15
		mov	r1,@-r15
		sts	pr,@-r15
		stc	sr,r0
		shlr2	r0
		and	#$3C,r0
		mov	r0,r1
		mov.b	#$F0,r0		; ** $F0
		extu.b	r0,r0
		ldc	r0,sr
		mova	int_m_list,r0
		add	r1,r0
		mov	@r0,r1
		jsr	@r1
		nop
		lds	@r15+,pr
		mov	@r15+,r1
		mov	@r15+,r0
		rte
		nop
		align 4

; ====================================================================

slave_irq:
		mov	r0,@-r15
		mov	r1,@-r15
		sts	pr,@-r15
		stc	sr,r0
		shlr2	r0
		and	#$3C,r0
		mov	r0,r1
		mov.b	#$F0,r0		; ** $F0
		extu.b	r0,r0
		ldc	r0,sr
		mova	int_s_list,r0
		add	r1,r0
		mov	@r0,r1
		jsr	@r1
		nop
		lds	@r15+,pr
		mov	@r15+,r1
		mov	@r15+,r0
		rte
		nop
		align 4

; ====================================================================
; ------------------------------------------------
; irq list
; ------------------------------------------------

		align 4
;				  		  IRQ Level:
int_m_list:
		dc.l m_irq_bad			; 0
		dc.l m_irq_bad			; 1
		dc.l m_irq_bad			; 2
		dc.l m_irq_wdg			; 3 Watchdog
		dc.l m_irq_bad			; 4
		dc.l m_irq_dma			; 5 DMA exit
		dc.l m_irq_pwm			; 6
		dc.l m_irq_pwm			; 7
		dc.l m_irq_cmd			; 8
		dc.l m_irq_cmd			; 9
		dc.l m_irq_h			; A
		dc.l m_irq_h			; B
		dc.l m_irq_v			; C
		dc.l m_irq_v			; D
		dc.l m_irq_vres			; E
		dc.l m_irq_vres			; F
int_s_list:
		dc.l s_irq_bad			; 0
		dc.l s_irq_bad			; 1
		dc.l s_irq_bad			; 2
		dc.l s_irq_wdg			; 3 Watchdog
		dc.l s_irq_bad			; 4
		dc.l s_irq_dma			; 5 DMA exit
		dc.l s_irq_pwm|$C0000000	; 6
		dc.l s_irq_pwm|$C0000000	; 7
		dc.l s_irq_cmd			; 8
		dc.l s_irq_cmd			; 9
		dc.l s_irq_h			; A
		dc.l s_irq_h			; B
		dc.l s_irq_v			; C
		dc.l s_irq_v			; D
		dc.l s_irq_vres			; E
		dc.l s_irq_vres			; F

; ====================================================================
; ----------------------------------------------------------------
; Error handler
; ----------------------------------------------------------------

; *** Only works on HARDWARE ***
;
; comm2: (CPU)(CODE)
; comm4: PC counter
;
;  CPU | The CPU who got the error:
;        $00 - Master
;        $01 - Slave
;
; CODE | Error type:
;	 $00: Unknown error
;	 $01: Illegal instruction
;	 $02: Invalid slot instruction
;	 $03: Address error
;	 $04: DMA error
;	 $05: NMI vector
;	 $06: User break

SH2_M_Error:
		bra	SH2_M_ErrCode
		mov	#0,r0
SH2_M_ErrIllg:
		bra	SH2_M_ErrCode
		mov	#1,r0
SH2_M_ErrInvl:
		bra	SH2_M_ErrCode
		mov	#2,r0
SH2_M_ErrAddr:
		bra	SH2_M_ErrCode
		mov	#3,r0
SH2_M_ErrDma:
		bra	SH2_M_ErrCode
		mov	#4,r0
SH2_M_ErrNmi:
		bra	SH2_M_ErrCode
		mov	#5,r0
SH2_M_ErrUser:
		bra	SH2_M_ErrCode
		mov	#6,r0
; r0 - value
SH2_M_ErrCode:
		mov	#_sysreg+comm2,r1
		mov.w	r0,@r1
		mov	#_sysreg+comm4,r1
		mov	@r15,r0
		mov	r0,@r1
		bra	*
		nop
		align 4

; ----------------------------------------------------

SH2_S_Error:
		bra	SH2_S_ErrCode
		mov	#0,r0
SH2_S_ErrIllg:
		bra	SH2_S_ErrCode
		mov	#-1,r0
SH2_S_ErrInvl:
		bra	SH2_S_ErrCode
		mov	#-2,r0
SH2_S_ErrAddr:
		bra	SH2_S_ErrCode
		mov	#-3,r0
SH2_S_ErrDma:
		bra	SH2_S_ErrCode
		mov	#-4,r0
SH2_S_ErrNmi:
		bra	SH2_S_ErrCode
		mov	#-5,r0
SH2_S_ErrUser:
		bra	SH2_S_ErrCode
		mov	#-6,r0
; r0 - value
SH2_S_ErrCode:
		mov	#_sysreg+comm2,r1
		mov.w	r0,@r1
		mov	#_sysreg+comm4,r1
		mov	@r15,r0
		mov	r0,@r1
		bra	*
		nop
		align 4
		ltorg

; ====================================================================
; ----------------------------------------------------------------
; Interrupts
; ----------------------------------------------------------------

; =================================================================
; ------------------------------------------------
; Master | Unused interrupt
; ------------------------------------------------

		align 4
m_irq_bad:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		nop
		nop
		nop
		nop
		nop
		rts
		nop
		align 4

; ; =================================================================
; ; ------------------------------------------------
; ; Master | Watchdog
; ; ------------------------------------------------
;
; MOVED TO video.asm
; m_irq_wdg:
; 		mov	#_FRT,r1
; 		mov.b	@(7,r1),r0
; 		xor	#2,r0
; 		mov.b	r0,@(7,r1)
; 		nop
; 		nop
; 		nop
; 		nop
; 		nop
; 		rts
; 		nop
; 		align 4

; =================================================================
; ------------------------------------------------
; Master | DMA Exit
; ------------------------------------------------

m_irq_dma:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov	#_DMACHANNEL0,r1
.wait_dma:	mov	@r1,r0				; <-- Fail-safe
		tst	#%10,r0
		bt	.wait_dma
		mov	@r1,r0				; Dummy read
		mov	#%0100010011100000,r0
		mov	r0,@r1				; Turn this DMA off.
		mov	#_sysreg+comm12,r1
		mov.b	@r1,r0
		and	#%10111111,r0			; Report EXIT status
		mov.b	r0,@r1
	if EMU=0
		mov.w	@(marsGbl_WdgActive,gbr),r0
		tst	r0,r0
		bt	.not_use
		mov.w	#$FE80,r1		; $FFFFFE80
		mov.w	#$5A00|$18,r0		; Watchdog timer
		mov.w	r0,@r1
		mov.w	#$A538,r0		; Enable Watchdog
		mov.w	r0,@r1
.not_use:
	endif
		nop
		nop
		nop
		nop
		nop
		rts
		nop
		align 4

; =================================================================
; ------------------------------------------------
; Master | PWM Interrupt
; ------------------------------------------------

m_irq_pwm:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov	#_sysreg+pwmintclr,r1
		mov.w	r0,@r1
		rts
		nop
		align 4

; =================================================================
; ------------------------------------------------
; Master | CMD Interrupt
; ------------------------------------------------

m_irq_cmd:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov	#_sysreg+cmdintclr,r1
		mov.w	r0,@r1
		mov.w	@r1,r0
		mov	r2,@-r15
		mov	r3,@-r15
		mov	r4,@-r15
	; --------------------------------
	if EMU=0
; 		mov	#1,r0				; Pause watchdog
; 		mov.w	r0,@(marsGbl_WdgHold,gbr)
		mov.w	@(marsGbl_WdgActive,gbr),r0
		tst	r0,r0
		bt	.wdg_inuse
		mov.w   #$FE80,r1			; Disable Watchdog
		mov.w   #$A518,r0
		mov.w   r0,@r1
.wdg_inuse:
	endif
	; --------------------------------
		mov	#_sysreg,r4			; r4 - sysreg base
		mov	#_DMASOURCE0,r3			; r3 - DMA base register
		mov	#_sysreg+comm12,r2		; r2 - comm to write the signal
		mov	#%0100010011100000,r0		; Transfer mode + DMA enable OFF
		mov	r0,@($C,r3)
		mov.b	@r2,r0
		and	#%00001111,r0
		tst	r0,r0				; CMD mode $00?
		bf	.dreq_ram
		mov	@(dreqdest,r4),r0		; Set destination
		mov	#CS3,r1
		bra	.dreq_setdest
		or	r1,r0
.dreq_ram:
		mov	@(marsGbl_DreqWrite,gbr),r0	; Pick current WRITE buffer
.dreq_setdest:
		mov	#TH,r1				; as Cache-thru
		or	r1,r0
		mov	r0,@(4,r3)			; Set Destination
		mov.w	@(dreqlen,r4),r0
		extu.w	r0,r0
		mov	r0,@(8,r3)			; Length set by 68k
		mov	#_sysreg+dreqfifo,r1
		mov	r1,@r3				; Source point: DREQ FIFO
		mov	#%0100010011100101,r0		; Transfer mode + DMA enable + Use DMA interrupt
; 		mov	#%0100010011100001,r0		; Transfer mode + DMA enable
		mov	r0,@($C,r3)			; Dest:Incr(01) Src:Keep(00) Size:Word(01)
		mov.b	@r2,r0
		or	#%01000000,r0			; Report ENTER status
		mov.b	r0,@r2

	; ********************************
	; Wait here if NOT using
	; DMA interrupt
	; ********************************
; 		mov	#_DMACHANNEL0,r1
; .wait_dma:
; 		mov	@r1,r0
; 		tst	#%10,r0
; 		bt	.wait_dma
; 		mov	@r1,r0				; Dummy read
; 		mov	#%0100010011100000,r0
; 		mov	r0,@r1
; 		mov	#_sysreg+comm12,r1
; 		mov.b	@r1,r0
; 		and	#%10111111,r0			; Report EXIT status
; 		mov.b	r0,@r1
	; ********************************

	; --------------------------------
		mov	@r15+,r4
		mov	@r15+,r3
		mov	@r15+,r2
		rts
		nop
		align 4

; =================================================================
; ------------------------------------------------
; Master | HBlank
; ------------------------------------------------

m_irq_h:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov	#_sysreg+hintclr,r1
		mov.w	r0,@r1
		rts
		nop
		align 4

; =================================================================
; ------------------------------------------------
; Master | VBlank
; ------------------------------------------------

m_irq_v:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov	#_sysreg+vintclr,r1
		mov.w	r0,@r1
		nop
		nop
		nop
		nop
		nop
		rts
		nop
		align 4

; =================================================================
; ------------------------------------------------
; Master | VRES Interrupt (RESET button)
; ------------------------------------------------

m_irq_vres:
		mov	#_sysreg,r1
		mov	r15,r0
		mov.w	r0,@(vresintclr,r1)
		mov.w	@(dreqctl,r1),r0
		tst	#1,r0
		bf	.rv_busy
		mov.b	#$F0,r0			; ** $F0
		extu.b	r0,r0
		ldc	r0,sr
		mov	#0,r0
		mov	#_DMAOPERATION,r1	; Quickly cancel DMA's
		mov	r0,@r1
		mov	#_sysreg+comm12,r1	; Clear our comm
		mov.w	r0,@r1
		mov.w	#$FE80,r1		; $FFFFFE80
		mov.w	#$A518,r0		; Disable Watchdog
		mov.w	r0,@r1
		mov	#(STACK_MSTR)-8,r15	; Reset Master's STACK
		mov	#SH2_M_HotStart,r0	; Write return point and status
		mov	r0,@r15
		mov.w   #$F0,r0
		mov	r0,@(4,r15)
		mov	#_sysreg,r1		; Report Master as OK
		mov	#"M_OK",r0
		mov	r0,@(comm0,r1)
		rte
		nop
		align 4
.rv_busy:
		mov	#_FRT,r1		; *** MASTER ONLY _FRT ***
		mov.b	@(7,r1),r0
		or	#1,r0
		mov.b	r0,@(7,r1)
		bra	*
		nop
		align 4
		ltorg

; =================================================================
; ------------------------------------------------
; Slave | Unused Interrupt
; ------------------------------------------------

		align 4
s_irq_bad:
		rts
		nop
		align 4

; =================================================================
; ------------------------------------------------
; Slave | Watchdog
; ------------------------------------------------

s_irq_wdg:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		rts
		nop
		align 4

; =================================================================
; ------------------------------------------------
; Slave | DMA Exit
; ------------------------------------------------

		align 4
s_irq_dma:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		rts
		nop
		align 4

; =================================================================
; ------------------------------------------------
; Slave | PWM Interrupt
; ------------------------------------------------

; located on cache/cache_slv.asm
;
; s_irq_pwm:
		ltorg	; Save literals

; =================================================================
; ------------------------------------------------
; Slave | CMD Interrupt
; ------------------------------------------------

		align 4
s_irq_cmd:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov	#_sysreg+cmdintclr,r1
		mov.w	r0,@r1
		mov.w	@r1,r0
	; --------------------------------
		mov	r2,@-r15
		mov	r3,@-r15
		mov	r4,@-r15
		mov	r5,@-r15
		mov	r6,@-r15
		mov	r7,@-r15
		mov	r8,@-r15
		sts	pr,@-r15
		mov	#_sysreg+comm14,r1
		mov.b	@r1,r0
		and	#%00001111,r0
		shll2	r0
		mov	r0,r1
		mova	scmd_tasks,r0
		add	r1,r0
		mov	@r0,r1
		jmp	@r1
		nop
		align 4
		ltorg

; --------------------------------

		align 4
scmd_tasks:
		dc.l .scmd_task00	; NULL
		dc.l .scmd_task01	; PWM table transfer and update
		dc.l .scmd_task02	; PWM RV backup
		dc.l .scmd_task03	; PWM RV restore

; --------------------------------
; Task $00
; --------------------------------

.scmd_task00:
		bra	.exit_scmd
		nop

; --------------------------------
; Task $02
; --------------------------------

.scmd_task02:
		mov	#RAM_Mars_PwmBackup,r4
		mov	#RAM_Mars_PwmList,r8
		mov	#MAX_PWMCHNL,r7
		mov	#$200,r5
.next_one:
		mov	@(marspwm_enbl,r8),r0	; PWM active?
		tst	#$80,r0
		bt	.no_chnl

		mov	@(marspwm_bank,r8),r1
		mov	#CS1,r0
		cmp/eq	r0,r1
		bf	.no_chnl
		mov	@(marspwm_read,r8),r0
		mov	r0,r6			; Save last read
		shlr8	r0
		or	r1,r0
		mov	#-4,r1
		and	r1,r0
		mov	r0,r1
		mov	r4,r2
		mov	r5,r3
		shlr2	r3			; /4
		shlr	r3			; /2
.copy_data:
		mov	@r1+,r0
		mov	r0,@r2
		add	#4,r2
		mov	@r1+,r0
		mov	r0,@r2
		dt	r3
		bf/s	.copy_data
		add	#4,r2
		mov	@(marspwm_read,r8),r3
		mov	r6,r0
		shlr8	r0
		and	#%11,r0
		shll8	r0
		mov	#-4,r2
		shll8	r2
		sub	r6,r3
		and	r2,r3
		add	r0,r3
		mov	r3,@(marspwm_cread,r8)

		mov	@(marspwm_enbl,r8),r0	; Playback stopped here?
		tst	#%10000000,r0
		bt	.no_chnl
		or	#%01000000,r0
		mov	r0,@(marspwm_enbl,r8)
.no_chnl:
		mov	#marspwm_len,r0
		add	r0,r8
		dt	r7
		bf/s	.next_one
		add	r5,r4

		bra	.exit_scmd
		nop
		align 4

; 		mov	#_DMASOURCE0,r7			; r4 - DMA base register
; 		mov	@($C,r7),r0
; 		mov	#%0101000011100000,r0		; Transfer mode + DMA enable OFF
; 		mov	r0,@($C,r7)
; 		mov	r1,@r7				; Source point: DREQ FIFO
; 		mov	r2,@(4,r7)			; Set Destination
; 		mov	r3,@(8,r7)			; Length set by 68k
; 		mov	@($C,r7),r0
; 		mov	#%0101000011100000|1,r0		; Transfer mode + DMA enable
; 		mov	r0,@($C,r7)			; Dest:Incr(01) Src:Keep(00) Size:Word(01)
; .wait_dma:
; 		mov	@($C,r7),r0
; 		tst	#%10,r0
; 		bt	.wait_dma
; 		mov	@($C,r7),r0			; Dummy read
; 		mov	#%0101000011100000,r0
; 		mov	r0,@($C,r7)

; --------------------------------
; Task $03
; --------------------------------

.scmd_task03:
		mov	#RAM_Mars_PwmList,r8
		mov	#MAX_PWMCHNL,r7
		mov	#marspwm_len,r6
.next_out:
		mov	@(marspwm_enbl,r8),r0
		tst	#%10000000,r0
		bt	.no_chnlo
		tst	#%01000000,r0
		bt	.no_chnlo
		mov	@(marspwm_enbl,r8),r0
		and	#%10111111,r0
		mov	r0,@(marspwm_enbl,r8)
.no_chnlo:
		dt	r7
		bf/s	.next_out
		add	r6,r8
		bra	.exit_scmd
		nop
		align 4

; --------------------------------
; Task $01
; --------------------------------

.scmd_task01:
		mov	#_sysreg+comm8,r1		; Input
		mov	#RAM_Mars_PwmTable,r2		; Output
		mov	#_sysreg+comm14,r3		; comm
		nop
.wait_1:
		mov.b	@r3,r0
		and	#%11000000,r0
		tst	#%10000000,r0			; LOCK exit?
		bt	.exit_c
		tst	#%01000000,r0			; Wait PASS
		bt	.wait_1
.copy_1:
		mov	@r1,r0				; Copy full longword
		mov	r0,@r2
		add	#4,r2				; Increment table pos
		mov.b	@r3,r0
		and	#%10111111,r0
		bra	.wait_1
		mov.b	r0,@r3				; Clear PASS bit, Z80 loops
.exit_c:

; --------------------------------
; Process table changes
; --------------------------------

.proc_pwm:
		mov	#RAM_Mars_PwmTable,r8		; Input
		mov	#RAM_Mars_PwmList,r7		; Output
		mov	#MAX_PWMCHNL,r6
.next_chnl:
		mov	r8,r3				; r3 - current table column
		mov.b	@r3,r0				; r0: %kfo o-on f-off k-cut
		and	#%00011111,r0
		tst	r0,r0
		bt	.no_chng
.no_keycut:
		tst	#%00000010,r0
		bf	.is_keycut
		tst	#%00000100,r0
		bf	.is_keycut
		tst	#%00000001,r0
		bt	.no_chng

		tst	#%00001000,r0
		bt	.no_pitchbnd
		mov	@(marspwm_enbl,r7),r0
		tst	#$80,r0
		bt	.no_chng
		add	#8,r3			; Next: Volume and Pitch MSB
		mov.b	@r3,r0			; r0: %vvvvvvpp
		mov	r0,r2			; Save pp-pitch
		and	#%11111100,r0
		mov	r0,@(marspwm_vol,r7)
		add	#8,r3			; Next: Pitch LSB
		mov.b	@r3,r1			; r0: %pppppppp
		extu.b	r1,r1
		mov	r2,r0
		and	#%11,r0
		shll8	r0
		or	r1,r0
		bra	.no_chng
		mov	r0,@(marspwm_pitch,r7)

.no_pitchbnd:
		mov	#0,r0
		mov	r0,@(marspwm_enbl,r7)
		add	#8,r3			; Next: Volume and Pitch MSB
		mov.b	@r3,r0			; r0: %vvvvvvpp
		mov	r0,r2			; Save pp-pitch
		and	#%11111100,r0
		mov	r0,@(marspwm_vol,r7)
		add	#8,r3			; Next: Pitch LSB
		mov.b	@r3,r1			; r0: %pppppppp
		extu.b	r1,r1
		mov	r2,r0
		and	#%11,r0
		shll8	r0
		or	r1,r0
		mov	r0,@(marspwm_pitch,r7)
		add	#8,r3			; Next: Stereo/Loop/Left/Right | 32-bit**
		mov.b	@r3,r0			; r0: %SLlraaaa
		mov	r0,r1			; Save aaaa-address
		and	#%11110000,r0
		shlr2	r0
		shlr2	r0
		or	#$80,r0			; Set as Enabled
		mov	r0,r4
		mov	r1,r0
		and	#%00001111,r0
		shll16	r0
		shll8	r0
		mov	r0,@(marspwm_bank,r7)
		mov	r0,r1			; r1 - BANK
		add	#8,r3			; Next: Pointer $xx0000
		mov.b	@r3,r0
		extu.b	r0,r0
		shll16	r0
		mov	r0,r2			; r2: $xx0000
		add	#8,r3			; Next: Pointer $00xx00
		mov.b	@r3,r0
		extu.b	r0,r0
		shll8	r0
		or	r0,r2			; r2: $xxxx00
		add	#8,r3			; Next: Pointer $0000xx
		mov.b	@r3,r0
		extu.b	r0,r0
		or	r2,r0			; r0: $00xxxxxx
		add	r0,r1
	; Read LEN and LOOP
		mov.b	@r1+,r0
		extu.b	r0,r3
		mov.b	@r1+,r2
		extu.b	r2,r2
		shll8	r2
		or	r2,r3
		mov.b	@r1+,r2
		extu.b	r2,r2
		shll16	r2
		or	r2,r3
		mov.b	@r1+,r0
		extu.b	r0,r0
		mov.b	@r1+,r2
		extu.b	r2,r2
		shll8	r2
		or	r2,r0
		mov.b	@r1+,r2
		extu.b	r2,r2
		shll16	r2
		or	r2,r0
		shll8	r0
		mov	r0,@(marspwm_loop,r7)
		mov	r1,r0
		shll8	r0
		mov	r0,@(marspwm_start,r7)
		mov	r0,@(marspwm_read,r7)
		mov	r1,r0
		add	r3,r0
		shll8	r0
		mov	r0,@(marspwm_length,r7)
		bra	.no_chng
		mov	r4,@(marspwm_enbl,r7)
.is_keycut:
		mov	#0,r0
		mov	r0,@(marspwm_enbl,r7)
.no_chng:
		mov	#marspwm_len,r0
		add	r0,r7
		dt	r6
		bf/s	.next_chnl
		add	#1,r8
.exit_scmd:
	; --------------------------------
		mov	#_sysreg+comm14,r1	; Clear CMD task
		mov	#0,r0
		mov.b	r0,@r1
		lds	@r15+,pr
		mov	@r15+,r8
		mov	@r15+,r7
		mov	@r15+,r6
		mov	@r15+,r5
		mov	@r15+,r4
		mov	@r15+,r3
		mov	@r15+,r2
		rts
		nop
		align 4
		ltorg

; =================================================================
; ------------------------------------------------
; Slave | HBlank
; ------------------------------------------------

s_irq_h:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov	#_sysreg+hintclr,r1
		mov.w	r0,@r1
		rts
		nop
		align 4

; =================================================================
; ------------------------------------------------
; Slave | VBlank
; ------------------------------------------------

s_irq_v:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov	#_sysreg+vintclr,r1
		mov.w	r0,@r1
		rts
		nop
		align 4

; =================================================================
; ------------------------------------------------
; Slave | VRES Interrupt (RESET button on Genesis)
; ------------------------------------------------

s_irq_vres:
		mov	#_sysreg,r1
		mov	r15,r0
		mov.w	r0,@(vresintclr,r1)
		mov.w	@(dreqctl,r1),r0
		tst	#1,r0
		bf	.rv_busy
		mov.b	#$F0,r0			; ** $F0
		extu.b	r0,r0
		ldc	r0,sr
		mov	#0,r0
		mov	#_DMAOPERATION,r1	; Quickly cancel DMA's
		mov	r0,@r1
		mov	#_sysreg+comm14,r1	; Clear our comm
		mov.w	r0,@r1
		mov.w	#$FE80,r1		; $FFFFFE80
		mov.w	#$A518,r0		; Disable Watchdog
		mov.w	r0,@r1
		mov	#(STACK_SLV)-8,r15	; Reset Slave's STACK
		mov	#SH2_S_HotStart,r0	; Write return point and status
		mov	r0,@r15
		mov.w   #$F0,r0
		mov	r0,@(4,r15)
		mov	#_sysreg,r1
		mov	#"S_OK",r0		; Report Slave as OK
		mov	r0,@(comm4,r1)
		rte
		nop
		align 4
.rv_busy:
		bra	*
		nop
		align 4

		ltorg		; Save literals

; ====================================================================
; ----------------------------------------------------------------
; Master entry point
; ----------------------------------------------------------------

		align 4
SH2_M_Entry:
		mov.b	#$F0,r0				; ** $F0
		extu.b	r0,r0
		ldc	r0,sr
		mov	#STACK_MSTR,r15			; Reset stack
		mov	#SH2_Master,r0			; Reset vbr
		ldc	r0,vbr
		mov.l	#_FRT,r1
		mov	#$00,r0
		mov.b	r0,@(0,r1)
		mov.b	#$E2,r0
		mov.b	r0,@(7,r1)
		mov	#$00,r0
		mov.b	r0,@(4,r1)
		mov	#$01,r0
		mov.b	r0,@(5,r1)
		mov	#$00,r0
		mov.b	r0,@(6,r1)
		mov	#$01,r0
		mov.b	r0,@(1,r1)
		mov	#$00,r0
		mov.b	r0,@(3,r1)
		mov.b	r0,@(2,r1)
		mov.b	#$F2,r0				; ****
		mov.b	r0,@(7,r1)
		mov	#0,r0
		mov.b	r0,@(4,r1)
		mov	#1,r0
		mov.b	r0,@(5,r1)
		mov.b	#$E2,r0
		mov.b	r0,@(7,r1)

	; --------------------------------------------------------
	; Extra interrupt settings
		mov.w   #$FEE2,r0			; Extra interrupt priority levels ($FFFFFEE2)
		mov     #(3<<4)|(5<<8),r1		; (DMA_LVL<<8)|(WDG_LVL<<4) Current: WDG 3 DMA 5
		mov.w   r1,@r0
		mov.w   #$FEE4,r0			; Vector jump number for Watchdog ($FFFFFEE4)
		mov     #($120/4)<<8,r1			; (vbr+POINTER)<<8
		mov.w   r1,@r0
		mov.b	#$A0,r0				; Vector jump number for DMACHANNEL0 ($FFFFFFA0)
		mov     #($124/4),r1			; (vbr+POINTER)
		mov	r1,@r0
	; --------------------------------------------------------
	; CD32X initialization
	;
	; *** FUSION: Framebuffer flipping fails if
	; bitmapmd is 0 ***
	; --------------------------------------------------------
	if MARSCD
	if EMU
		mov 	#_vdpreg,r1
		mov	#1,r0
		mov.b	r0,@(bitmapmd,r1)	; Set bitmap to 1 for no reason.
		mov.b	r0,@(framectl,r1)	; Set Framebuffer frame 1
.waitl:		mov.b	@(vdpsts,r1),r0		; Wait blank
		tst	#VBLK,r0
		bt	.waitl
.wait_frm:	mov.b	@(framectl,r1),r0	; Framebuffer frame is 1?
		cmp/eq	#1,r0
		bf	.wait_frm
	else

	; HW method:
		mov 	#_vdpreg,r1
.waite:		mov.b	@(vdpsts,r1),r0		; Inside VBlank
		tst	#VBLK,r0
		bf	.waite
.waitl:		mov.b	@(vdpsts,r1),r0		; Wait new VBlank
		tst	#VBLK,r0
		bt	.waitl
		mov	#1,r2			; Set Framebuffer 1 and check
		mov	r2,r0
		mov.b	r0,@(framectl,r1)
.wait_frm:	mov.b	@(framectl,r1),r0
		cmp/eq	r2,r0
		bf	.wait_frm
	endif
		mov	#0,r0
		mov	#CS3+($20000-$38),r2		; FIRST Cleanup
		mov	#CS3+($40000),r3
.clean_up:
		cmp/ge	r3,r2
		bt	.exit_clean
		mov	r0,@r2
		bra	.clean_up
		add	#4,r2
.exit_clean:
		mov	#_framebuffer,r1		; Copy the other half of SDRAM
		mov	#CS3+($20000-$38),r2
		mov	#CS3+(SH2_END&$3FFFFF),r3
.copy_new:
		cmp/ge	r3,r2
		bt	.exit_send
		mov	@r1+,r0
		mov	r0,@r2
		bra	.copy_new
		add	#4,r2
.exit_send:
		mov	#_sysreg+comm0,r1
		mov	#0,r0
		mov	r0,@r1
	endif

; ====================================================================
; ----------------------------------------------------------------
; Master MAIN code
; ----------------------------------------------------------------

SH2_M_HotStart:
		mov	#RAM_Mars_Global,r0		; Reset gbr
		ldc	r0,gbr
		mov	#RAM_Mars_DreqBuff_0,r0
		mov	r0,@(marsGbl_DreqRead,gbr)
		mov	#RAM_Mars_DreqBuff_1,r0
		mov	r0,@(marsGbl_DreqWrite,gbr)
		bsr	MarsVideo_Init
		nop
		bsr	Mars_CachePurge
		nop
		mov	#_sysreg,r1
		mov.w	@r1,r0
		or	#CMDIRQ_ON,r0
		mov.w	r0,@r1
		mov	#_sysreg+comm14,r1
.wait_slv:	mov.w	@r1,r0
		tst	r0,r0
		bf	.wait_slv
		mov	#_DMAOPERATION,r1		; Enable DMA operation
		mov	#1,r0
		mov	r0,@r1
		mov.b	#$20,r0				; Interrupts ON
		ldc	r0,sr
		bra	master_loop
		nop
		align 4
		ltorg

; ----------------------------------------------------------------
; MASTER CPU loop
;
; comm12: %BD00cccc RRdflmmm

; B | This CPU's BUSY bit
; D | DREQ DMA active
; c | CMD task number
;
; R | Graphics mode init bits.
; d | DREQ-RAM flip request: Set to 1 after sending your RAM data
; f | CPU Syncronize bit, clears if drawing finishes
; l | Setting to skip frames (3D rendering)
; m | Graphics mode
; ----------------------------------------------------------------

		align 4
master_loop:
	if SH2_DEBUG
		mov	#_sysreg+comm0,r1		; DEBUG counter
		mov.b	@r1,r0
		add	#1,r0
		mov.b	r0,@r1
	endif
	; ---------------------------------------
	; Flip the DREQ Read/Write points
	; ---------------------------------------

	if EMU=0
.pending_dreq:
		mov	#_sysreg+comm12,r1		; Wait pending DREQ DMA transfer
		mov.b	@r1,r0
		tst	#%01000000,r0
		bf	.pending_dreq
	endif
		stc	sr,@-r15
		mov.b	#$F0,r0				; Disable interrupts
		extu.b	r0,r0				; ** $F0
		ldc	r0,sr
		mov	#_sysreg+comm12+1,r2
		mov.b	@r2,r0
		tst	#%00100000,r0
		bt	.keep_buff
		mov	@(marsGbl_DreqWrite,gbr),r0	; Flip DMA Read/Write buffers
		mov	r0,r1
		mov	@(marsGbl_DreqRead,gbr),r0
		nop
		mov	r0,@(marsGbl_DreqWrite,gbr)
		mov	r1,r0
		mov	r0,@(marsGbl_DreqRead,gbr)
		mov.b	@r2,r0
		and	#%11011111,r0
		mov.b	r0,@r2
.keep_buff:
		ldc	@r15+,sr			; Enable interrupts
		mov	#_sysreg+comm12+1,r1
		mov.b	@r1,r0
		and	#%11101111,r0			; Reset DREQ sync
		mov.b	r0,@r1
		bsr	Mars_CachePurge			; Purge cache
		nop
		nop	; alignment
	; ---------------------------------------
	; Update SVDP in VBlank
	; ---------------------------------------
		bsr	Mars_WaitVBlank
		nop
	; ---------------------------------------
	; Jump into a screen mode
	; ---------------------------------------
		mova	mstr_list,r0
		mov	r0,r1
		mov	#_sysreg+comm12,r2
		nop
		mov.w	@r2,r0
		tst	#%11000000,r0
		bt	.non_init
		add	#4,r1
.non_init:
		and	#%00000111,r0		; <-- Current limit
		shll2	r0
		shll	r0
		add	r0,r1
		mov	@r1,r0
		jmp	@r0
		nop
		align 4
		ltorg

; ====================================================================
; ----------------------------------------------------------------
; MODES LIST, MAXIMUM 7
;
; Mode number $00 sets the SVDP to Genesis.
; ----------------------------------------------------------------

		align 4
mstr_list:
		dc.l MstrMode_0,MstrMode_0
		dc.l MstrMode_2D,MstrMode_2D_i
		dc.l MstrMode_3D,MstrMode_3D_i
		dc.l MstrMode_0,MstrMode_0
		dc.l MstrMode_0,MstrMode_0
		dc.l MstrMode_0,MstrMode_0
		dc.l MstrMode_0,MstrMode_0
		dc.l MstrMode_0,MstrMode_0

; ====================================================================
; ----------------------------------------------------------------
; Wait VBlank
; ----------------------------------------------------------------

		align 4
Mars_WaitVBlank:
		mov	#_sysreg,r14
		mov	#_vdpreg,r13
  		mov.b	@(adapter,r14),r0
  		tst	#FM,r0
  		bt	.svdp_locked
.wait_v:	mov.b	@(vdpsts,r13),r0
		tst	#VBLK,r0
		bt	.wait_v
		rts
		nop
		align 4
.svdp_locked:
		rts
		nop
		align 4

; ====================================================================
; ----------------------------------------------------------------
; Blank screen mode, NOTHING.
;
; Setting this mode will also give the SVDP to the Genesis,
; CHECK FM BIT AFTER SETTING THIS MODE.
; ----------------------------------------------------------------

		align 4
MstrMode_0:
		bsr	Mars_WaitVBlank
		nop
; ---------------------------------------
; Init
;
; Running from here...
; ---------------------------------------
		mov	#_sysreg+comm12+1,r1
		mov.b	@r1,r0
		and	#%11000000,r0
		tst	r0,r0
		bt	master_loop
		bsr	Mars_CachePurge
		nop
		mov.w   #$FE80,r1			; Disable Watchdog
		mov.w   #$A518,r0
		mov.w   r0,@r1
		mov	#_sysreg+comm14,r1
.wait_slvn:
		mov.w	@r1,r0
		and	#%00000111,r0			; Slave busy?
		tst	r0,r0
		bf	.wait_slvn
		mov	#0,r0
		mov	r0,@(marsGbl_Scrl_Xpos,gbr)
		mov	r0,@(marsGbl_Scrl_Ypos,gbr)
		mov	r0,@(marsGbl_Scrl_Xold,gbr)
		mov	r0,@(marsGbl_Scrl_Yold,gbr)
		mov	r0,@(marsGbl_Scrl_FbTL,gbr)
		mov	r0,@(marsGbl_Scrl_FbY,gbr)
		mov	r0,@(marsGbl_Scrl_FbX,gbr)
		mov.w	r0,@(marsGbl_XShift,gbr)
		mov.w	r0,@(marsGbl_ThisFrame,gbr)
		mov 	#_vdpreg,r13
  		mov.b	@(adapter,r14),r0
  		tst	#FM,r0
  		bt	.still_locked
		mov	#_framebuffer,r2
		mov	#(($20000)/4)/4,r1
		mov	#0,r0
.clr_manual:
	rept 4-1
		mov	r0,@r2
		add	#4,r2
	endm
		mov	r0,@r2
		dt	r1
		bf/s	.clr_manual
		add	#4,r2
.still_locked:
		mov.w	@(marsGbl_ThisFrame,gbr),r0
		xor	#1,r0
		mov.w	r0,@(marsGbl_ThisFrame,gbr)
		mov	#_sysreg+comm12,r1
		mov.w	@r1,r0
		and	#%01000000,r0
		tst	r0,r0
		bf	.not_yet
		mov	#_sysreg,r14
		mov	#FM,r0
  		mov.b	r0,@(adapter,r14)
  		nop
  		nop
  		nop
  		nop
		mov	#0,r0
		mov.b	r0,@(bitmapmd,r13)
		mov	#$00,r0
  		mov.b	r0,@(adapter,r14)
.not_yet:

		bra	MstrMode_InitExit
		nop

; ---------------------------------------
; JUMP here at the end of the
; Screen's INIT code.

MstrMode_InitExit:
		mov	#_sysreg+comm12+1,r3
		mov.b	@r3,r0
		mov	r0,r1
		mov	#%11000000,r2
		and	#%00111111,r0
		and	r2,r1
		shll	r1
		or	r1,r0
		bra	master_loop
		mov.b	r0,@r3

; ====================================================================
; ----------------------------------------------------------------
; 256-color tiled scroll area with "Super" Sprites
;
; NOTES:
; - This will set SVDP permission to here.
; - MAXIMUM scrolling speed is 8 pixels
; ----------------------------------------------------------------

; ---------------------------------------
; Init
; ---------------------------------------

		align 4
MstrMode_2D_i:
		mov	#_sysreg+comm12,r1
		mov.w	@r1,r0
		and	#%01000000,r0
		tst	r0,r0
		bf	MstrMode_InitExit
		bsr	Mars_CachePurge
		nop
		mov.w   #$FE80,r1			; Disable Watchdog
		mov.w   #$A518,r0
		mov.w   r0,@r1
		mov	#_sysreg+comm14,r1
.wait_slvn:
		mov.w	@r1,r0
		and	#%00000111,r0			; Slave busy?
		tst	r0,r0
		bf	.wait_slvn
		mov	#0,r0
		mov 	#$C0000000,r1
		mov	#$600/4,r2
.clean_up:
		mov	r0,@r1
		dt	r2
		bf/s	.clean_up
		add	#4,r1
		mov	#_sysreg,r14
		mov	#_vdpreg,r13
		mov	#FM,r0
  		mov.b	r0,@(adapter,r14)
		mov	#Dreq_Buff0,r14			; ** DREQ READ **
		mov	@(marsGbl_DreqRead,gbr),r0
		add	r0,r14
		mov	@(sscrl_x_pos,r14),r1
		shlr16	r1
		mov	@(sscrl_y_pos,r14),r2
		shlr16	r2
		mov	@(sscrl_vram,r14),r0
		mov 	#_vdpreg,r13
		mov	r0,@(marsGbl_Scrl_Vram,gbr)
		exts.w	r2,r0
		mov	r0,@(marsGbl_Scrl_Ypos,gbr)
		exts.w	r1,r0
		mov	r0,@(marsGbl_Scrl_Xpos,gbr)
		mov	#1,r0
		mov.b	r0,@(bitmapmd,r13)
; 		add	#1,r0
; 		mov.w	r0,@(marsGbl_DrawAll,gbr)
		bra	MstrMode_InitExit
		nop
		align 4
		ltorg

; ---------------------------------------
; Loop
; ---------------------------------------

		align 4
MstrMode_2D:
	; ---------------------------------------
	; *** We are in VBLANK ***
		mov	#_sysreg,r14			; r14 - _sysreg
		mov	#_vdpreg,r13			; r13 - _vdpreg
		mov.w	@(marsGbl_ThisFrame,gbr),r0
		and	#1,r0
		mov.b	r0,@(framectl,r13)		; Set current framebuffer
 		mov.w	@(marsGbl_XShift,gbr),r0
		and	#1,r0
		mov.w	r0,@(shift,r13)			; Set SHIFT bit (Xpos & 1)
		bsr	g_Mstr_CopyPalette		; Copy 256-color palette
		nop
	; ---------------------------------------
	; Set scrolling varaibles
		mov	@(marsGbl_DreqRead,gbr),r0
		mov	#Dreq_Buff0,r14			; ** DREQ READ **
		add	r0,r14
		mov	#0,r1				; X increment
		mov	#0,r2				; Y increment
		mov	#2,r3				; Drawflags counter
		mov	@(sscrl_x_pos,r14),r6
		mov	#SET_MSCRLSIZE/2,r4		; Scroll speed limit
		mov	@(marsGbl_Scrl_Xpos,gbr),r0
		mov	#-SET_MSCRLSIZE,r5		; -block_size
		mov	@(sscrl_y_pos,r14),r8
		mov	r0,r7
		mov	@(marsGbl_Scrl_Ypos,gbr),r0
		mov	r0,r9
		mov	r0,@(marsGbl_Scrl_Yold,gbr)
		mov	r7,r0
		mov	r0,@(marsGbl_Scrl_Xold,gbr)
		shlr16	r6				; X >> 16
		exts.w	r6,r6				; extend
		shlr16	r8				; Y >> 16
		exts.w	r8,r8				; extend
		mov	r6,r1				; Make X increment
		sub	r7,r1
		mov	r8,r2				; Make Y increment
		sub	r9,r2
		tst	r1,r1				; X changed?
		bf	.x_patch
.x_patch:
		mov	r8,r0
		mov	r0,@(marsGbl_Scrl_Ypos,gbr)
		mov	r6,r0
		mov	r0,@(marsGbl_Scrl_Xpos,gbr)
		exts.w	r1,r1
		mov.w	r0,@(marsGbl_XShift,gbr)	; Write Xshift here
		exts.w	r2,r2
	; ---------------------------------------
	; Increment FB draw TL and Y pos
	; r1 - X increment
	; r2 - Y increment
		mov	@(marsGbl_Scrl_Wdth,gbr),r0
		mov	r0,r8
		mov	@(marsGbl_Scrl_FbX,gbr),r0
		mov	r0,r7
		mov	@(marsGbl_Scrl_Hght,gbr),r0
		mov	r0,r6
		mov	@(marsGbl_Scrl_FbY,gbr),r0
		mov	r0,r5
		mov	@(marsGbl_Scrl_Size,gbr),r0
		mov	r0,r4
		mov	@(marsGbl_Scrl_FbTL,gbr),r0
		add	r1,r0		; Add X
		cmp/pl	r1
		bf	.yx_negtv
.yx_toptva:	cmp/ge	r4,r0
		bf	.yx_negtv
		bra	.yx_toptva
		sub	r4,r0
.yx_negtv:
		cmp/pz	r1
		bt	.yx_postv
.yx_negtva:	cmp/pz	r0
		bt	.yx_postv
		bra	.yx_negtva
		add	r4,r0
.yx_postv:

	; Add Y
		add	r2,r5
		cmp/pl	r2
		bf	.ypu_negtv
.yx_postva:	cmp/ge	r6,r5
		bf	.ypu_negtv
		bra	.yx_postva
		sub	r6,r5
.ypu_negtv:
		cmp/pz	r2
		bt	.ypu_postv
.ypu_negtva:	cmp/pz	r5
		bt	.ypu_postv
		bra	.ypu_negtva
		add	r6,r5
.ypu_postv:

	; X special

		add	r1,r7
		cmp/pl	r1
		bf	.xpu_negtv
.ypu_postva:	cmp/ge	r8,r7
		bf	.xpu_negtv
		bra	.ypu_postva
		sub	r8,r7
.xpu_negtv:
		cmp/pz	r1
		bt	.xpu_postv
.xpu_negtva:	cmp/pz	r7
		bt	.xpu_postv
		bra	.xpu_negtva
		add	r8,r7
.xpu_postv:
		nop
		mov	r0,@(marsGbl_Scrl_FbTL,gbr)
		mov	r5,r0
		mov	r0,@(marsGbl_Scrl_FbY,gbr)
		mov	r7,r0
		mov	r0,@(marsGbl_Scrl_FbX,gbr)

	; ---------------------------------------
	; Make refill timers on movement
	; ---------------------------------------
		mov	#$C0000000|RAM_Mars_ScrlRefill,r14
		mov	#320,r13
		mov	#%11,r12
		mov	#-16,r11
		nop
		mov	@(marsGbl_Scrl_Ypos,gbr),r0
		mov	r0,r9
		mov	@(marsGbl_Scrl_Xpos,gbr),r0
		mov	r0,r4
		mov	@(marsGbl_Scrl_Xold,gbr),r0
		and	r11,r4
		and	r11,r0
		cmp/eq	r4,r0
		bt	.x_dont_scrl
		tst	r1,r1
		bt	.x_dont_scrl
		mov	r14,r10
		cmp/pl	r1
		bf	.x_scrl_l
		add	r13,r4
.x_scrl_l:
		mov	#512-1,r0
		and	r0,r4
		mov	#256-1,r0
		and	r0,r9
		shlr2	r4
		shlr2	r4
		shlr2	r9
		shlr2	r9
		shll	r4
		add	r4,r10
		mov	#256/16,r7
.x_sloop:
		mov	r9,r0
		and	#$0F,r0
		shll8	r0
		shlr2	r0
		mov.w	@(r10,r0),r8
		or	r12,r8
		mov.w	r8,@(r10,r0)
		dt	r7
		bf/s	.x_sloop
		add	#1,r9
.x_dont_scrl:
; 		mov	#224,r13
		mov	#SET_MSCRLHGHT,r13			; Y draw
		mov	@(marsGbl_Scrl_Xpos,gbr),r0
		mov	r0,r9
		mov	@(marsGbl_Scrl_Ypos,gbr),r0
		mov	r0,r4
		mov	@(marsGbl_Scrl_Yold,gbr),r0
		and	r11,r4
		and	r11,r0
		cmp/eq	r4,r0
		bt	.y_dont_scrl
		tst	r2,r2
		bt	.y_dont_scrl
		mov	r14,r10
		cmp/pl	r2
		bf	.y_scrl_l
		add	r13,r4
.y_scrl_l:
		mov	#256-1,r0
		and	r0,r4
		mov	#512-1,r0
		and	r0,r9
		shlr2	r4
		shlr2	r4
		shlr2	r9
		shlr2	r9
		shll8	r4
		shlr2	r4
		add	r4,r10
		mov	#512/16,r7
.y_sloop:
		mov	r9,r0
		and	#$1F,r0
		shll	r0
		mov.w	@(r10,r0),r8
		or	r12,r8
		mov.w	r8,@(r10,r0)
		dt	r7
		bf/s	.y_sloop
		add	#1,r9
.y_dont_scrl:
	; ---------------------------------------
	; Start drawing
	; ---------------------------------------
 		bsr	Mars_CachePurge
		nop
		bsr	MarsVideo_DrawFillBlk		; Redraw changes from Refill boxes
		nop
		bsr	MarsVideo_SuperSpr_Make
		nop
		bsr	Mars_CachePurge
		nop
		bsr	MarsVideo_MkFillBlk		; Build refill boxes
		nop
		bsr	MarsVideo_SuperSpr_Draw
		nop
	; ---------------------------------------
	; Make the scroll area visible and
	; fix the broken lines.
		mov	#0,r1
		mov	#240,r2				; Show scroll area 0 to 240
		bsr	MarsVideo_ShowScrlBg
		nop
		bsr	marsScrl_CopyTopBot		; Bottom
		nop
		mov	#240,r2				; $xxFF patcher
		mov	#SET_FBVRAM_PATCH,r3
		bsr	MarsVideo_FixTblShift
		mov	#0,r1

	; ---------------------------------------
; 		mov.w	@(marsGbl_SVdpQWrt,gbr),r0
; 		mov	r0,r6
; .wait_wdg:	mov.w	@(marsGbl_SVdpQRead,gbr),r0
; 		cmp/ge	r6,r0
; 		bf	.wait_wdg
; 		mov.w   #$FE80,r1			; Disable Watchdog
; 		mov.w   #$A518,r0
; 		mov.w   r0,@r1
		bsr	Mars_CachePurge
		nop
		mov.w	@(marsGbl_ThisFrame,gbr),r0
		xor	#1,r0
		mov.w	r0,@(marsGbl_ThisFrame,gbr)
		bra	master_loop
		nop
		align 4
		ltorg

; ----------------------------------------------------------------
; Halfway jumps...
		align 4
g_Mstr_CopyPalette:
		bra	Mstr_CopyPalette
		nop
		align 4
g_MstrMode_InitExit:
		bra	MstrMode_InitExit
		nop

; ====================================================================
; ----------------------------------------------------------------
; 3D polygons mode, CPU INTENSIVE
;
; NOTES:
; - This will set SVDP permission to here.
; - Slave CPU will help a little.
; ----------------------------------------------------------------

; ---------------------------------------
; Init
; ---------------------------------------

		align 4
MstrMode_3D_i:
		mov	#_sysreg+comm12,r1
		mov.w	@r1,r0
		and	#%01000000,r0
		tst	r0,r0
		bf	g_MstrMode_InitExit
		bsr	Mars_CachePurge
		nop
		mov.w   #$FE80,r1			; Disable Watchdog
		mov.w   #$A518,r0
		mov.w   r0,@r1
		mov	#_sysreg+comm14,r1
.wait_slvn:
		mov.w	@r1,r0
		and	#%00000111,r0			; Slave busy?
		tst	r0,r0
		bf	.wait_slvn
		mov	#RAM_Mars_Buff3D_Start,r1
		mov	#RAM_Mars_Buff3D_End,r2
		mov	#0,r0
.clr_me2d:
		mov	r0,@r1
		cmp/ge	r2,r1
		bf/s	.clr_me2d
		add	#4,r1
		mov	#_sysreg,r14
		mov	#_vdpreg,r13
		mov	#0,r0
		mov	r0,@(marsGbl_Scrl_Xpos,gbr)
		mov	r0,@(marsGbl_Scrl_Ypos,gbr)
		mov	r0,@(marsGbl_Scrl_Xold,gbr)
		mov	r0,@(marsGbl_Scrl_Yold,gbr)
		mov	r0,@(marsGbl_Scrl_FbTL,gbr)
		mov	r0,@(marsGbl_Scrl_FbY,gbr)
		mov.w	r0,@(marsGbl_XShift,gbr)
		mov.w	r0,@(marsGbl_WdgTask,gbr)
		mov.w	r0,@(marsGbl_WdgHold,gbr)
		mov.w	r0,@(marsGbl_WdgDivLock,gbr)
		mov.w	r0,@(marsGbl_WdgClLines,gbr)
		mov.w	r0,@(marsGbl_WdgReady,gbr)
		mov.w	@(marsGbl_ThisFrame,gbr),r0
		xor	#1,r0
		mov.w	r0,@(marsGbl_ThisFrame,gbr)
		mov	#FM,r0
  		mov.b	r0,@(adapter,r14)
		mov	#1,r0
		mov.b	r0,@(bitmapmd,r13)
	; **** TEMPORAL
; 		mov	#TEST_MODEL,r0
; 		mov	#RAM_Mars_Objects,r1
; 		mov	r0,@(mdl_data,r1)
	; ****
		mov	#_sysreg+comm12+1,r1	; Enable frame-dropping
		mov.b	@r1,r0
		or	#%00001000,r0
		mov.b	r0,@r1
		bra	g_MstrMode_InitExit
		nop
		align 4
		ltorg

; ---------------------------------------
; Loop
; ---------------------------------------

		align 4
MstrMode_3D:
	; ---------------------------------------
	; *** We are in VBLANK ***
		mov	#_sysreg,r14
		mov	#_vdpreg,r13
.wait_sv:	mov.w	@(vdpsts,r13),r0			; Check if Framebuffer is locked
		tst	#%10,r0
		bf	.wait_sv
		mov.w	@(marsGbl_ThisFrame,gbr),r0		; Set current Framebuffer
		and	#1,r0
		mov.b	r0,@(framectl,r13)
		bsr	Mstr_CopyPalette
		nop
	; ---------------------------------------
		mov	#_sysreg+comm14,r4
.wait_slvi:
		mov.w	@r4,r0
		and	#%00000111,r0				; Slave busy?
		tst	r0,r0
		bf	.wait_slvi
		bsr	Mars_CachePurge				; Purge cache
		nop

	; Copy CAMERA and OBJECTS for Slave
		mov	@(marsGbl_DreqRead,gbr),r0
		mov	r0,r4
		mov	#Dreq_Buff1,r1
		add	r4,r1
		mov	#RAM_Mars_SprPolygn,r2
		mov	#(mspr_len*MAX_MARSMSPR)/4,r3		; $400 bytes
.copy_mspr:
		mov	@r1+,r0
		mov	r0,@r2
		dt	r3
		bf/s	.copy_mspr
		add	#4,r2
		mov	#Dreq_Buff2,r1
		add	r4,r1
		mov	#RAM_Mars_Objects,r2
		mov	#(mmdl_len*MAX_MARSOBJ)/4,r3		; $400 bytes
.copy_obj:
		mov	@r1+,r0
		mov	r0,@r2
		dt	r3
		bf/s	.copy_obj
		add	#4,r2
		mov	#Dreq_Buff0,r1
		add	r4,r1
		mov	#RAM_Mars_ObjCamera,r2
		mov	#$40/4,r3				; $40 bytes
.copy_cam:
		mov	@r1+,r0
		mov	r0,@r2
		dt	r3
		bf/s	.copy_cam
		add	#4,r2
		mov	#RAM_Mars_CurrPlgnPage,r1		; Swap polygon R/W sections
		mov	@r1,r0
		xor	#1,r0
		mov	r0,r13					; ** Current R/W page
		mov	r0,@r1
		mov	#_sysreg+comm14+1,r4			; Request Slave Task $01
		mov	#1,r0
		mov.b	r0,@r4
	; -------------------------------
	; Start drawing the polygons
		mov	#_vdpreg,r1
		mov	#$A1,r0					; VDPFILL LEN: Pre-start at $A1
		mov.w	r0,@(6,r1)
		mov	#_framebuffer,r1
		mov	#240,r3
		mov	#$100>>2,r0
		shll2	r0
		mov	r0,r2
.mk_table:
		mov.w	r0,@r1
		add	r2,r0
		dt	r3
		bf/s	.mk_table
		add	#2,r1
	; Prepare watchdog
		mov	#0,r0
		mov	r0,@(marsGbl_PlgnPzIndx_R,gbr)
		mov	r0,@(marsGbl_PlgnPzIndx_W,gbr)
		mov.w	r0,@(marsGbl_PlyPzCntr,gbr)
		mov.w	r0,@(marsGbl_WdgReady,gbr)
		mov	#240,r0					; Lines to clear for WdgMode $07
		mov.w	r0,@(marsGbl_WdgClLines,gbr)
		mov	#7,r0
		mov.w	r0,@(marsGbl_WdgTask,gbr)		; Start at the last mode
		bsr	Mars_CachePurge
		nop
		mov	#0,r1
		mov	#$20,r2
		mov	#Mars_SetWatchdog,r0
		jsr	@r0
		nop

	; WATCHDOG IS ACTIVE
		nop
		mov	r13,r0					; GET current page
		tst     #1,r0					; on this frame
		bt	.page_2
	if EMU
		mov 	#RAM_Mars_PlgnList_0,r14
		mov	#RAM_Mars_PlgnNum_0,r13
		bra	.cont_plgn
		nop
	else
		mov 	#RAM_Mars_PlgnList_0,r14
		bra	.cont_plgn
		mov	#RAM_Mars_PlgnNum_0,r13
	endif
.page_2:
	if EMU
		mov 	#RAM_Mars_PlgnList_1,r14
		mov	#RAM_Mars_PlgnNum_1,r13
		bra	.cont_plgn
		nop
	else
		mov 	#RAM_Mars_PlgnList_1,r14
		bra	.cont_plgn		; <-- syncronizing, i think.
		mov	#RAM_Mars_PlgnNum_1,r13
	endif
.cont_plgn:
		mov	@r13,r13	; Grab number of polygons
		cmp/pl	r13		; If < 0: leave
		bf	.skip

	; ---------------------------------------
	; Z sorting
		mov	r14,r12		; r12 - PlgnList copy
		mov	r13,r11		; r11 - PlgnNum copy
.roll:
		mov	r12,r10
		mov	@r10,r7		; r1 - Start value
		mov	r10,r8		; Set Lower pointer
		mov	r11,r9
		nop
.srch:
		mov	@r10,r0
		cmp/ge	r7,r0
		bt	.higher
		mov	r0,r7		; Update LOW r1 value
		mov	r10,r8		; Save NEW Lower pointer
.higher:
		dt	r9
		bf/s	.srch
		add	#8,r10
		mov	@r8+,r1		; Swap Z and pointers
		mov	@r8+,r2
		mov	@r12+,r3
		mov	@r12+,r4
		mov	r2,@-r12
		mov	r1,@-r12
		mov	r4,@-r8
		mov	r3,@-r8
		dt	r11
		bf/s	.roll
		add	#8,r12

	; ---------------------------------------
	; Slice polygon with the sorted list
.loop:
		mov	@(4,r14),r0			; Grab current pointer
		cmp/pl	r0				; Zero?
		bf	.invalid
		mov	r14,@-r15
		mov	r0,r14
		mov	#MarsVideo_SlicePlgn,r0
		jsr	@r0
; 		bsr	MarsVideo_SlicePlgn
		mov	r13,@-r15
		mov	@r15+,r13
		mov	@r15+,r14
		mov	#0,r0
		mov	r0,@r14
		mov	r0,@(4,r14)
.invalid:
		dt	r13				; Decrement numof_polygons
		bf/s	.loop
		add	#8,r14				; Move to next entry
.skip:
		mov	#1,r0				; Report to Watchdog that we
		mov.w	r0,@(marsGbl_WdgReady,gbr)	; finished slicing.

	; ---------------------------------------
.wait_pz: 	mov.w	@(marsGbl_PlyPzCntr,gbr),r0	; Any pieces remaining?
		tst	r0,r0
		bf	.wait_pz
.wait_wdg:	mov.w	@(marsGbl_WdgTask,gbr),r0	; Watchdog finished?
		tst	r0,r0
		bf	.wait_wdg
		mov	#0,r0
		mov.w	r0,@(marsGbl_WdgActive,gbr)
		mov.w   #$FE80,r1			; Disable Watchdog
		mov.w   #$A518,r0
		mov.w   r0,@r1
		bsr	Mars_CachePurge
		nop
		mov.w	@(marsGbl_ThisFrame,gbr),r0
		xor	#1,r0
		mov.w	r0,@(marsGbl_ThisFrame,gbr)
		bra	master_loop
		nop
		align 4

; ----------------------------------------------------------------

		align 4
Mstr_CopyPalette:
		mov	#_sysreg,r14
  		mov.b	@(adapter,r14),r0
  		tst	#FM,r0
  		bt	.svdp_locked
		mov	#_palette,r2
		mov	#(256/2)/4,r3
		mov	@(marsGbl_DreqRead,gbr),r0
		mov	#Dreq_Palette,r1		; PALETTE MUST BE AT THE TOP OF DREQ DATA,
; 		add	r0,r1				; so I don't need to add Dreq_Palette...
		mov	r0,r1
.copy_pal:
	rept 4
		mov	@r1+,r0				; Copy 2 colors as LONGs
		nop
		mov	r0,@r2
		add	#4,r2
	endm
		dt	r3
		bf	.copy_pal
.svdp_locked:
		rts
		nop
		align 4
		ltorg

; ====================================================================
; ----------------------------------------------------------------
; Slave entry point
; ----------------------------------------------------------------

		align 4
SH2_S_Entry:
		mov.b	#$F0,r0			; ** $F0
		extu.b	r0,r0
		ldc	r0,sr
		mov	#STACK_SLV,r15		; Reset stack
		mov	#SH2_Slave,r0		; Reset vbr
		ldc	r0,vbr
		mov.l	#_FRT,r1		; Free-run timer settings
		mov	#0,r0			; ** REQUIRED FOR REAL HARDWARE **
		mov.b	r0,@(0,r1)
		mov.b	#$E2,r0
		mov.b	r0,@(7,r1)
		mov	#0,r0
		mov.b	r0,@(4,r1)
		mov	#1,r0
		mov.b	r0,@(5,r1)
		mov	#0,r0
		mov.b	r0,@(6,r1)
		mov	#1,r0
		mov.b	r0,@(1,r1)
		mov	#0,r0
		mov.b	r0,@(3,r1)
		mov.b	r0,@(2,r1)
		mov.b	#$F2,r0			; ****
		mov.b	r0,@(7,r1)
		mov	#0,r0
		mov.b	r0,@(4,r1)
		mov	#1,r0
		mov.b	r0,@(5,r1)
		mov.b	#$E2,r0
		mov.b	r0,@(7,r1)

	; --------------------------------------------------------
	; Extra interrupt settings
		mov.w   #$FEE2,r0		; Extra interrupt priority levels ($FFFFFEE2)
		mov     #(3<<4)|(5<<8),r1	; (DMA_LVL<<8)|(WDG_LVL<<4) Current: WDG 3 DMA 5
		mov.w   r1,@r0
		mov.w   #$FEE4,r0		; Vector jump number for Watchdog ($FFFFFEE4)
		mov     #($120/4)<<8,r1		; (vbr+POINTER)<<8
		mov.w   r1,@r0
		mov.b	#$A8,r0			; Vector jump number for DMACHANNEL1 ($FFFFFFA8)
		mov     #($124/4),r1		; (vbr+POINTER)
		mov	r1,@r0
	; --------------------------------------------------------
	; CD32X only:
	; --------------------------------------------------------
	if MARSCD
		mov	#_sysreg+comm0,r1
.wait_mstr:	mov	@r1,r0
		tst	r0,r0
		bf	.wait_mstr
		add	#4,r1
		mov	#0,r0				; clear comm4
		mov	r0,@r1
	endif
		bsr	MarsSound_Init			; Init sound
		nop

; ====================================================================
; ----------------------------------------------------------------
; Slave MAIN code
;
; *** NOTE ***
; On actual HW this CPU runs slower than MASTER because of
; priority of the SDRAM.
; The important code is stored on 2K Cache
; (see cache/cache_slv.asm)
; ----------------------------------------------------------------

SH2_S_HotStart:
		mov	#RAM_Mars_Global,r0		; Reset gbr
		ldc	r0,gbr
		bsr	Mars_CachePurge
		nop
		mov	#CACHE_SLAVE,r1
		mov	#CACHE_SLAVE_E-CACHE_SLAVE,r2
		mov	#Mars_CacheRamCode,r0
		jsr	@r0
		nop
		mov	#_sysreg,r1
		mov.w	@r1,r0
		or	#CMDIRQ_ON|PWMIRQ_ON,r0		; Enable these interrupts
; 		or	#CMDIRQ_ON,r0
		mov.w	r0,@r1
		mov	#_sysreg+comm12,r1
.wait_mst:	mov.w	@r1,r0
		tst	r0,r0
		bf	.wait_mst
		mov	#_DMAOPERATION,r1		; Enable DMA operation
		mov	#1,r0
		mov	r0,@r1
		mov.b	#$20,r0				; Interrupts ON
		ldc	r0,sr
		bra	slave_loop
		nop
		align 4
		ltorg

; ----------------------------------------------------------------
; SLAVE CPU loop
;
; comm14: %Bp00cccc 00000ttt

; B | This CPU's busy bit (CMD lock)
; p | DATA pass bit
; c | CMD task number
;
; t | Task number
; ----------------------------------------------------------------

		align 4
slave_loop:
	if SH2_DEBUG
		mov	#_sysreg+comm1,r1		; DEBUG counter
		mov.b	@r1,r0
		add	#1,r0
		mov.b	r0,@r1
	endif
		mov	#_sysreg+comm14,r1
		mov.w	@r1,r0
		and	#%00000111,r0
		shll2	r0
		mov	r0,r1
		mova	slv_list,r0
		add	r1,r0
		mov	@r0,r1
		jmp	@r1
		nop
		align 4

; ====================================================================

		align 4
slv_list:
		dc.l SlvMode_00
		dc.l SlvMode_01
		dc.l SlvMode_00
		dc.l SlvMode_00
		dc.l SlvMode_00
		dc.l SlvMode_00
		dc.l SlvMode_00
		dc.l SlvMode_00

; ====================================================================
; ----------------------------------------------------------------
; NOTHING
; ----------------------------------------------------------------

SlvMode_00:
		bra	slave_loop
		nop

; ====================================================================
; ----------------------------------------------------------------
; Slave task 01
; ----------------------------------------------------------------

		align 4
SlvMode_01:
		mov	#$C0000000|CachSlv_CurrPage,r1
		mov	#RAM_Mars_CurrPlgnPage,r0
		mov	@r0,r0
		mov	r0,@r1
		mov	#$C0000000|MarsMdl_MdlLoop,r0	; Cache jump
		jsr	@r0
		nop
		mov	#_sysreg+comm14+1,r1
		mov	#0,r0
		bra	slave_loop
		mov.b	r0,@r1
		align 4
		ltorg

; ====================================================================
; ----------------------------------------------------------------
; Shared routines
; ----------------------------------------------------------------

; --------------------------------------------------------
; Mars_CachePurge, Mars_CachePurge_S
;
; Purges the internal cache, call this often.
;
; Breaks:
; r0-r1
; --------------------------------------------------------

		align 4
Mars_CachePurge:
		mov.w	#_CCR&$FFFF,r1		; Purge ON, Cache OFF
		mov	#%10000,r0
		mov.b	r0,@r1
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		mov	#%01001,r0		; Purge OFF, Two-Way mode, Cache ON
		rts
		mov.b	r0,@r1

; ----------------------------------------------------------------
; Mars_CacheRamCode
;
; Loads "fast code" into the SH2's cache, maximum size is
; $700 bytes aprox.
;
; Input:
; r1 | Code to send
; r2 | Size
;
; Breaks:
; r0/r3
; ----------------------------------------------------------------

		align 4
Mars_CacheRamCode:
		stc	sr,@-r15	; Interrupts OFF
		mov.b	#$F0,r0		; ** $F0
		extu.b	r0,r0
		ldc	r0,sr
		mov	#_CCR,r3
		mov	#%00010000,r0	; Cache purge + Disable
		mov.w	r0,@r3
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		mov	#%00001001,r0	; Cache two-way mode + Enable
		mov.w	r0,@r3
		mov 	#$C0000000,r3
		shlr2	r2
.copy:
		mov 	@r1+,r0
		mov 	r0,@r3
		dt	r2
		bf/s	.copy
		add 	#4,r3
		rts
		ldc	@r15+,sr
		align 4
		ltorg

; --------------------------------------------------------
; Mars_SetWatchdog
;
; Prepares watchdog interrupt
;
; Input:
; r1 | Watchdog CPU clock divider
; r2 | Watchdog timer
; --------------------------------------------------------

		align 4
Mars_SetWatchdog:
		stc	sr,r4
		mov.b	#$F0,r0			; ** $F0
		extu.b	r0,r0
		ldc 	r0,sr
		mov.w	r0,@(marsGbl_WdgActive,gbr)
		mov.l	#_CCR,r3		; Refresh Cache
		mov	#%00001000,r0		; Two-way mode
		mov.w	r0,@r3
		mov	#%00011001,r0		; Cache purge / Two-way mode / Cache ON
		mov.w	r0,@r3
		mov.w	#$FE80,r3		; $FFFFFE80
		mov.w	#$5A00,r0		; Watchdog timer
		or	r2,r0
		mov.w	r0,@r3
		mov.w	#$A538,r0		; Enable Watchdog
		or	r1,r0
		mov.w	r0,@r3
		ldc	r4,sr
		rts
		nop
		align 4
		ltorg

; ====================================================================
; ----------------------------------------------------------------
; Includes
; ----------------------------------------------------------------

		align 4
		include "system/mars/sound.asm"
		include "system/mars/video.asm"
		include "system/mars/cache/cache_mstr.asm"
		include "system/mars/cache/cache_slv.asm"

; ====================================================================
; ----------------------------------------------------------------
; Data
; ----------------------------------------------------------------

		align 4
sin_table	binclude "system/mars/data/sinedata.bin"
		align 4

; ====================================================================
; ----------------------------------------------------------------
; GLOBAL GBR Variables for MASTER
; ----------------------------------------------------------------

		align $10
RAM_Mars_Global:

marsGbl		struct
ThisFrame	ds.w 1			; Current framebuffer number
XShift		ds.w 1			; horizontal scroll & 1 bit (2D ONLY)
WdgTask		ds.w 1			; Current Watchdog task
WdgHold		ds.w 1			; Watchdog ignore (without turning it off)
WdgDivLock	ds.w 1			; Watchdog division skip (for Textures only)
WdgReady	ds.w 1			; Flag to report that all polygons are finished slicing
PlyPzCntr	ds.w 1			; Number of polygon pieces to draw
WdgClLines	ds.w 1			; Number of lines to clear for WDG task $07
WdgActive	ds.w 1
		ds.w 1
		ds.w 1
DrawAll		ds.w 1
3D_OutWidth	ds.l 1
3D_OutHeight	ds.l 1
DreqRead	ds.l 1			; **** RAM_Mars_DreqBuff_0|TH
DreqWrite	ds.l 1			; RAM_Mars_DreqBuff_1|TH
PlgnPzIndx_R	ds.l 1			; R/W piece indexes
PlgnPzIndx_W	ds.l 1			;
Scrl_Xpos	ds.l 1			; ****
Scrl_Ypos	ds.l 1
Scrl_Xold	ds.l 1
Scrl_Yold	ds.l 1
Scrl_Size	ds.l 1			; ****
Scrl_Wdth	ds.l 1
Scrl_Hght	ds.l 1
Scrl_Vram	ds.l 1
Scrl_FbOut	ds.l 1			; ****
Scrl_FbTL	ds.l 1
Scrl_FbY	ds.l 1
Scrl_FbX	ds.l 1
; len		ds.l 0
		endstruct
		ds.b marsGbl_len

; ====================================================================
; ----------------------------------------------------------------
; NON-CACHED RAM
; ----------------------------------------------------------------

			align $10
SH2_RAM_TH:
			phase SH2_RAM_TH|TH
RAM_Mars_DreqBuff_0	ds.b Dreq_len				; DREQ data from Genesis
RAM_Mars_DreqBuff_1	ds.b Dreq_len				; ****
RAM_Mars_PwmTable	ds.b 8*8				; GEMA Z80 table
RAM_Mars_PwmList	ds.b marspwm_len*MAX_PWMCHNL		; PWM list
RAM_Mars_PwmBackup	ds.b $200*MAX_PWMCHNL			; RV PWM backup buffer
RAM_Mars_CurrPlgnPage	ds.l 1
			dephase

; ====================================================================
; ----------------------------------------------------------------
; CACHED RAM
;
; Flush the cache often when using this.
; ----------------------------------------------------------------

			align $10
SH2_RAM:
			ds.b $8800				; <-- Maximum RAM for the fake-Video modes
RAM_Mars_VramData	ds.b MAX_MarsVram			; ** SHARED
			align $10

; ----------------------------------------------------------------
; RAM section for 2D
; ----------------------------------------------------------------

			memory SH2_RAM
RAM_Mars_SprDrwCanvas	ds.b 320*92
sizeof_marsram_0	ds.l 0
			endmemory
			erreport "2D section",sizeof_marsram_0-SH2_RAM,$8800

; ----------------------------------------------------------------
; RAM section for 3D
; ----------------------------------------------------------------

			memory SH2_RAM
RAM_Mars_Buff3D_Start	ds.l 0				; <-- ****
RAM_Mars_ObjCamera	ds.b $40			; Object camera
RAM_Mars_Objects	ds.b mmdl_len*MAX_MARSOBJ	; Objects
RAM_Mars_SprPolygn	ds.b mspr_len*MAX_MARSMSPR
RAM_Mars_Polygons_0	ds.b plygn_len*MAX_FACES	; Read/Write polygon data
RAM_Mars_Polygons_1	ds.b plygn_len*MAX_FACES
RAM_Mars_PlgnList_0	ds.l MAX_FACES*2		; Polygon order list: Zpos, pointer
RAM_Mars_PlgnList_1	ds.l MAX_FACES*2
RAM_Mars_PlgnNum_0	ds.l 1
RAM_Mars_PlgnNum_1	ds.l 1
RAM_Mars_Buff3D_End	ds.l 0				; <-- ****
sizeof_marsram_1	ds.l 0
			endmemory
			erreport "3D section",sizeof_marsram_1-SH2_RAM,$8800

; ====================================================================
; ----------------------------------------------------------------
; USER DATA GOES HERE
; ----------------------------------------------------------------

SH2_USER_DATA:
		include "sound/smpl_pwm.asm"			; GEMA: PWM samples
		include "game/data/mars/objects/list.asm"

; ====================================================================

.end:
		erreport "SH2 USER DATA",.end-SH2_USER_DATA,(CS3|$40000)-SH2_USER_DATA

; ====================================================================
		align $10
SH2_END:
		cpu 68000
		padding off
		dephase
		phase (SH2_END-SH2_Master)+MARS_RAMCODE
		align 4
