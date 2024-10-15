; ===========================================================================
; -------------------------------------------------------------------
; SegaCD SUB-CPU
;
; Loaded on BOOT
; -------------------------------------------------------------------

SET_PCMBLK		equ $100	; $100 or $80
SET_PCMLAST		equ $F00	;

SET_STAMPPOV		equ 256
; MAX_MCDSTAMPS		equ 64		; see shared.asm

; Dot output size: (WIDTH/8)*(HEIGHT/8)*$20
; Map slots: $4000 bytes
; Trace data: $2000 ($800 bytes * 4)
; Stamp list: ($20*MAX_MCDSTAMPS)
; Dot-screen: $9600 320x240 max

WRAM_DotOutput_0	equ $20000
WRAM_DotOutput_1	equ $28000
WRAM_MdMapTable		equ $30000
WRAM_MdStampList	equ $3A000
WRAM_TraceBuff		equ $3B000	; Size $780*2 ($F00)
WRAM_StampsDone		equ $3BFFC
WRAM_StampCurrFlip	equ $3BFFE
WRAM_PcmTable		equ $3A000	; TODO
WRAM_SaveDataCopy	equ $3C000	; ** DONT Overwrite THIS **

; ====================================================================
; ----------------------------------------------------------------
; Variables
; ----------------------------------------------------------------

SCPU_wram	equ $00080000
SCPU_bram	equ $FFFE8000
SCPU_pcm	equ $FFFF0000
; SCPU_pcmram	equ $FFFF2001
SCPU_reg	equ $FFFF8000

PCM		equ $00
ENV		equ $01		; Envelope (Volume)
PAN		equ $03		; Panning (%bbbbaaaa, aaaa = left, bbbb = right)
FDL		equ $05		; Sample rate $00xx
FDH		equ $07		; Sample rate $xx00
LSL		equ $09		; Loop address $xx00
LSH		equ $0B		; Loop address $00xx
ST		equ $0D		; Start address (only $x0, $x000)
CTREG		equ $0F		; Control register ($80 - Bank select, $C0 - Channel select)
ONREG		equ $11		; Channel On/Off (BITS: 1 - off, 0 - on)

; ====================================================================
; ----------------------------------------------------------------
; Structs
; ----------------------------------------------------------------

cdpcm		struct
status		ds.b 1		; Status bits
flags		ds.b 1		; Playback flags: %0000000L
start		ds.l 1
length		ds.l 1
loop		ds.l 1
clen		ds.l 1
cread		ds.l 1
strmhalf	ds.w 1		; Halfway MSB $00/$04/$08/$0C
pitch		ds.w 1
cblk		ds.w 1
cout		ds.w 1
pan		ds.b 1
env		ds.b 1
; len		ds.l 0
		endstruct

stmpc		struct
XC		ds.w 1
YC		ds.w 1
X		ds.l 1
Y		ds.l 1
DX		ds.l 1
DY		ds.l 1
TX		ds.l 1
TY		ds.l 1
xmul		ds.w 1
zmul		ds.w 1
zmul_sin	ds.w 1
zmul_cos	ds.w 1
rot_sin		ds.w 1
rot_cos		ds.w 1
; len		ds.l 0
		endstruct

stmpi		struct
map		ds.w 1
x		ds.w 1
y		ds.w 1
xr		ds.w 1
yd		ds.w 1
flags		ds.w 1
; len		ds.l 0
		endstruct

; ====================================================================
; ----------------------------------------------------------------
; Includes
; ----------------------------------------------------------------

		include "system/mcd/cdbios.asm"

; ====================================================================
; ----------------------------------------------------------------
; MAIN CODE
; ----------------------------------------------------------------

		phase $6000
		dc.b "MAIN-NIKONA",0
		dc.w $0100,0
		dc.l 0
		dc.l 0
		dc.l $20
		dc.l 0
.table:
		dc.w SCPU_Init-.table
		dc.w SCPU_Main-.table
		dc.w SCPU_IRQ-.table
		dc.w SCPU_User-.table
		dc.w 0

; ====================================================================
; ----------------------------------------------------------------
; Init
; ----------------------------------------------------------------

SCPU_Init:
		bclr	#3,(SCPU_reg+$33).w		; Disable Timer interrupt
		move.b	#$30,(SCPU_reg+$31).w		; Set timer value
		move.l	#SCPU_Timer,(_LEVEL3+2).l	; Write LEVEL 3 jump
		move.l	#SCPU_Stamp,(_LEVEL1+2).l	; Write LEVEL 1 jump
		bsr	spCdda_ResetVolume		; Reset CDDA Volume
		bsr	CdSub_PCM_Init			; Init PCM
		move.b	#0,(SCPU_reg+mcd_memory).l	; Reset Memory mode
		lea	(SCPU_RAM),a0
		moveq	#0,d0
		move.w	#($10000/4)-1,d1
.clr_ram:	move.w	d0,(a0)+
		dbf	d1,.clr_ram
		lea	.drv_init(pc),a0
		move.w	#DRVINIT,d0
		jsr	_CDBIOS
		bsr	spInitFS			; Init ISO Filesystem
		lea	.sub_file(pc),a0		; Search and load the PCM samples
		bsr	spSearchFile
		lea	(SCPU_DATA),a0
		bsr	spReadSectorsN
		move.b	#0,(SCPU_reg+mcd_comm_s).w	; Report we are free.
; 		bset	#3,(SCPU_reg+$33).w		; Enable Timer interrupt
		rts

; --------------------------------------------------------

.drv_init:	dc.b $01,$FF
		align 2
.sub_file:	dc.b "NKNA_SUB.BIN",0
		align 2

; =====================================================================
; ----------------------------------------------------------------
; Level 1 IRQ
; ----------------------------------------------------------------

SCPU_Stamp:
		clr.w	(RAM_CdSub_StampBusy).w
		rte

; =====================================================================
; ----------------------------------------------------------------
; Level 2 IRQ
;
; WARNING: The SEGA screen before starting calls this on
; every frame.
; ----------------------------------------------------------------

SCPU_IRQ:
		move.b	(SCPU_reg+mcd_comm_m).w,d0		; Read MAIN comm
		andi.w	#$C0,d0
		cmpi.w	#$C0,d0
		bne	.not_sound
		addq.b	#1,(RAM_CdSub_PcmReqUpd).w
		rts
.not_sound:
		cmpi.w	#$80,d0
		bne.s	.not_req
		st.b	(RAM_CdSub_StampReqUpd).w
.not_req:
		rts

; =====================================================================
; ----------------------------------------------------------------
; Level 3 IRQ
; ----------------------------------------------------------------

SCPU_Timer:
		rte

; =====================================================================
; ----------------------------------------------------------------
; User interrupt
; ----------------------------------------------------------------

SCPU_User:
		rts

; ====================================================================
; ----------------------------------------------------------------
; Main
;
; mcd_comm_m READ ONLY: %BBlpiiii
; BB | %01 Busy/Lock bit
;      %11 GEMA driver: table transfer request from Z80
; l  | If BB == %11: transfer LOCK bit
; p  | If BB == %11: transfer PASS bit, else: one extra bit for i
; i  | Current Sub-Task
;
; mcd_comm_s READ/WRITE: %Bbsseeee
; B | Sub-CPU is busy
; b | IRQ entrance
; s | Misc. status bits
; e | Error flag
;
; Uses:
; ALL
; ----------------------------------------------------------------

SCPU_Main:
		bsr	CdSub_PCM_Process
		bsr	CdSub_StampRender
		move.b	(SCPU_reg+mcd_comm_m).w,d0	; Read MAIN comm
		move.b	d0,d1
		andi.w	#$C0,d1
		cmpi.b	#$C0,d1				; Middle of IRQ task?
		beq.s	SCPU_Main
		andi.w	#%00011111,d0
		beq.s	SCPU_Main
		bset	#7,(SCPU_reg+mcd_comm_s).w	; Tell MAIN we are BUSY
		add.w	d0,d0				; Task index*2
		move.w	SCPU_cmdlist(pc,d0.w),d1
		jsr	SCPU_cmdlist(pc,d1.w)
		bclr	#7,(SCPU_reg+mcd_comm_s).w	; Tell MAIN we are done
		bra	SCPU_Main

; =====================================================================
; ----------------------------------------------------------------
; Commands list
; ----------------------------------------------------------------

; Struct
; $01-$07: Common data tasks
; $08-$0F: BRAM tasks
; $10-$17: CDDA Playback control
; $18-$1F: Stamps

