; ===========================================================================
; -------------------------------------------------------------------
; GEMA/Nikona Sound Driver v1.0.x
; by GenesisFan64 2023-2024
; -------------------------------------------------------------------

; ====================================================================
; --------------------------------------------------------
; Variables
; --------------------------------------------------------

; z80_cpu	equ $A00000			; Z80 CPU area, size: $2000
; z80_bus 	equ $A11100			; only read bit 0 (bit 8 as WORD)
; z80_reset	equ $A11200			; WRITE only: $0000 reset/$0100 cancel

; Z80-area points:
zDrvFifo	equ $1F60;commZfifo		; FIFO command storage
zDrvFWrt	equ $1F80;commZWrite		; FIFO command index
zDrvRomBlk	equ $1F81;commZRomBlk		; ROM block flag
zDrvRamSrc	equ $1F82+4;cdRamSrcB		; !! RAM-read source+dest pointers
zDrvRamLen	equ $1F87;cdRamLen		; RAM-read length + flag
zDrvPalMode	equ $1F88;palMode		; PAL speed flag
zDrvMarsBlk	equ $1F89;marsBlock		; Flag to disable 32X's PWM
zDrvMcdBlk	equ $1F8A;mcdBlock		; Flag to disable SegaCD's PCM
zDrvMaxCmnd	equ $20;MAX_ZCMND		; Command fifo size

; ====================================================================
; --------------------------------------------------------
; Labels
; --------------------------------------------------------

RAM_ZCdFlagD	equ RAM_SoundBuff		; transferRom flag (shared with Z80)

; ====================================================================
; --------------------------------------------------------
; Initialize Sound
; --------------------------------------------------------

gemaInit:
		ori.w	#$0700,sr
	if PICO
		; PICO driver init...
	else
		move.w	#$0100,(z80_bus).l		; Get Z80 bus
		move.w	#$0100,(z80_reset).l		; Z80 reset
.wait:
		btst	#0,(z80_bus).l
		bne.s	.wait
		lea	(z80_cpu).l,a1			; a1 - Z80 CPU area
		move.l	a1,a0
		move.w	#$1FFF,d1
		moveq	#0,d0
.cleanup:
		move.b	d0,(a0)+
		dbf	d1,.cleanup
		lea	(Z80_CODE).l,a0			; a0 - Z80 code (on $880000)
		move.w	#(Z80_CODE_END-Z80_CODE)-1,d0	; d0 - Size
.copy:
		move.b	(a0)+,(a1)+
		dbf	d0,.copy
		move.w	#0,(z80_reset).l		; Reset
		clr.b	(RAM_ZCdFlagD).w		; Reset Z80 transferRom flag
		move.b	(sys_io).l,d0			; Write PAL mode flag from here
		btst	#6,d0
		beq.s	.not_pal
		move.b	#1,(z80_cpu+zDrvPalMode).l
.not_pal:
		nop
		nop
		move.w	#$100,(z80_reset).l
		move.w	#0,(z80_bus).l			; Start Z80
	endif

; ====================================================================
; ----------------------------------------------------------------
; gemaReset
;
; Reset sound to default sequence list
; ----------------------------------------------------------------

gemaReset:
		lea	(MainGemaSeqList),a0
		bsr	gemaSetMasterList
		moveq	#6-1,d7				; Make sure it finishes.
		dbf	d7,*
		rts

; ====================================================================
; ----------------------------------------------------------------
; gemaSendRam
;
; If you are reading data from 68000's RAM you MUST call
; this a lot during display, commonly during the VBlank waiting
; loop.
;
; This checks if the Z80 wants to read from RAM, then here
; we manually write the bytes the Z80 wants to read.
;
; SCD/CD32X:
; - DAC samples are safe to read from WORD-RAM, but NOT
;   when Stamps are being used, use PCM samples instead.
; - Be careful when loading new data with gemaSetMasterList to
;   WORD-RAM, make sure MAIN-CPU has the permission set for
;   reading from there
; ----------------------------------------------------------------

gemaSendRam:
		tst.b	(RAM_ZCdFlagD).w		; Z80 WROTE the flag?
		beq.s	.no_task
		clr.b	(RAM_ZCdFlagD).w		; Clear here, Z80 doesn't know.
		movem.l	a4-a6/d5-d7,-(sp)
		moveq	#0,d7				; Cleanup d7
		bsr	sndLockZ80
		move.b	(z80_cpu+zDrvRamLen).l,d7	; Len == 0?
		beq.s	.no_size			; Invalid size, do nothing
		subq.w	#1,d7				; dbf -1
		lea	(z80_cpu+(zDrvRamSrc+1)),a6	; a6 - SRC location and DST, backwards
		lea	(z80_cpu),a5			; a5 - Z80 area
		move.b	-(a6),d6			; d6 - Source
		swap	d6
		move.b	-(a6),d6
		lsl.w	#8,d6
		move.b	-(a6),d6
		moveq	#0,d5
		move.b	-(a6),d5			; d5 - Dest
		lsl.w	#8,d5
		move.b	-(a6),d5
		add.l	d5,a5
		move.l	d6,a4
