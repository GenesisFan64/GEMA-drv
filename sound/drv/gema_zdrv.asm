; ===========================================================================
; -------------------------------------------------------------------
; GEMA Z80 code
; -------------------------------------------------------------------

		phase 0
		cpu Z80		; Enter Z80 CPU

; --------------------------------------------------------
; SETTINGS
; --------------------------------------------------------

; !! = HARDCODED
MAX_TRFRPZ	equ 9		; !! Max readRom packets(bytes) **AFFECTS WAVE QUALITY**
MAX_TRKCHN	equ 32		; !! Max internal shared tracker channel slots *** MSB alinged ***
MAX_RCACH	equ 20h		; !! Max storage for ROM pattern data *** 1-BIT SIZES ONLY, MUST BE LSB ALIGNED ***
MAX_BUFFNTRY	equ 4*2		; !! nikona_BuffList buffer entry size **HARDCODED
MAX_SLOTS	equ 3		; !! Number of track buffers
MAX_ZCMND	equ 20h		; !! Size of command array ** 1-bit SIZES ONLY ** (68k uses this label too)
MAX_TBLSIZE	equ 12h		; Maximum size for chip table arrays
MAX_TRKINDX	equ 26		; Max channel indexes per buffer: 4PSG+6FM+8PCM+8PWM

; --------------------------------------------------------
; Structs
; --------------------------------------------------------

; trkBuff struct
;
; trk_Status: %ERP- V--0
; E - enabled
; R - Init|Restart track
; P - refill-on-playback
; V - volume change flag
; 0 - Use global sub-beats
trk_Status	equ 00h	; ** Track Status and Flags (MUST BE at 00h)
trk_SeqId	equ 01h ; ** Track ID to play.
trk_SetBlk	equ 02h	; ** Start on this block
trk_TickSet	equ 03h	; ** Ticks for this track
trk_Blocks	equ 04h ; ** [W] Current track's blocks
trk_Patt	equ 06h ; ** [W] Current track's heads and patterns
trk_Cach	equ 08h	; ** [W] Current track's cache notedata
trk_Read	equ 0Ah	; [W] Track current pattern read
trk_Rows	equ 0Ch	; [W] Track row counter
trk_VolMaster	equ 0Eh ; [W] Master volume for this track slot (00-max), +80h update
trk_cachHalf	equ 10h ; ROM-cache halfcheck
trk_rowPause	equ 11h	; Row-pause timer
trk_TickTmr	equ 12h	; Ticks timer
trk_currBlk	equ 13h	; Current block
trk_Priority	equ 14h ; Priority level for this buffer
trk_BankHeads	equ 15h ; Header bank
trk_BankBlk	equ 16h	; Block bank
trk_MaxChnl	equ 17h ; MAX channels used in this track
trk_VolFdTarget	equ 18h	; Target fade volume
trk_RomPattRead	equ 19h ; [3b] ROM current pattern data to be cache'd
trk_RomPatt	equ 1Ch ; [3b] ROM BASE pattern data
trk_RomInst	equ 1Fh ; [3b] ROM instrument data
trk_RomBlks	equ 22h ; [3b] ROM blocks data
trk_ChnIndx	equ 25h	; CHANNEL INDEXING START HERE

; chnBuff struct, 8 BYTES ONLY.
;
; chnl_Flags: E0LRevin
; 	 E - Channel is active
; 	LR - 1-bit Left/Right panning bits: 0-ON 1-OFF
; 	 e - Effect*
; 	 v - Volume*
; 	 i - Intrument*
; 	 n - Note*

chnl_Flags	equ 0	; !! Playback flags: %E0LRevin ** MUST BE LOCATED AT 0 **
chnl_Chip	equ 1	; %ccccpppp c - Current Chip ID / p - Priority level
chnl_Note	equ 2	; IT Music note or command
chnl_Ins	equ 3	; IT Instrument starting from 1 (0 is invalid)
chnl_Vol	equ 4	; IT Volume: MAX(64) to MIN(0)
chnl_EffId	equ 5	; IT Effect number
chnl_EffArg	equ 6	; IT Effect argument
chnl_Type	equ 7	; Impulse type bits


; Table struct
ztbl_Link	equ 00h			; !! current linked channel in trkChnls
ztbl_Priority	equ 02h			; !! 00h-7Fh: Priority level 0-15 + 80h+chipID Silence request
ztbl_Chip	equ 03h			; Chip index (YM2612: direct index) *MUST BE ON THE LIST*
ztbl_MasterVol	equ 04h			; MASTER volume for this channel
ztbl_FreqIndx	equ 05h			; Frequency list index (YM2612: %oooiiiii oct|index)
ztbl_PitchBend	equ 06h			; Pitchbend incr/decr
ztbl_Volume	equ 07h			; Current Volume: 00-max
ztbl_VolSlide	equ 08h			; Volume slide incr/decr
ztbl_InstCach	equ 0Ah			; <-- 8 bytes

; --------------------------------------------------------
; Variables
; --------------------------------------------------------

; Z80 opcode labels for the wave playback routines
zopcNop		equ 00h
zopcEx		equ 08h
zopcRet		equ 0C9h
zopcExx		equ 0D9h		; (dac_me ONLY)
zopcPushAf	equ 0F5h		; (dac_fill ONLY)

; PSG
COM		equ 0
LEV		equ 4
ATK		equ 8
DKY		equ 12
SLV		equ 16
RRT		equ 20
MODE		equ 24
DTL		equ 28
DTH		equ 32
ALV		equ 36
FLG		equ 40
ARP		equ 44
MVOL		equ 48
EFFV		equ 52
PTMR		equ 56

; ====================================================================
; --------------------------------------------------------
; Code starts here
; --------------------------------------------------------

		di			; Disable interrupts
		im	1		; Interrupt mode 1
		ld	sp,2000h	; Set STACK at the end of Z80
		jr	z80_init	; Jump to z80_init

; --------------------------------------------------------
; RST 8 (dac_me)
;
; Writes wave data to DAC using data stored
; on the wave buffer, call this routine every 6 or 8
; instructions to keep the samplerate stable.
;
; Input (EXX):
;  c - WAVE buffer MSB
; de - Pitch (xx.00)
; h  - WAVE buffer LSB (as xx.00)
;
; Uses (EXX):
; b
;
; Notes:
; ONLY USE dac_on and dac_off to turn OFF/ON
; DAC playback
;
; Samplerate is 16000hz with minimal quality loss.
; --------------------------------------------------------

; EXX set:
; af - temporal
; bc - l temporal | dWaveBuff MSB
; de - pitch increment
; hl - wave buffer position 00.00h
		org 8
dac_me:		exx			; * flip registers | Changes between EXX(play) and RET(stop)
		ex	af,af'		; Swap af
		ld	b,l		; Save old hl buff
		ld	l,h		;
		ld	h,c		; h - Set buffer MSB
		ld	a,2Ah		;
		ld	(Zym_ctrl_1),a	; Set YM Register 2Ah
		ld	a,(hl)		; Read wave byte and
		ld	(Zym_data_1),a	; write it to DAC
		ld	h,l		; Get hl buff back
		ld	l,b		;
		add	hl,de		; Pitch increment hl
		ex	af,af'		; Return af
		exx			; * return regs
		ret

; --------------------------------------------------------
; 1Ch - Master tracklist pointer
gemaMstrListPos:
		db 0			; ** 32-bit 68k address **
		db 0
		db 0
		db 0

; --------------------------------------------------------
; RST 20h (dac_me)
; *** self-modifiable code ***
;
; Checks if the WAVE cache needs refilling to keep
; it playing.
; --------------------------------------------------------

		org 20h
dac_fill:	push	af		; Save af | Changes between PUSH AF(play) and RET(stop)
		ld	a,(dDacFifoMid)	; a - Get half-way value
		exx			; * flip registers
		xor	h		; Grab LSB.00
		exx			; * restore regs
		and	80h		; Check if LSB 7th bit changed
		call	nz,dac_refill	; If yes, call refill and update LSB
		pop	af		; Restore af
		ret

; --------------------------------------------------------
; 02Eh - User read/write values

commZRead	db 0			; cmd fifo READ pointer (here)
psgHatMode	db 0			; Current PSGN mode
fmSpecial	db 0			; copy of FM3 enable bit
sbeatAcc	dw 0			; Accumulates on each tick to trigger the sub beats
sbeatPtck	dw 214			; Default global subbeats (this-32 for PAL) 214=125
x68ksrclsb	db 0			; readRom temporal LSB
x68ksrcmid	db 0			; readRom temporal MID
dDacFifoMid	db 0			; WAVE play halfway refill flag (00h/80h)

; --------------------------------------------------------
; Z80 Interrupt at 0038h
; --------------------------------------------------------

		org 38h				; Align 38h
		ld	(tickSpSet),sp		; Write TICK flag using current sp (read tickFlag only)
		di				; Disable interrupt
		ret

; --------------------------------------------------------
; Initialize
; --------------------------------------------------------

z80_init:
		call	gema_init		; Init values

; --------------------------------------------------------
; MAIN LOOP
; --------------------------------------------------------

drv_loop:
		rst	8
		call	get_tick		; Check tick on VBlank
		rst	20h			; Refill wave here
		rst	8
		ld	b,0			; b - Reset current flags (beat|tick)
		ld	a,(tickCnt)		; Decrement tick counter
		sub	1
		jr	c,.noticks		; If non-zero, no tick passed.
		ld	(tickCnt),a
		call	chip_env		; Process PSG and YM
		call	get_tick		; Check for another tick
		ld 	b,01b			; Set TICK and clear BEAT flags (01b)
.noticks:
		ld	a,(sbeatAcc+1)		; check beat counter (scaled by tempo)
		sub	1
		jr	c,.nobeats
		rst	8
		ld	(sbeatAcc+1),a		; 1/24 beat passed.
		set	1,b			; Set BEAT (10b) flag
.nobeats:
		rst	8
		ld	a,b			; Any beat/tick bits set?
		or	a
		jr	z,.neither
		ld	(currTickBits),a	; Save BEAT/TICK bits
		rst	8
		call	get_tick
		call	set_chips		; Send changes to sound chips
		call	get_tick
		rst	8
		call	upd_seq			; Process sequences
		call	get_tick
.neither:
		rst	8
	if MCD|MARS|MARSCD
		call	zmars_send		; External communication with CD and 32X
	endif
		call	get_tick
.next_cmd:
		ld	a,(commZWrite)		; Check if commZ R/W indexes
		ld	b,a			; are in the same spot a == b
		ld	a,(commZRead)
		cp	b			; If equal, loop back.
		jr	z,drv_loop
		rst	8
		call	.grab_arg		; Read staring flag -1
		cp	-1			; Got START -1?
		jr	nz,drv_loop		; If not, end of commands
		call	.grab_arg		; Read command number
		add	a,a			; ID * 2
		ld	hl,.list		; Index-jump...
		ld	d,0
		ld	e,a
		add	hl,de
		ld	a,(hl)
		inc	hl
		ld	h,(hl)
		rst	8
		ld	l,a
		jp	(hl)

; --------------------------------------------------------
; Read cmd byte, auto re-rolls to 3Fh
; --------------------------------------------------------

.grab_arg:
		push	de
		push	hl
.getcbytel:
		ld	a,(commZWrite)
		ld	d,a
		rst	8
		ld	a,(commZRead)
		cp	d		; commZ R/W indexes are the same?
		jr	z,.getcbytel	; wait until these counters change.
		ld	d,0
		ld	e,a
		ld	hl,commZfifo	; Read commZ list + index
		add	hl,de
		rst	8
		inc	a
		and	MAX_ZCMND-1	; ** commZ list buffer limit
		ld	(commZRead),a
		ld	a,(hl)		; a - got this byte from the buffer
		pop	hl
		pop	de
		ret

; --------------------------------------------------------

.list:
		dw .cmnd_0		; 00h - TESTING
		dw .cmnd_1		; 01h - Set Master tracklist
		dw .cmnd_2		; 02h - Play by track number
		dw .cmnd_3		; 03h - Stop by track number
		dw .cmnd_0		; 04h - **
		dw .cmnd_5		; 05h - Fade volume (FadeIn/FadeOut)
		dw .cmnd_6		; 06h - Set maximum volume to slot
		dw .cmnd_7		; 07h - Set GLOBAL sub-beats

; --------------------------------------------------------
; Command 00h
;
; Reserved for TESTING purposes.
; --------------------------------------------------------

.cmnd_0:
		jp	.next_cmd

; --------------------------------------------------------
; Command 01h:
;
; Set the Track MASTER-list.
; --------------------------------------------------------

.cmnd_1:
		ld	hl,gemaMstrListPos+3	; 32-bit big endian
		call	.grab_arg		; $000000xx
		ld	(hl),a
		dec	hl
		call	.grab_arg		; $0000xx00
		ld	(hl),a
		dec	hl
		call	.grab_arg		; $00xx0000
		ld	(hl),a
		dec	hl
		call	.grab_arg		; $xx000000 (filler)
		ld	(hl),a
		jp	.next_cmd

; --------------------------------------------------------
; Command 02h:
;
; Make new track by sequence number
;
; Arguments:
; SeqID,BlockPos,SlotIndex(If -1 autofill)
; --------------------------------------------------------

.cmnd_2:
		call	.grab_arg		; d1: Sequence ID
		ld	c,a			; copy as c
		call	.grab_arg		; d2: Block from
		ld	b,a			; copy as b
		rst	8
		call	.grab_arg		; d0: Slot index
		ld	iy,nikona_BuffList	; iy - Slot buffer list
		or	a
		jp	m,.srch_mode
; 		cp	-1			; if d2 == -1, search
; 		jr	z,.srch_mode
		cp	MAX_SLOTS		; If maxed out slots
		jp	nc,.next_cmd
		rst	8
		call	.cmnd_rdslot
		jp	.wrtto_slot
; -1
.srch_mode:
		call	.srch_slot
		cp	-1
		jp	z,.next_cmd		; Then skip, no free slot.
		bit	7,(hl)			; Is this track free?
		jp	z,.wrtto_slot
		jr	.srch_mode
.wrtto_slot:
		ld	(hl),0C0h		; ** Write trk_Status flags: Enable+Restart
		inc	hl
		rst	8
		ld	(hl),c			; ** write trk_SeqId
		inc	hl
		ld	(hl),b			; ** write trk_SetBlk
		ld	a,c
		jp	.next_cmd

; --------------------------------------------------------
; Command 03h:
;
; Stop track with the same sequence number
;
; SeqID,SlotIndex(-1 allslots)
; --------------------------------------------------------

.cmnd_3:
		call	.grab_arg			; d1: Sequence ID
		ld	c,a				; copy to c
		call	.grab_arg			; d0: Slot index
		ld	iy,nikona_BuffList		; iy - Slot buffer list
		or	a
		jp	m,.srch_del			; if -1, search for all with same ID
		cp	MAX_SLOTS			; If maxed out slots
		jp	nc,.next_cmd
		rst	8
		call	.cmnd_rdslot
		call	.wrtto_del
		jp	.next_cmd
; -1
.srch_del:
		call	.srch_slot
		cp	-1
		jp	z,.next_cmd
		call	.wrtto_del
		jr	.srch_del
.wrtto_del:
		bit	7,(hl)
		ret	z
		bit	7,c		; <-- lazy -1 check
		jr	nz,.del_all
		ld	a,(ix+trk_SeqId)
		cp	c
		ret	nz
.del_all:
		ld	(hl),-1		; -1 flag, stop channel and clear slot
		inc	hl
		ld	(hl),-1		; Reset seqId
		rst	8
		ret

; --------------------------------------------------------
; Command 05h:
;
; Fade volume (FadeIn/FadeOut)
;
; Arguments:
; TargetVol,SlotIndex(If -1 autofill)
; --------------------------------------------------------

.cmnd_5:
		call	.grab_arg		; d1: Master volume
		ld	c,a			; copy to c
		call	.grab_arg		; d0: Slot index
		ld	iy,nikona_BuffList	; iy - Slot buffer list
		or	a
		jp	m,.srch_fvol		; if -1, search for all with same ID
		cp	MAX_SLOTS		; If maxed out slots
		jp	nc,.next_cmd
		rst	8
		call	.cmnd_rdslot
		call	.wrtto_fvol
		jp	.next_cmd