SCPU_cmdlist:
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $00 | **INVALID**
		dc.w SubTask_cmnd01-SCPU_cmdlist	; $01 | Read file from disc, copy data through mcd_dcomm_s
		dc.w SubTask_cmnd02-SCPU_cmdlist	; $02 | Read file from disc, outputs to WORD-RAM
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $03
		dc.w SubTask_cmnd04-SCPU_cmdlist	; $04
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $05
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $06
		dc.w SubTask_cmnd07-SCPU_cmdlist	; $07 | Set 2M WORD-RAM permission to MAIN

		dc.w SubTask_cmnd08-SCPU_cmdlist	; $08 | BRAM support Initialize (MUST CALL FIRST)
		dc.w SubTask_cmnd09-SCPU_cmdlist	; $09 | BRAM Read data
		dc.w SubTask_cmnd0A-SCPU_cmdlist	; $0A | BRAM Save data
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $0B
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $0C
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $0D
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $0E
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $0F

		dc.w SubTask_cmnd10-SCPU_cmdlist	; $10 | Play CDDA once
		dc.w SubTask_cmnd11-SCPU_cmdlist	; $11 | Play CDDA and loop
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $12 |
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $13 |
		dc.w SubTask_cmnd14-SCPU_cmdlist	; $14 | Stop CDDA
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $15 |
		dc.w SubTask_cmnd16-SCPU_cmdlist	; $16 | CDDA fade-out
		dc.w SubTask_cmnd17-SCPU_cmdlist	; $17 | CDDA Reset volumes

		dc.w SubTask_cmnd18-SCPU_cmdlist	; $18 | Enable Stamps
		dc.w SubTask_cmnd19-SCPU_cmdlist	; $19 | Disable Stamps
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $1A |
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $1B |
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $1C |
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $1D |
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $1E |
		dc.w SubTask_cmnd00-SCPU_cmdlist	; $1F |

; =====================================================================
; ----------------------------------------------------------------
; Commands $01-$0F
;
; General purpose data transfering
; ----------------------------------------------------------------

; --------------------------------------------------------
; NULL COMMAND
; --------------------------------------------------------

SubTask_cmnd00:
		rts

; --------------------------------------------------------
; Command $01
;
; Read data from disc and transfer the output data
; through mcd_dcomm_s as packets of $10 bytes.
;
; Input:
; mcd_comm_m  | %lp------
;               l - LOCK bit set by MAIN-CPU
;               p - PASS bit
; mcd_dcomm_m | "FILENAME.BIN",0
;               Filename string 8.3 zero terminated
;
; Returns:
; mcd_comm_s  | %--ep----
;               p - SUB-CPU reports that data passed
;               e - Flag: 0 - Found file
;                         1 - File NOT found
; mcd_dcomm_s | $00-$10
;               Current data packet.
; --------------------------------------------------------

SubTask_cmnd01:
		lea	(SCPU_reg+mcd_dcomm_m).w,a0	; a0 - Filename
		bsr	spSearchFile
		bcs	SubTask_RetErr_NoFile
		tst.l	d1
		beq	SubTask_RetErr_NoFile
		lea	(ISO_Output).l,a0		; Temporal OUTPUT location
		move.l	a0,-(sp)
		bsr	spReadSectorsN
		move.l	(sp)+,a0			; a0 - Read temporal location
		lea	(SCPU_reg+mcd_dcomm_s).w,a2	; a1 - Output data packets
.next_packet:
		move.l	a2,a1
	rept $10/2
		move.w	(a0)+,(a1)+			; WORD writes
	endm
		move.b	(SCPU_reg+mcd_comm_s).w,d7	; Sub PASS the data.
		bset	#4,d7
		move.b	d7,(SCPU_reg+mcd_comm_s).w
.wait_main:	move.b	(SCPU_reg+mcd_comm_m).w,d7	; Read MAIN comm
		btst	#7,d7				; Locked?
		beq.s	.exit_now
		btst	#6,d7				; MAIN got the data?
		beq.s	.wait_main
		move.b	(SCPU_reg+mcd_comm_s).w,d7	; Clear Sub PASS bit.
		bclr	#4,d7
		move.b	d7,(SCPU_reg+mcd_comm_s).w
.wait_main_o:	move.b	(SCPU_reg+mcd_comm_m).w,d7	; Wait MAIN response
		btst	#6,d7
		bne.s	.wait_main_o
		bra.s	.next_packet
; Finished:
.exit_now:
		bclr	#4,(SCPU_reg+mcd_comm_s).w
		rts

; --------------------------------------------------------
; Command $02
;
; Read data from disc directly to WORD-RAM,
; REQUIRES THE DMNA BIT TO BE SET BY MAIN-CPU
;
; Input:
; mcd_dcomm_m | $00-$0C - "FILENAME.BIN",0
;             |           Filename string 8.3 incl. zero
;             |
;             | $0D - Destination increment * $800
;             | $0E -
;             | $0F -
;
; Note:
; DO NOT CALL THIS IF STAMPS ARE IN THE MIDDLE
; OF RENDERING
; --------------------------------------------------------

SubTask_cmnd02:
		move.b	(SCPU_reg+mcd_memory).l,d7	; Wait until MAIN sets Word-RAM to SUB. (DMNA)
		btst	#1,d7
		beq.s	SubTask_cmnd02

		lea	(SCPU_reg+mcd_dcomm_m).w,a0	; a0 - filename
		bsr	spSearchFile
		bcs	SubTask_RetErr_NoFile
		tst.l	d1
		beq	SubTask_RetErr_NoFile
		lea	(SCPU_wram),a0
		moveq	#0,d7
		move.b	(SCPU_reg+mcd_dcomm_m+$0D).w,d7
		lsl.w	#8,d7
		lsl.w	#3,d7
		add.l	d7,a0
		bsr	spReadSectorsN
.wait_ret:	bset	#0,(SCPU_reg+mcd_memory).l	; Return Word-RAM to MAIN (RET=1)
		beq.s	.wait_ret
		rts

; --------------------------------------------------------
; Command $04
;
; Transfer memory from MAIN-CPU to SUB-CPU in
; packets of 10-bytes.
;
; Input:
; mcd_comm_m  | %lp------
;               l - LOCK bit
;               p - PASS bit
; mcd_dcomm_m | BEFORE mcd_comm_s returns first PASS:
;               $00-$03    - Output Destination in Sub-CPU
;                         area
;               AFTER mcd_comm_s returns first PASS:
;               $00-$08 - Data packet
;
; Returns:
; mcd_comm_s  | %-------p
;               p - SUB-CPU got the data packet
; --------------------------------------------------------

SubTask_cmnd04:
		move.b	(SCPU_reg+mcd_comm_s).w,d7
		bset	#4,d7
		move.b	d7,(SCPU_reg+mcd_comm_s).w
.wait_enter:
		move.b	(SCPU_reg+mcd_comm_m).w,d7	; Wait for MAIN
		btst	#7,d7
		beq.s	.wait_enter
		lea	(SCPU_reg+mcd_dcomm_m).w,a2
		move.w	(a2),d7				; a1 - Destination
		swap	d7
		move.w	2(a2),d7
		move.l	d7,a1
		move.b	(SCPU_reg+mcd_comm_s).w,d7
		bclr	#4,d7
		move.b	d7,(SCPU_reg+mcd_comm_s).w
.next_packet:
		move.b	(SCPU_reg+mcd_comm_m).w,d7
		btst	#7,d7
		beq.s	.exit_now
		btst	#6,d7
		beq.s	.next_packet
		move.l	a2,a0
	rept 8/2
		move.w	(a0)+,(a1)+			; WORD writes to be safe...
	endm
		move.b	(SCPU_reg+mcd_comm_s).w,d7
		bset	#4,d7
		move.b	d7,(SCPU_reg+mcd_comm_s).w
.wait_main:	move.b	(SCPU_reg+mcd_comm_m).w,d7	; Wait MAIN
		btst	#6,d7
		bne.s	.wait_main
		move.b	(SCPU_reg+mcd_comm_s).w,d7
		bclr	#4,d7
		move.b	d7,(SCPU_reg+mcd_comm_s).w
		bra	.next_packet
.exit_now:
		rts

; --------------------------------------------------------
; Command $07
;
; Set Word-RAM permission to MAIN-CPU
; --------------------------------------------------------

SubTask_cmnd07:
		bset	#0,(SCPU_reg+mcd_memory).l	; Set WORD-RAM to MAIN, RET=1
		beq.s	SubTask_cmnd07
		rts

; =====================================================================
; ----------------------------------------------------------------
; Commands $08-$0F
;
; BRAM Management
;
; IF using CD32X: RV MUST BE ENABLED
; ----------------------------------------------------------------

; --------------------------------------------------------
; Command $08
;
; Init or check if SAVE file exists
;
; Input:
; mcd_dcomm_m | $00-$0B: dc.b "STR_SAVEDAT",0
;             |     $0C: Save Size / $40
;             |     $0E: Flags
;
; Returns:
; mcd_dcomm_s | $00.w:  0 | OK
;             |        -1 | File not found
;             |        -2 | Format error /
;             |             Not enough space
;             |
;             | $02.w: Back-up size
;             | $04.w: Flags
; --------------------------------------------------------

SubTask_cmnd08:
		bsr	SubTsk_BramCall
		bcs	.big_fail
		lea	(SCPU_reg+mcd_dcomm_m).w,a0
		lea	(RAM_CdSub_CurrSaveInfo).l,a1
		moveq	#($10/2)-1,d7