.copy_bytes:
		move.b	(a4)+,(a5)+
		dbf	d7,.copy_bytes
		move.b	#0,(z80_cpu+zDrvRamLen).l	; clear LEN, breaks loop
.no_size:
		bsr	sndUnlockZ80
		movem.l	(sp)+,a4-a6/d5-d7
.no_task:
		rts

; ====================================================================
; ------------------------------------------------
; sndLockZ80
;
; Stop Z80, unlocks bus
; ------------------------------------------------

sndLockZ80:
	if PICO=0
		move.w	#$0100,(z80_bus).l
.wait:
		btst	#0,(z80_bus).l
		bne.s	.wait
	endif
		rts

; ------------------------------------------------
; sndUnlockZ80
;
; Resume Z80, locks bus
; ------------------------------------------------

sndUnlockZ80:
	if PICO=0
		move.w	#0,(z80_bus).l
	endif
		rts

; ------------------------------------------------
; 68K-to-Z80 sound request enter/exit routines
;
; d6 - commFifo index
; ------------------------------------------------

sndReq_Enter:
	if PICO=0
		move.w	#$0100,(z80_bus).l		; Request Z80 Stop
	endif
		suba	#4,sp				; Extra jump return
		movem.l	d6-d7/a5-a6,-(sp)		; Save these regs to the stack
		move.w	sr,-(sp)			; and sr too
		ori.w	#$0700,sr			; Disable interrupts
		adda	#(4*4)+2+4,sp			; Go back to the RTS jump
		lea	(z80_cpu+zDrvFWrt).l,a5		; a5 - commZWrite
		lea	(z80_cpu+zDrvFifo).l,a6		; a6 - fifo command list
.wait:
	if PICO=0
		btst	#0,(z80_bus).l			; Wait for Z80
		bne.s	.wait
	endif
		move.b	(a5),d6				; d6 - index fifo position
		ext.w	d6				; extend to 16 bits
		rts
; JUMP ONLY
sndReq_Exit:
	if PICO=0
		move.w	#0,(z80_bus).l
	endif
		suba	#8+2+(4*4),sp
		move.w	(sp)+,sr
		movem.l	(sp)+,d6-d7/a5-a6		; And pop those back
		adda	#8,sp
		andi.w	#$F8FF,sr			; Enable interrupts
		rts

; ------------------------------------------------
; Send request id and arguments
;
; Input:
; d7 - byte to write
; d6 - index pointer
; a5 - commZWrite, update index
; a6 - commZfifo command list
;
; *** CALL sndReq_Enter FIRST ***
; ------------------------------------------------

sndReq_scmd:
		move.b	#-1,(a6,d6.w)			; Command-start flag
		addq.b	#1,d6				; Next fifo pos
		andi.b	#zDrvMaxCmnd-1,d6
		bra.s	sndReq_sbyte
sndReq_slong:
		bsr	sndReq_sbyte
		ror.l	#8,d7
; 24-bit address
sndReq_saddr:
		bsr	sndReq_sbyte
		ror.l	#8,d7
sndReq_sword:
		bsr	sndReq_sbyte
		ror.l	#8,d7
sndReq_sbyte:
		move.b	d7,(a6,d6.w)			; Write byte
		addq.b	#1,d6				; Next fifo pos
		andi.b	#zDrvMaxCmnd-1,d6
		move.b	d6,(a5)				; Update commZWrite
		rts

; --------------------------------------------------------
; gemaDmaPause
;
; Call this BEFORE doing any DMA transfer
;
; 32X: Set RV bit manually AFTER calling this.
; --------------------------------------------------------

gemaDmaPause:
	if PICO=0
		move.l	d7,-(sp)
		bsr	sndLockZ80
		move.b	#1,(z80_cpu+zDrvRomBlk).l	; Set ROM-busy flag
		bsr	sndUnlockZ80
		move.w	#96,d7				; Small delay
		dbf	d7,*
		move.l	(sp)+,d7
	endif
		rts

; --------------------------------------------------------
; gemaDmaResume
;
; Call this AFTER finishing DMA transfer
;
; 32X: Reset the RV bit manually BEFORE calling this.
; --------------------------------------------------------

gemaDmaResume:
	if PICO=0
		move.l	d7,-(sp)
		bsr	sndLockZ80
		move.b	#0,(z80_cpu+zDrvRomBlk).l	; Clear ROM-busy flag
		bsr	sndUnlockZ80
		move.w	#96,d7				; Small delay
		dbf	d7,*
		move.l	(sp)+,d7
	endif
		rts

; ====================================================================
; --------------------------------------------------------
; Subroutines
;
; USER Sound calls are here
; --------------------------------------------------------

; --------------------------------------------------------
; gemaTest
;
; For TESTING only
; --------------------------------------------------------

gemaTest:
		bsr	sndReq_Enter
		move.w	#$00,d7		; Command $00
		bsr	sndReq_scmd
		bra 	sndReq_Exit

; --------------------------------------------------------
; gemaSetMasterList
;
; Sets the Master sequence list location
;
; Input:
; a0 | 68k pointer
;
; Notes:
; - ALL TRACKS MUST BE STOPPED, CALL gemaStopAll FIRST,
; wait a few frames is required.
; --------------------------------------------------------