; -1
.srch_fvol:
		call	.srch_slot
		cp	-1
		jp	z,.next_cmd		; Then skip, no free slot.
		call	.wrtto_fvol
		jr	.srch_fvol
.wrtto_fvol:
		bit	7,(hl)			; Active?
		ret	z
		set	3,(hl)			; Volume update flag
		ld	(ix+trk_VolFdTarget),c
		ld	(ix+trk_VolMaster+1),0
		rst	8
		ret

; --------------------------------------------------------
; Command 06h:
;
; Set track's master volume
;
; Arguments:
; MasterVol,SlotIndex(If -1 autofill)
; --------------------------------------------------------

.cmnd_6:
		call	.grab_arg		; d1: Master volume
		ld	c,a			; copy to c
		call	.grab_arg		; d0: Slot index
		ld	iy,nikona_BuffList	; iy - Slot buffer list
		or	a
		jp	m,.srch_vol		; if -1, search for all with same ID
		cp	MAX_SLOTS		; If maxed out slots
		jp	nc,.next_cmd
		rst	8
		call	.cmnd_rdslot
		call	.wrtto_vol
		jp	.next_cmd
; -1
.srch_vol:
		call	.srch_slot
		cp	-1
		jp	z,.next_cmd		; Then skip, no free slot.
		call	.wrtto_vol
		jr	.srch_vol
.wrtto_vol:
		set	3,(hl)			; Volume update flag
		ld	(ix+trk_VolMaster),c
		ld	(ix+trk_VolFdTarget),c
		ld	(ix+trk_VolMaster+1),0
		rst	8
		ret

; --------------------------------------------------------
; Command 07h:
;
; Set global sub-beats
; --------------------------------------------------------

.cmnd_7:
		call	.grab_arg	; d0.w: $00xx
		ld	c,a
		call	.grab_arg	; d0.w: $xx00
		ld	h,a
		ld	l,c
		ld	a,(palMode)
		or	a
		jr	z,.not_pal
		ld	de,40
		add	hl,de
.not_pal:
		ld	a,h
		ld	(sbeatPtck+1),a
		ld	a,l
		ld	(sbeatPtck),a
		jp	.next_cmd

; --------------------------------------------------------
; Shared subs
; --------------------------------------------------------

.cmnd_rdslot:
		add	a,a			; ** MANUAL MAX_BUFFNTRY
		add	a,a			; id*8
		add	a,a
		ld	d,0
		ld	e,a
		add	iy,de
		ld	l,(iy)
		ld	h,(iy+1)
		push	hl
		pop	ix
		ret

; ------------------------------------------------
; iy - nikona_BuffList

.srch_slot:
		ld	a,(iy)
		cp	-1			; End of list?
		ret	z
		ld	h,(iy+1)		; hl - Current track slot
		ld	l,a
		push	hl
		pop	ix
		ld	de,MAX_BUFFNTRY
		add	iy,de			; Next entry for later
		ret

; ====================================================================
; ----------------------------------------------------------------
; MAIN Playback section
; ----------------------------------------------------------------

; --------------------------------------------------------
; Read mini-impulse-tracker data
; --------------------------------------------------------

upd_seq:
		rst	20h
		call	get_tick		; Check for tick flag
		ld	iy,trkBuff_0		; ** MANUAL BUFFERS
		call	.read_track
		ld	iy,trkBuff_1
		call	.read_track
		rst	8
		ld	iy,trkBuff_2

; ----------------------------------------
; Read track
;
; iy - Track buffer
; ----------------------------------------

.read_track:
		rst	8
		ld	b,(iy+trk_Status)	; b - Track status and settings
		bit	7,b			; bit7: Track active?
		ret	z			; Return if not.
		ld	a,b
		cp	-1			; Value is -1?
		ret	z
		rst	8
	; ----------------------------------------
	; Track volume changes
		ld	l,(iy+trk_VolMaster+1)
		ld	h,(iy+trk_VolMaster)
		ld	c,(iy+trk_VolFdTarget)
		ld	de,0100h		; <-- Manual volfade speed MAX 0100h
		ld	a,c
		cp	h
		jr	z,.keep_vol
		jr	nc,.fade_out
		ld	de,-80h
		add	hl,de
		jr	.too_much
.fade_out:
		add	hl,de
		rst	8
		ld	a,h
		cp	c
		jr	c,.too_much
		ld	h,c
		ld	l,0
		ld	(iy+trk_VolFdTarget),c
.too_much:
		set	3,(iy+trk_Status)	; Volume update flag
		ld	(iy+trk_VolMaster+1),l
		ld	(iy+trk_VolMaster),h
.keep_vol:
	; ----------------------------------------
		ld	a,(currTickBits)	; a - Tick/Beat bits
		bit	0,b			; bit0: This track uses Beats?
		jr	z,.sfxmd
		bit	1,a			; BEAT passed?
		ret	z			; No BEAT.
.sfxmd:
		bit	0,a			; TICK passed?
		ret	z			; No TICK.
		rst	8
	; ----------------------------------------
	; Start reading notes
		bit	6,b			; bit6: Restart/First time?
		call	nz,.first_fill
		bit	5,b			; bit5: FILL request by effect?
		call	nz,.effect_fill
		ld	a,(iy+trk_TickTmr)	; TICK ex-timer for this track
		dec	a
		ld	(iy+trk_TickTmr),a
		or	a			; Check a
		ret	nz			; If Tick timer != 0, exit.
		rst	8
		ld	a,(iy+trk_TickSet)	; Set new tick timer
		ld	(iy+trk_TickTmr),a
	; ----------------------------------------
		ld	c,(iy+trk_Rows)		; bc - Set row counter
		ld	b,(iy+(trk_Rows+1))
		ld	a,c			; Check rowcount
		or	b
		jr	nz,.row_active		; If bc != 0: row is currenly playing.
	; ----------------------------------------
	; Read next block
		rst	8
		ld	a,(iy+trk_currBlk)	; Next block
		inc	a
		ld 	(iy+trk_currBlk),a
		call	.set_track		; Read track data ** ROM ACCESS **
		cp	-1			; Track finished?
		ret	z
		ld	c,(iy+trk_Rows)		; Set new rowcount to bc
		ld	b,(iy+(trk_Rows+1))
	; ----------------------------------------
	; bc - Row count
.row_active:
		rst	8
		ld	l,(iy+trk_Read)		; hl - CURRENT pattern to read
		ld	h,(iy+((trk_Read+1)))

; --------------------------------
; Main read-loop
; --------------------------------

.next_note:
		ld	a,(iy+trk_rowPause)	; Check row timer
		or	a
		jr	nz,.decrow
		ld	a,(hl)			; Check if byte is a timer or a note
		or	a
		jr	z,.exit			; If == 00h: exit
		jp	m,.has_note		; If 80h-0FFh: Note data
		ld	(iy+trk_rowPause),a	; If 01h-07Fh: Row-pause timer

; --------------------------------
; Exit
; --------------------------------

.exit:
		rst	8
		call	.inc_cpatt		; * Increment patt pos
		ld	(iy+trk_Read),l		; Update READ location
		ld	(iy+((trk_Read+1))),h
		jr	.decrow_e
.decrow:
		dec	(iy+trk_rowPause)	; Decrement row-pause timer
.decrow_e:
		dec	bc			; Decrement rowcount
		ld	(iy+trk_Rows),c		; Write last row to memory
		ld	(iy+(trk_Rows+1)),b
		ret	; Exit.

; --------------------------------
; New note request
;
; a - %1tcccccc
;   | t - next byte has new type
;   | c - channel
; --------------------------------

.has_note:
		rst	8
		push	bc			; Save rowcount
		ld	c,a			; Copy patt byte control to c
		call	.inc_cpatt		; * Increment patt pos
		push	hl			; Save hl patt pos
		push	iy			; copy iy to hl
		pop	hl
		ld	ix,trkChnls		; ix - Channels buffer
		ld	de,trk_ChnIndx		; <-- this clears d
		rst	8
		add	hl,de			; hl - Track's index points buffer
		ld	a,c			; Get patt note position
		and	00011111b		; Filter index bits
		ld	e,a			; Save as e
		add	hl,de			; Increment more by this pos
		ld	a,(hl)			; Check if this index is occupied.
		or	a
		jr	z,.srch_new		; If == 0, search new one
		and	00011111b		; If already taken, read that channel
		add	a,a
		add	a,a
		add	a,a
		ld	e,a
		add	ix,de
		ld	a,(ix)			; Check status (chnl_Flags)
		or	a
		jp	p,.srch_reroll
		jr	.cont_chnl

; Make NEW channel
; ix - channel list start
.srch_reroll:
		ld	(ix),0
.srch_new:
		rst	8
		ld	b,MAX_TRKCHN-1		; Max channels to check - 1
		ld	d,0			; Reset out index
.next_chnl:
		ld	a,(ix)			; Read chnl_Flags
		or	a			; If plus, track channel is free
		jp	p,.chnl_free
		inc	ix			; Search next channel, increment by 8
		inc	ix
		inc	ix
		inc	ix
		rst	8
		inc	ix
		inc	ix
		inc	ix
		inc	ix
		inc	d			; Increment out index
		djnz	.next_chnl
.chnl_free:
		rst	8
		ld	a,d			; Read index we got
		and	00011111b		; Filter bits
		or	10000000b		; and set as used
		ld	(hl),a			; Write index slot
		set	7,(ix+chnl_Flags)	; Enable channel on the list
.cont_chnl:
		pop	hl			; Recover patt pos

	; ix - current channel
	; b - evinEVIN
	;     E-effect/V-volume/I-instrument/N-note
	;     evin: byte is already stored on track-channel buffer
	;     EVIN: next byte(s) contain a new value. for eff:2 bytes
		rst	8
		ld	b,(ix+chnl_Type)	; b - current TYPE byte
		bit	6,c			; This byte has new TYPE setting?
		jr	z,.old_type
		ld	a,(hl)
		ld	(ix+chnl_Type),a	; Update TYPE byte
		ld	b,a			; Set to b
		call	.inc_cpatt		; Next patt pos
.old_type:
		rst	8
		bit	0,b			; New NOTE?
		jr	z,.no_note
		ld	a,(hl)			; Set NOTE and increment patt
		ld	(ix+chnl_Note),a
		call	.inc_cpatt
.no_note:
		bit	1,b			; New INS?
		jr	z,.no_ins
		ld	a,(hl)			; Set INS and increment patt
		ld	(ix+chnl_Ins),a
		call	.inc_cpatt
.no_ins:
		rst	8
		bit	2,b			; New VOL?
		jr	z,.no_vol
		ld	a,(hl)			; Set VOL and increment patt
		ld	(ix+chnl_Vol),a
		call	.inc_cpatt
.no_vol:
		bit	3,b			; New EFFECT?
		jr	z,.no_eff
		ld	a,(hl)			; Set EFFECT ID, incr patt
		ld	(ix+chnl_EffId),a
		call	.inc_cpatt
		rst	8
		ld	a,(hl)			; Set EFFECT ARG, incr patt
		ld	(ix+chnl_EffArg),a
		call	.inc_cpatt
.no_eff:
		ld	a,b			; Merge the Impulse evin bits into main EVIN bits
		rrca
		rrca
		rrca
		rrca
		and	00001111b		; Filter bits
		ld	c,a			; Save as c
		ld	a,b
		and	00001111b		; Filter again
		or	c			; Merge c with a
		rst	8
		ld	c,a			; Save bit flags
		ld	a,(ix+chnl_Flags)
		or	c
		ld	(ix+chnl_Flags),a
		pop	bc			; Restore rowcount
	; ----------------------------------------
	; Effects that affect internal playback
		ld	a,(ix+chnl_Flags)
		and	1000b			; ONLY check for the EFFECT bit
		jp	z,.next_note
		ld	a,(ix+chnl_EffId)
		or	a			; 00h = invalid effect
		jp	z,.next_note
		cp	1			; Effect A: Tick set
		jr	z,.eff_A
		cp	2			; Effect B: Position Jump
		jr	z,.eff_B
		cp	3			; Effect C: Pattern break
		jr	z,.eff_C
		jp	.next_note

; ----------------------------------------
; Effect A: Set ticks
; ----------------------------------------

.eff_A:
		rst	8
		ld	e,(ix+chnl_EffArg)	; e - ticks number
		ld	(iy+trk_TickSet),e	; set for both Set and Timer.
		ld	(iy+trk_TickTmr),e
		res	3,(ix+chnl_Flags)	; <-- Clear EFFECT bit
		jp	.next_note

; ----------------------------------------
; Effect B: jump to a new block
; ----------------------------------------

.eff_B:
		ld	e,(ix+chnl_EffArg)	; e - Block SLOT to jump
		ld 	(iy+trk_currBlk),e
		rst	8
		ld	(iy+trk_rowPause),0	; Reset rowpause
		res	3,(ix+chnl_Flags)	; <-- Clear EFFECT bit
		set	5,(iy+trk_Status)	; set fill-from-effect flag on exit
		ld	a,80h
		ld	(iy+trk_BankHeads),a
		ld	(iy+trk_BankBlk),a
		jp	.next_note

; ----------------------------------------
; Effect C: Pattern break/exit
;
; Only used on SFX, arguments ignored.
; ----------------------------------------

.eff_C:
		jp	.track_end

; ----------------------------------------
; Increment the current patt position
; and recieve more data
;
; Breaks:
; a,e
; ----------------------------------------

.inc_cpatt:
		ld	e,(iy+trk_Cach)		; Read curret cache LSB
		ld	a,l
		inc	a
		and	MAX_RCACH-1
		cp	MAX_RCACH-2		; ALMOST RAN OUT of bytes?
		jr	nc,.ran_out
		or	e
		ld	l,a
		ret
.ran_out:
		ld	l,(iy+trk_Cach)
		push	hl
		push	bc
		ld	b,0
		ld	c,a
		rst	8
		ld	e,l
		ld	d,h
		ld	l,(iy+trk_RomPattRead)
		ld	h,(iy+(trk_RomPattRead+1))
		ld	a,(iy+(trk_RomPattRead+2))
		add	hl,bc
		adc	a,0
		ld	(iy+trk_RomPattRead),l
		ld	(iy+(trk_RomPattRead+1)),h
		rst	8
		ld	(iy+(trk_RomPattRead+2)),a
		ld	bc,MAX_RCACH
		call	readRom		; *** ROM ACCESS ***
		pop	bc
		pop	hl
		ret

; ----------------------------------------
; Set track pattern by trk_currBlk
; ----------------------------------------

.set_track:
	; ----------------------------------------
	; Make block id list
		ld	e,(iy+trk_Blocks)
		ld	d,(iy+(trk_Blocks+1))
		ld	a,(iy+trk_currBlk)
		ld	c,a
		push	bc
		push	de
		rst	8
		rrca
		rrca
		rrca
		and	00011111b
		ld	c,(iy+trk_BankBlk)	; c - current block bank
		bit	7,c			; First time?
		jr	nz,.first_blk
		cp	c			; SAME instrument data?
		jr	z,.keep_blk
.first_blk:
		rst	8
		ld	(iy+trk_BankBlk),a	; Save inst number
		rlca
		rlca
		rlca
		ld	b,0
		ld	c,a
		ld	l,(iy+trk_RomBlks)
		ld	h,(iy+(trk_RomBlks+1))
		ld	a,(iy+(trk_RomBlks+2))
		add	hl,bc
		adc	a,0
		ld	bc,8			; 8 blocks stored
		call	readRom			; ** ROM ACCESS **