.copy_paste:
		move.w	(a0)+,(a1)+
		dbf	d7,.copy_paste
		lea	(RAM_CdSub_BramStrings).l,a1
		moveq	#BRMSTAT,d0
		jsr	_BURAM
		move.w	(SCPU_reg+mcd_dcomm_m+$0C).w,d7
		cmp.w	d7,d0				; Enough space?
		blt.s	.big_fail

		lea	(RAM_CdSub_CurrSaveInfo).l,a0
		move.w	#BRMSERCH,d0			; "SERCH"
		jsr	_BURAM
		bcs	SubTsk_ReturnFail
		lea	(SCPU_reg+mcd_dcomm_s).w,a6
		andi.w	#$FF,d1
		move.w	#0,(a6)				; Report OK
		move.w	d0,2(a6)			; Number of block of this save
		move.w	d1,4(a6)			; Mode: 0=normal -1=Protected
		rts

; No RAM / No Format
.big_fail:
		lea	(SCPU_reg+mcd_dcomm_s).w,a6
		move.w	#-2,(a6)			; Report FAIL
		move.w	d0,2(a6)			; Number of block of this save
		rts

; --------------------------------------------------------
; Command $09
;
; READ Save data, requires Word-RAM permission.
;
; Returns:
; mcd_dcomm_s | $00.w:
;             |  0 - OK
;             | -1 - Not found / Fatal error
; --------------------------------------------------------

SubTask_cmnd09:
		bsr	SubTsk_BramCall
		bcs	SubTsk_ReturnFail
.wait_dmna:	btst	#1,(SCPU_reg+mcd_memory).l		; Word-RAM Allowed (DMNA)?
		beq	.wait_dmna
		lea	(RAM_CdSub_CurrSaveInfo).l,a0
		lea	(SCPU_wram+WRAM_SaveDataCopy).l,a1
		moveq	#0,d1
		move.w	#BRMREAD,d0
		jsr	_BURAM
		bcs	SubTsk_ReturnFail
		bra	SubTask_cmnd07

; --------------------------------------------------------
; Command $0A
;
; WRITE Save data, requires Word-RAM permission.
;
; Returns:
; mcd_dcomm_s | $00.w:
;             |  0 - OK
;             | -1 - Not found
; --------------------------------------------------------

SubTask_cmnd0A:
		bsr	SubTsk_BramCall
		bcs	SubTsk_ReturnFail
.wait_dmna:	btst	#1,(SCPU_reg+mcd_memory).l		; Word-RAM Allowed (DMNA)?
		beq	.wait_dmna
		lea	(RAM_CdSub_CurrSaveInfo).l,a0
		lea	(SCPU_wram+WRAM_SaveDataCopy).l,a1
		moveq	#0,d1
		move.w	#BRMWRITE,d0
		jsr	_BURAM
		bcs	SubTsk_ReturnFail
		bra	SubTask_cmnd07

; --------------------------------------------------------

SubTsk_BramCall:
		lea	(RAM_CdSub_BramWork).l,a0
		lea	(RAM_CdSub_BramStrings).l,a1
		moveq	#BRMINIT,d0
		jsr	_BURAM
		rts
SubTsk_ReturnFail:
		move.w	#-1,(SCPU_reg+mcd_dcomm_s).w
		rts
; SubTsk_ReturnOk:
; 		move.w	#0,(SCPU_reg+mcd_dcomm_s).w
; 		rts

SubTask_RetErr_NoFile:
		move.b	#%00000001,(SCPU_reg+mcd_comm_s).w	; SET ERROR %0001

; 	; *** REMOVE THIS ON RELEASE ***
; 		move.w	#4,d1					; READY off | ACCESS blink
; 		move.w	#LEDSET,d0
; 		jmp	(_CDBIOS).w
; 	; ***
		rts

; =====================================================================
; ----------------------------------------------------------------
; Commands $10-$17
;
; CDDA
; ----------------------------------------------------------------

; --------------------------------------------------------
; Command $10
;
; Play CDDA Track, stops on finish.
;
; Input:
; mcd_dcomm_m | dc.w track_num
;               - DO NOT USE TRACK 1
;               - TRACK 0 IS INVALID
; --------------------------------------------------------

SubTask_cmnd10:
		move.w	#MSCSTOP,d0
		jsr	(_CDBIOS).w
		bsr	spCdda_ResetVolume
		lea	(SCPU_reg+mcd_dcomm_m).w,a0
		move.w	#MSCPLAY1,d0
		jmp	(_CDBIOS).w

; --------------------------------------------------------
; Command $11
;
; Play CDDA Track, loops indefiniely.
;
; Input:
; mcd_dcomm_m | dc.w track_num
;               - DO NOT USE TRACK 1
;               - TRACK 0 IS INVALID
; --------------------------------------------------------

SubTask_cmnd11:
		move.w	#MSCSTOP,d0
		jsr	(_CDBIOS).w
		bsr	spCdda_ResetVolume
		lea	(SCPU_reg+mcd_dcomm_m).w,a0
		move.w	#MSCPLAYR,d0
		jmp	(_CDBIOS).w

; --------------------------------------------------------
; Command $14
;
; Stop CDDA Track
; --------------------------------------------------------

SubTask_cmnd14:
		move.w	#MSCSTOP,d0
		jsr	(_CDBIOS).w
		bra	spCdda_ResetVolume

; --------------------------------------------------------
; Command $16
;
; Fade-out/Fade-in CD Volume
;
; Input:
; mcd_dcomm_m | dc.w target_vol,fade_speed
;               - Target volume: $000-$400 Max-Min
;               - Fade Speed:    $001-$200 Slow-Fast
;                                     $400 Set once
; --------------------------------------------------------

SubTask_cmnd16:
		move.l	(SCPU_reg+mcd_dcomm_m).w,d1
		move.w	#FDRCHG,d0
		jsr	(_CDBIOS).w
		rts

; --------------------------------------------------------
; Command $17
;
; CDDA Fade-out
; --------------------------------------------------------

SubTask_cmnd17:
; 		move.l	#$0380,d1
; 		move.w	#FDRSET,d0			; Set CDDA music volume
; 		jsr	(_CDBIOS).w
; 		move.l	#$0380|$8000,d1
; 		move.w	#FDRSET,d0			; Set CDDA music master volume
; 		jsr	(_CDBIOS).w
; 		rts

; --------------------------------------------------------
; CDDA subroutines:

spCdda_ResetVolume:
		movem.l	d0-d1/a0-a1,-(sp)
		move.w	#$0400,d1
		move.w	#FDRSET,d0			; Set CDDA music volume
		jsr	(_CDBIOS).w
		move.w	#$0400|$8000,d1
		move.w	#FDRSET,d0			; Set CDDA music master volume
		jsr	(_CDBIOS).w
		movem.l	(sp)+,d0-d1/a0-a1
		rts

; =====================================================================
; ----------------------------------------------------------------
; Commands $18-$1F
;
; Stamp rendering
; ----------------------------------------------------------------

; --------------------------------------------------------
; Command $18
;
; Init/Enable Stamps
;
; Input:
; mcd_dcomm_m | dc.w width,height
;               - Stamp Dot-Screen Width
;               - Stamp Dot-Screen Height
; --------------------------------------------------------

SubTask_cmnd18:
		lea	(SCPU_reg+mcd_dcomm_m).w,a1
		move.w	(a1),d0
		move.w	2(a1),d1
		move.w	d0,(RAM_CdSub_StampW).w
		move.w	d1,(RAM_CdSub_StampH).w
		move.w	#%000,(RAM_CdSub_StampSize).w	; Stamp type/size: 1x1 screen | 16x16 dot | RPT
		bsr	CdSub_StampResetVcell
		bsr	CdSub_StampDefaults
		move.w	#-1,(RAM_CdSub_StampCBuff).w
		move.w	#1,(RAM_CdSub_StampEnbl).w	; Enable Stamp rendering
		bset	#1,(SCPU_reg+$33).w
		rts

; --------------------------------------------------------
; Command $19
;
; Disable Stamps, DMNA must bet set.
; --------------------------------------------------------

SubTask_cmnd19:
		bclr	#1,(SCPU_reg+$33).w
 		move.b	(SCPU_reg+mcd_memory).w,d7
 		andi.b	#%00111,d7
 		move.b	d7,(SCPU_reg+mcd_memory).w		; Restore WRAM write mode
		move.w	#0,(SCPU_wram+WRAM_StampCurrFlip).l
		move.w	#0,(RAM_CdSub_StampEnbl).w		; Disable Stamp rendering
		move.w	#-1,(RAM_CdSub_StampCBuff).w
.set_ret:	bset	#0,(SCPU_reg+mcd_memory).w
		beq.s	.set_ret
		rts

; =====================================================================
; ----------------------------------------------------------------
; Subroutines
; ----------------------------------------------------------------

; --------------------------------------------------------
; CD-ROM data
; --------------------------------------------------------

; ------------------------------------------------
; spReadSectorsN
;
; Input:
; a0 - Destination
; d0 - Sector start
; d1 - Number of sectors
; ------------------------------------------------