gemaSetMasterList:
		bsr	sndReq_Enter
		move.w	#$01,d7		; Command $01
		bsr	sndReq_scmd
		move.l	a0,d7
		bsr	sndReq_slong
		bra 	sndReq_Exit

; --------------------------------------------------------
; gemaPlaySeq
;
; Play a sequence
;
; Input:
; d0.b | Sequence number
; d1.b | Starting block
; d2.b | Playback slot number
;        If -1: Auto-search free slot
;        (same as gemaPlaySeqAuto)
; --------------------------------------------------------

gemaPlaySeq:
		bsr	sndReq_Enter
		move.w	#$02,d7		; Command $02
		bsr	sndReq_scmd
		move.b	d0,d7		; d0.b Seq number
		bsr	sndReq_sbyte
		move.b	d1,d7		; d1.b Block <--
		bsr	sndReq_sbyte
		move.b	d2,d7		; d2.b Slot
		bsr	sndReq_sbyte
		bra 	sndReq_Exit

; --------------------------------------------------------
; gemaPlaySeqAuto
;
; Play a sequence into any free slot
;
; Input:
; d0.b | Sequence number
; d1.b | Starting block
; --------------------------------------------------------

gemaPlaySeqAuto:
		bsr	sndReq_Enter
		move.w	#$02,d7		; Command $02
		bsr	sndReq_scmd
		move.b	d0,d7		; d0.b Seq number
		bsr	sndReq_sbyte
		move.b	d1,d7		; d1.b Block <--
		bsr	sndReq_sbyte
		moveq	#-1,d7		; d2.b Slot
		bsr	sndReq_sbyte
		bra 	sndReq_Exit

; --------------------------------------------------------
; gemaStopSeq
;
; Stops tracks with the same sequence number
;
; Input:
; d0.b | Sequence number to search for
;        If -1: Stop all tracks with any sequence
; d1.b | Playback slot number
;        If -1: Stop all slots
;
; If both d0 and d1 are -1 it acts like gemaStopAll
; --------------------------------------------------------

gemaStopSeq:
		bsr	sndReq_Enter
		move.w	#$03,d7		; Command $03
		bsr	sndReq_scmd
		move.b	d0,d7		; d0.b Seq number
		bsr	sndReq_sbyte
		move.b	d1,d7		; d1.b Slot
		bsr	sndReq_sbyte
		bra 	sndReq_Exit

; --------------------------------------------------------
; gemaStopAll
;
; Stops ALL tracks, quick version of gemaStopTrack.
; --------------------------------------------------------

gemaStopAll:
		bsr	sndReq_Enter
		move.w	#$03,d7		; Command $03
		bsr	sndReq_scmd
		moveq	#-1,d7		; d0.b Seq number
		bsr	sndReq_sbyte
		moveq	#-1,d7		; d1.b Slot
		bsr	sndReq_sbyte
		bra 	sndReq_Exit

; --------------------------------------------------------
; gemaFadeSeq
;
; Set Master volume to a track slot.
;
; Input:
; d0.b | Target volume
; d1.b | Playback slot number
;        If -1: Apply to all slots
;
; Notes:
; - DO NOT MIX THIS WITH gemaSetTrackVol
; - v1.0: This only works on (re)start
;   or during new notes on playback.
; --------------------------------------------------------

gemaFadeSeq:
		bsr	sndReq_Enter
		move.w	#$05,d7		; Command $05
		bsr	sndReq_scmd
		move.b	d0,d7		; d0.b Target volume
		bsr	sndReq_sbyte
		move.b	d1,d7		; d1.b Slot
		bsr	sndReq_sbyte
		bra 	sndReq_Exit

; --------------------------------------------------------
; gemaSetSeqVol
;
; Set Master volume to a Seq slot.
;
; Input:
; d0.b | Master volume: $00-max $40-min
; d1.b | Playback slot number
;        If -1: Set to all slots
;
; Notes:
; - DO NOT MIX THIS WITH gemaFadeSeq
; - v1.0: This only works on (re)start
;   or during new notes on playback.
; --------------------------------------------------------

gemaSetSeqVol:
		bsr	sndReq_Enter
		move.w	#$06,d7		; Command $06
		bsr	sndReq_scmd
		move.b	d0,d7		; d1.b Volume data <--
		bsr	sndReq_sbyte
		move.b	d1,d7		; d0.b Slot
		bsr	sndReq_sbyte
		bra 	sndReq_Exit

; --------------------------------------------------------
; gemaSetBeats
;
; Set global sub-beats
;
; Input:
; d0.w | Sub-beats value
;
; Note:
; If the Z80 is running in PAL mode the number will
; change inside the Z80 to match the PAL's speed.
; --------------------------------------------------------

gemaSetBeats:
		bsr	sndReq_Enter
		move.w	#$07,d7		; Command $07
		bsr	sndReq_scmd
		move.w	d0,d7
		bsr	sndReq_sword
		bra 	sndReq_Exit