.keep_blk:
		pop	hl
		pop	bc
		ld	a,c
		and	00000111b
		rst	8
		ld	d,0
		ld	e,a
		add	hl,de
	; ----------------------------------------
		ld	a,(hl)			; Read block byte
		cp	-1			; If block == -1, end track
		jp	z,.track_end
		rst	8
	; ----------------------------------------
		ld	e,(iy+trk_Patt)		; Read CACHE patt heads
		ld	d,(iy+(trk_Patt+1))
		ld	c,a
		push	de
		push	bc
		rst	8
		rrca
		rrca
		rrca
		and	00011111b
		ld	c,(iy+trk_BankHeads)	; c - current intrument loaded
		bit	7,c			; First time?
		jr	nz,.first_head
		cp	c			; SAME instrument data?
		jr	z,.keep_it
.first_head:
		rst	8
		ld	(iy+trk_BankHeads),a	; Save inst number
		ld	b,a
		rrca
		rrca
		rrca
		and	11100000b
		ld	c,a
		ld	a,b
		rrca
		rrca
		rrca
		and	00000011b
		ld	b,a
	; ----------------------------------------
		ld	l,(iy+trk_RomPatt)	; Transfer FIRST patt
		ld	h,(iy+(trk_RomPatt+1))	; packet
		ld	a,(iy+(trk_RomPatt+2))
		rst	20h
		rst	8
		add	hl,bc
		adc	a,0
		ld	bc,4*8			; 8 heads stored
		call	readRom			; ** ROM ACCESS **
.keep_it:
		pop	bc
		ld	a,c
		and	00000111b
		add	a,a
		add	a,a
		ld	d,a
		rst	8
		and	11111100b
		ld	e,a
		ld	a,d
		and	00000011b
		ld	d,a
		pop	hl
		add	hl,de
		ld	e,(hl)			; de - Pos
		inc	hl
		rst	8
		ld	d,(hl)
		inc	hl
		ld	a,(hl)
		inc	hl
		ld	(iy+trk_Rows),a
		ld	a,(hl)
		inc	hl
		ld	(iy+(trk_Rows+1)),a
		ld	l,(iy+trk_RomPatt)	; Transfer FIRST patt
		ld	h,(iy+(trk_RomPatt+1))	; packet
		rst	8
		ld	a,(iy+(trk_RomPatt+2))
		add	hl,de
		adc	a,0
		ld	(iy+trk_RomPattRead),l
		ld	(iy+(trk_RomPattRead+1)),h
		ld	(iy+(trk_RomPattRead+2)),a
		ld	e,(iy+trk_Cach)
		ld	d,(iy+(trk_Cach+1))
		ld	(iy+trk_Read),e
		ld	(iy+(trk_Read+1)),d
		ld	c,MAX_RCACH
		ld	(iy+trk_cachHalf),0
		ld	(iy+trk_rowPause),0
		jp	readRom		; ** ROM access **

; ----------------------------------------
; **JUMP ONLY**
.track_end:
		rst	8
		ld	(iy+trk_Status),-1	; Disable track slot
		ld	(iy+trk_SeqId),-1
		ret

; ----------------------------------------
; Track refill
; ----------------------------------------

.effect_fill:
		res	5,(iy+trk_Status)	; Reset refill-from-effect flag
		jp	.set_track

; ----------------------------------------
; Track Start/Reset
;
; iy - Track buffer
; ----------------------------------------

.first_fill:
		res	6,(iy+trk_Status)	; Clear FILL flag
		call	track_out
		ld	(iy+trk_TickTmr),1	; Reset tick timer
		ld	a,(iy+trk_SetBlk)	; Make start block as current block
		rst	8
		ld 	(iy+trk_currBlk),a	; block
		ld	a,(iy+trk_SeqId)
		cp	-1			; Sequence -1?
		ret	z
		add	a,a
		add	a,a
		ld	d,0
		ld	e,a
		ld	hl,gemaMstrListPos
		inc	hl
		ld	a,(hl)			; $00xx0000
		inc	hl
		ld	c,(hl)			; $0000xx00
		inc	hl
		ld	l,(hl)			; $000000xx
		rst	8
		ld	h,c
		add	hl,de
		adc	a,0
		ld	de,trkInfoCach
		push	de
		ld	bc,4
		call	readRom			; *** ROM ACCESS ***
		pop	hl
		ld	a,(hl)
		inc	hl
		bit	7,a
		jr	z,.no_glbl
		set	0,(iy+trk_Status)	; Enable GLOBAL sub-beats
.no_glbl:
		rst	8
		and	01111111b
		ld	(iy+trk_TickSet),a
		ld	a,(hl)			; Read and temporally
		inc	hl			; grab it's pointers
		ld	c,(hl)
		inc	hl
		ld	l,(hl)
		ld	h,c
		ld	de,headerOut
		ld	c,0Eh
		call	readRom		; ** ROM access **

	; headerOut:
	; dc.w numof_chnls
	; dc.l .blk,.pat,.ins
	; *** READING BACKWARDS
		ld	ix,headerOut_e-1	; Read temp header BACKWARDS
		rst	20h
		call	.grab_rhead		; Instrument data
		ld	(iy+trk_RomInst),l
		ld	(iy+(trk_RomInst+1)),h
		ld	(iy+(trk_RomInst+2)),b
		call	.grab_rhead		; Pattern heads
		ld	(iy+trk_RomPatt),l	; Save ROM patt base
		ld	(iy+(trk_RomPatt+1)),h
		ld	(iy+(trk_RomPatt+2)),b
		ld	(iy+trk_BankHeads),80h	; Reset pattern banking
		call	.grab_rhead		; Block data
		ld	(iy+trk_RomBlks),l	; Save ROM patt base
		ld	(iy+(trk_RomBlks+1)),h
		ld	(iy+(trk_RomBlks+2)),b
		ld	(iy+trk_BankBlk),80h	; Reset pattern banking
		ld	a,(ix)			; dc.w numof_chnls
		ld	(iy+trk_MaxChnl),a
		rst	8
		jp	.set_track

; Read 68K pointer:
; hl - 00xxxx
;  b - xx0000
.grab_rhead:
		ld	l,(ix)
		dec	ix
		ld	h,(ix)
		rst	8
		dec	ix
		ld	b,(ix)
		dec	ix
; 		ld	c,(ix)
		dec	ix
		ret

; ----------------------------------------
; Reset tracker channels
;
; iy - Track buffer
;
; Breaks:
; b ,de,hl,ix
; ----------------------------------------

track_out:
		push	iy
		pop	hl
		ld	ix,trkChnls
		rst	8
		ld	de,trk_ChnIndx
		add	hl,de
		ld	a,(iy+trk_MaxChnl)
		or	a
		jr	nz,.valid
		ld	a,MAX_TRKINDX		; If zero, Read ALL channels
.valid:
		ld	b,a
.indx_del:
		ld	a,(hl)
		or	a
		jr	z,.nothin
		rst	8
		push	ix
		and	00011111b
		add	a,a
		add	a,a
		add	a,a
		ld	e,a
		rst	8
		add	ix,de
		xor	a
		ld	(ix+chnl_Note),-2
		ld	(ix+chnl_Flags),1
		ld	(ix+chnl_Vol),64
		ld	(ix+chnl_EffId),a
		ld	(ix+chnl_EffArg),a
		rst	8
		ld	(ix+chnl_Ins),a
		ld	(ix+chnl_Type),a
		pop	ix
		ld	(hl),a
		nop
.nothin:
		inc	hl
		djnz	.indx_del
		ld	a,1
		ld	(marsUpd),a
		ld	(mcdUpd),a
		ret

; ============================================================
; --------------------------------------------------------
; Process track channels to the sound chips
; --------------------------------------------------------

set_chips:
		rst	8
		call	get_tick
		ld	iy,trkBuff_0		; ** MANUAL BUFFERS
		call	tblbuff_read
		ld	iy,trkBuff_1
		call	tblbuff_read
		rst	8
		ld	iy,trkBuff_2
		call	tblbuff_read
		call	get_tick
proc_chips:
		rst	20h
		ld	iy,tblPSGN		; PSG Noise
		call	dtbl_singl
		ld	iy,tblPSG		; PSG Squares
		call	dtbl_multi
		call	get_tick
		rst	8
		ld	iy,tblFM		; FM/FM3/DAC
		call	dtbl_multi
		ld	iy,tblPCM		; SEGA CD PCM
		call	dtbl_multi
		rst	8
		ld	iy,tblPWM		; 32X PWM
		jp	dtbl_multi

; ----------------------------------------
; Read current track
;
; iy - Buffer
tblbuff_read:
		rst	20h			; Refill wave here
		call	get_tick
		rst	8
		ld	b,(iy+trk_Status)	; bit7: Track active?
		bit	7,b
		ret	z
		ld	a,b			; trk_Status == -1?
		cp	-1
		jp	nz,.track_cont
		call	track_out
		ld	(iy+trk_Status),0
.track_cont:
		push	iy
		pop	hl
		rst	8
		ld	ix,trkChnls
		ld	de,trk_ChnIndx
		add	hl,de
		ld	a,(iy+trk_MaxChnl)
		or	a
		jr	nz,.valid
		ld	a,MAX_TRKINDX		; If zero, Read ALL channels
.valid:
		rst	8
		ld	b,a
.next_indx:
		ld	a,(hl)			; Read index
		or	a
		jr	nz,.has_indx		; If non-zero: valid
		push	bc			; ** wave sync
; 		ld	b,4
; 		djnz	$
		pop	bc			; **
		rst	8
		jr	.no_indx
.has_indx:
		and	00011111b
		add	a,a
		add	a,a
		add	a,a
		rst	8
		ld	d,0
		ld	e,a
		push	bc
		push	hl
		push	ix
		add	ix,de
		ld	a,(ix)			; Read 0000evin
		and	00001111b
		call	nz,.do_chip		; Call if non-zero
		rst	8
		pop	ix
		pop	hl
		pop	bc
.no_indx:
		inc	hl
		djnz	.next_indx
		res	3,(iy+trk_Status)	; RESET Volume update bit
		ret

; ----------------------------------------
; iy - Track buffer
; ix - Current channel

.do_chip:
		ld	a,(ix+chnl_Ins)		; Check intrument type FIRST
		or	a
		ret	z			; If 0 == stop
		dec	a			; inst-1
		and	01111111b
		ld	hl,instListOut		; hl - Temporal storage for instrument
		push	hl
		rst	8
		rlca
		rlca
		rlca
		ld	b,a
		and	11111000b
		ld	c,a
		ld	a,b
		xor	a
		and	00000011b
		rst	8
		ld	b,a
		ex	hl,de
		ld	l,(iy+trk_RomInst)
		ld	h,(iy+(trk_RomInst+1))
		ld	a,(iy+(trk_RomInst+2))
		add	hl,bc
		adc	a,0
		ld	bc,8			; 8 bytes
		call	readRom		; ** ROM access **
		pop	hl
		push	hl			; <-- save hl
		call	.grab_link
		pop	de			; --> recover as de
	; hl - current table
	; de - instrument data
		cp	-1			; Found any link?
		ret	z
		inc	hl			; MANUAL SETTING ztbl_MasterVol
		inc	hl
		inc	hl
		inc	hl
		ld	a,(iy+trk_VolMaster)
		ld	(hl),a
		ld	bc,ztbl_InstCach-4	; Move to instr data
		add	hl,bc
		ex	hl,de			; <-- swap for ldir
		ld	bc,8
		ldir				; COPYPASTE instr data from temporal
		ret

; ----------------------------------------
; Search for a linked channel on the
; chip table
;
; Input:
; iy - Track buffer
; ix - Current channel
; hl - Intrument data
;
; Returns:
; hl | Channel table to use
;  a | Return value:
;       0 | Found
;      -1 | Not found
; ----------------------------------------

.grab_link:
		ld	a,(hl)			; Check INSTRUMENT type
		and	11110000b		; Filter bits
		ld	e,a			; e - NEW chip
		ld	a,(ix+chnl_Chip)	; a - CURRENT chip in this channel
		and	11110000b
		jr	z,.new_chip		; If 0: It's a NEW chip
		cp 	e			; CURRENT chip is same as NEW?
		jr	z,.same_link		; If yes, check linked channel.
		rst	8
		ld	d,a			; d - Chip to silence
		push	de
		call	.srch_link		; Search OLD link
		pop	de
		cp	-1
		jr	z,.dont_res
		call	tblz_clear
.dont_res:
		rst	8
		jr	.new_chip
.same_link:
		call	.srch_link		; Search link
		cp	-1
		ret	nz
		ld	e,(ix+chnl_Chip)
		rst	8
		jr	.new_chip

; ----------------------------------------
; ** RELINK **
; a - Chip to search for

.srch_link:
		call	.pick_tbl		; Pick chip table in hl
		push	ix			; Copy ix to bc for checking
		pop	bc
		or	a			; Single table?
		jp	m,.singl_link
.srch_lloop:
		ld	a,(hl)			; Read Table's LSB
		cp	-1			; If -1 (EOL) also return -1
		jr	z,.refill
		cp	c			; Same link LSB?
		jr	nz,.invldl
		inc	hl
		rst	8
		ld	a,(hl)
		dec	hl
		cp	b			; Same link MSB?
		jr	z,.reroll
.invldl:
		push	de
		ld	de,MAX_TBLSIZE
		add	hl,de
		pop	de
		jr	.srch_lloop

; ----------------------
; PSGN/FM3/FM6
.singl_link:
		inc	hl			; Read MSB first
		ld	a,(hl)
		dec	hl
		rst	8
		cp	b			; MSB match?
		jr	nz,.refill
		ld	a,(hl)			; Read LSB
		cp	c
		jr	nz,.refill
		jp	.rnot_psg

; ----------------------------------------
; *** Special re-roll check for
; listed tables ***

.reroll:
		push	hl
		ld	bc,ztbl_Chip	; <-- fake iy+ztbl_Chip
		add	hl,bc
		rst	8
		ld	c,(hl)		; c - ID
		pop	hl
		ld	a,e
		cp	80h		; PSG?
		jr	nz,.rnot_psg
	; Special PSG3/PSGN check
		ld	a,(psgHatMode)	; Tone3 enabled?
		and	011b
		cp	011b
		jr	nz,.rnot_psg
		ld	a,c		; Channel 2? (PSG3)
		cp	2
		jr	nz,.rnot_psg
		rst	8
		push	de
		ld	d,80h		; Force silence
		call	tblz_clear
		pop	de
.refill:
		jr	.set_asfull
.rnot_psg:
		xor	a
		ret

; ----------------------------------------
; *** NEW CHIP ***
; e - Chip to set

.new_chip:
		ld	a,e			; Read NEW chip
		or	a			; If non-minus, exit.
		jp	p,.set_asfull
		call	.pick_tbl
		rst	8
		ld	c,(iy+trk_Priority)	; c - OUR priority level
		or	a
		jp	m,.singl_free
		push	hl			; Backup START table
; PASS 1
.srch_free:
		ld	a,(hl)			; Read LSB
		cp	-1			; If -1, return -1
		jr	z,.pass_2
		inc	hl
		ld	b,(hl)			; Read MSB
		dec	hl
		or	b
		jr	z,.new_link_z
		call	.nextsrch_tbl
		jr	.srch_free

; PASS 2
; Rewrite mode
.pass_2:
		pop	hl
.next_prio:
		ld	a,(hl)			; Read LSB
		cp	-1			; If -1, return -1
		ret	z
		inc	hl
		inc	hl
		ld	a,(hl)			; Read priority
		dec	hl
		dec	hl
		or	a			; Failsafe zero priority overwrite
		jr	z,.new_link_o
		cp	c
		jr	c,.new_link_o		; PRIORITY
; 		jr	z,.new_link_o
		rst	8
		call	.nextsrch_tbl
		jr	.next_prio
.nextsrch_tbl:
		push	de
		ld	de,MAX_TBLSIZE
		add	hl,de
		pop	de
		ret
.new_link_z:
		inc	sp			; skip backup
		inc	sp
		jr	.new_link

; OVERWRITE link
.new_link_o:
		push	hl
		ld	d,(ix+chnl_Chip)
		call	tblz_clear
		pop	hl
; NEW link
.new_link:
		rst	8
		inc	hl
		inc	hl