spReadSectorsN:
		lea	(RAM_CdSub_FsBuff).l,a5
		andi.l	#$FFFF,d0
		andi.l	#$FFFF,d1
		move.l	d0,(a5)
		move.l	d1,4(a5)
		move.l	a0,8(a5)
		move.b	#%011,(SCPU_reg+4).w		; Set CDC device to "Sub CPU"
		move.w	#CDCSTOP,d0			; Stop CDC
		jsr	(_CDBIOS).w
		move.l	a5,a0
		move.w	#ROMREADN,d0			; Read sector by count
		jsr	(_CDBIOS).w
.wait_STAT:
		move.l	a5,-(sp)
		bsr	CdSub_PCM_Process
		move.l	(sp)+,a5
		move.w	#CDCSTAT,d0			; Get CDC Status
		jsr	(_CDBIOS).w
 		bcs.s	.wait_STAT
.wait_READ:
		move.l	a5,-(sp)
		bsr	CdSub_PCM_Process
		move.l	(sp)+,a5
		move.w	#CDCREAD,d0			; CDC Read mode
		jsr	(_CDBIOS).w
		bcs.s	.wait_READ
		move.l	d0,$10(a5)
.WaitTransfer:
		movea.l	8(a5),a0			; a0 - DATA Destination
		lea	$10(a5),a1			; a1 - HEADER out
		move.w	#CDCTRN,d0			; CDC Transfer data
		jsr	(_CDBIOS).w
		bcs.s	.waitTransfer
		move.w	#CDCACK,d0			; Finish read
		jsr	(_CDBIOS).w
		addi.l	#$800,8(a5)
		addq.l	#1,(a5)
		subq.l	#1,4(a5)
		bne.s	.wait_STAT
		rts

; ------------------------------------------------
; ISO9660 Driver
; ------------------------------------------------

spInitFS:
		movem.l	d0-d7/a0-a6,-(a7)
		moveq	#$10,d0			; Read sector number $10 (At $8000)
		moveq	#8,d1			; Read 8 sectors
		lea	(ISO_Filelist).l,a0
		move.l	a0,-(sp)
		bsr	spReadSectorsN
		move.l	(sp)+,a0		; Now use the actual output
		lea	$9C(a0),a1
		move.b	6(a1),d0		; Read sector where filelist is located.
		lsl.l	#8,d0
		move.b	7(a1),d0
		lsl.l	#8,d0
		move.b	8(a1),d0
		lsl.l	#8,d0
		move.b	9(a1),d0
		moveq	#8,d1			; Read 8 sectors
		bsr	spReadSectorsN
		movem.l	(a7)+,d0-d7/a0-a6
		rts

; --------------------------------------------------------
; spSearchFile
;
; Search a file on the disc
; FILELIST MUST BE LOADED WITH spInitFS ON INIT.
;
; Input:
; a0   | Filename string with zero termination
;
; Returns:
; bcs  | File NOT found / error
; bcc  | File found
;
; bcc:
; d0.l | Start sector
; d1.l | Number of sectors
; d2.l | Filesize
;
; Breaks:
; d4-d7,a6
; --------------------------------------------------------

spSearchFile:
		lea	(ISO_Filelist).l,a4	; a4 - Root filelist
		moveq	#0,d0
		moveq	#0,d1
		moveq	#0,d2
.next_file:
		move.b	(a4),d7			; d7 - Block size
		beq.s	.failed_srch
		andi.w	#$FF,d7
		move.l	a4,a3			; a3 - Current file block
		adda	#$19,a3			; Go to flags
		move.b	(a3),d6
		bne.s	.non_file		; $00: iso_file, non-Zero: iso_setfs
		adda	#$07,a3			; Go to Filename string
		moveq	#0,d6
		move.b	(a3)+,d6
		subq.w	#3+1,d6
		move.l	a0,a2			; a2 - string to seach for
.chk_str:
		move.b	(a3)+,d5
		cmp.b	(a2)+,d5
		bne.s	.non_file
		dbf	d6,.chk_str
		bra.s	.found_file
.non_file:
		adda	d7,a4			; Next block
		bra.s	.next_file
.found_file:
		move.l	$06(a4),d0		; d0 - Sector position
		move.l	$0E(a4),d1		; d1 - Number of sectors
		move.l	d1,d2			; d2 - ORIGINAL filesize
		lsr.l	#8,d1			; bitshift d1
		lsr.l	#3,d1
		move	#0,ccr
		rts
.failed_srch:
		move	#1,ccr
		rts

; =====================================================================
; ----------------------------------------------------------------
; Stamps rendering
; ----------------------------------------------------------------

CdSub_StampRender:
		move.w	(RAM_CdSub_StampEnbl).w,d7	; Stamp rendering enabled?
		beq	.exit_render
		btst	#1,(SCPU_reg+mcd_memory).l	; Word-RAM allowed (DMNA)?
		beq	.exit_render
; 		bset	#7,(SCPU_reg+mcd_comm_s).w
		tst.b	(RAM_CdSub_StampReqUpd).w	; MAIN wants WRAM?
		beq	.no_break
		clr.b	(RAM_CdSub_StampReqUpd).w
.wait_done:
		bsr	CdSub_PCM_Process
		move.b	($FFFF8058).w,d7
		bmi.s	.wait_done
; 		bset	#3,(SCPU_reg+mcd_comm_s).w
; 		tst.b	(RAM_CdSub_StampBusy).w
; 		bne.s	.wait_done
.wait_ret:	bset	#0,(SCPU_reg+mcd_memory).l	; Return Word-RAM to MAIN
		beq.s	.wait_ret
		bra	.exit_render			; Exit
.no_break:

; ----------------------------------------
; Genesis request
; ----------------------------------------

		move.w	(SCPU_wram+WRAM_StampCurrFlip).l,d7
		move.w	(RAM_CdSub_StampCBuff).w,d6
		cmp.w	d6,d7
		beq	.flip_turn
		move.w	d7,(RAM_CdSub_StampCBuff).w
; 		move.w	#0,(SCPU_wram+WRAM_StampsDone).l
; 		bclr	#3,(SCPU_reg+mcd_comm_s).w
		bsr	CdSub_PCM_Process
		bsr	.make_list
		bsr	CdSub_PCM_Process
		bsr	.trace_blank
		move.w	#0,(RAM_CdSub_StampNextRd).w		; Start the engine
		move.w	#$780,(RAM_CdSub_StampNextWr).w
		st.b	(RAM_CdSub_DotClearFlag).w
		bsr	CdSub_PCM_Process
.flip_turn:

; ----------------------------------------
; Main engine
; ----------------------------------------

; 		move.w	(SCPU_wram+WRAM_StampsDone).l,d7
		move.b	(SCPU_reg+mcd_comm_s).w,d7
		btst	#3,d7
		bne	.return_ret
; 		move.b	($FFFF8058).w,d7
; 		bmi.s	.exit_render
		tst.b	(RAM_CdSub_StampBusy).w			; Check if current Stamp finished
		bne	.exit_render
		bsr	CdSub_PCM_Process
		bsr	.process_trace
		eori.w	#$780,(RAM_CdSub_StampNextRd).w
		bsr	CdSub_PCM_Process
		bsr	.make_stamp
		tst.w	(RAM_CdSub_StampNum).w
		bne	.exit_render
; 		move.w	#1,(SCPU_wram+WRAM_StampsDone).l

; ------------------------------------------------
; All stamps are checked
; ------------------------------------------------

.return_ret:
; 		move.b	($FFFF8058).w,d7
; 		bmi.s	.return_ret
		bsr	CdSub_PCM_Process
		tst.b	(RAM_CdSub_StampBusy).w
		bne	.return_ret
		bsr	CdSub_StampDefaults
; 		bclr	#7,(SCPU_reg+mcd_comm_s).w
		move.w	#-1,(RAM_CdSub_StampCBuff).w
.wait_rete:	bset	#0,(SCPU_reg+mcd_memory).l		; Set RET
		beq.s	.wait_rete
; 		bset	#3,(SCPU_reg+mcd_comm_s).w

; ------------------------------------------------
; Exit
; ------------------------------------------------

.exit_render:
		bra	CdSub_PCM_Process

; =====================================================================
; ------------------------------------------------
; Make a list of available stamps to use
; ------------------------------------------------

.make_list:
		lea	(SCPU_wram+WRAM_MdStampList).l,a0
		lea	(RAM_CdSub_StampList).l,a1
		moveq	#MAX_MCDSTAMPS-1,d7
.loop_list:
		move.b	cdstamp_flags(a0),d6		; %Et00000R
		btst	#7,d6
		beq.s	.no_stamp
		move.l	a0,(a1)
		adda	#8,a1
.no_stamp:
		adda	#$20,a0
		dbf	d7,.loop_list
		rts

; ------------------------------------------------
; Make stamp from the generated list
; ------------------------------------------------

.make_stamp:
		clr.w	(RAM_CdSub_StampNum).w