; hl+2
.l_hiprio:
		ld	(ix+chnl_Chip),e
		push	ix
		pop	de
		ld	(hl),c		; Write priority
		dec	hl
		rst	8
		ld 	(hl),d		; MSB
		dec	hl
		ld	(hl),e		; LSB
		xor	a		; Return OK
		ret

; Single slot
; c - priority
; e - chip
.singl_free:
		ld	b,(hl)
		inc	hl
		ld	a,(hl)
		inc	hl
		or	b
		jr	z,.l_hiprio
		rst	8
		ld	a,(hl)
		or	a
		jr	z,.l_hiprio
		cp	c
		jr	c,.l_hiprio		; PRIORITY
; 		jr	z,.l_hiprio
		rst	8
.set_asfull:
		ld	a,-1			; Return -1
		ret

; Pick chip table
; In:
;  a - ID
;
; Out:
;  a - Special bit + ID
;
; hl - Table
.pick_tbl:
		push	de
		rrca
		rrca
		rrca
		rrca
		and	00000111b
		add	a,a
		ld	hl,tblList
		push	hl
		ld	d,0
		ld	e,a
		add	hl,de
		ld	e,(hl)
		inc	hl
		ld	a,(hl)
		ld	d,a
		and	10000000b
		res	7,d
		pop	hl
		add	hl,de
		pop	de
		ret

; ============================================
; ----------------------------------------
; Process chip using it's table
;
; iy - table to read
; ----------------------------------------

dtbl_multi:
		ld	a,(iy)
		cp	-1
		ret	z
		call	dtbl_singl
		rst	8
		ld	de,MAX_TBLSIZE
		add	iy,de
		nop
		nop
		rst	8
		nop
		jr	dtbl_multi
dtbl_singl:
		ld	e,(iy)			; Read link
		ld	d,(iy+1)
		ld	a,d			; If no-zero, active
		or	e
		jr	nz,.linked
		ld	a,(iy+ztbl_Priority)	; Silence request?
		or	a
		ret	p			; Return if not.
		rst	8
		ld	(iy+ztbl_Priority),0	; Reset request on memory

; ----------------------------------------
; chip-silence request
; iy - Table

		ld	b,0
		ld	c,(iy+ztbl_Chip)
		and	11110000b
		cp	80h
		jr	z,.siln_psg
		cp	90h
		jr	z,.siln_psg_n
		cp	0A0h
		jr	z,.siln_fm
		cp	0B0h
		jr	z,.siln_fm
		rst	8
		cp	0C0h
		jr	z,.siln_dac
		cp	0D0h
		jr	z,.siln_pcm
		cp	0E0h
		jr	z,.siln_pwm
		ret
.siln_psg_n:
		xor	a
		ld	(psgHatMode),a
.siln_psg:
		rst	8
		ld	hl,psgcom
		jr	.rcyl_com

; --------------------------------

.siln_pcm:
		ld	a,1
		ld	(mcdUpd),a
		rst	8
		ld	hl,pcmcom+32
		add	hl,bc
		ld	(hl),-1
		ld	hl,pcmcom
		jr	.rcyl_com
.siln_pwm:
		ld	a,1
		ld	(marsUpd),a
		rst	8
		ld	hl,pwmcom
.rcyl_com:
		add	hl,bc
		ld	(hl),100b	; key-cut
		ret

; --------------------------------

.siln_dac:
		call	dac_off
.siln_fm:
		call	.fm_tloff
		jp	.fm_keyoff

; ----------------------------------------
; Process channel now
; iy - Table
; ix - Tracker channel
.linked:
		ld	a,(de)		; ** chnl_Flags
		ld	b,a		; b - flags to check
		and	00001111b	; evin flags?
		ret	z
		ld	a,b
		and	11110000b	; Keep OTHER bits
		ld	(de),a		; ** clear chnl_Flags
		push	iy		; table+10h instrment data
		push	de
		pop	ix
		pop	hl
		ld	de,ztbl_InstCach	; Go to stored inst data
		add	hl,de
	; --------------------------------
	;  b - Flags LR00evin (Eff|Vol|Ins|Note)
	; iy - Our chip table
	; ix - Track channel
	; hl - Intrument data
		ld	a,b		; Note and/or Inst?
		and	0011b
		call	nz,.reset_effc	; Reset effects
		bit	2,b		; Volume
		call	nz,.volu
		bit	0,b		; Note
		call	nz,.note
		bit	1,b		; Intrument
		call	nz,.inst
		rst	8
		bit	3,b		; Effect
		call	nz,.effc
		ld	a,(hl)		; Read INS type
		and	01110000b	; Filter bits
		rrca
		rrca
		rrca
		rst	8
		ld	d,0
		ld	e,a
		ld	hl,.mk_list
		add	hl,de
		ld	a,(hl)
		inc	hl
		ld	h,(hl)
		ld	l,a
		jp	(hl)
.reset_effc:
		ld	(iy+ztbl_PitchBend),0
		ld	(iy+ztbl_VolSlide),0
		ld	(iy+ztbl_Volume),0
		ret

; --------------------------------
.mk_list:
		dw .mk_psg
		dw .mk_psg
		dw .mk_fm
		dw .mk_fm_sp
		dw .mk_dac
		dw .mk_pcm
		dw .mk_pwm

; --------------------------------
; PSG and PSGN
; --------------------------------

.mk_psg:
		ld	c,(ix+chnl_Note)	; c - Note
		push	ix			; * Save ix
		rst	8
		ld	ix,psgcom		; ix - psgcom
		ld	d,0
		ld	e,(iy+ztbl_Chip)
		add	ix,de			; Get com index
		ld	a,b			; New NOTE and/or INS?
		and	0011b
		jr	z,.psgc_proc		; Process only
		ld	a,c			; c - Note
		or	a
		ret	z
		cp	-2			; Key cut?
		jr	z,.kycut_psg
		cp	-1			; Key off?
		jr	z,.kyoff_psg
		ld	(ix+COM),001b		; Set Key ON
		ld	a,e			; a - Channel 0-3
		ld	de,0			; Clear de
		cp	3			; NOISE channel?
		jr	nz,.not_ns
		ld	a,(psgHatMode)		; Tone 3?
		and	011b
		cp	011b
		jp	nz,.psg_keyon		; Normal
		ld	de,12*2			; Add octave to freq
.not_ns:
		call	.psg_getfreq
		jr	.psgc_keyon

; --------------------------------
; -1
.kyoff_psgn:
		call	.kypsgn_hatoff
.kyoff_psg:
		ld	(ix),010b		; Write key off
		pop	ix			; * Restore ix
		jp	.chnl_ulnkoff

; --------------------------------
; -2
.kycut_psgn:
		call	.kypsgn_hatoff
.kycut_psg:
		ld	(ix),100b		; Write key cut
		pop	ix			; * Restore ix
		jp	.chnl_ulnkcut


.kypsgn_hatoff:
		ld	a,000b
		ld	(psgHatMode),a		; ** GLOBAL SETTING
		rst	8
		ret

; --------------------------------
; hl - current freq
; ix - psgcom
; b - flags

.psgc_proc:
		rst	8
		ld	l,(ix+DTL)		; Read saved freq
		ld	h,(ix+DTH)
.psgc_keyon:
		ld	a,(iy+ztbl_PitchBend)	; pitchbend
		or	a
		jp	z,.no_req
		neg	a
		ld	e,a
		ld	c,a
		xor	a
		ld	(iy+ztbl_PitchBend),a
		ccf
		sla	c
		sbc	a,a
		ld	d,a
		add	hl,de
.no_req:
		ld	(ix+DTL),l
		ld	(ix+DTH),h
.psg_keyon:
		ld	a,(iy+ztbl_VolSlide)
		add	a,a
		ld	e,a
		ld	a,(iy+ztbl_Volume)	; Set current Volume
		sub	a,e
		sub	a,(iy+ztbl_MasterVol)	; + MASTER vol
		neg	a
		rst	8
		add	a,a
		add	a,a
		jr	nc,.vmuch
		ld	a,-1
.vmuch:
		ld	(ix+MVOL),a
		pop	ix			; * Restore ix
		ret

; --------------------------------
; de - increment

.psg_getfreq:
		ld	hl,psgFreq_List-(36*2)
		add	hl,de
		ld	e,(iy+ztbl_FreqIndx)	; de - note*2
		add	hl,de
		ld	a,(hl)
		inc	hl
		ld	h,(hl)
		ld	l,a
		ld	a,(palMode)
		or	a
		jr	z,.fnot_pal
		dec	hl
.fnot_pal:
		ret

; --------------------------------
; FM
; --------------------------------

.mk_fm:
		ld	c,(iy+ztbl_Chip)	; c - YM key
		ld	a,b			; New NOTE and/or INS?
		and	0011b
		jr	z,.mkfm_proc		; Process only
		ld	a,(ix+chnl_Note)	; Get IT note
		or	a
		ret	z
		cp	-2			; Key-cut?
		jp	z,.fm_cut
		cp	-1			; Key-off?
		jp	z,.fm_off
		rst	8
		ld	a,c
		cp	6			; Check FM6
		jr	nz,.not_dac
		call	dac_off			; Turn DAC off
		jr	.not_dspc
.not_dac:
		cp	2			; Check FM3
		jr	nz,.not_dspc
		ld	a,(fmSpecial)		; FM3 Special active?
		or	a
		jr	z,.not_dspc
		ld	a,0
		ld	(fmSpecial),a
		ld	de,2700h		; Turn FM3 Special OFF
		call	fm_send_1
.not_dspc:
		call	.fm_keyoff		; Turn FM keys off
.mkfm_proc:
		call	.mkfm_freq
		jp	.mkfm_set		; Volume

; --------------------------------
; Read FM freq

.mkfm_freq:
		push	bc
		ld	a,(iy+ztbl_FreqIndx)
		ld	b,a
		and	00011111b
		ld	e,a
		ld	d,0
		ld	hl,fmFreq_List
		add	hl,de
		ld	a,(hl)
		rst	8
		inc	hl
		ld	h,(hl)
		ld	l,a			; hl - Current FM freq
		ld	a,(palMode)		; PAL speed check
		or	a
		jr	z,.not_pal
		ld	de,4			; freq + 4
		add	hl,de
.not_pal:
		ld	a,b
		and	11100000b
		rrca
		rrca
		or	h
		ld	h,a
		ld	e,(iy+ztbl_PitchBend)	; Get pitchbend effect
		rst	8
		xor	a			; clear high
		ccf				; clear carry
		sla	e			; pitchbend << 2
		nop				; **
		sbc	a,a			; get carry MSB
		ld	d,a
		add	hl,de			; Pitchbend the freq
		call	.fm_setfreq
		pop	bc
.nofm_note:
		ret

; --------------------------------
; FM3 special
; --------------------------------

.mk_fm_sp:
		ld	c,010b			; ** FM3 special ID
		ld	a,b			; New NOTE and/or INS?
		and	0011b
		jp	z,.mkfm_set		; Process only
		ld	a,(ix+chnl_Note)
		or	a
		ret	z
		cp	-2
		jp	z,.fm_cut
		cp	-1
		jp	z,.fm_off
		call	.fm_keyoff
		rst	8
		ld	hl,fmcach_3		; DIRECT point to FM3 data
		ld	de,20h			; point to regs
		add	hl,de
		push	ix
		ld	ix,.this_regs
		ld	b,8
.wr_spc:
		ld	d,(ix)			; Manually write the FM3 freqs
		ld	e,(hl)
		call	fm_send_1
		rst	8
		inc	hl
		inc	ix
		djnz	.wr_spc
		pop	ix
		ld	de,2740h		; Turn FM3 Special mode
		call	fm_send_1
		ld	a,1
		ld	(fmSpecial),a
		jp	.mkfm_set
.this_regs:
		db 0ADh,0A9h
		db 0ACh,0A8h
		db 0AEh,0AAh
		db 0A6h,0A2h

; ----------------------------------------

.fm_off:
		call	.fm_keyoff
		jp	.chnl_ulnkoff
.fm_cut:
		ld	a,(iy+ztbl_Chip)
		add	a,a
		add	a,a
		ld	hl,fmlist_rsave
		ld	d,0
		ld	e,a
		add	hl,de
		ld	(hl),0
		inc	hl
		ld	(hl),0
		inc	hl
		ld	(hl),0
		call	.fm_keyoff
		call	.fm_tloff
		jp	.chnl_ulnkcut

; ----------------------------------------
; iy - current FM table

.fm_keyoff:
		ld	d,28h
		ld	e,(iy+ztbl_Chip)
		jp	fm_send_1

.fm_tloff:
		ld	b,4
		ld	c,(iy+ztbl_Chip)
		ld	a,c
		and	011b
		or	40h		; TL regs
		ld	e,7Fh
.tl_down:
		ld	d,a
		; e - 7Fh
		call	fm_autoreg
		rst	8
		ld	a,d
		add	a,4
		djnz	.tl_down
		ret

; --------------------------------

; c - KeyID
.fm_setfreq:
		ld	a,c
		and	011b
		or	0A4h
		ld	d,a
		ld	e,h
		rst	8
		call	fm_autoreg
		ld	a,c
		and	011b
		or	0A0h
		ld	d,a
		ld	e,l
		call	fm_autoreg
		rst	8
		ret

; ----------------------------------------

.mkfm_set:
		ld	a,(iy+ztbl_Chip)
		call	.get_fmcach

		push	hl
		ld	de,1Ch			; Go to last regs
		add	hl,de
		ld	b,(hl)			; c - 0B0h from here
		pop	hl
		rst	8
		ld	c,(iy+ztbl_Chip)
		ld	a,c
		and	011b
		or	30h			; Start at reg 30h
		ld	d,a

	; hl - reg data
	;  b - 0B0h algorithm copy
	;  c - current FM channel 0-6
	;  d - Starting FM reg
		call	.mkfm_wregs		; 30h+
		call	.mkfm_tlvol		; 40h+
		call	.mkfm_wregs		; 50h+
		call	.mkfm_wregs		; 60h+
		call	.mkfm_wregs		; 70h+
		call	.mkfm_wregs		; 80h+
		call	.mkfm_wregs		; 90h+

; 		ld	a,(hl)			; 0B0h algorithm
		ld	a,b
		inc	hl
		ld	e,a
		ld	a,c
		and	011b
		or	0B0h
		ld	d,a
		call	fm_autoreg		; Write algorithm
		rst	8
		ld	a,(ix+chnl_Flags)	; Read panning bits
		cpl				; REVERSE bits
		and	00110000b
		rlca				; << 2
		rlca
		ld	e,a			; save as e
		ld	a,(hl)			; 0B4h %00aa0ppp
		inc	hl
		and	00111111b
		or	e			; Merge panning
		ld	e,a
		ld	a,c
		rst	8
		and	011b
		or	0B4h
		ld	d,a
		call	fm_autoreg
		ld	a,(hl)			; 022h
		inc	hl
		rst	8
		bit	3,a			; Intrument wants LFO?
		jr	z,.no_lfo
		ld	e,a
		ld	d,22h
		call	fm_send_1
.no_lfo:
		rst	8
		ld	a,(hl)			; 028h
		and	11110000b
		or	c			; Merge FM channel
		ld	e,a
		ld	d,28h
		jp	fm_send_1		; Set keys

; ----------------------------------------

.mkfm_wregs:
		rst	8
		ld	e,(hl)
		inc	hl
		call	fm_autoreg
		inc	d
		inc	d
		inc	d
		inc	d
		rst	8
		ld	e,(hl)
		inc	hl
		call	fm_autoreg
		inc	d
		inc	d
		inc	d
		inc	d
		rst	8
		ld	e,(hl)
		inc	hl
		call	fm_autoreg
		inc	d
		inc	d
		inc	d
		inc	d
		rst	8
		ld	e,(hl)
		inc	hl
		call	fm_autoreg
		inc	d
		inc	d
		inc	d
		inc	d
		rst	8
		ret

; ----------------------------------------
; Write 40+ TL w/volume

; hl - TL reg data
; b - current 0B0h
; d - 40h+

.mkfm_tlvol:
		ld	a,b			; Read 0B0h copy
		push	bc
		push	hl
		ld	hl,.fm_cindx		; hl - jump carry list
		and	0111b
		ld	b,0
		ld	c,a
		add	hl,bc
		rst	8
		ld	a,(iy+ztbl_Volume)	; Read current Volume
		sub	a,(iy+ztbl_VolSlide)
		sub	a,(iy+ztbl_MasterVol)	; + MASTER vol
		ld	c,a			; c - Current Volume
		ld	b,(hl)			; b - Current jump-carry byte
		pop	hl
		rrc	b			; OP1
		call	c,.write_tl
		call	nc,.write_ntl
		inc	hl
		inc	d
		inc	d
		rst	8
		inc	d
		inc	d
		rrc	b			; OP2
		call	c,.write_tl
		call	nc,.write_ntl
		inc	hl
		inc	d
		inc	d
		inc	d
		inc	d
		rrc	b			; OP3
		call	c,.write_tl
		call	nc,.write_ntl
		inc	hl
		rst	8
		inc	d
		inc	d
		inc	d
		inc	d
		rrc	b			; OP4
		call	c,.write_tl
		call	nc,.write_ntl
		inc	hl
		inc	d
		inc	d
		inc	d
		inc	d
		rst	8
		pop	bc
		ret

; --------------------------------

.write_tl:
		ld	a,(hl)
		sub	a,c			; reg - volume
		jp	p,.keep_tlmx
		ld	a,7Fh			; <-- maximum TL
.keep_tlmx:
		push	bc
		ld	e,a
		ld	c,(iy+ztbl_Chip)
		call	fm_autoreg
		rst	8
		pop	bc
		ret

.write_ntl:
		push	bc
		ld	e,(hl)
		ld	c,(iy+ztbl_Chip)
		call	fm_autoreg
		rst	8
		pop	bc
		ret

; --------------------------------
; Jump carry list
.fm_cindx:
		db 1000b
		db 1000b
		db 1000b
		db 1000b
		db 1100b
		db 1110b
		db 1110b
		db 1111b

; --------------------------------
; Input:
; a - FM id (0-2,4-6)
;
; Ouput:
; hl - instrument data
;
; Uses:
; de
; --------------------------------

.get_fmcach:
		ld	hl,fmcach_list
		and	0111b
		ld	d,0
		rst	8
		add	a,a
		ld	e,a
		add	hl,de
		ld	a,(hl)
		inc	hl
		ld	h,(hl)
		ld	l,a
		ret

; --------------------------------
; DAC
; --------------------------------

.mk_dac:
		ld	a,b
		and	0011b
		jr	z,.dac_proc
		ld	a,(ix+chnl_Note)
		or	a
		ret	z
		cp	-2
		jp	z,.dac_cut
		cp	-1
		jp	z,.dac_off
		call	.dac_proc
		jp	dac_play
.dac_cut:
		call	dac_off
		jp	.chnl_ulnkoff
.dac_off:
		call	dac_off
		jp	.chnl_ulnkcut
.dac_proc:
		ld	d,0			; Freq index
		ld	e,(iy+ztbl_FreqIndx)
		ld	hl,wavFreq_List-(2*36)
		add	hl,de
		ld	a,(hl)
		inc	hl
		ld	h,(hl)
		ld	l,a
		ld	e,(iy+ztbl_PitchBend)	; pitchbend
		rst	8
		xor	a			; Clear high
		ccf				; Clear carry
		sla	e			; << 1
		sbc	a,a			; Get carry MSB
		ld	d,a
		add	hl,de
		ld	(wave_Pitch),hl
		exx				; *
		ld	de,(wave_Pitch)		; *
		exx				; *
		ld	a,(ix+chnl_Flags)	; Read panning
		cpl				; REVERSE bits
		and	00110000b
		rlca
		rlca
		rst	8
		ld	e,a
		ld	d,0B6h			; Channel 6 panning
		jp	fm_send_2

; --------------------------------
; PCM
; --------------------------------

.mk_pcm:
	if MCD|MARSCD
		ld	d,0
		ld	e,(iy+ztbl_Chip)	; e - Channel ID
		ld	c,(ix+chnl_Note)	; c - Current note
		push	ix
		ld	ix,pcmcom
		add	ix,de
		ld	e,00001000b
		rst	8
		ld	a,b
		and	0011b			; Note and Ins?
		jr	z,.mkpcm_wrton
		ld	a,c
		or	a
		ret	z
		cp	-2
		jp	z,.pcm_cut
		cp	-1
		jp	z,.pcm_off
		jr	.pcm_note
.pcm_note:
; 		ld	(ix+32),-1
		ld	e,00000001b		; KeyON request
.mkpcm_wrton:
		ld	(ix),e			; Write key-on bit
		call	.readfreq_pcm
		ld	de,8			; Go to Pitch
		add	ix,de
		ld	(ix),h			; Set pitch
		add	ix,de
		ld	(ix),l
		add	ix,de			; Go to volume
	; PCM volume
		ld	c,-1
		ld	a,(iy+ztbl_MasterVol)
		cp	40h
		jr	z,.vpcm_siln
		jr	nc,.vpcm_siln
		or	a
		jp	m,.vpcm_siln
		add	a,a
		ld	b,a
		ld	a,(iy+ztbl_Volume)	; Read current Volume
		sub	a,(iy+ztbl_VolSlide)
		add	a,a			; * 2
		ccf
		sbc	a,b			; + MASTER vol
		add	a,a			; *2
		jr	c,.vpcm_carry
.vpcm_siln:
		xor	a
		jr	.vpcm_zero
.vpcm_carry:
		add	a,c
.vpcm_zero:
		ld	(ix),a
		ld	a,1
		ld	(mcdUpd),a
		pop	ix
		ret

; --------------------------------
; -1
.pcm_off:
		rst	8
		ld	(ix),0010b
		jr	.pcm_setcoff
; -2
.pcm_cut:
		rst	8
		ld	(ix),0100b
.pcm_setcoff:
		ld	a,1
		ld	(mcdUpd),a
		pop	ix
		jp	.chnl_ulnkoff
	else
		ret
	endif

; --------------------------------
; PWM
; --------------------------------

.mk_pwm:
	if MARS|MARSCD
		ld	l,(ix+chnl_Note)
		ld	c,(ix+chnl_Flags)	; c - Panning bits
		ld	d,0
		ld	e,(iy+ztbl_Chip)	; e - Channel ID
		push	ix
		ld	ix,pwmcom
		add	ix,de
		rst	8
		ld	a,b
		and	0011b			; Note and Ins?
		jr	z,.pw_effc
		ld	a,l
		or	a
		ret	z
		cp	-2
		jp	z,.pwm_cut
		cp	-1
		jp	z,.pwm_off
		jr	.pw_note
.pw_effc:
		ld	e,00001001b
		jr	.pw_send
.pw_note:
		ld	e,00000001b		; KeyON request
.pw_send:
		ld	(ix),e			; Set command
		call	.readfreq_pwm
	; hl - current freq
		ld	a,c			; Read panning bits
		cpl				; Reverse and filter bits
		and	00110000b
		rst	8
		ld	e,a			; Save panning to e
		ld	a,(iy+ztbl_MasterVol)
		cp	40h
		jr	z,.vpwm_siln
		jr	nc,.vpwm_siln
		ld	c,a
		ld	a,(iy+ztbl_Volume)	; Read current volume
		sub	a,(iy+ztbl_VolSlide)
		sub	a,c			; + MASTER vol
		jr	.vpwm_much
.vpwm_siln:
		ld	a,-40h
.vpwm_much:
		neg	a
		and	11111100b
		or	h		; Merge MSB freq
		ld	bc,8
		add	ix,bc
		ld	(ix),a
		add	ix,bc
		ld	(ix),l
		add	ix,bc
		rst	8
		ld	a,(ix)
		and	11001111b
		or	e		; Set panning bits
		ld	(ix),a
		ld	a,1
		ld	(marsUpd),a
		pop	ix
		ret

; --------------------------------
; -1
.pwm_off:
		rst	8
		ld	(ix),010b
		jr	.pwm_setcoff
; -2
.pwm_cut:
		rst	8
		ld	(ix),100b
.pwm_setcoff:
		ld	a,1
		ld	(marsUpd),a
		pop	ix
		jp	.chnl_ulnkoff
	else
		ret
	endif

; --------------------------------
; SHARED routine

.readfreq_pcm:
		ld	hl,wavFreq_CdPcm-(2*36)	; <-- one octave lower
		jr	.set_wavfreq
.readfreq_pwm:
		ld	hl,wavFreq_List-(2*36)
.set_wavfreq:
		ld	d,0			; Freq index
		ld	e,(iy+ztbl_FreqIndx)
		add	hl,de
		ld	a,(hl)
		inc	hl
		ld	h,(hl)
		ld	l,a
		ld	e,(iy+ztbl_PitchBend)	; pitchbend
		rst	8
		xor	a			; Clear high
		ccf				; Clear carry
		sla	e			; Get carry MSB
		sbc	a,a			; -1 if carry is set
		ld	d,a
		add	hl,de
		ret

; ----------------------------------------
; NEW effect
; ----------------------------------------

.effc:
		ld	e,(ix+chnl_EffArg)	; e - effect data
		ld	a,(ix+chnl_EffId)	; d - effect id
		ld	d,a
		rst	8
		cp	4			; Effect D?
		jr	z,.effc_D
		cp	5			; Effect E?
		jr	z,.effc_E
		cp	6			; Effect F?
		jr	z,.effc_F
		rst	8
		cp	24			; Effect X?
		jp	z,.effc_X
		ret

; ----------------------------------------
; Effect D: Volume slide up/down
;
; 00h - DON'T USE HERE
;       (Original: Keep effect)
; 0xh - Slide down normal
; Fxh - Slide down fine
; xFh - Slide up normal
; x0h - Slide up fine
; ----------------------------------------

.effc_D:
		ld	a,e
		rrca
		rrca
		rrca
		rrca
		and	0Fh
		ld	c,a
	; e - DOWN value: ????dddd
	; c - UP value:   0000uuuu

		ld	a,e
		or	a
		ret	z
		and	0F0h		; 0Xh
		jr	z,.D_down
		cp	0F0h		; FXh
		jr	z,.D_downhf
		ld	a,e
		and	00Fh		; X0h
		jr	z,.D_up
		cp	00Fh		; XFh
		ret	nz
; 		jr	z,.D_uphf
; Go UP
.D_uphf:
		ld	a,c
		jr	.setefU_D
.D_up:
		ld	a,c
		add	a,a
.setefU_D:
		ld	e,a
		ld	a,(iy+ztbl_VolSlide)
		sub	a,e
		jr	.setef_mcD
; Go DOWN
.D_downhf:
		ld	a,e
		and	0Fh
		jr	.setef_D
.D_down:
		ld	a,e
		and	0Fh
		add	a,a
.setef_D:
		ld	e,a
		ld	a,(iy+ztbl_VolSlide)
		add	a,e
; 		jr	.setef_mcD

; Write slide
.setef_mcD:
		ld	(iy+ztbl_VolSlide),a
		ret

; ----------------------------------------
; Effect E
; ----------------------------------------

.effc_E:
		ld	a,e
		and	0F0h
		cp	0F0h
		ret	z
		cp	0E0h
		ret	z
		rst	8
		ld	a,e
		neg	a
		jr	.wrt_EF

; ----------------------------------------
; Effect F
; ----------------------------------------

.effc_F:
		ld	a,e
		and	0F0h
		cp	0F0h
		ret	z
		cp	0E0h
		ret	z
		rst	8
		ld	a,e
.wrt_EF:
		add	a,a
		add	a,a
		ld	(iy+ztbl_PitchBend),a
		ret

; ----------------------------------------
; Effect X
;
; Common panning values:
;  00h LEFT
;  80h MIDDLE
; 0FFh RIGHT
; ----------------------------------------

.effc_X:
		ld	d,0
		ld	a,(hl)
		and	11110000b
		cp	80h		; PSG?
		jr	z,.res_pan
		cp	90h		; PSGN?
		jr	z,.res_pan
		cp	0D0h		; MCD: write separate PAN values
		call	z,.pan_mcd	; <-- CALL, not JP

	; ----------------------------------------
	; Common panning bits: %00LR0000
	; (REVERSE: 0-on 1-off)
		rst	8
		push	hl
		ld	hl,.comn_panlist
		ld	a,e
		rlca
		rlca
		rlca
		and	0111b
; 		ld	d,0
		ld	e,a
		rst	8
		add	hl,de
		ld	d,(hl)
		pop	hl
.res_pan:
		ld	a,(ix+chnl_Flags)	; Save panning
		and	11001111b
		or	d
		ld	(ix+chnl_Flags),a
		ret

	; ----------------------------------------
	; MCD panning
.pan_mcd:
		push	hl
		push	de
		ld	d,0
		ld	hl,.pcm_panlist
		ld	a,e
		and	0F8h
		rrca
		rrca
		rrca
		ld	e,a
		add	hl,de
		ld	a,(hl)
		ld	hl,pcmcom+32
		ld	d,0
		ld	e,(iy+ztbl_Chip)
		add	hl,de
		cpl
		ld	(hl),a
		pop	de
		pop	hl
		ld	a,1
		ld	(mcdUpd),a
		ret

; 0 - ENABLE, 1 - DISABLE
; 00LR0000b
.comn_panlist:
		db 00010000b
		db 00010000b
		db 00010000b
		db 00000000b
		db 00000000b
		db 00100000b
		db 00100000b
		db 00100000b

; REVERSE OUTPUT BITS
; RRRR | LLLL
.pcm_panlist:
		db 0F0h	; 00h
		db 0E0h
		db 0D0h	; 10h
		db 0C0h
		db 0B0h	; 20h
		db 0A0h
		db 090h	; 30h
		db 080h
		db 070h	; 40h
		db 060h
		db 050h	; 50h
		db 040h
		db 030h	; 60h
		db 020h
		db 010h	; 70h
		db 000h
		db 000h ; 80h
		db 001h
		db 002h ; 90h
		db 003h
		db 004h ; A0h
		db 005h
		db 006h ; B0h
		db 007h
		db 008h ; C0h
		db 009h
		db 00Ah ; D0h
		db 00Bh
		db 00Ch ; E0h
		db 00Dh
		db 00Eh ; F0h
		db 00Fh

; ----------------------------------------
; NEW volume
; ----------------------------------------

.volu:
		ld	a,(ix+chnl_Vol)
		sub	a,64
		ld	(iy+ztbl_Volume),a	; BASE volume
		ret

; ----------------------------------------
; NEW instrument
; ----------------------------------------

.inst:
		ld	a,(hl)
		and	11110000b
		cp	080h
		jr	z,.ins_psg
		cp	090h
		jr	z,.ins_psgn
		cp	0A0h
		jr	z,.ins_fm
		rst	8
		cp	0B0h
		jr	z,.ins_fm
		cp	0C0h
		jp	z,.ins_dac
		cp	0D0h
		jp	z,.ins_pcm
		cp	0E0h
		jp	z,.ins_pwm
		rst	8
.invl_ins:
		ret

; ----------------------------------------
; PSG

.ins_psgn:
		ld	a,(hl)		; Grab noise setting
		and	0111b
		ld	(psgHatMode),a	; ** GLOBAL SETTING
.ins_psg:
		rst	8
		push	ix
		push	hl
		inc	hl		; Skip ID
		ld	ix,psgcom	; Read psg control
		ld	e,(iy+ztbl_Chip)
		ld	d,0
		add	ix,de
		ld	a,(hl)
		rst	8
		inc	hl
		ld	a,(hl)
		ld	(ix+ALV),a	; ALV
		inc	hl
		ld	a,(hl)
		ld	(ix+ATK),a	; ATK
		inc	hl
		ld	a,(hl)
		rst	8
		ld	(ix+SLV),a	; SLV
		inc	hl
		ld	a,(hl)
		ld	(ix+DKY),a	; DKY
		inc	hl
		ld	a,(hl)
		ld	(ix+RRT),a	; RRT
		inc	hl
		ld	a,(hl)
		rst	8
		ld	(ix+ARP),a	; ARP
		pop	hl
		pop	ix
		ret