.retry:
		moveq	#0,d7
		move.w	(RAM_CdSub_StampIndxW).w,d7
		addq.w	#1,(RAM_CdSub_StampIndxW).w
		move.w	d7,d6
		lsl.w	#3,d7
		lea	(RAM_CdSub_StampList).l,a0
		move.l	(a0,d7.w),d0
		beq.s	.exit_last
		clr.l	(a0,d7.w)
		move.l	d0,a0
		bsr	.make_trace
		bcs	.retry
		addq.w	#1,(RAM_CdSub_StampNum).w
		eori.w	#$780,(RAM_CdSub_StampNextWr).w
.exit_last:
		rts

; =====================================================================
; ------------------------------------------------
; Clear all the dot-screen
;
; Uses:
; a1,d0
; ------------------------------------------------

.trace_blank:
		lea	(SCPU_wram+WRAM_TraceBuff).l,a0
		moveq	#(256/16)-1,d0
.reset_out:
	rept 16
		move.l	#$FFF8,(a0)+
		move.l	#0,(a0)+
	endm
		dbf	d0,.reset_out
		rts

; =====================================================================
; ------------------------------------------------
; Make the trace data
;
; Input:
; a0 - Current stamp
; a1 - Output trace location
; a6 - Stamp math buffer
; d1.w - Center X
; d2.w - Center Y
; ------------------------------------------------

.make_trace:
		lea	(RAM_CdSub_StampProc).l,a6
		lea	(RAM_CdSub_StampOutBox).w,a5
		moveq	#0,d7
		move.b	cdstamp_map(a0),d7
		lsl.l	#8,d7
		lsl.l	#3,d7
		add.l	#WRAM_MdMapTable,d7
		lsr.l	#2,d7
		move.w	d7,stmpi_map(a5)
		move.w	cdstamp_scale(a0),d6
		cmp.w	#-$400,d6
		blt	.invalid
		cmp.w	#$100,d6
		bge	.invalid

	; ------------------------------------------------
	; Trace texture
		moveq	#0,d1
		moveq	#0,d2
		move.w	cdstamp_wdth(a0),d1
		move.w	cdstamp_hght(a0),d2
		move.w	cdstamp_scale(a0),d3
		move.w	d3,d4
		muls.w	#SET_STAMPPOV,d3
		asr.l	#8,d3
		tst.w	d3
		bpl.s	.splusv
		asr.l	#3,d3
.splusv:
		addi.w	#48,d1
		addi.w	#48,d2
		add.w	d3,d1
		add.w	d3,d2
		move.w	(RAM_CdSub_StampW).w,d3
		move.w	(RAM_CdSub_StampH).w,d4
		lsr.w	#1,d1
		lsr.w	#1,d2
		lsr.w	#1,d3
		lsr.w	#1,d4
		neg.w	d3
		neg.w	d4
		move.w	cdstamp_x(a0),d7
		move.w	cdstamp_y(a0),d6
		sub.w	d1,d7
		sub.w	d2,d6
		cmp.w	d3,d7
		bge.s	.no_xl
		sub.w	d3,d7
		add.w	d7,d1
.no_xl:
		cmp.w	d4,d6
		bge.s	.no_yl
		sub.w	d4,d6
		add.w	d6,d2
.no_yl:
; 		addi.w	#8,d1
; 		addi.w	#8,d2
; 		move.w	#SET_STAMPPOV,d7
; 		add.w	cdstamp_scale(a0),d7
; 		muls.w	d7,d2
; 		muls.w	d7,d1
; 		asr.l	#8,d2
; 		asr.l	#8,d1

		neg.w	d1
		neg.w	d2
		bsr	.mk_vars
		lea	(SCPU_wram+WRAM_TraceBuff).l,a4
		move.w	(RAM_CdSub_StampNextWr).w,d6
		adda	d6,a4
		move.w	(RAM_CdSub_StampH).w,d7
		subq.w	#1,d7
.next_line:
		move.w	stmpc_XC(a6),d6
		muls.w	d2,d6
		add.l	stmpc_X(a6),d6
		asr.l	#5,d6
		move.w	d6,(a4)+			; X pos
		move.w	stmpc_YC(a6),d6
		muls.w	d2,d6
		sub.l	stmpc_Y(a6),d6
		asr.l	#5,d6
		move.w	d6,(a4)+			; Y pos
		move.l	stmpc_TX(a6),d6
		asr.l	#5,d6
		move.w	d6,(a4)+			; X Delta
		move.l	stmpc_TY(a6),d6
		asr.l	#5,d6
		move.w	d6,(a4)+			; Y Delta

		addq.w	#1,d2
		dbf	d7,.next_line

	; ------------------------------------------------
	; Expand out size
		move.w	cdstamp_wdth(a0),d7
		move.w	cdstamp_hght(a0),d6
		addi.w	#48,d7
		addi.w	#48,d6
		move.w	cdstamp_scale(a0),d5
		move.w	d5,d4
		muls.w	#SET_STAMPPOV,d5
		asr.l	#8,d5
		tst.w	d4
		bpl.s	.splus
		asr.l	#3,d5
.splus:
		add.w	d5,d7
		add.w	d5,d6
		move.w	d7,d5
		move.w	d6,d4
		move.w	cdstamp_x(a0),d0
		move.w	cdstamp_y(a0),d1
		lsr.w	#1,d5
		lsr.w	#1,d4
		sub.w	d5,d0
		sub.w	d4,d1
		move.w	d0,d2
		move.w	d1,d3
		add.w	d7,d2
		add.w	d6,d3
		move.w	(RAM_CdSub_StampW).w,d4		; Add center
		move.w	(RAM_CdSub_StampH).w,d5
		move.w	d4,d7
		move.w	d5,d6
		lsr.w	#1,d7
		lsr.w	#1,d6
		add.w	d7,d0
		add.w	d6,d1
		add.w	d7,d2
		add.w	d6,d3


; 		muls.w	d5,d2
; 		muls.w	d5,d3
; 		asr.l	#8,d2
; 		asr.l	#8,d3

	; d0 - X Left
	; d1 - Y top
	; d2 - X right
	; d3 - Y down
; 		move.w	(RAM_CdSub_StampW).w,d4
; 		move.w	(RAM_CdSub_StampH).w,d5
		subi.w	#16,d4
		subi.w	#16,d5
		move.w	d2,d7
		subi.w	#16,d7
		tst.w	d7
		bmi.s	.invalid
		move.w	d3,d7
		subi.w	#16,d7
		tst.w	d7
		bmi.s	.invalid
		cmp.w	d4,d0
		bge.s	.invalid
		cmp.w	d5,d1
		bge.s	.invalid
		addi.w	#16,d4
		addi.w	#16,d5
		tst.w	d0
		bpl.s	.xl_p
		clr.w	d0
.xl_p:		tst.w	d1
		bpl.s	.yl_p
		clr.w	d1
.yl_p:		cmp.w	d4,d2
		blt.s	.xr_p
		move.w	d4,d2
.xr_p:		cmp.w	d5,d3
		blt.s	.yr_p
		move.w	d5,d3
.yr_p:
		move.w	d0,stmpi_x(a5)
		move.w	d1,stmpi_y(a5)
		move.w	d2,stmpi_xr(a5)
		move.w	d3,stmpi_yd(a5)
		and	#%11110,ccr
		rts

.invalid:
		or	#1,ccr
		rts

; ------------------------------------------------

.mk_vars:
		move.w	cdstamp_rot(a0),d7
		move.w	d7,d5
		bsr	CdSub_SineWave
		move.w	d7,d6
		move.w	d5,d7
		bsr	CdSub_SineWave_Cos
		move.w	d6,stmpc_rot_sin(a6)
		move.w	d7,stmpc_rot_cos(a6)

		move.w	#0,d4
		move.w	#0,d5
		move.w	cdstamp_scale(a0),d6
		move.w	#SET_STAMPPOV,d7
		sub.w	d6,d7
		move.w	d7,stmpc_zmul(a6)	; Z multi
; 		move.w	d4,d7
; 		move.w	d7,stmpc_xmul(a6)	; X multi
		move.w	stmpc_zmul(a6),d7
		muls.w	stmpc_rot_cos(a6),d7
		asr.l	#8,d7
		move.w	d7,stmpc_zmul_cos(a6)
		move.w	stmpc_zmul(a6),d7
		muls.w	stmpc_rot_sin(a6),d7
		asr.l	#8,d7
		move.w	d7,stmpc_zmul_sin(a6)
		move.w	#SET_STAMPPOV,d7
		sub.w	d6,d7
		muls.w	stmpc_rot_sin(a6),d7
		asr.l	#8,d7
		move.w	d7,stmpc_XC(a6)
		move.w	#SET_STAMPPOV,d7
		sub.w	d6,d7
		muls.w	stmpc_rot_cos(a6),d7
		asr.l	#8,d7
		move.w	d7,stmpc_YC(a6)

		move.w	stmpc_xmul(a6),d7
		muls.w	stmpc_rot_cos(a6),d7
		move.w	d5,d6
		muls.w	stmpc_rot_sin(a6),d6
		add.l	d6,d7
		moveq	#0,d6
		move.w	cdstamp_cx(a0),d6
		lsl.l	#8,d6
		add.l	d6,d7
		move.l	d7,stmpc_X(a6)
		move.w	stmpc_xmul(a6),d7
		muls.w	stmpc_rot_sin(a6),d7
		move.w	d5,d6
		muls.w	stmpc_rot_cos(a6),d6
		sub.l	d6,d7
		moveq	#0,d6
		move.w	cdstamp_cy(a0),d6
		lsl.l	#8,d6
		sub.l	d6,d7
		move.l	d7,stmpc_Y(a6)

		move.w	stmpc_zmul_cos(a6),d7
		muls.w	d1,d7
		add.l	d7,stmpc_X(a6)
		move.w	stmpc_zmul_sin(a6),d7
		muls.w	d1,d7
		add.l	d7,stmpc_Y(a6)

		move.w	stmpc_zmul_cos(a6),d7
		ext.l	d7
		asl.l	#8,d7
		move.l	d7,stmpc_TX(a6)
		move.w	stmpc_zmul_sin(a6),d7
		neg.w	d7
		ext.l	d7
		asl.l	#8,d7
		move.l	d7,stmpc_TY(a6)
		rts

; =====================================================================
; ------------------------------------------------
; Send trace to ASIC
;
; Input:
; d0.w | Map location / 2
; d1.w | X pos
; d2.w | Y pos
; d3.w | Width
; d4.w | Height
;
; Uses:
; d5-d7
; ------------------------------------------------

.process_trace:
		bsr	CdSub_PCM_Process
		bclr	#0,(RAM_CdSub_DotClearFlag).w	; Clear dotscreen flag?
		bne	.clear_frame
		lea	(RAM_CdSub_StampOutBox).w,a0
		move.w	stmpi_map(a0),d0
		move.w	stmpi_x(a0),d1			; X left
		move.w	stmpi_y(a0),d2			; Y top
		move.w  stmpi_xr(a0),d3			; X right
		move.w  stmpi_yd(a0),d4			; Y bottom
		sub.w	d1,d3				; XR-XL
		sub.w	d2,d4				; YB-YT
		moveq	#%10,d6				; Overwrite mode
 		move.b	(SCPU_reg+mcd_memory).w,d7
 		andi.b	#%00111,d7
 		andi.w	#%11,d6
 		lsl.w	#3,d6
 		or.w	d6,d7
 		move.b	d7,(SCPU_reg+mcd_memory).w	; Set Normal or Overwrite
 		moveq	#0,d6				; RPT bit
 		move.w	(RAM_CdSub_StampSize).w,d7
 		andi.w	#%110,d7
 		andi.w	#%001,d6
 		or.w	d6,d7
		move.w	d7,($FFFF8058).w		; Stamp data size
		move.w  d0,($FFFF805A).w		; d0 - Stamp map location

	; X,Y,W,H
		move.l	#WRAM_DotOutput_0,d7
		tst.w	(RAM_CdSub_StampCBuff).w
		beq.s	.dot_0
		move.l	#WRAM_DotOutput_1,d7
.dot_0:
		moveq	#0,d6
		move.w	d1,d5
		asr.w	#3,d5
		move.w	(RAM_CdSub_StampH).w,d6
		muls.w	d5,d6
		asl.l	#2,d6
		add.l	d6,d7
		move.l	d2,d5
		andi.w	#-8,d5
		lsl.l	#2,d5
		add.l	d5,d7
		andi.l	#%111,d1
		andi.l	#%111,d2
		lsl.w	#3,d2
		or.w	d2,d1
		lsr.l	#2,d7
		move.w  d1,($FFFF8060).w		; Output image buffer offset
		move.w  d7,($FFFF805E).w		; Output image buffer start address
		move.w	d3,($FFFF8062).w		; Image buffer H dot
		move.w	d4,($FFFF8064).w		; Image buffer V dot **
		moveq	#0,d7
		move.w	(RAM_CdSub_StampNextRd).w,d7
		add.l	#WRAM_TraceBuff,d7
		lsr.l	#2,d7
		move.w  d7,($FFFF8066).w		; Image trace vector base address (START)
		st.b	(RAM_CdSub_StampBusy).w
		bra	CdSub_PCM_Process

; ----------------------------------------------------------------
; FIRST FRAME ONLY

.clear_frame:
		bsr	CdSub_PCM_Process
 		move.b	(SCPU_reg+mcd_memory).w,d7
 		andi.b	#%00111,d7
 		move.b	d7,(SCPU_reg+mcd_memory).w	; Set Normal or Overwrite
		move.w	#0,($FFFF8058).w		; Stamp data size
		move.w  #0,($FFFF805A).w		; d0 - Stamp map location
		move.l	#WRAM_DotOutput_0,d6
		tst.w	(RAM_CdSub_StampCBuff).w
		beq.s	.dotc_0
		move.l	#WRAM_DotOutput_1,d6
.dotc_0:
		lsr.l	#2,d6
		move.w  d6,($FFFF805E).w		; Output image buffer start address
		move.w  #0,($FFFF8060).w		; Output image buffer offset
		move.w	(RAM_CdSub_StampW).w,d5
		move.w	(RAM_CdSub_StampH).w,d4
		move.w	d5,($FFFF8062).w		; Image buffer H dot
		move.w	d4,($FFFF8064).w		; Image buffer V dot **
		moveq	#0,d7
		move.w	(RAM_CdSub_StampNextRd).w,d7
		add.l	#WRAM_TraceBuff,d7
		lsr.l	#2,d7
		move.w  d7,($FFFF8066).w		; Image trace vector base address (START)
		st.b	(RAM_CdSub_StampBusy).w
		bra	CdSub_PCM_Process

; =====================================================================
; ----------------------------------------------------------------
;
; ----------------------------------------------------------------

CdSub_SineWave_Cos:
		addi.w  #$80,d7
CdSub_SineWave:
		move.l	d6,-(sp)
		andi.w	#$1FF,d7
		move.w	d7,d6
		btst	#7,d7
		beq.s	.loc_7EFA
		not.w	d6
.loc_7EFA:
		andi.w  #$7F,d6
		lsl.w   #1,d6
		move.w  .sine_data(pc,d6.w),d6
		btst    #8,d7
		beq.s   .loc_7F0C
		neg.w   d6
.loc_7F0C:
		move.w  d6,d7
		move.l  (sp)+,d6
		rts

; ------------------------------------------------

.sine_data:
		binclude "system/md/data/sine_data.bin"
		align 2

; =====================================================================
; ------------------------------------------------
; Flip output Dotscreen
; ------------------------------------------------

CdSub_StampResetVcell:
		move.w  (RAM_CdSub_StampH).w,d6		; Image V cell size
		lsr.w	#3,d6
		subq.w	#1,d6
		move.w  d6,($FFFF805C).w
CdSub_StampDefaults:
		clr.w	(RAM_CdSub_StampIndxW).w
		clr.w	(RAM_CdSub_StampNextWr).w
		clr.w	(RAM_CdSub_StampNextRd).w
		clr.w	(RAM_CdSub_DotClearFlag).w
		clr.w	(RAM_CdSub_StampBusy).w
		clr.w	(RAM_CdSub_StampNum).w
		rts

; =====================================================================
; ----------------------------------------------------------------
; PCM sound
; ----------------------------------------------------------------

; --------------------------------------------------------
; CdSub_PCM_Init
; --------------------------------------------------------

; PCM WAVE RAM setup:
; $0000-$7FFF | Streaming data blocks, $1000 each
; $8000-$8FFF | Silence block "emergency stop"

CdSub_PCM_Init:
		lea	(SCPU_pcm),a6		; a6 - PCM registers
		move.b	#-1,ONREG(a6)
		moveq	#0,d0			; d0 - BLANK byte
		moveq	#-1,d1			; d1 - LOOP byte
		move.w	#$80,d2			; d2 - Current BANK
		moveq	#$0F+1,d7		; $0000-$9FFF
		lea	$2000(a6),a5		; a5 - WAVE RAM
.clr_pwm:
		move.b	d2,CTREG(a6)
		nop
		nop
		move.l	a5,a4
		move.w	#$0FF0-1,d6
.wr_end:	move.w	d0,(a4)+
		dbf	d6,.wr_end
	rept $10
		move.w	d1,(a4)+
	endm
		addq.b	#$01,d2
		dbf	d7,.clr_pwm
		st.b	(RAM_CdSub_PcmEnbl).w
		rts

; ============================================================
; --------------------------------------------------------
; CdSub_PCM_Process
;
; Checks for playback changes
; --------------------------------------------------------

CdSub_PCM_Process:
		bsr	CdSub_PCM_Stream
		tst.b	(RAM_CdSub_PcmReqUpd).w
		beq.s	.no_req
		bsr	.get_table
		bsr	CdSub_PCM_Stream
		bsr	CdSub_PCM_ReadTable
		bsr	CdSub_PCM_Stream
		bsr	CdSub_PCM_Stream
		bsr	CdSub_PCM_Stream
		move.b	(RAM_CdSub_PcmEnbl).w,(SCPU_pcm+ONREG).l
		subq.b	#1,(RAM_CdSub_PcmReqUpd).w
		bra	CdSub_PCM_Process