; ----------------------------------------
; FM/FM3

.ins_fm:
		ld	a,(iy+ztbl_Chip)
		and	0111b
		ld	d,0
		add	a,a
		ld	e,a
		push	ix
		push	hl
		push	bc
		ld	ix,fmcach_list
		add	ix,de
		rst	8
		ld	e,(ix)
		inc	ix
		ld	d,(ix)

		ld	ix,fmlist_rsave
		ld	a,(iy+ztbl_Chip)
		add	a,a
		add	a,a
		ld	b,0
		ld	c,a
		add	ix,bc
		inc	hl			; Skip id and pitch
		inc	hl
		ld	b,(hl)
		inc	hl
		ld	a,(hl)
		inc	hl
		ld	l,(hl)
		ld	h,a
	;   ix - last MID and LOW bytes
	;   de - current FM cache
	; b,hl - 24-bit ROM address
		ld	a,(ix+2)
		cp	b
		jr	nz,.new_romdat
		rst	8
		ld	a,(ix+1)
		cp	h
		jr	nz,.new_romdat
		ld	a,(ix)
		cp	l
		jr	z,.same_patch
		rst	8
.new_romdat:
		ld	(ix+2),b
		ld	(ix+1),h
		ld	(ix),l
		ld	a,b
		ld	bc,28h			; <- size
		call	readRom			; *** ROM ACCESS ***
.same_patch:
		pop	bc
		pop	hl
		pop	ix
		ret

; ----------------------------------------

.ins_dac:
		push	hl
		push	bc
		call	dac_off
		ld	a,(hl)
		and	00001111b
		ld	(wave_Flags),a
		rst	8
		inc	hl
		inc	hl
		ld	e,(hl)
		inc	hl
		ld	a,(hl)
		inc	hl
		ld	l,(hl)
		ld	h,a
		push	hl
		ld	a,e
		ld	bc,6		; Skip head
		add	hl,bc
		adc	a,0
		ld	(wave_Start),hl	; Set START point
		ld	(wave_Start+2),a
		pop	hl
		ld	a,e
		ld	de,sampleHead
		ld	bc,6
		push	de
		rst	8
		call	readRom	; *** ROM ACCESS ***
		pop	hl
	; hl - temporal header
		ld	e,(hl)
		inc	hl
		ld	d,(hl)
		inc	hl
		ld	a,(hl)
		inc	hl
		ld	(wave_Len),de	; LEN
		ld	(wave_Len+2),a
		ld	e,(hl)
		inc	hl
		rst	8
		ld	d,(hl)
		inc	hl
		ld	a,(hl)
		inc	hl
		ld	(wave_Loop),de	; LOOP
		ld	(wave_Loop+2),a
		ld	de,2806h	; keys off
		call	fm_send_1
		pop	bc
		pop	hl
; .same_dac:
		ret

; ----------------------------------------

.ins_pcm:
		push	ix
		push	hl
		push	bc
		ld	a,(hl)		; Stereo|Loop bits
		and	00000001b	; Read loop bit
		rrca			; Move to MSB
		rst	8
		inc	hl		; Skip ID and Pitch
		inc	hl
		ld	e,(hl)		; Read 24-bit pointer
		or	e
		ld	e,a
		inc	hl
		ld	a,(hl)
		inc	hl
		ld	l,(hl)
		ld	h,a
	; d    - Loop enable bit
	; e,hl - 24-bit pointer + loop bit
		ld	ix,pcmcom
		ld	b,0
		ld	c,(iy+ztbl_Chip)
		add	ix,bc
		ld	bc,40		; Go to 40
		add	ix,bc
		ld	bc,8
		ld	(ix),e		; Write 24-bit pointer
		add	ix,bc
		ld	(ix),h
		add	ix,bc
		ld	(ix),l
		pop	bc
		pop	hl
		pop	ix
		ld	a,1
		ld	(mcdUpd),a
		ret

; ----------------------------------------

.ins_pwm:
		push	ix
		push	hl
		push	bc
		ld	a,(hl)		; Stereo|Loop bits
		and	00000011b
		rrca
		rrca
		ld	c,a
		rst	8
		inc	hl		; Skip ID and Pitch
		inc	hl
		ld	d,(hl)
		inc	hl
		ld	e,(hl)
		inc	hl
		ld	a,(hl)
		inc	hl
		ld	l,(hl)
		ld	h,a
		ld	a,c
		or	d
		ld	d,a
		rst	8
	; de,hl - 32-bit PWM pointer
		ld	ix,pwmcom
		ld	b,0
		ld	c,(iy+ztbl_Chip)
		add	ix,bc
		ld	bc,24
		add	ix,bc		; Move to PWOUTF
		ld	bc,8
		ld	(ix),d
		add	ix,bc
		ld	(ix),e
		add	ix,bc
		ld	(ix),h
		add	ix,bc
		ld	(ix),l
		pop	bc
		pop	hl
		pop	ix
		ld	a,1
		ld	(marsUpd),a
		ret

; ----------------------------------------
; NEW note
; ----------------------------------------

.note:
		ld	a,b			; Volume bit?
		and	0100b
		jr	nz,.fm_hasvol
		ld	(iy+ztbl_Volume),0	; Reset to default volume
		rst	8
.fm_hasvol:
		ld	a,(ix+chnl_Note)
		ld	c,a
		cp	-1
		ret	z
		cp	-2
		ret	z
		rst	8
		ld	a,(hl)
		and	11110000b
		cp	0A0h
		jr	z,.n_fm

; --------------------------------

.n_indx:
		ld	a,c
.n_stfreq:
		inc	hl			; Skip ID
		ld	e,(hl)			; Read pitch
		dec	hl
		add	a,e			; Note + pitch
		rst	8
		add	a,a			; * 2
		ld	(iy+ztbl_FreqIndx),a
		ret

; --------------------------------
; FM custom search

.n_fm:
		ld	a,c
		inc	hl		; Skip ID
		ld	e,(hl)		; Read pitch
		dec	hl
		rst	8
		add	a,e		; Note + pitch
	; Search for octave and note...
		ld	c,0		; c - octave
		ld	d,7
.get_oct:
		ld	e,a		; e - note
		sub	12
		jp	m,.fnd_oct
		inc	c
		dec	d
		jr	nz,.get_oct
.fnd_oct:
		rst	8
		ld	a,e
		add	a,a		; Note * 2
		and	00011111b
		rrc	c
		rrc	c
		rrc	c
		rst	8
		or	c
		ld	(iy+ztbl_FreqIndx),a	; Save octave + index: OOOiiiiib
		ret

; ----------------------------------------

.chnl_ulnkcut:

.chnl_ulnkoff:

.chnl_ulnk:
		ld	d,(ix+chnl_Chip)
		rst	8
		push	iy
		pop	hl
; 		jp	tblz_clear

; ----------------------------------------
; Reset all table
;
; Input:
; iy - Current buffer
; hl - Channel table
; d  - Silence chip
;
; Uses:
; b,de,hl
; ----------------------------------------

tblz_clear:
		ld	b,MAX_TBLSIZE-4
		xor	a
		ld	(hl),a			; 0 - Delete link
		inc	hl
		ld	(hl),a
		inc	hl
		ld	(hl),d			; 2 - Write silence request
		inc	hl
		inc	hl			; 3 - skip ID
.clr_all:
		ld	(hl),a
		inc	hl
		djnz	.clr_all
; 		ld	(ix+chnl_Chip),0
		ret

; ============================================================
; --------------------------------------------------------
; Communication with the SCD and 32X
;
; SCD: Sends a level2 interrupt to Sub-CPU
;    | Uses: commM,comm18-1F
;    |
; 32X: Interrupts Slave SH2
;    | Uses: comm8-comm11 (CMD request)
;    | two bits of comm14
; --------------------------------------------------------

; NOTE: careful modifing this

zmars_send:
	; ----------------------------------------
	; Send PCM table
	if MCD|MARSCD
		ld	a,(mcdBlock)	; Enable MARS requests?
		or	a
		jp	nz,.mcdt_blocked
		ld	iy,8000h|200Eh	; iy - command ports
		rst	8
		ld	a,(mcdUpd)	; NEW transfer?
		or	a
		jp	z,.mcdt_blocked
		xor	a
		ld	(mcdUpd),a
		rst	20h
		call	.set_combank
		ld	ix,pcmcom
		ld	hl,8000h|2000h
.wait_in:
		ld	a,(iy+1)	; SUB is busy?
		or	a
		jp	m,.wait_in
		ld	a,(iy)		; MAIN got first?
		or	a		; != 0
		jr	nz,.wait_in
		ld	c,0C0h
		ld	(iy),c		; Set our entrance ID
		ld	b,14		; Retry 14 times
.make_sure:
		ld	a,(iy)		; Check if did write
		cp	c
		jr	nz,.wait_in
		djnz	.make_sure
		ld	(hl),81h	; Request IRQ
		rst	8
.test_sub:
		ld	a,(iy+1)	; Sub response?
		and	0C0h
		cp	0C0h
		jr	nz,.test_sub
		set	5,(iy)		; "MAIN" lock
		rst	8
		ld	de,10h+8	; ix - MAIN comm ports
		add	hl,de
	; ix - table
	; hl - main data
		ld	c,40h/8		; c - Packets to send
.mcd_nextp:
		bit	4,(iy+1)	; SUB is busy?
		jr	nz,.mcd_nextp
		ld	b,8		; 2words to write
		push	hl
.copy_bytes:
		ld	a,(ix)
		ld	(hl),a
		inc	ix
		inc	hl
		djnz	.copy_bytes
		pop	hl
		set	4,(iy)		; PASS bit
		rst	8
.wait_sub:
		bit	4,(iy+1)	; SUB is busy?
		jr	z,.wait_sub
		res	4,(iy)		; Clear PASS bit
		rst	8
		dec	c
		jr	nz,.mcd_nextp
		ld	(iy),0		; "MAIN" unlock
.mcdt_blocked:
		ld	hl,pcmcom
		xor	a
		ld	b,8		; MAX PCM channels
		rst	8
.clr_pcm:
		ld	(hl),a
		inc	hl
		djnz	.clr_pcm
.mcdt_noupd:
		ld	b,3
		djnz	$
		nop
		nop
		rst	8
		nop
		nop
		nop
	endif
	; ----------------------------------------
	; Send PWM table
	if MARS|MARSCD
		ld	a,(marsBlock)	; Enable MARS requests?
		or	a
		jp	nz,.blocked_m
		rst	8
		ld	a,(marsUpd)	; NEW transfer?
		or	a
		jr	z,.blocked_m
		xor	a
		ld	(marsUpd),a
		rst	20h
		call	.set_combank
		ld	iy,8000h|5100h	; iy - mars sysreg
		ld	ix,pwmcom
.wait_enter:
		rst	8
		ld	a,(iy+comm14)	; check if 68k got first.
		bit	7,a
		jr	nz,.wait_enter
		and	11110000b
		or	1		; Set CMD task mode $01
		ld	(iy+comm14),a
		rst	8
		and	00001111b	; Did it write?
		cp	1
		jr	nz,.wait_enter	; If not, retry
		set	7,(iy+comm14)	; LOCK bit
		set	1,(iy+standby)	; Request Slave CMD
; .wait_cmd:
; 		bit	1,(iy+standby)	; <-- unstable on HW
; 		jr	nz,.wait_cmd
		ld	c,14		; c - 14 words/2-byte
.next_packet:
		rst	8
		push	iy
		pop	hl
		ld	de,comm8	; hl - comm8
		add	hl,de
		ld	b,2
.next_comm:
		ld	d,(ix)
		ld	e,(ix+1)
		inc	ix
		inc	ix
		rst	8
		ld	(hl),d
		inc	hl
		ld	(hl),e
		inc	hl
		djnz	.next_comm
		set	6,(iy+comm14)	; PASS data bit
		rst	8
.w_pass2:
		nop
		bit	6,(iy+comm14)	; PASS cleared?
		jr	nz,.w_pass2
		dec	c
		jr	nz,.next_packet
		res	7,(iy+comm14)	; Break transfer loop
		res	6,(iy+comm14)	; Clear PASS
; Reset comm ports
.blocked_m:
		xor	a
		ld	hl,pwmcom
		ld	b,8
		rst	8
.clr_pwm:
		ld	(hl),a		; Reset our COM bytes
		inc	hl
		djnz	.clr_pwm
.pwm_exit:
		nop
		nop
		rst	8
		nop
		nop
		nop
	if MARSCD
		ld	b,3
		djnz	$
		nop
		nop
		nop
	endif

	endif
		ret

; --------------------------------------------------------
; Set bank to $A10000 area
	if MCD|MARS|MARSCD
.set_combank:
		ld	hl,6000h
		ld	(hl),0
		ld	(hl),1
		ld	(hl),0
		ld	(hl),0
		rst	8
		ld	(hl),0
		ld	(hl),0
		ld	(hl),1
		ld	(hl),0
		ld	(hl),1
		ret
	endif

; ====================================================================
; ----------------------------------------------------------------
; Subroutines
; ----------------------------------------------------------------

; --------------------------------------------------------
; Init sound engine
; --------------------------------------------------------

gema_init:
		call	gema_lastbank		; Set last bank slot, solves problem with 32X
		call	dac_off
		xor	a
		ld	(marsUpd),a
		ld	(mcdUpd),a
		ld	(cdRamLen),a
		ld	iy,nikona_BuffList
		ld	c,1			; Start at this priority
.setup_list:
		ld	a,(iy)
		cp	-1
		jr	z,.end_setup
		inc	iy
		ld	l,a
		ld	h,(iy)
		push	hl
		pop	ix
		ld	(ix+trk_Priority),c
		ld	(ix+trk_SeqId),-1	; Reset sequence ID
		inc	iy
	; iy - src
	; hl - dst
		ld	de,trk_Blocks
		add	hl,de
		ld	b,MAX_BUFFNTRY-2
.st_copy:
		ld	a,(iy)
		ld	(hl),a
		inc	iy
		inc	hl
		djnz	.st_copy
		inc	c
		jr	.setup_list
.end_setup:

		ld	de,2208h|03h	; Set Default LFO
		call	fm_send_1
		ld	de,2700h	; CH3 special/timers OFF
		call	fm_send_1
; 		ld	de,2800h
		inc	d		; FM KEYS off
		call	fm_send_1
		inc	e
		call	fm_send_1
		inc	e
		call	fm_send_1
		inc	e
		inc	e
		call	fm_send_1
		inc	e
		call	fm_send_1
		inc	e
		call	fm_send_1
		ld	hl,Zpsg_ctrl	; Silence PSG channels
		ld	(hl),09Fh
		ld	(hl),0BFh
		ld	(hl),0DFh
		ld	(hl),0FFh
		ret

; --------------------------------------------------------
; get_tick
;
; Checks if VBlank triggred a TICK
; (1/150 NTSC, 1/120 PAL)
; --------------------------------------------------------

get_tick:
		di				; Disable ints
		push	af
		push	hl
		ld	hl,tickFlag		; read last TICK flag
		ld	a,(hl)			; non-zero value (1Fh)?
		or 	a
		jr	z,.ctnotick
		ld	(hl),0			; Reset TICK flag
		inc	hl			; Move to tickCnt
		inc	(hl)			; and increment
		rst	8
		push	de
		ld	hl,(sbeatAcc)		; Increment subbeats
		ld	de,(sbeatPtck)
		rst	8
		add	hl,de
		ld	(sbeatAcc),hl
		pop	de
.ctnotick:
		pop	hl
		pop	af
		ei				; Enable ints again
		ret

; --------------------------------------------------------
; readRom
;
; Transfer bytes from ROM to Z80 RAM.
; This also tells to 68k that we want to access ROM
;
; Input:
; a  | 68K Address $xx0000
;  c | Byte count (size 0 NOT allowed, MAX: 0FFh)
; hl | 68K Address $00xxxx
; de | Destination pointer
;
; Uses:
; b
;
; Notes:
; call RST 20h first, so the currenty playing DAC
; sample has enough data before getting busy here.
; --------------------------------------------------------