.no_req:
		rts

; ------------------------------------------------
; Get PCM table from Z80
; ------------------------------------------------

.get_table:
		lea	(RAM_CdSub_PcmTable).l,a1		; a1 - PCM Table output
		lea	(SCPU_reg+mcd_dcomm_m+8).w,a2		; a2 - Data input
.trnsfr_mode:
		move.b	(SCPU_reg+mcd_comm_s).w,d0		; Tell Z80 we are here.
		andi.w	#%00001111,d0				; Flag $Cx
		or.b	#%11000000,d0
		move.b	d0,(SCPU_reg+mcd_comm_s).w
.wait_start:
		move.b	(SCPU_reg+mcd_comm_m).w,d0		; Z80 lock bit set?
		btst	#5,d0
		beq.s	.wait_start
		move.b	(SCPU_reg+mcd_comm_s).w,d0
		andi.w	#%11000000,d0
		move.b	d0,(SCPU_reg+mcd_comm_s).w
.next_packet:
		move.b	(SCPU_reg+mcd_comm_m).l,d0		; Read MAIN comm
		btst	#5,d0					; Still LOCKed?
		beq.s	.exit_now				; If not, finish.
		btst	#4,d0					; PASS bit set?
		beq.s	.next_packet
		move.l	a2,a0
	rept $08/2
		move.w	(a0)+,(a1)+				; Copying as WORDs
	endm
		bset	#4,(SCPU_reg+mcd_comm_s).w
.wait_main:
		move.b	(SCPU_reg+mcd_comm_m).w,d0		; PASS bit cleared?
		btst	#4,d0
		bne.s	.wait_main
		bclr	#4,(SCPU_reg+mcd_comm_s).w
		bra	.next_packet
.exit_now:
		move.b	(SCPU_reg+mcd_comm_s).w,d0
		andi.w	#%00001111,d0
		move.b	d0,(SCPU_reg+mcd_comm_s).w
.not_now:
		rts

; --------------------------------------------------------
; CdSub_PCM_ReadTable
; --------------------------------------------------------

CdSub_PCM_ReadTable:
		lea	(RAM_CdSub_PcmBuff).l,a6
		lea	(RAM_CdSub_PcmTable).l,a5
		lea	(SCPU_pcm),a4
		moveq	#8-1,d7				; 8 channels
		moveq	#0,d6				; Starting channel number
.get_tbl:
		move.b	(a5),d5
		bclr	#3,d5				; Update only?
		beq.s	.no_updset
		bsr	.get_chnlset
		bsr	.update_set
.no_updset:
		bclr	#2,d5				; Key-cut?
		beq.s	.no_keyoff
		bsr	.cdcom_keycut
.no_keyoff:
		bclr	#1,d5				; Key-off?
		beq.s	.no_keycut
		bsr	.cdcom_keyoff
.no_keycut:
		bclr	#0,d5				; Key-on?
		beq.s	.no_comm
		bsr	.cdcom_keyon
.no_comm:
		move.b	#0,(a5)+
		adda	#cdpcm_len,a6			; Next PCM buffer
		addq.w	#1,d6
		dbf	d7,.get_tbl
		rts

; --------------------------------------------------------
; pcmcom:b
; 0 - Playback bits: %0000PCOK /Pitchbend/keyCut/keyOff/KeyOn
; 8 - Pitch MSB
; 16 - Pitch LSB
; 24 - Volume
; 32 - Panning %RRRRLLLL
; 40 - LoopEnable bit | 24-bit sample location in Sub-CPU area
; 48
; 56
;
; a0 - table

.cdcom_keyon:
		bsr	.cdcom_keycut
		bsr	.get_chnlset
		moveq	#0,d0
		move.b	40(a0),d0		; 40
		move.b	d0,d3
		andi.w	#$7F,d0
		swap	d0
		move.b	48(a0),d0		; 48
		lsl.w	#8,d0
		move.b	56(a0),d0		; 56
		move.l	d0,a2
		moveq	#0,d0
		moveq	#0,d1			; Read LEN
		move.b	(a2)+,d0
		rol.w	#8,d0
		move.b	(a2)+,d0
		ror.w	#8,d0
		move.b	(a2)+,d1
		swap	d1
		or.l	d1,d0
		move.l	d0,cdpcm_length(a6)
		moveq	#0,d1
		moveq	#0,d0
		move.b	(a2)+,d0
		rol.w	#8,d0
		move.b	(a2)+,d0
		ror.w	#8,d0
		move.b	(a2)+,d1
		swap	d1
		or.l	d1,d0
		move.l	d0,cdpcm_loop(a6)
		move.l	a2,cdpcm_start(a6)
		rol.b	#1,d3
		andi.b	#1,d3
		move.b	d3,cdpcm_flags(a6)

	; Setup stream
		move.l	cdpcm_start(a6),cdpcm_cread(a6)
		move.l	cdpcm_length(a6),cdpcm_clen(a6)
		move.w	#0,cdpcm_cout(a6)
		move.w	#($1000/SET_PCMBLK),cdpcm_cblk(a6)
		bsr	.update_set
	; Start/End
		moveq	#0,d0
		move.b	d6,d0
		lsl.w	#4,d0
		move.b	d0,ST(a4)
		lsl.w	#8,d0
		cmp.l	#$1000-$10,cdpcm_length(a6)
		bcs.s	.small_sampl
		bset	#6,cdpcm_status(a6)
		bra.s	.cont_tloop
.small_sampl:
		bclr	#6,cdpcm_status(a6)
		moveq	#0,d1
		move.w	d0,d1
		move.w	#$8000,d0
		btst	#0,cdpcm_flags(a6)
		beq.s	.cont_tloop
		move.l	cdpcm_loop(a6),d0
		add.l	d1,d0
.cont_tloop:
		move.b	d0,LSL(a4)
		lsr.w	#8,d0
		move.b	d0,LSH(a4)
		bclr	d6,(RAM_CdSub_PcmEnbl).w
		bset	#7,cdpcm_status(a6)
		rts
.cdcom_keyoff:
; 		bset	d6,(RAM_CdSub_PcmEnbl).w
; 		move.b	(RAM_CdSub_PcmEnbl).w,ONREG(a4)
; 		rts
.cdcom_keycut:
		clr.w	cdpcm_cblk(a6)
		clr.b	cdpcm_status(a6)
		bset	d6,(RAM_CdSub_PcmEnbl).w
		move.b	(RAM_CdSub_PcmEnbl).w,ONREG(a4)
		move.b	d6,d0			; Set PCM to control mode
		or.b	#$C0,d0
		move.b	d0,CTREG(a4)
		move.b	#$80,ST(a4)
		move.w	#$8000,d0
		move.b	d0,LSL(a4)
		lsr.w	#8,d0
		move.b	d0,LSH(a4)
		move.w	#$1000/SET_PCMBLK,cdpcm_cblk(a6)
		move.w	#0,cdpcm_cout(a6)
		move.l	#0,cdpcm_clen(a6)
		bset	#7,cdpcm_status(a6)
		rts
.get_chnlset:
		move.l	a5,a0
		move.b	8(a0),d0		; 8 - Pitch MSB
		lsl.w	#8,d0
		move.b	16(a0),d0		; 16 - Pitch LSB
		move.b	24(a0),d1		; 24 - Volume
		move.b	32(a0),d2		; 32 - Panning
		move.w	d0,cdpcm_pitch(a6)
		move.b	d1,cdpcm_env(a6)
		move.b	d2,cdpcm_pan(a6)
		rts

; ------------------------------------------------
; Channel changes
;
; *DISABLE TIMER INTERRUPT*
; ------------------------------------------------

.update_set:
		move.b	d6,d0			; Set PCM to control mode
		or.b	#$C0,d0
		move.b	d0,CTREG(a4)
		move.w	cdpcm_pitch(a6),d0	; Write frequency
		move.b	d0,FDL(a4)
		lsr.w	#8,d0
		move.b	d0,FDH(a4)
		move.b	cdpcm_pan(a6),d0	; Panning
		move.b	d0,PAN(a4)
		move.b	cdpcm_env(a6),d0	; Envelope
		move.b	d0,ENV(a4)
		rts

; ============================================================
; --------------------------------------------------------
; CdSub_PCM_Stream
; --------------------------------------------------------

CdSub_PCM_Stream:
		lea	(RAM_CdSub_PcmBuff).l,a6
		lea	(SCPU_pcm),a5
		lea	$21(a5),a4
		moveq	#8-1,d7					; 8 channels
		moveq	#0,d6					; Starting channel number