readRom:
		push	ix
		ld	ix,commZRomBlk		; ix - rom read/block flags
		cp	0FFh			; Reading from 68k's RAM?
		jr	z,.from_ram
		rst	8
		ld	(x68ksrclsb),hl		; Backup midlow address
		res	7,h			; Reset MSB bit 7
		ld	b,0			; Clear b
		dec	bc			; len-1
		add	hl,bc			; Add len to the mid and low to this temp address
		bit	7,h			; Did it cross the bank?
		jr	nz,.double		; Then it's a double transfer
		ld	hl,(x68ksrclsb)		; Restore hl
		inc	c			; len+1
		ld	b,a			; b - $xx0000
		call	.transfer
		pop	ix
		ret
.double:
		rst	8
		ld	b,a			; b - $xx0000
		push	bc			; Backup len and midlow address
		push	hl
		ld	a,c			; len - LSB
		sub	a,l
		ld	c,a			; Save new size
		ld	hl,(x68ksrclsb)		; Restore TOP
		call	.transfer
		pop	hl			; Restore len and midlow address
		pop	bc
		ld	c,l			; Get second len
		inc	c
		ld	a,(x68ksrcmid)
		and	80h
		add	a,80h
		ld	h,a
		ld	l,0
		jr	nc,.x68knocarry
		inc	b			; Next $xx0000
.x68knocarry:
		call	.transfer
		pop	ix
		ret

; ------------------------------------------------
; WORKAROUND FOR READING FROM $FF0000 RAM
;
; On the 68K side YOU MUST CALL
; gemaSendRam manually and every time, normally
; from a Vblank wait-loop.
; ------------------------------------------------

.from_ram:
		ld	(cdRamDst),de			; Show variables
		ld	(cdRamSrc),hl
		ld	(cdRamSrcB),a
		call	gema_lastbank			; Set bank to $FF8000 area
		rst	8
		ld	a,c
		ld	(cdRamLen),a			; Show length
		ld	hl,RAM_ZCdFlagD&07FFFh+8000h	; ** 68K LABEL **
		ld	(hl),1				; WRITE flag
.wait:
		ld	a,(cdRamLen)			; Wait until 68K clears
		or	a
		jr	nz,.wait
		pop	ix
		ret

; ------------------------------------------------
; b  - Source ROM $xx0000
;  c - Bytes to transfer (00h is invalid)
; hl - Source ROM $00xxxx | 8000h
; de - Output location
; ix - ROM-block flag
; ------------------------------------------------

.transfer:
		rst	8
		push	hl
		ld	a,h
		ld	hl,6000h
		rlca
		ld	(hl),a
		ld	a,b
		rst	8
		ld	(hl),a
		rrca
		ld	(hl),a
		rrca
		ld	(hl),a
		rrca
		ld	(hl),a
		rrca
		rst	8
		ld	(hl),a
		rrca
		ld	(hl),a
		rrca
		ld	(hl),a
		rrca
		ld	(hl),a
		pop	hl
		set	7,h
		rst	8
	; Transfer ROM data in packets
	; while playing the cache'd sample
	; *** CRITICAL PROCESS ***
	;
	; pseudo-ref for ldir:
	; ld (de),(hl)	; load memory (hl) to (de)
	; inc de	; incr de + 1
	; inc hl	; incr hl + 1
	; dec bc	; decr bc - 1
		ld	b,0
		ld	a,c		; a - Size counter
		sub	MAX_TRFRPZ	; Length lower than MAX_TRFRPZ?
		jr	c,.x68klast	; Process single piece only
.x68kloop:
		rst	8
		nop
		ld	c,MAX_TRFRPZ-1
		bit	0,(ix)		; Genesis blocks ROM?
		call	nz,.x68klpwt
		ldir			; (de) to (hl) until bc == 0
		rst	8
		nop
		sub	a,MAX_TRFRPZ-1
		jp	nc,.x68kloop
; last block
.x68klast:
		add	a,MAX_TRFRPZ
		ld	c,a
		bit	0,(ix)		; Genesis blocks ROM?
		call	nz,.x68klpwt
		ldir
		rst	8
		ret

; Wait here until Genesis unlocks ROM
.x68klpwt:
		nop
		nop
	if EMU=0
		nop
		nop
	endif
		rst	8
	if EMU=0
		nop
		nop
	endif
		nop
		bit	0,(ix)		; 68k finished?
		jr	nz,.x68klpwt
		ret

; ====================================================================
; ----------------------------------------------------------------
; Sound chip routines
; ----------------------------------------------------------------

; --------------------------------------------------------
; chip_env
;
; Process the PSG
; --------------------------------------------------------

chip_env:
	if MARS|MARSCD
		call	gema_lastbank		; Keep bank out of ROM before writing PSG
	endif
		ld	iy,psgcom+3		; Start from NOISE first
		ld	ix,Zpsg_ctrl
		ld	c,0E0h			; c - PSG first ctrl command
		ld	b,4			; b - 4 channels
.vloop:
		rst	8
		ld	e,(iy+COM)		; e - current command
		ld	(iy+COM),0

	; ----------------------------
	; bit 2 - stop sound
		bit	2,e
		jr	z,.ckof
		ld	(iy+LEV),-1		; reset level
		ld	(iy+FLG),1		; and update
		ld	(iy+MODE),0		; envelope off
.ckof:
	; ----------------------------
	; bit 1 - key off
		bit	1,e
		jr      z,.ckon
		ld	a,(iy+MODE)		; mode 0?
		or	a
		jr	z,.ckon
		ld	(iy+FLG),1		; psg update flag
		ld	(iy+MODE),100b		; set envelope mode 100b
		rst	8
.ckon:
	; ----------------------------
	; bit 0 - key on
		bit	0,e
		jr	z,.envproc
		ld	(iy+LEV),-1		; reset level
		ld	a,b
		cp	4			; NOISE channel?
		jr	nz,.nskip
		rst	8			; Set NOISE mode
		ld	a,(psgHatMode)		; write hat mode only.
		or	c
		ld	(ix),a			; WRITE PSG
.nskip:
		ld	(iy+FLG),1		; psg update flag
		rst	8
		ld	(iy+MODE),001b		; set to attack mode
.nblock:

	; ----------------------------
	; Process effects
	; ----------------------------
.envproc:
		ld	a,(iy+MODE)
		or	a			; no modes
		jp	z,.vedlp
		cp 	001b			; Attack mode
		jr	nz,.chk2
		ld	(iy+FLG),1		; psg update flag
		ld	e,(iy+ALV)
		ld	a,(iy+ATK)		; if ATK == 0, don't use
		or	a
		jr	z,.atkend
		ld	d,a			; c - attack rate
		ld	a,e			; a - attack level
		rst	8
		ld	e,(iy+ALV)		; b - OLD attack level
		sub	a,d			; (attack rate) - (level)
		jr	c,.atkend		; if carry: already finished
		jr	z,.atkend		; if zero: no attack rate
		cp	e			; attack rate == level?
		jr	c,.atkend
		jr	z,.atkend
		ld	(iy+LEV),a		; set new level
		rst	8
		jr	.vedlp
.atkend:
		ld	(iy+LEV),e		; attack level = new level
.atkzero:
		ld	(iy+MODE),010b		; set to decay mode
		jr	.vedlp
.chk2:

		cp	010b			; Decay mode
		jr	nz,.chk4
.dectmr:
		ld	(iy+FLG),1		; psg update flag
		ld	a,(iy+LEV)		; a - Level
		ld	e,(iy+SLV)		; b - Sustain
		cp	e
		jr	c,.dkadd		; if carry: add
		jr	z,.dkyend		; if zero:  finish
		rst	8
		sub	(iy+DKY)		; substract decay rate
		jr	c,.dkyend		; finish if wraped.
		cp	e			; compare level
		jr	c,.dkyend		; and finish
		jr	.dksav
.dkadd:
		add	a,(iy+DKY)		;  (level) + (decay rate)
		jr	c,.dkyend		; finish if wraped.
		cp	e			; compare level
		jr	nc,.dkyend
.dksav:
		ld	(iy+LEV),a		; save new level
		jr	.vedlp
.dkyend:
		rst	8
		ld	(iy+LEV),e		; save last attack
		ld	(iy+MODE),100b		; and set to sustain
		jr	.vedlp
.chk4:
		cp	100b			; Sustain phase
		jr	nz,.vedlp
		ld	(iy+FLG),1		; psg update flag
		ld	a,(iy+LEV)		; a - Level
		rst	8
		add 	a,(iy+RRT)		; add Release Rate
		jr	c,.killenv		; release done
		ld	(iy+LEV),a		; set new Level
		jr	.vedlp
.killenv:
		ld	(iy+LEV),-1		; Silence this channel
		ld	(iy+MODE),0		; Reset mode
.vedlp:
	; ----------------------------
	; PSG UPDATE
	; ----------------------------
		ld	a,(iy+FLG)
		or	a
		jr	z,.noupd
		ld	(iy+FLG),0	; Reset until next one
		ld	e,c
		ld	a,(psgHatMode)
		ld	d,a
		and	011b
		cp	011b
		jr	nz,.normal
		rst	8
		ld	a,b		; Channel 4?
		cp	3
		jr	z,.silnc_3
		cp	4
		jr	nz,.do_nfreq
		ld	a,(psgHatMode)
		ld	d,a
		and	011b
		rst	8
		cp	011b
		jr	nz,.vonly
		ld	e,0C0h
		jr	.do_nfreq
.silnc_3:
		ld	a,-1
		jr	.vlmuch
.normal:
		ld	a,b
		cp	4
		jr	z,.vonly
.do_nfreq:
		ld	l,(iy+DTL)
		ld	h,(iy+DTH)
	; freq effects go here
	; (save e FIRST.)
	;	push	de
	;	pop	de
		ld	a,l		; Grab LSB 4 right bits
		and	00001111b
		or	e		; OR with channel set in e
		rst	8
		ld	(ix),a		; write it
		ld	a,l		; Grab LSB 4 left bits
		rrca
		rrca
		rrca
		rrca
		and	00001111b
		ld	e,a
		ld	a,h		; Grab MSB bits
		rst	8
		rlca
		rlca
		rlca
		rlca
		and	00110000b
		or	e
		ld	(ix),a
		rst	8
.vonly:
		ld	a,(iy+MVOL)		; c - Level
		add	a,(iy+LEV)		; Add MASTER volume
		jr	nc,.vlmuch
		ld	a,-1
.vlmuch:
		srl	a			; (Level >> 4)
		srl	a
		srl	a
		rst	8
		srl	a
		and	00001111b		; Filter volume value
		or	c			; and OR with current channel
		or	90h			; Set volume-set mode
		ld	(ix),a			; *** WRITE volume
		inc	(iy+PTMR)		; Update general timer
.noupd:
	; ----------------------------
		dec	iy			; next COM to check (backwards)
		ld	a,c
		rst	8
		sub	a,20h			; next PSG (backwards)
		ld	c,a
		dec	b
		jp	nz,.vloop
		ret

; ---------------------------------------------
; FM register writes
;
; Input:
; d - ctrl
; e - data
; ---------------------------------------------

; c - KeyID
fm_autoreg:
		bit	2,c
		jr	nz,fm_send_2

; Channels 1-3 and global registers
fm_send_1:
		ld	a,d
		ld	(Zym_ctrl_1),a
		nop
		ld	a,e
		ld	(Zym_data_1),a
		nop
		ret
; Channels 4-6
fm_send_2:
		ld	a,d
		ld	(Zym_ctrl_2),a
		nop
		ld	a,e
		ld	(Zym_data_2),a
		nop
		ret

; --------------------------------------------------------
; brute-force WAVE ON/OFF playback
; --------------------------------------------------------

dac_on:
		ld	a,2Bh
		ld	(Zym_ctrl_1),a
		ld	a,80h
		ld	(Zym_data_1),a
		ld 	a,zopcExx
		ld	(dac_me),a
		ld 	a,zopcPushAf
		ld	(dac_fill),a
		ret
dac_off:
		ld	a,2Bh
		ld	(Zym_ctrl_1),a
		ld	a,00h
		ld	(Zym_data_1),a
		ld 	a,zopcRet
		ld	(dac_me),a
		ld 	a,zopcRet
		ld	(dac_fill),a
		ret

; --------------------------------------------------------
; dac_play
;
; Plays a new sample
;
; NOTE:
; Set wave_Flags and wave_Pitch externally
; getting here.
; --------------------------------------------------------

dac_play:
		di
		call	dac_off
		exx				; flip exx regs
		ld	bc,dWaveBuff>>8		; bc - WAVFIFO MSB
		ld	de,(wave_Pitch)		; de - Pitch
		ld	hl,(dWaveBuff&0FFh)<<8	; hl - WAVFIFO LSB pointer (xx.00)
		exx				; move them back
		ld	hl,(wave_Start)		; copy Start and length
		ld 	a,(wave_Start+2)
		ld	(dDacPntr),hl
		ld	(dDacPntr+2),a
		ld	hl,(wave_Len)
		ld 	a,(wave_Len+2)
		ld	(dDacCntr),hl
		ld	(dDacCntr+2),a
		xor	a
		ld	(dDacFifoMid),a		; Reset half-way
		call	dac_refill
		call	dac_on
		ei
		ret

; --------------------------------------------------------

dac_refill:
		rst	8
		push	bc
		push	de
		push	hl
		ld	a,(wave_Flags)	; Already finished?
		cp	111b
		jp	nc,.dacfill_end
		ld	a,(dDacCntr+2)	; Last bytes
		ld	hl,(dDacCntr)
		ld	bc,80h
		scf
		ccf
		sbc	hl,bc
		sbc	a,0
		ld	(dDacCntr+2),a
		ld	(dDacCntr),hl
		ld	d,dWaveBuff>>8
		or	a
		jp	m,.dac_over
		ld	a,(dDacFifoMid)	; Update halfway value
		ld	e,a
		add 	a,80h
		ld	(dDacFifoMid),a
		ld	hl,(dDacPntr)
		ld	a,(dDacPntr+2)
		call	readRom	; *** ROM ACCESS ***
		ld	hl,(dDacPntr)
		ld	a,(dDacPntr+2)
		ld	bc,80h
		add	hl,bc
		adc	a,0
		ld	(dDacPntr),hl
		ld	(dDacPntr+2),a
		jp	.dacfill_ret
; NOTE: This doesn't finish at the exact END point
; but the USER won't notice it.
.dac_over:
		ld	d,dWaveBuff>>8
		ld	a,(wave_Flags)	; LOOP enabled?
		and	001b
		jp	nz,.dacfill_loop
		ld	a,l
		add	a,80h
		ld	c,a
		ld	b,0
		push	bc
		ld	a,(dDacFifoMid)
		ld	e,a
		add	a,80h
		ld	(dDacFifoMid),a
		pop	bc
		ld	a,c
		or	b
		jr	z,.dacfill_end
		ld	hl,(dDacPntr)
		ld	a,(dDacPntr+2)
		call	readRom	; *** ROM ACCESS ***
		jr	.dacfill_end
; loop sample
.dacfill_loop:
		push	bc
		push	de
		ld	a,(wave_Loop+2)
		ld	c,a
		ld	de,(wave_Loop)
		ld	hl,(wave_Start)
		ld 	a,(wave_Start+2)
		add	a,c
		add	hl,de
		adc	a,0
		ld	(dDacPntr),hl
		ld	(dDacPntr+2),a
		ld	hl,(wave_Len)
		ld 	a,(wave_Len+2)
		sub	a,c
		scf
		ccf
		sbc	hl,de
		sbc	a,0
		ld	(dDacCntr),hl
		ld	(dDacCntr+2),a
		pop	de
		pop	bc
		ld	a,b
		or	c
		jr	z,.dacfill_ret
		ld	a,(dDacFifoMid)
		ld	e,a
		add	a,80h
		ld	(dDacFifoMid),a
		ld	hl,(dDacPntr)
		ld	a,(dDacPntr+2)
		call	readRom	; *** ROM ACCESS ***
		jr	.dacfill_ret
.dacfill_end:
		call	dac_off		; DAC finished
.dacfill_ret:
		pop	hl
		pop	de
		pop	bc
		ret

; ----------------------------------------------------------------
; gema_lastbank
;
; Two purposes:
; - Set the BANK to the very last part of memory for the
;   readRom to read from RAM
; - On 32X this sets the bank out of the ROM-reading areas due
;   to a conflict with the PSG according to a Tech Bulletin.
;
; Uses:
; hl,b
; ----------------------------------------------------------------

gema_lastbank:
		ld	hl,6000h
		ld	b,9		; 9 bits
.write:
		ld	(hl),1
		djnz	.write
		ret

; ====================================================================
; ----------------------------------------------------------------
; Frequency tables
; ----------------------------------------------------------------

fmFreq_List:	dw 644
		dw 681
		dw 722
		dw 765
		dw 810
		dw 858
		dw 910
		dw 964
		dw 1021
		dw 1081
		dw 1146
		dw 1214

; ----------------------------------------
; DAC and PWM
; ----------------------------------------

psgFreq_List:
; 	dw    -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1	; x-0
; 	dw    -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1	; x-1
; 	dw    -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1	; x-2
	dw    -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,   -1,03F8h,03BFh,0389h	; x-3
	dw 0356h,0326h,02F9h,02CEh,02A5h,0280h,025Ch,023Ah,021Ah,01FBh,01DFh,01C4h	; x-4
	dw 01ABh,0193h,017Dh,0167h,0153h,0140h,012Eh,011Dh,010Dh,00FEh,00EFh,00E2h	; x-5
	dw 00D6h,00C9h,00BEh,00B4h,00A9h,00A0h,0097h,008Fh,0087h,007Fh,0078h,0071h	; x-6
	dw 006Bh,0065h,005Fh,005Ah,0055h,0050h,004Bh,0047h,0043h,0040h,003Ch,0039h	; x-7
	dw 0036h,0033h,0030h,002Dh,002Bh,0028h,0026h,0024h,0022h,0020h,001Fh,001Dh	; x-8 *UNTESTED*
	dw 001Bh,001Ah,0018h,0017h,0016h,0015h,0013h,0012h,0011h,0010h,0009h,0001h	; x-9 *RESERVED FOR NOISE* Set to +47

; ----------------------------------------
; DAC and PWM shared list
; ----------------------------------------

wavFreq_List:
	;   C     C#    D     D#    E     F     F#    G     G#    A     A#    B
; 	dw 0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h	; x-0
; 	dw 0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h	; x-1
; 	dw 0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0036h,003Bh	; x-2
	dw 0040h,0044h,0048h,004Ch,0051h,0056h,005Bh,0060h,0066h,006Ch,0073h,0079h	; x-3 4000 ok
	dw 0080h,0088h,0090h,0099h,00A2h,00ACh,00B6h,00C1h,00CCh,00D8h,00E5h,00F2h	; x-4 8000 ok
	dw 0100h,0110h,0120h,0132h,0145h,0158h,016Ch,0182h,0198h,01AEh,01C7h,01E0h	; x-5 16000 ok
	dw 0200h,0220h,0240h,0260h,0280h,02A0h,02D0h,02F8h,0328h,0352h,0390h,03C8h	; x-6 32000 bad/ok
	dw 0400h;,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h	; x-7
; 	dw 0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h	; x-8
; 	dw 0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h,0100h	; x-9

; ----------------------------------------
; SegaCD PCM
; ----------------------------------------
wavFreq_CdPcm:
	;     C     C#     D      D#     E      F      F#     G      G#     A      A#     B
; 	dw  0100h, 0100h, 0100h, 0100h, 0100h, 0100h, 0100h, 0100h, 0100h, 0100h, 0100h, 0100h	; x-0
; 	dw  0100h, 0100h, 0100h, 0100h, 0100h, 0100h, 0100h, 0100h, 0100h, 0100h, 0100h, 0100h	; x-1
	dw  00F8h, 0108h, 011Ch, 0128h, 013Ch, 014Ch, 0160h, 017Ch, 0188h, 01AAh, 01BCh, 01DCh	; x-2  4000 ok
	dw  01F8h, 0214h, 023Ch, 0258h, 027Ch, 02A0h, 02C8h, 02FCh, 031Ch, 0354h, 037Ch, 03B8h	; x-3  8000 ok
	dw  03F0h, 0428h, 0468h, 04ACh, 04ECh, 0540h, 0590h, 05E4h, 063Ch, 0698h, 0704h, 0760h	; x-4 16000 ok
	dw  07DCh, 0848h, 08D4h, 0960h, 09F0h, 0A64h, 0B04h, 0BAAh, 0C60h, 0D18h, 0DE4h, 0EB8h	; x-5 32000 ok
	dw  0FB0h, 1074h, 1184h, 1280h, 139Ch, 14C8h, 1624h, 174Ch, 18DCh, 1A38h, 1BE0h, 1D94h	; x-6 64000 untested
; 	dw  1F64h, 20FCh, 2330h, 2524h, 2750h, 29B4h, 2C63h, 2F63h, 31E0h, 347Bh, 377Bh, 3B41h	; x-7 128000 bad
; 	dw  3EE8h, 4206h, 4684h, 4A5Ah, 4EB5h, 5379h, 58E1h, 5DE0h, 63C0h, 68FFh, 6EFFh, 783Ch	; x-8 256000 bad
; 	dw  7FC2h, 83FCh, 8D14h, 9780h,0AA5Dh,0B1F9h,   -1 ,   -1 ,   -1 ,   -1 ,   -1 ,   -1 	; x-9 bad

; ====================================================================
; ----------------------------------------------------------------
; Chip buffers
; ----------------------------------------------------------------

pcmcom:	db 00h,00h,00h,00h,00h,00h,00h,00h	; 0 - Playback bits: %0000PCOK Pitchbend/keyCut/keyOff/KeyOn
	db 00h,00h,00h,00h,00h,00h,00h,00h	; 8 - Pitch MSB
	db 00h,00h,00h,00h,00h,00h,00h,00h	; 16 - Pitch LSB
	db -1,-1,-1,-1,-1,-1,-1,-1		; 24 - Volume
	db -1,-1,-1,-1,-1,-1,-1,-1		; 32 - CURRENT Panning %RRRRLLLL
	db 00h,00h,00h,00h,00h,00h,00h,00h	; 40 - 24-bit sample location in Sub-CPU area
	db 00h,00h,00h,00h,00h,00h,00h,00h	; 48
	db 00h,00h,00h,00h,00h,00h,00h,00h	; 56

pwmcom:	db 00h,00h,00h,00h,00h,00h,00h,00h	; 0 - Playback bits: %0000PCOK Pitchbend/keyCut/keyOff/KeyOn
	db 00h,00h,00h,00h,00h,00h,00h,00h	; 8 - Volume | Pitch MSB
	db 00h,00h,00h,00h,00h,00h,00h,00h	; 16 - Pitch LSB
	db 00h,00h,00h,00h,00h,00h,00h,00h	; 24 - Flags+MSB bits of sample %SlLRxxxx Stereo/Loop/Left/Right
	db 00h,00h,00h,00h,00h,00h,00h,00h	; 32 - ''
	db 00h,00h,00h,00h,00h,00h,00h,00h
	db 00h,00h,00h,00h,00h,00h,00h,00h

psgcom:	db 00h,00h,00h,00h	;  0 - command 1 = key on, 2 = key off, 4 = stop snd
	db -1, -1, -1, -1	;  4 - output level attenuation (%llll.0000, -1 = silent)
	db 00h,00h,00h,00h	;  8 - attack rate (START)
	db 00h,00h,00h,00h	; 12 - decay rate
	db 00h,00h,00h,00h	; 16 - sustain level attenuation (MAXIMUM)
	db 00h,00h,00h,00h	; 20 - release rate
	db 00h,00h,00h,00h	; 24 - envelope mode 0 = off, 1 = attack, 2 = decay, 3 = sustain
	db 00h,00h,00h,00h	; 28 - freq bottom 4 bits
	db 00h,00h,00h,00h	; 32 - freq upper 6 bits
	db 00h,00h,00h,00h	; 36 - attack level attenuation
	db 00h,00h,00h,00h	; 40 - flags to indicate hardware should be updated
	db 00h,00h,00h,00h	; 44 - timer for sustain
	db 00h,00h,00h,00h	; 48 - MAX Volume
	db 00h,00h,00h,00h	; 52 - Vibrato value
	db 00h,00h,00h,00h	; 56 - General timer

; --------------------------------------------------------
fmcach_1	ds 28h
fmcach_2	ds 28h
fmcach_3	ds 28h
fmcach_4	ds 28h
fmcach_5	ds 28h
fmcach_6	ds 28h
fmlist_rsave	ds 4*3		; 4 bytes per channel: 0000h,00h,00h
trkInfoCach	ds 4
		ds 4*3		; _rsave followup

; ====================================================================
; ----------------------------------------------------------------
; Track buffers
; ----------------------------------------------------------------

trkHdrs_0	ds 8*4			; dw point,rowcntr
trkHdrs_1	ds 8*4
trkHdrs_2	ds 8*4
trkBlks_0	ds 8
trkBlks_1	ds 8
trkBlks_2	ds 8
trkBuff_0	ds trk_ChnIndx+MAX_TRKINDX
trkBuff_1	ds trk_ChnIndx+MAX_TRKINDX
trkBuff_2	ds trk_ChnIndx+MAX_TRKINDX
fmcach_list:	dw fmcach_1
		dw fmcach_2
		dw fmcach_3
marsUpd		db 0			; Flag to request a PWM transfer
mcdUpd		db 0			; Flag to request a PCM transfer
		dw fmcach_4		; Followup
		dw fmcach_5
		dw fmcach_6
dDacPntr	db 0,0,0	; WAVE play current ROM position
dDacCntr	db 0,0,0	; WAVE play length counter
headerOut	ds 00Eh		; Temporal storage for 68k pointers
headerOut_e	ds 2		; <-- reverse readpoint
sampleHead	ds 006h
instListOut	ds 8

; ====================================================================
; --------------------------------------------------------
; MASTER buffers list
;
; dw track_buffer
; dw channel_list,block_cache,header_cache,track_cache*
;
; * Cache MUST be aligned and in 1-bit sizes
; --------------------------------------------------------

nikona_BuffList:
	dw trkBuff_0,trkBlks_0,trkHdrs_0,trkCach_0
	dw trkBuff_1,trkBlks_1,trkHdrs_1,trkCach_1
	dw trkBuff_2,trkBlks_2,trkHdrs_2,trkCach_2
nikona_BuffList_e:
	dw -1	; ENDOFLIST

; ====================================================================
; --------------------------------------------------------
; Channel tables
;
; PSG   80h
; PSGN  90h
; FM   0A0h
; FM3  0B0h
; DAC  0C0h
; PCM  0D0h
; PWM  0E0h
; --------------------------------------------------------

		org 1B00h			; <-- MUST BE x0h ALIGNED
tblList:	dw tblPSG-tblList		;  80h
		dw tblPSGN-tblList|8000h	;  90h *
		dw tblFM-tblList		; 0A0h
		dw tblFM3-tblList|8000h		; 0B0h *
		dw tblFM6-tblList|8000h		; 0C0h *
		dw tblPCM-tblList		; 0D0h
		dw tblPWM-tblList		; 0E0h
; 		dw 0				; 0F0h
; --------------------------------------------------------
tblPCM:		db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h	; Channel 1
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,01h,00h,00h,00h,00h,00h,00h	; Channel 2
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,02h,00h,00h,00h,00h,00h,00h	; Channel 3
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,03h,00h,00h,00h,00h,00h,00h	; Channel 4
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,04h,00h,00h,00h,00h,00h,00h	; Channel 5
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,05h,00h,00h,00h,00h,00h,00h	; Channel 6
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,06h,00h,00h,00h,00h,00h,00h	; Channel 7
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,07h,00h,00h,00h,00h,00h,00h	; Channel 8
		db 00h,00h,00h,00h,00h,00h,00h,00h
		dw -1	; end-of-list
tblFM:		db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h	; Channel 1
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,01h,00h,00h,00h,00h,00h,00h	; Channel 2
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,04h,00h,00h,00h,00h,00h,00h	; Channel 4 <--
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,05h,00h,00h,00h,00h,00h,00h	; Channel 5
		db 00h,00h,00h,00h,00h,00h,00h,00h
tblFM3:		db 00h,00h,00h,02h,00h,00h,00h,00h,00h,00h	; Channel 3 <--
		db 00h,00h,00h,00h,00h,00h,00h,00h
tblFM6:		db 00h,00h,00h,06h,00h,00h,00h,00h,00h,00h	; Channel 6 <--
		db 00h,00h,00h,00h,00h,00h,00h,00h
		dw -1	; end-of-list
tblPSG:		db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h	; Channel 1
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,01h,00h,00h,00h,00h,00h,00h	; Channel 2
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,02h,00h,00h,00h,00h,00h,00h	; Channel 3
		db 00h,00h,00h,00h,00h,00h,00h,00h
		dw -1	; end-of-list
tblPSGN:	db 00h,00h,00h,03h,00h,00h,00h,00h,00h,00h	; Noise
		db 00h,00h,00h,00h,00h,00h,00h,00h
tblPWM:		db 00h,00h,00h,00h,00h,00h,00h,00h,00h,00h	; Channel 1
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,01h,00h,00h,00h,00h,00h,00h	; Channel 2
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,02h,00h,00h,00h,00h,00h,00h	; Channel 3
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,03h,00h,00h,00h,00h,00h,00h	; Channel 4
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,04h,00h,00h,00h,00h,00h,00h	; Channel 5
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,05h,00h,00h,00h,00h,00h,00h	; Channel 6
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,06h,00h,00h,00h,00h,00h,00h	; Channel 7
		db 00h,00h,00h,00h,00h,00h,00h,00h
		db 00h,00h,00h,07h,00h,00h,00h,00h,00h,00h	; Channel 8
		db 00h,00h,00h,00h,00h,00h,00h,00h
		dw -1	; end-of-list
; ----------------------------------------------------------------
wave_Start	dw 0		; START: 68k 24-bit pointer
		db 0
wave_Len	dw 0		; LENGTH 24-bit
		db 0
wave_Loop	dw 0		; LOOP POINT 24-bit
		db 0
wave_Pitch	dw 0100h	; 01.00h
wave_Flags	db 0		; WAVE playback flags (%10x: 1 loop / 0 no loop)

tickSpSet	db 0		; **
tickFlag	db 0		; Tick flag from VBlank
tickCnt		db 0		; ** Tick counter (PUT THIS AFTER tickFlag)
currTickBits	db 0		; Current Tick/Subbeat flags (000000BTb B-beat, T-tick)

; ====================================================================
; ----------------------------------------------------------------
; Special aligned buffers
;
; Located at 1D00h
; ----------------------------------------------------------------

		org 1D00h
dWaveBuff	ds 100h				; WAVE data buffer: 100h bytes
trkChnls	ds 8*MAX_TRKCHN
trkCach_0	ds MAX_RCACH
trkCach_1	ds MAX_RCACH
trkCach_2	ds MAX_RCACH

; ====================================================================
; ----------------------------------------------------------------
; Control area
; * MANUAL ORDER, check gema.asm *
; ----------------------------------------------------------------

		org 1F60h
commZfifo	ds MAX_ZCMND			; Buffer for commands from 68k side
commZWrite	db 0				; cmd fifo wptr (from 68k)
commZRomBlk	db 0				; 68k ROM block flag
cdRamDst	db 0,0				; ** Z80 destination
cdRamSrc	db 0,0				; ** 68k 24-bit source
cdRamSrcB	db 0				; **
cdRamLen	db 0				; Size + status flag
palMode		db 0				; PAL mode flag
mcdBlock	db 0				; Flag to BLOCK PCM transfers.
marsBlock	db 0				; Flag to BLOCK PWM transfers.

; --------------------------------------------------------
		dephase
		cpu 68000		; [AS] Return to 68k
		padding off		; [AS] NO padding
		align 2