.pick_stream:
		tst.b	cdpcm_status(a6)			; Streaming enabled?
		bpl	.no_strm
		tst.w	cdpcm_cblk(a6)				; Blocks counter
		bne.s	.mid_blocks
		btst	#6,cdpcm_status(a6)			; Larger sample?
		beq	.no_strm				; Finish now then.
		move.b	2(a4),d0				; d0 - PCM current position
		move.b	(a4),d1
		lsl.w	#8,d0
		move.b	d1,d0
		move.w	cdpcm_cout(a6),d1			; d1 - Buffer's pos
		move.w	#$1000/2,d2				; Only check halfs
		and.w	d2,d0
		and.w	d2,d1
		eor.w	d0,d1					; Check if halfs changed
		beq.s	.no_strm
		move.w	#($1000/SET_PCMBLK)/2,cdpcm_cblk(a6)	; Make new blocks, half.
.mid_blocks:
		subi.w	#1,cdpcm_cblk(a6)			; Count 1 block
		move.w	#SET_PCMBLK-1,d3			; d3 - Block size
		move.w	cdpcm_cout(a6),d4			; d4 - Current buffer output
		cmp.w	#SET_PCMLAST,d4				; Are we in the last block?
		bne.s	.not_last
		subi.w	#$10,d3					; Skip loop bytes
.not_last:
		move.l	cdpcm_cread(a6),a0			; a0 - Current Wave data to read
		move.l	cdpcm_clen(a6),d1			; d1 - Current wave size
		bsr	.make_block
		move.l	d1,cdpcm_clen(a6)			; Save next wave size
		move.l	a0,cdpcm_cread(a6)			; Save next wave pos
		tst.l	d1					; Size is zero? (non-looping only)
		bne.s	.next_one
		bset	#5,cdpcm_status(a6)			; Report as finished
.next_one:
		add.w	#SET_PCMBLK,cdpcm_cout(a6)		; Next output block
		andi.w	#$0FFF,cdpcm_cout(a6)			; w/Limit
.no_strm:
		adda	#cdpcm_len,a6				; Next PCM buffer
		addq.w	#1,d6					; Next PCM channel number
		adda	#4,a4					; Next PCM read
		dbf	d7,.pick_stream
		rts

; --------------------------------------------------------
; Fill wave block
;
; Input:
; a6 - Current channel buffer
; a5 - PCM chip
; a0 - wave data to write
; d1 - channel current length
; d3 - block size - 1
; d4 - output location in wave ram & $0FFF
; d6 - current channel
; --------------------------------------------------------

.make_block:
		move.b	d6,d0			; Set PCM memory mode + current channel
		or.b	#$80,d0
		move.b	d0,CTREG(a5)
		lea	$2000(a5),a1		; a1 - WAVE RAM output
		add.w	d4,d4			; Pos * 2
		adda	d4,a1			; add to a1
		move.w	d3,d4			; d4 - block size - 1
		moveq	#0,d0
		tst.l	d1
		beq.s	.last_bytes
		btst	#0,cdpcm_flags(a6)	; Looping enabled?
		beq	.end_point

; ----------------------------------------
; Wave loops
; ----------------------------------------

.loop_point:
		subq.l	#1,d1			; Decrement current len
		bne.s	.strlen_it
		movea.l	cdpcm_start(a6),a0	; a2 - WAVE start
		move.l	cdpcm_loop(a6),d2	; d0 - Loop start point
		add.l	d2,a0
		move.l	cdpcm_length(a6),d1	; d2 - NEW length to set
		sub.l	d2,d1
.strlen_it:
		move.b	(a0)+,d0		; Write wave data and
		move.b	.wave_list(pc,d0.w),d0
		move.w	d0,(a1)+
		dbf	d4,.loop_point
		rts

; ----------------------------------------
; Wave doesn't loop
; ----------------------------------------

.end_point:
		subq.l	#1,d1			; Count length
		beq.s	.last_bytes		; If == 0, finished
		move.b	(a0)+,d0
		move.b	.wave_list(pc,d0.w),d0
		move.w	d0,(a1)+
		dbf	d4,.end_point
		rts
.last_bytes:
		move.w	d0,(a1)+
		dbf	d4,.last_bytes
		rts

; =====================================================================
; ----------------------------------------------------------------
; WAV to PCM table conversion
; ----------------------------------------------------------------

.wave_list:
	dc.b $FE,$FE,$FD,$FC,$FB,$FA,$F9,$F8,$F7,$F6,$F5,$F4,$F3,$F2,$F1,$F0
	dc.b $EF,$EE,$ED,$EC,$EB,$EA,$E9,$E8,$E7,$E6,$E5,$E4,$E3,$E2,$E1,$E0
	dc.b $DF,$DE,$DD,$DC,$DB,$DA,$D9,$D8,$D7,$D6,$D5,$D4,$D3,$D2,$D1,$D0
	dc.b $CF,$CE,$CD,$CC,$CB,$CA,$C9,$C8,$C7,$C6,$C5,$C4,$C3,$C2,$C1,$C0
	dc.b $BF,$BE,$BD,$BC,$BB,$BA,$B9,$B8,$B7,$B6,$B5,$B4,$B3,$B2,$B1,$B0
	dc.b $AF,$AE,$AD,$AC,$AB,$AA,$A9,$A8,$A7,$A6,$A5,$A4,$A3,$A2,$A1,$A0
	dc.b $9F,$9E,$9D,$9C,$9B,$9A,$99,$98,$97,$96,$95,$94,$93,$92,$91,$90
	dc.b $8F,$8E,$8D,$8C,$8B,$8A,$89,$88,$87,$86,$85,$84,$83,$82,$81,$80
	dc.b $00,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0A,$0B,$0C,$0D,$0E,$0F
	dc.b $10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1A,$1B,$1C,$1D,$1E,$1F
	dc.b $20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$2A,$2B,$2C,$2D,$2E,$2F
	dc.b $30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3A,$3B,$3C,$3D,$3E,$3F
	dc.b $40,$41,$42,$43,$44,$45,$46,$47,$48,$49,$4A,$4B,$4C,$4D,$4E,$4F
	dc.b $50,$51,$52,$53,$54,$55,$56,$57,$58,$59,$5A,$5B,$5C,$5D,$5E,$5F
	dc.b $60,$61,$62,$63,$64,$65,$66,$67,$68,$69,$6A,$6B,$6C,$6D,$6E,$6F
	dc.b $70,$71,$72,$73,$74,$75,$76,$77,$78,$79,$7A,$7B,$7C,$7D,$7E,$7F
	align 2

; ====================================================================
; ----------------------------------------------------------------
; Short .w variables
; ----------------------------------------------------------------

			align $80
SCPU_RAM:
			memory SCPU_RAM
RAM_CdSub_StampNum	ds.w 1
RAM_CdSub_StampW	ds.w 1				; Safer W/H reads
RAM_CdSub_StampH	ds.w 1				; ''
RAM_CdSub_StampEnbl	ds.w 1				; Flag to Disable/Enable Stamp rendering *IMPORTANT*
RAM_CdSub_StampBusy	ds.w 1				; Stamp is busy drawing, Level 1 clears this
RAM_CdSub_StampSize	ds.w 1				; %msr m-Map size: 1x1/16x16 s-Stamp 16x16/32x32 r-Repeat No/Yes
RAM_CdSub_StampNextWr	ds.w 1
RAM_CdSub_StampNextRd	ds.w 1
RAM_CdSub_DotClearFlag	ds.w 1
RAM_CdSub_StampIndxW	ds.w 1
RAM_CdSub_StampCBuff	ds.w 1
RAM_CdSub_StampPending	ds.w 1
RAM_CdSub_IrqIndex	ds.w 1
RAM_CdSub_PcmEnbl	ds.b 1				; PCM Enable bits
RAM_CdSub_PcmReqUpd	ds.b 1				; PCM new data request
RAM_CdSub_StampReqUpd	ds.b 1
RAM_CdSub_PcmMkNew	ds.b 1
			align 2

; ====================================================================
; ----------------------------------------------------------------
; Buffers after $8000
; ----------------------------------------------------------------

RAM_CdSub_StampProc	ds.b stmpc_len
RAM_CdSub_StampOutBox	ds.b stmpi_len
RAM_CdSub_StampList	ds.l 2*MAX_MCDSTAMPS		; Location and Z sort pos
RAM_CdSub_CurrSaveInfo	ds.b $10
RAM_CdSub_BramWork	ds.b $640
RAM_CdSub_BramStrings	ds.b $C
RAM_CdSub_PcmBuff	ds.b 8*cdpcm_len		; PCM Streaming buffer
RAM_CdSub_PcmTable	ds.b 8*8			; PCM table recieved from Z80
ISO_Filelist		ds.b $800*(8+1)
ISO_Output		ds.b $800*($10+1)
RAM_CdSub_FsBuff	ds.l $20
sizeof_subcpu		ds.l 0
			endmemory
			erreport "SUB-CPU IP",sizeof_subcpu,$20000

; ====================================================================
; ----------------------------------------------------------------
; SUB-CPU data
; ----------------------------------------------------------------

			dephase
			phase $20000		; <-- MANUAL location on Sub-CPU area
SCPU_DATA:
			dephase
			dephase
