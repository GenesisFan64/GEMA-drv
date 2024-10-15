; ===========================================================================
; ----------------------------------------------------------------
; Genesis system routines
;
; including SCD, 32X and PICO.
; ----------------------------------------------------------------

; ====================================================================
; --------------------------------------------------------
; Settings
; --------------------------------------------------------

MAX_MDOBJ	equ 40		; Maximum Genesis objects/scripts
TAG_SRAMDATA	equ "SAVE"	; 4-letter savefile id

; ===================================================================
; --------------------------------------------------------
; Variables
; --------------------------------------------------------

; ------------------------------------------------
; Controller buffer data
;
; MUST call System_Input during VBlank
; ------------------------------------------------

; ------------------------------------------------
; pad_id
;
; JoyID_MD:
; Read pad_ver separately to check if controller
; is 3button(0) or 6button(1)
; ------------------------------------------------

JoyID_Mouse	equ $03
JoyID_MD	equ $0D
JoyID_MS	equ $0F		; <-- Same ID for no controller

; ------------------------------------------------
; Genesis controller
;
; Read these as WORD
; ------------------------------------------------

; on_hold, on_press
JoyUp		equ $0001
JoyDown		equ $0002
JoyLeft		equ $0004
JoyRight	equ $0008
JoyB		equ $0010
JoyC		equ $0020
JoyA		equ $0040
JoyStart	equ $0080
JoyZ		equ $0100
JoyY		equ $0200
JoyX		equ $0400
JoyMode		equ $0800
bitJoyUp	equ 0
bitJoyDown	equ 1
bitJoyLeft	equ 2
bitJoyRight	equ 3
bitJoyB		equ 4
bitJoyC		equ 5
bitJoyA		equ 6
bitJoyStart	equ 7
bitJoyZ		equ 8
bitJoyY		equ 9
bitJoyX		equ 10
bitJoyMode	equ 11

; ------------------------------------------------
; Mega Mouse ONLY
;
; mouse_x and mouse_y are speed increment values,
; NOT screen position.
; ------------------------------------------------

ClickR		equ $0001
ClickL		equ $0002
ClickM		equ $0004		; US MOUSE ONLY
ClickS		equ $0008		; (Untested)
bitClickL	equ 0
bitClickR	equ 1
bitClickM	equ 2
bitClickS	equ 3

; ------------------------------------------------
; Sega PICO
; Directons U/D/L/R use the same bits as Genesis.
; For reading the pen position use
; mouse_x and mouse_y
; ------------------------------------------------

JoyRED		equ $0010
JoyPEN		equ $0080
bitJoyRED	equ 4
bitJoyPEN	equ 7

; ====================================================================
; ----------------------------------------------------------------
; Structs
; ----------------------------------------------------------------

; ------------------------------------------------
; RAM_InputData

; *** MANUAL VARIABLES ***
pad_id			equ $00;ds.b 1			; Controller ID
pad_ver			equ $01;ds.b 1			; Controller type/revision
on_hold			equ $02;ds.w 1			; User HOLD bits
on_press		equ $04;ds.w 1			; User PRESSED bits
on_release		equ $06;ds.w 1			; User RELEASED bits
mouse_x			equ $08;ds.w 1			; Mouse/Pen X speed
mouse_y			equ $0A;ds.w 1			; Mouse/pen Y speed
ext_3			equ $0C;ds.w 1
ext_4			equ $0E;ds.w 1
sizeof_input		equ $10

; ------------------------------------------------
; RAM_Objects
;
; Size must end as even
; ------------------------------------------------

obj			struct
code			ds.l 1		; Object code, If 0 == blank slot
x			ds.l 1		; Object X Position $xxxx.0000
y			ds.l 1		; Object Y Position $yyyy.0000
z			ds.l 1		; Object Z Position $zzzz.0000 (3D ONLY)
size_x			ds.w 1		; Object size Left/Right
size_y			ds.w 1		; Object size Up/Down
size_z			ds.w 1		; Object size Zback/Zfront starting from object's X/Y pointer in 10mm's (3D ONLY)
x_spd			ds.w 1		; Object X Speed $xx.00 (object_Speed)
y_spd			ds.w 1		; Object Y Speed $yy.00 ''
z_spd			ds.w 1		; Object Z Speed $zz.00 '' (3D ONLY)
index			ds.b 1		; Object current code index, mostly for init(0) and main(1)
subid			ds.b 1		; Object Sub-ID for custom placement settings
status			ds.b 1		; General purpose USER status: Falling, Floating, etc.
attr			ds.b 1		; Quick attribute bits for VRAM (depending of the type)
					; ** object_Animate ONLY:
frame			ds.w 1		; ** Current frame, object_Animate outputs here
anim_num		ds.w 1		; ** Animation number to use
anim_indx		ds.w 1		; ** Animation script index
anim_icur		ds.b 1		; ** Current animation id
anim_spd		ds.b 1		; ** Animation delay set on animation script
ram			ds.b $40	; Object's own RAM
; obj_len		ds.l 0
			endstruct

; ====================================================================
; ----------------------------------------------------------------
; RAM section
; ----------------------------------------------------------------

			memory RAM_MdSystem
RAM_SaveData		ds.b SET_SRAMSIZE		; Read/Write of the SAVE data
RAM_InputData		ds.b sizeof_input*4		; Input data section
RAM_Objects		ds.b obj_len*MAX_MDOBJ		; Objects buffer
RAM_SysRandVal		ds.l 1				; Random value
RAM_SysRandom		ds.l 1				; Randomness seed
RAM_VBlankJump		ds.w 3				; VBlank jump (JMP xxxx xxxx)
RAM_HBlankJump		ds.w 3				; HBlank jump (JMP xxxx xxxx)
RAM_ExternalJump	ds.w 3				; External jump (JMP xxxx xxxx)
RAM_SaveEnable		ds.w 1				; Flag to enable SAVE data
RAM_ScreenMode		ds.w 1				; Current screen number
RAM_ScreenOption	ds.w 1				; Current screen setting (OPTIONAL)
RAM_McdExit		ds.w 1
sizeof_mdsys		ds.l 0
			endmemory

; ====================================================================
; ----------------------------------------------------------------
; Label aliases
; ----------------------------------------------------------------

Controller_1		equ RAM_InputData
Controller_2		equ RAM_InputData+sizeof_input

; ====================================================================
; --------------------------------------------------------
; Init System
; 
; Uses:
; a0-a2,d0-d1
; --------------------------------------------------------

System_Init:
		or.w	#$0700,sr
	if PICO=0
		move.w	#$0100,(z80_bus).l	; Stop Z80
.wait:
		btst	#0,(z80_bus).l		; Wait Z80
		bne.s	.wait
		moveq	#%01000000,d0		; Init ports, TH=1
		move.b	d0,(sys_ctrl_1).l	; Controller 1
		move.b	d0,(sys_ctrl_2).l	; Controller 2
		move.b	d0,(sys_ctrl_3).l	; Modem
		move.w	#0,(z80_bus).l		; Enable Z80
	endif
		move.w	#$4EF9,d0		; JMP opcode for the Interrupt jumps
 		move.w	d0,(RAM_VBlankJump).w
		move.w	d0,(RAM_HBlankJump).w
		move.w	d0,(RAM_ExternalJump).w
		move.l	#VInt_Default,d0	; Set default interrupt jumps
		move.l	#HInt_Default,d1
		move.l	#ExtInt_Default,d2
		bsr	System_SetIntJumps
		lea	(RAM_InputData).w,a0	; Clear input data buffer
		move.w	#(sizeof_input/2)-1,d1
		moveq	#0,d0
.clrinput:
		move.w	d0,(a0)+
		dbf	d1,.clrinput
		andi.w	#$F8FF,sr
		rts

; ====================================================================
; --------------------------------------------------------
; System_Render
;
; This will:
; - Drop a frame if we got late on VBlank
; - Process Palette fading buffers
;   (Video_MdMars_RunFade, CPU-INTENSIVE IF PROCESSING
;   BOTH VDP AND 32X SVDP Palettes)
; - Check the sound driver for any changes/requests
;   from Z80 (Sound_Update, several times)
; - 32X/CD32X only: Update the "DREQ RAM" section
;   to the SH2 using DREQ FIFO (System_MdMars_Update)
;
; During VBlank:
; - Read the Input data, (System_Input)
; - Transfer the VDP Palette, Sprites and Scroll
;   from from RAM to VDP and process the DMA BLAST list.
;   (Video_Render)
;
; Notes:
; - If VDP Display is disabled all of this
;   will be skipped.
; --------------------------------------------------------

System_Render:
		move.w	(RAM_VdpRegSet1).w,d7
		btst	#bitDispEnbl,d7
		beq	.forgot_disp
		bsr	Video_RunFade			; Process VDP palette fade
.wait_early:
		bsr	Sound_Update			; Update sound on wait
		move.w	(vdp_ctrl).l,d7
		btst	#bitVBlk,d7
		bne.s	.wait_early
	; ----------------------------------------
	; 32X/CD32X
	if MARS|MARSCD
		bsr	Video_MdMars_RunFade		; Process SVDP palette fade
		lea	(sysmars_reg+comm12).l,a5	; %SW00
		move.w	(a5),d7				; SH2 allows framedropping?
		btst	#3,d7
		beq.s	.mars_sync
; ----------------------------------------
; w/32X Framedrop
; ----------------------------------------

.mars_wait:
		bsr	Sound_Update			; Update sound on wait
		move.w	(a5),d7				; Sync bit cleared?
		btst	#4,d7
		beq.s	.mars_free
.got_late:
		bsr	Sound_Update			; Update sound on wait
		move.w	(vdp_ctrl).l,d7
		btst	#bitVBlk,d7
		bne.s	.got_late
		bsr	Sound_Update
		bsr	.wait_vblank
		bra.s	.from_late
; ----------------------------------------
; w/32X Sync
; ----------------------------------------
.mars_sync:
		bsr	Video_MdMars_WaitSync		; Wait DREQ-RAM normally
		bsr	Sound_Update
.mars_free:
		bsr	System_MdMars_Update		; Send DREQ changes
	endif
; ----------------------------------------
		bsr	.wait_vblank			; <-- Genesis normal VBlank wait
; ----------------------------------------
	if MARS|MARSCD
		bsr	Sound_Update
		bsr	Video_MdMars_PalBackup		; backup SVDP palette transfer if set to us.
		bsr	Video_MdMars_SetSync		; Set bit to wait for DREQ-RAM swap
	endif
.from_late:
	if MCD|MARSCD
		bsr	Sound_Update
	endif
	if MARS|MARSCD
		bsr	Sound_Update
		bsr	Video_MdMars_Cleanup
	endif
		addq.l	#1,(RAM_Framecount).w		; Count the frame.
		bsr	Sound_Update
.forgot_disp:
		rts
; ----------------------------------------
; Wait until beam reaches VBlank
; ----------------------------------------

.wait_vblank:	bsr	Sound_Update			; Update sound on wait
		move.w	(vdp_ctrl).l,d7
		btst	#bitVBlk,d7
		beq.s	.wait_vblank
		bsr	System_Input			; Read input data **FIRST**
		bra	Video_Render			; Render VDP Visuals

; ====================================================================
; --------------------------------------------------------
; System_DmaEnter_(from) and System_DmaEnter_(from)
; from ROM or RAM
;
; Call these labels BEFORE and AFTER your
; DMA-to-VDP transers, these are NOT needed for
; FILL or COPY.
;
; This is where you put your Sound driver's Z80 stop
; or pause calls here, SAVE THE REGISTERS THAT YOU
; GONNA USE TO STACK.
; --------------------------------------------------------

; --------------------------------------------------------
; *** THESE ENABLE AND DISABLE THE RV BIT ***
System_DmaEnter_ROM:
		bsr	System_DmaEnter_RAM
	if MARS
		movem.w	d6-d7,-(sp)
		move.w	#$02,d6				; PWM data backup request
		bsr	sys_MarsSlvCmd
		bset	#0,(sysmars_reg+dreqctl+1).l	; Set RV=1
		movem.w	(sp)+,d6-d7
	endif
		rts

System_DmaExit_ROM:
	if MARS
		movem.w	d6-d7,-(sp)
		move.w	#$03,d6				; PWM restore playback
		bsr	sys_MarsSlvCmd
		bclr	#0,(sysmars_reg+dreqctl+1).l	; Set RV=0
		movem.w	(sp)+,d6-d7
	endif
		bra	System_DmaExit_RAM

; ------------------------------------------------

sys_MarsSlvCmd:
		move.b	(sysmars_reg+comm14).l,d7
		bne.s	sys_MarsSlvCmd
		move.b	(sysmars_reg+comm14).l,d7
		or.b	d6,d7
		or.b	#$80,d7				; We got first.
		move.b	d7,(sysmars_reg+comm14).l
		bset	#1,(sysmars_reg+standby).l	; Slave CMD request
		nop
		nop
.wait_exit:
		nop
		nop
		move.b	(sysmars_reg+comm14).l,d7
		bne.s	.wait_exit
		rts

; --------------------------------------------------------
; *** EXTERNAL JUMPS ***
; --------------------------------------------------------

System_DmaEnter_RAM:
		bra	gemaDmaPause
System_DmaExit_RAM:
		bra	gemaDmaResume

; ====================================================================
; --------------------------------------------------------
; Update sound/sycronize with the Z80
; --------------------------------------------------------

Sound_Update:
		bra	gemaSendRam

; ====================================================================
; --------------------------------------------------------
; Init sound driver
; --------------------------------------------------------

Sound_Init:
		bra	gemaInit

; ====================================================================
; --------------------------------------------------------
; System_Input
;
; Reads data from the Controller ports
;
; Call this during VBlank only once per frame,
; System_Render already calls this.
;
; Uses:
; d5-d7,a5-a6
; --------------------------------------------------------

; ----------------------------------------
; PICO input is hard-coded to
; Controller_1
;
; on_hold/on_press:
; %P00BRLDU
; UDLR - Arrows
;    B - BIG button red (JoyB)
;    P - Pen press/click (JoyStart)
;
; mouse_x/mouse_y:
; Pen X/Y position
; ----------------------------------------

System_Input:
	if PICO
		lea	(RAM_InputData).w,a6
		lea	($800003).l,a5
		moveq	#0,d7
		move.b	(a5),d7			; $800003: %P00BRLDU
		eori.w	#$FF,d7
		move.w	d7,d6
		move.w	on_hold(a6),d5
		eor.w	d5,d7
		and.w	d5,d7
		move.w	d7,on_release(a6)
		move.w	on_hold(a6),d5
		eori.w	#$FF,d5
		and.w	d6,d5
		move.w	d5,on_press(a6)
		move.w	d6,on_hold(a6)
		move.b	2(a5),d7
		lsl.w	#8,d7
		move.b	4(a5),d7
		sub.w	#$3C,d7
		bpl.s	.x_valid	 	; Failsafe negative X
		clr.w	d7
.x_valid:
		move.w	d7,mouse_x(a6)
	; $0000-$00EF - Tablet
	; $0100-$01EF - Storyware
		moveq	#0,d7
		move.b	6(a5),d6
		lsl.w	#8,d6
		move.b	8(a5),d6
		subi.w	#$1FC,d6
		bmi.s	.bad_y
		move.w	d6,d7
.bad_y:
		move.w	d7,mouse_y(a6)
		move.b	10(a5),d6
		moveq	#0,d7
		moveq	#6-1,d5		; 6 pages
.page_it:
		lsr.w	#1,d6
		bcc.s	.no_bit
		addq.w	#1,d7
.no_bit:
		dbf	d5,.page_it
		move.b	d7,ext_3(a6)
	else

	; ----------------------------------------
	; Normal Genesis controls
		lea	(RAM_InputData).w,a6	; a6 - Output
		lea	(sys_data_1),a5		; a5 - BASE Genesis Input regs area
		bsr.s	.this_one
		adda	#2,a5
		adda	#sizeof_input,a6

; ----------------------------------------
; Read port
;
; a5 - Current port
; a6 - Output data
; ----------------------------------------

.this_one:
		bsr	.pick_id
		move.b	d7,pad_id(a6)
		cmpi.w	#$0F,d7
		beq.s	.exit
		andi.w	#$0F,d7
		add.w	d7,d7
		move.w	.list(pc,d7.w),d6
		jmp	.list(pc,d6.w)
.exit:
		clr.b	pad_ver(a6)
		rts

; ----------------------------------------
; Grab ID
; ----------------------------------------

.pick_id:
		moveq	#0,d7
		move.b	#%01110000,(a5)		; TH=1,TR=1,TL=1
		nop
		nop
		bsr	.read
		move.b	#%00110000,(a5)		; TH=0,TR=1,TL=1
		nop
		nop
		add.w	d7,d7
.read:
		move.b	(a5),d5
		move.b	d5,d6
		andi.b	#%1100,d6
		beq.s	.step_1
		addq.w	#1,d7
.step_1:
		add.w	d7,d7
		move.b	d5,d6
		andi.w	#%0011,d6
		beq.s	.step_2
		addq.w	#1,d7
.step_2:
		rts

; ----------------------------------------
; Grab ID
; ----------------------------------------

.list:
		dc.w .exit-.list	; $00
		dc.w .exit-.list
		dc.w .exit-.list
		dc.w .id_03-.list	; $03 - Mega Mouse
		dc.w .exit-.list	; $04
		dc.w .exit-.list
		dc.w .exit-.list
		dc.w .exit-.list
		dc.w .exit-.list	; $08
		dc.w .exit-.list
		dc.w .exit-.list
		dc.w .exit-.list
		dc.w .exit-.list	; $0C
		dc.w .id_0D-.list	; $0D - Genesis controller (3 or 6 button)
		dc.w .exit-.list
		dc.w .exit-.list	; $0F - No controller / Master System controller (Buttons 1 and 2)

; ----------------------------------------
; ID $03
;
; Mega Mouse
; ----------------------------------------

; *** NOT TESTED ON HARDWARE ***
; *** NO RELEASED BITS ***

.id_03:
		move.b	#$20,(a5)
		move.b	#$60,6(a5)
		btst	#4,(a5)
		beq.w	.invalid
		move.b	#$00,(a5)	; $0F
		nop
		nop
		move.b	#$20,(a5)	; $0F
		nop
		nop
		move.b	#$00,(a5)	; Yo | Xo | Ys | Xs
		nop
		nop
		move.b	(a5),d5		; d5 - X/Y direction bits (Ys Xs)
		move.b	#$20,(a5)	; C | M | R | L
		nop
		nop
		move.b	(a5),d7
 		andi.w	#%1111,d7
		move.w	on_hold(a6),d6
		eor.w	d7,d6
		move.w	d7,on_hold(a6)
		and.w	d7,d6
		move.w	d6,on_press(a6)
		move.b	#$00,(a5)	; X7 | X6 | X5 | X4
		nop
		nop
		move.b	(a5),d7
		move.b	#$20,(a5)	; X3 | X2 | X1 | X0
		andi.w	#%1111,d7
		lsl.w	#4,d7
		nop
		move.b	(a5),d6
		andi.w	#%1111,d6
		or.w	d6,d7
		btst    #0,d5
		beq.s	.x_neg
		neg.b	d7
		neg.w	d7
.x_neg:
		move.w	d7,mouse_x(a6)
		move.b	#$00,(a5)	; Y7 | Y6 | Y5 | Y4
		nop
		nop
		move.b	(a5),d7
		move.b	#$20,(a5)	; Y3 | Y2 | Y1 | Y0
		andi.w	#%1111,d7
		lsl.w	#4,d7
		nop
		move.b	(a5),d6
		andi.w	#%1111,d6
		or.w	d6,d7
		btst    #1,d5
		beq.s	.y_neg
		neg.b	d7
		neg.w	d7
.y_neg:
		neg.w	d7		; Reverse Y
		move.w	d7,mouse_y(a6)

.invalid:
		move.b	#$60,(a5)
		rts

; ----------------------------------------
; ID $0D
;
; Normal controller: 3 button or 6 button.
; ----------------------------------------

.id_0D:
		move.b	#$40,(a5)	; Show CB|RLDU
		nop
		nop
		move.b	(a5),d5
		andi.w	#%00111111,d5
		move.b	#$00,(a5)	; Show SA|RLDU
		nop
		nop
		move.b	(a5),d7		; The following flips are for
		lsl.w	#2,d7		; the 6pad's internal counter:
		andi.w	#%11000000,d7
		or.w	d5,d7
		move.b	#$40,(a5)	; Show CB|RLDU (2)
		not.w	d7
		move.b	on_hold+1(a6),d5
		move.b	d5,d4
		move.b	#$00,(a5)	; Show SA|RLDU (3)
		eor.b	d7,d5
		move.b	d7,on_hold+1(a6)
		and.b	d7,d5
		move.b	#$40,(a5)	; 6 button responds (4)
		move.b	d5,on_press+1(a6)
		move.b	d7,d5
		move.b	(a5),d7		; Grab ??|MXYZ
 		move.b	#$00,(a5)	; (5)
		eor.b	d4,d5
		and.b	d4,d5
 		move.b	(a5),d6		; Type: $03 old, $0F new
 		move.b	#$40,(a5)	; (6)
		move.b	d5,on_release+1(a6)
		andi.w	#$F,d6
		lsr.w	#2,d6
		andi.w	#1,d6
		beq.s	.oldpad
		not.b	d7
 		andi.w	#%1111,d7
 		move.b	d7,d6
		move.b	on_hold(a6),d5
		eor.b	d5,d6
		and.b	d5,d6
		move.b	d6,on_release(a6)
		move.b	on_hold(a6),d5
		eor.b	d7,d5
		move.b	d7,on_hold(a6)
		and.b	d7,d5
		move.b	d5,on_press(a6)
.oldpad:
		move.b	d6,pad_ver(a6)
		rts
	endif

; ============================================================
; --------------------------------------------------------
; System_SramInit
;
; Enable SRAM/BRAM support
;
; Input:
; a0 | CD/CD32X ONLY: Save data settings for BRAM
;      dc.b "SAVE_NAME__",0
;      dc.w SET_SRAMSIZE/$40 ; (save_size/$20 if using
;                            ; protection)
;      dc.w flags:
;            0 | Normal
;           -1 | Save protection
;
;
; Notes:
; - ONLY use the RAM_SaveData section to modify
;   your changes, then call System_SramSave to
;   save it into SRAM/BRAM.
;
; CD/CD32X ONLY:
; - NO lowercase CHARACTERS, NO " "($20) SPACES.
; - BE CAREFUL CHOOSING YOUR FILENAME as it can
;   OVERWRITE without warning any other save.
; - Call gemaStopAll FIRST if any track uses
;   PCM samples
; --------------------------------------------------------

System_SramInit:
	if PICO
		nop						; Pico can't use save data
	elseif MCD|MARSCD

	; ------------------------------------------------
	; CD BRAM
	; ------------------------------------------------
		tst.w	(RAM_SaveEnable).w			; Already initialized?
		bne	.already_set
; 	if MARSCD
; 		bset	#0,(sysmars_reg+dreqctl+1).l		; Set RV=1
; 	endif
		bsr	System_MdMcd_SubWait
		lea	def_SaveInfo(pc),a5			; Init+Load SRAM/BRAM feature
		lea	(sysmcd_reg+mcd_dcomm_m).l,a6		; Copy-paste info
		moveq	#($10/2)-1,d7
.copy_paste:
		move.w	(a5)+,(a6)+
		dbf	d7,.copy_paste
		moveq	#$08,d0					; Init BRAM support
		bsr	System_MdMcd_SubTask
		bsr	System_MdMcd_SubWait
; 	if MARSCD
; 		bclr	#0,(sysmars_reg+dreqctl+1).l		; Set RV=0
; 	endif
		move.w	#0,(RAM_SaveEnable).w			; Disable SAVE R/W
		cmp.w	#-2,(sysmcd_reg+mcd_dcomm_s).l		; Got -2 No RAM / Unformatted?
		beq.s	.cont_save
.not_fail:
		move.w	#1,(RAM_SaveEnable).w			; Enable SAVE Read/Write
		cmp.w	#-1,(sysmcd_reg+mcd_dcomm_s).l		; Found the file?
		bne.s	.cont_save
		movem.l	d6-d7/a6,-(sp)
		lea	(RAM_SaveData).w,a6			; If NOT found, Make SAVE template
		moveq	#0,d6
		move.w	#SET_SRAMSIZE-1,d7
.clr_sram:
		move.b	d6,(a6)+
		dbf	d7,.clr_sram
		movem.l	(sp)+,d6-d7/a6
		move.l	#TAG_SRAMDATA,(RAM_SaveData).w		; Write SAVE template
		bsr	System_SramSave
.cont_save:
		bsr	System_SramLoad				; Get data from BRAM
	; ------------------------------------------------
	else

	; ------------------------------------------------
	; Cartridge SRAM
	; ------------------------------------------------
		tst.w	(RAM_SaveEnable).w
		bne.s	.cant_use
		move.w	#1,(RAM_SaveEnable).w
	; Make SAVE template
		bsr	System_SramLoad
		cmpi.l	#TAG_SRAMDATA,(RAM_SaveData).w
		beq.s	.cant_use
		movem.l	d6-d7/a6,-(sp)
		lea	(RAM_SaveData).w,a6
		moveq	#0,d6
		move.w	#SET_SRAMSIZE-1,d7
.clr_sram:
		move.b	d6,(a6)+
		dbf	d7,.clr_sram
		movem.l	(sp)+,d6-d7/a6
		move.l	#TAG_SRAMDATA,(RAM_SaveData).w		; Write SAVE signature
		bsr	System_SramSave
	endif
.cant_use:
		bra	System_SramLoad
.already_set:
		rts

; --------------------------------------------------------
; System_SramSave
;
; Returns:
; bcc | Save OK
; bcs | Save failed
; --------------------------------------------------------

System_SramSave:
	if PICO
		nop			; Pico can't use save data
	elseif MCD|MARSCD

	; ------------------------------------------------
	; CD BRAM
	; ------------------------------------------------
		tst.w	(RAM_SaveEnable).w
		beq.s	.cant_use
		move.w	sr,-(sp)
		movem.l	d6-d7/a5-a6,-(sp)
		lea	(RAM_SaveData).w,a6
		lea	(sysmcd_wram+WRAM_SaveDataCopy).l,a5
		move.w	#(SET_SRAMSIZE/2)-1,d7
.copy_save:	move.w	(a6)+,d6
		move.w	d6,(a5)+
		dbf	d7,.copy_save
; 	if MARSCD
; 		bset	#0,(sysmars_reg+dreqctl+1).l	; Set RV=1
; 	endif
		moveq	#$0A,d0
		bsr	System_MdMcd_SubTask
		bsr	System_MdMcd_GiveWRAM
		bsr	System_MdMcd_WaitWRAM
; 	if MARSCD
; 		bclr	#0,(sysmars_reg+dreqctl+1).l	; Set RV=0
; 	endif
		move	#0,ccr
		move.w	(sysmcd_reg+mcd_dcomm_s).l,d7	; Get status
		bpl.s	.save_good
		move	#1,ccr
.save_good:
		movem.l	(sp)+,d6-d7/a5-a6
		move.w	(sp)+,sr
.cant_use:
	; ------------------------------------------------
	else

	; ------------------------------------------------
	; Cartridge SRAM
	; ------------------------------------------------
		tst.w	(RAM_SaveEnable).w
		beq.s	.cant_use_c
		move.w	sr,-(sp)
		movem.l	d6-d7/a5-a6,-(sp)
	if MARS
		bset	#0,(sysmars_reg+dreqctl+1).l	; Set RV=1
	endif
		move.b	#1,(md_bank_sram).l
		lea	(RAM_SaveData).w,a6
		lea	($200003).l,a5
		move.w	#((SET_SRAMSIZE-1))-1,d7
.save:		move.b	(a6)+,d6
		move.b	d6,(a5)
		adda	#2,a5
		dbf	d7,.save
		move.b	#0,(md_bank_sram).l
	if MARS
		bclr	#0,(sysmars_reg+dreqctl+1).l	; Set RV=0
	endif
		movem.l	(sp)+,d6-d7/a5-a6
		move.w	(sp)+,sr
.cant_use_c:
	; ------------------------------------------------
	endif
		rts

; --------------------------------------------------------
; System_SramLoad
;
; Returns:
; bcc | Save OK
; bcs | Save not found
; --------------------------------------------------------

System_SramLoad:
	if PICO
		nop			; Pico can't use save data
	elseif MCD|MARSCD
	; ------------------------------------------------
	; CD BRAM
	; ------------------------------------------------
		tst.w	(RAM_SaveEnable).w
		beq.s	.cant_use
		move.w	sr,-(sp)
		movem.l	d6-d7/a5-a6,-(sp)
; 	if MARSCD
; 		bset	#0,(sysmars_reg+dreqctl+1).l	; Set RV=1
; 	endif
		moveq	#$09,d0
		bsr	System_MdMcd_SubTask
		bsr	System_MdMcd_GiveWRAM
		bsr	System_MdMcd_WaitWRAM
; 	if MARSCD
; 		bclr	#0,(sysmars_reg+dreqctl+1).l	; Set RV=0
; 	endif
		lea	(sysmcd_wram+WRAM_SaveDataCopy).l,a6
		lea	(RAM_SaveData).w,a5
		move.w	#(SET_SRAMSIZE/2)-1,d7
.copy_save:	move.w	(a6)+,d6
		move.w	d6,(a5)+
		dbf	d7,.copy_save
		movem.l	(sp)+,d6-d7/a5-a6
		move.w	(sp)+,sr
.cant_use:
	; ------------------------------------------------
	else

	; ------------------------------------------------
	; Cartridge SRAM
	; ------------------------------------------------
		tst.w	(RAM_SaveEnable).w
		beq.s	.cant_use_c
		move.w	sr,-(sp)
		movem.l	d6-d7/a5-a6,-(sp)
		ori.w	#$0700,sr
	if MARS
		bset	#0,(sysmars_reg+dreqctl+1).l	; Set RV=1
	endif
		move.b	#1,(md_bank_sram).l
		lea	(RAM_SaveData).w,a6
		lea	($200003).l,a5
		move.w	#((SET_SRAMSIZE-1))-1,d7
.load:
		move.b	(a5),d6
		move.b	d6,(a6)+
		adda	#2,a5
		dbf	d7,.load
.dont_reset:
		move.b	#0,(md_bank_sram).l
	if MARS
		bclr	#0,(sysmars_reg+dreqctl+1).l	; Set RV=0
	endif
		movem.l	(sp)+,d6-d7/a5-a6
		move.w	(sp)+,sr
.cant_use_c:
	; ------------------------------------------------
	endif
		rts

; ============================================================
; --------------------------------------------------------
; System_Default
;
; Initializes current screen mode
;
; Uses:
; ALL
; --------------------------------------------------------

System_Default:
		ori.w	#$0700,sr			; Disable interrupts
		lea	(RAM_ScrnBuff).w,a6
		move.w	#MAX_ScrnBuff-1,d7
		moveq	#0,d6
.clr_loop:
		move.b	d6,(a6)+
		dbf	d7,.clr_loop
		bsr	Video_Clear
		bsr	Video_Default
		bra	Object_Init			; Reset all objects

; ====================================================================
; ----------------------------------------------------------------
; Default interrupts
; ----------------------------------------------------------------

; --------------------------------------------------------
; VBlank
; --------------------------------------------------------

VInt_Default:
; 		movem.l	d0-a6,-(sp)
; 		bsr	System_Input
; 		addi.l	#1,(RAM_FrameCount).w
; 		movem.l	(sp)+,d0-a6
		rte

; --------------------------------------------------------
; HBlank
; --------------------------------------------------------

HInt_Default:
		rte

; --------------------------------------------------------
; External interrupt
; --------------------------------------------------------

ExtInt_Default:
		rte

; ====================================================================
; ------------------------------------------------------------
; Subroutines
; ------------------------------------------------------------

; --------------------------------------------------------
; System_Random, System_Random_Seed
;
; Generate random value
;
; Input:
; d0.l | Seed value (_Random_Seed ONLY)
;
; Returns:
; d0.l | Result value
; --------------------------------------------------------

System_Random_Seed:
		move.l	d4,-(sp)
		move.l	d0,d4
		bsr	sysRnd_MkValue
		move.l	(sp)+,d4
		rts
System_Random:
		move.l	d4,-(sp)
		move.l	(RAM_SysRandom).w,d4
		bsr	sysRnd_MkValue
		move.l	d4,(RAM_SysRandom).w
		move.l	(sp)+,d4
		rts
sysRnd_MkValue:
		tst.l	d4
		bne.s	.has_seed
		move.l	(RAM_FrameCount).w,d4
		rol.l	d0,d4
		ror.l	d1,d4
		add.l	#$23B51947,d4		; Restart SEED if zero.
.has_seed:
		move.l	d4,d0
		asr.l	#2,d4
		add.l	d0,d4
		rol.l	#3,d4
		add.l	d0,d4
		move.w	d4,d0
		swap	d4
		add.w	d4,d0
		move.w	d0,d4
		ror.l	d0,d4
		swap	d4
		rts

; --------------------------------------------------------
; System_DiceRoll, System_DiceRoll_Seed
;
; Pick a random number using a maximum value,
; uses System_Random
;
; Input:
; d0.l | Maximum number to use + 1
; d1.l | Starting seed (_DiceRoll_Seed ONLY)
;
; Returns:
; d0.w | Output value
; --------------------------------------------------------

System_DiceRoll_Seed:
		movem.l	d4-d5,-(sp)
		move.l	d0,d5
		move.l	d1,d4
		bsr	System_Random_Seed
		and.l	#$FFFF,d0
		mulu.w	d5,d0
		swap	d0
		and.l	#$FFFF,d0
		movem.l	(sp)+,d4-d5
		rts

System_DiceRoll:
		move.l	d4,-(sp)
		move.l	d0,d4
		bsr	System_Random
		and.l	#$FFFF,d0
		mulu.w	d4,d0
		swap	d0
		and.l	#$FFFF,d0
		move.l	(sp)+,d4
		rts

; --------------------------------------------------------
; System_SineWave, System_SineWave_Cos
;
; Get Sine or Cosine value
;
; Input:
; d0.w | Tan value: 0-511
;
; Returns:
; d1.w | Result
; --------------------------------------------------------

System_SineWave_Cos:
		move.l	d7,-(sp)
		move.w	d0,d7
		addi.w  #$80,d7
		bra	sys_SineWave
System_SineWave:
		move.l	d7,-(sp)
		move.w	d0,d7
sys_SineWave:
		andi.w	#$1FF,d7
		move.w	d7,d1
		btst	#7,d7
		beq.s	.loc_7EFA
		not.w	d1
.loc_7EFA:
		andi.w  #$7F,d1
		add.w	d1,d1
		move.w  .sine_data(pc,d1.w),d1
		btst    #8,d7
		beq.s   .loc_7F0C
		neg.w   d1
.loc_7F0C:
		ext.l	d1
		move.l (sp)+,d7
		rts

.sine_data:
		binclude "system/md/data/sine_data.bin"
		align 2

; --------------------------------------------------------
; System_BCD_AddB, System_BCD_AddW, System_BCD_AddL
; System_BCD_SubB, System_BCD_SubW, System_BCD_SubL
;
; Increment/Decrement BCD value
; for Scores, Lives, and such.
;
; Input:
; d0.? | BCD value input
; d1.l | Increment/Decrement by
;
; Returns:
; d0.? | BCD value output
; --------------------------------------------------------

; TODO: An overflow check

System_BCD_SubB:
		andi.l	#$00FF,d0
		bra.s	System_BCD_SubL
System_BCD_SubW:
		andi.l	#$FFFF,d0
; 		bra.s	System_BCD_SubL
System_BCD_SubL:
		movem.l	a5-a6,-(sp)
		bsr	sysBCD_SpOut
		and	#0,ccr
		sbcd	-(a5),-(a6)
		sbcd	-(a5),-(a6)
		sbcd	-(a5),-(a6)
		sbcd	-(a5),-(a6)
		move.l	(a6),d0
		movem.l	(sp)+,a5-a6
		rts
System_BCD_AddB:
		andi.l	#$00FF,d0
		bra.s	System_BCD_AddL
System_BCD_AddW:
		andi.l	#$FFFF,d0
; 		bsr.s	System_BCD_AddL
System_BCD_AddL:
		movem.l	a5-a6,-(sp)
		bsr	sysBCD_SpOut
		and	#0,ccr
		abcd	-(a5),-(a6)
		abcd	-(a5),-(a6)
		abcd	-(a5),-(a6)
		abcd	-(a5),-(a6)
		move.l	(a6),d0
		movem.l	(sp)+,a5-a6
		rts
sysBCD_SpOut:
		subq.l	#4,sp
		move.l	sp,a6
		subq.l	#4,sp
		move.l	sp,a5
		move.l	d0,(a6)
		move.l	d1,(a5)
		adda	#4,a6
		adda	#4,a5
		addq.l	#8,sp
		rts

; --------------------------------------------------------
; System_SetIntJumps
;
; Set new VBlank/HBlank/External Interrupt jumps
; generated by VDP
;
; Input:
; d0.l | New VBlank location
; d1.l | New HBlank location
; d2.l | New External location
;
; Notes:
; - Writing 0 to any of the INPUTs skips it
; - Use Video_IntEnable to enable/disable the interrupts
; --------------------------------------------------------

System_SetIntJumps:
		tst.l	d0
		beq.s	.no_vint
	if MCD|MARSCD
		move.l	d0,($FFFFFD06+2).w
	else
 		move.l	d0,(RAM_VBlankJump+2).w
	endif
.no_vint:
		tst.l	d1
		beq.s	.no_hint
	if MCD|MARSCD
		move.l	d1,($FFFFFD0C+2).w
	else
 		move.l	d1,(RAM_HBlankJump+2).w
	endif
.no_hint:
		tst.l	d2
		beq.s	.no_exint
	if MCD|MARSCD
		move.l	d2,($FFFFFD12+2).w
	else
 		move.l	d2,(RAM_ExternalJump+2).w
	endif
.no_exint:
		rts

; ====================================================================
; ----------------------------------------------------------------
; SEGA CD / CD32X ONLY
; ----------------------------------------------------------------

; --------------------------------------------------------
; System_MdMcd_Interrupt
;
; Request an interrupt to Sub-CPU, call this during
; VBlank.
; --------------------------------------------------------

System_MdMcd_Interrupt:
		move.l	d7,-(sp)
; .wait_first:
; 		bsr	System_MdMcd_SubWait
; 		move.b	(sysmcd_reg+mcd_comm_m).l,d7
; 		andi.w	#$C0,d7
; 		cmpi.w	#$C0,d7
; 		beq.s	.wait_first
; 		bset	#0,(sysmcd_reg).l		; Request Level 1
		move.b	#$81,(sysmcd_reg).l
		move.l	(sp)+,d7
		rts

; --------------------------------------------------------
; System_MdMcd_SubWait
;
; Waits until Sub-CPU finishes.
;
; Uses:
; d7
; --------------------------------------------------------

System_MdMcd_SubWait:
	if MCD|MARSCD
.wait_sub_o:	move.b	(sysmcd_reg+mcd_comm_s).l,d7
		bmi.s	.wait_sub_o
	endif
		rts

; --------------------------------------------------------
; System_MdMcd_SubEnter
;
; Waits until Sub-CPU starts.
;
; Uses:
; d7
; --------------------------------------------------------

System_MdMcd_SubEnter:
	if MCD|MARSCD
.wait_sub_o:	move.b	(sysmcd_reg+mcd_comm_s).l,d7
		bpl.s	.wait_sub_o
	endif
		rts

; --------------------------------------------------------
; System_MdMcd_SubTask
;
; Request task to Sub-CPU
;
; Input:
; d0.b | Task number
;
; Uses:
; d7/a6
;
; Notes:
; This exits without waiting SUB to finish,
; call System_MdMcd_SubWait after this if required.
; --------------------------------------------------------

System_MdMcd_SubTask:
	if MCD|MARSCD
		movem.w	d6-d7,-(sp)
		lea	(sysmcd_reg+mcd_comm_m).l,a6
.wait_first:
		bsr	System_MdMcd_SubWait
		move.b	(a6),d7
		andi.w	#$C0,d7
		cmpi.w	#$C0,d7
		beq.s	.wait_first
		moveq	#9-1,d6
		move.b	d0,(a6)		; Set this command
.make_sure:
		move.b	(a6),d7
		cmp.b	d0,d7
		bne.s	.wait_first
		dbf	d6,.make_sure
.wait_sub_i:	move.b	1(a6),d7	; Wait until SUB gets busy
		bpl.s	.wait_sub_i
		andi.w	#$C0,d7
		cmp.w	#$C0,d7
		beq.s	.wait_first
		move.b	#$00,(a6)
		movem.w	(sp)+,d6-d7
	endif
		rts

; --------------------------------------------------------
; System_MdMcd_WaitWRAM
;
; Wait for Word-RAM permission.
; --------------------------------------------------------

System_MdMcd_WaitWRAM:
		btst	#0,(sysmcd_reg+mcd_memory).l
		beq.s	System_MdMcd_WaitWRAM
		rts

; --------------------------------------------------------
; System_MdMcd_CheckWRAM
;
; Checks if Word-RAM is set to MAIN in return
;
; Returns:
; beq | Word-RAM is available
; bne | Word-RAM is locked
; --------------------------------------------------------

System_MdMcd_CheckWRAM:
		btst	#0,(sysmcd_reg+mcd_memory).l
		beq.s	.no_ret
		or	#%00100,ccr	; beq
		rts
.no_ret:
		and	#%11011,ccr	; bne
		rts

; --------------------------------------------------------
; System_MdMcd_GiveWRAM
;
; Give Word-RAM to SubCPU (DMNA)
; --------------------------------------------------------

System_MdMcd_GiveWRAM:
		bset	#1,(sysmcd_reg+mcd_memory).l
		beq.s	System_MdMcd_GiveWRAM
		rts

; --------------------------------------------------------
; System_MdMcd_ReadFileRAM
;
; Read file from disc and transfer output the
; data to a1, uses communication ports.
;
; Input:
; a0   | Filename string: "FILENAME.BIN",0
; a1   | Output location in RAM
; d0.w | Size, $10-aligned sizes only
;
; Uses:
; d7,a0-a1,a5-a6
;
; Notes:
; - STOP ALL tracks that use PCM samples (gemaStopAll)
; --------------------------------------------------------

System_MdMcd_RdFile_RAM:
	if MCD|MARSCD
		movem.l	d0-d1/d7/a0-a1/a5-a6,-(sp)
		lea	(sysmcd_reg+mcd_dcomm_m),a5
		move.w	(a0)+,(a5)+			; 0 copy filename
		move.w	(a0)+,(a5)+			; 2
		move.w	(a0)+,(a5)+			; 4
		move.w	(a0)+,(a5)+			; 6
		move.w	(a0)+,(a5)+			; 8
		move.w	(a0)+,(a5)+			; 8
		move.w	#0,(a5)+			; A <-- zero end
		move.w	d0,d1
		moveq	#$01,d0				; COMMAND: READ CD AND PASS DATA
		bsr	System_MdMcd_SubTask
		move.w	d1,d0
	; a0 - Output location
	; d0 - Number of $10-byte packets
		lsr.w	#4,d0				; size >> 4
		subq.w	#1,d0				; -1
		lea	(sysmcd_reg+mcd_dcomm_s),a6
		move.b	(sysmcd_reg+mcd_comm_m).l,d7	; LOCK HERE
		bset	#7,d7
		move.b	d7,(sysmcd_reg+mcd_comm_m).l
.copy_ram:	move.b	(sysmcd_reg+mcd_comm_s).l,d7	; Wait if sub PASSed the packet
		btst	#4,d7
		beq.s	.copy_ram
		move.l	a6,a5
		move.w	(a5)+,(a1)+
		move.w	(a5)+,(a1)+
		move.w	(a5)+,(a1)+
		move.w	(a5)+,(a1)+
		move.w	(a5)+,(a1)+
		move.w	(a5)+,(a1)+
		move.w	(a5)+,(a1)+
		move.w	(a5)+,(a1)+
		move.b	(sysmcd_reg+mcd_comm_m).l,d7	; Tell SUB we got the pack
		bset	#6,d7
		move.b	d7,(sysmcd_reg+mcd_comm_m).l
.wait_sub:	move.b	(sysmcd_reg+mcd_comm_s).l,d7	; Wait clear
		btst	#4,d7
		bne.s	.wait_sub
		move.b	(sysmcd_reg+mcd_comm_m).l,d7	; and clear our bit too.
		bclr	#6,d7
		move.b	d7,(sysmcd_reg+mcd_comm_m).l
		dbf	d0,.copy_ram
		move.b	(sysmcd_reg+mcd_comm_m).l,d7	; UNLOCK
		bclr	#7,d7
		move.b	d7,(sysmcd_reg+mcd_comm_m).l
		movem.l	(sp)+,d0-d1/d7/a0-a1/a5-a6
	endif
		rts

; --------------------------------------------------------
; System_MdMcd_Trnsfr_WRAM
;
; Read file from disc and sends it to WORD-RAM,
; waits on finish.
;
; Input:
; a0   | Filename string "FILENAME.BIN",0
; a1   | Output location
;
; Notes:
; - STOP ALL tracks that use PCM samples (gemaStopAll)
; --------------------------------------------------------

System_MdMcd_RdFile_WRAM:
	if MCD|MARSCD
		movem.l	d7/a5-a6,-(sp)
		bsr	System_MdMcd_SubWait
		lea	(sysmcd_reg+mcd_dcomm_m).l,a5
		move.w	(a0)+,(a5)+				; $00 copy filename
		move.w	(a0)+,(a5)+				; $02
		move.w	(a0)+,(a5)+				; $04
		move.w	(a0)+,(a5)+				; $06
		move.w	(a0)+,(a5)+				; $08
		move.w	(a0)+,(a5)+				; $0A
		move.b	#0,(a5)+				; $0C: always 0
		move.b	#0,(a5)+				; $0D
		move.b	#0,(a5)+				; $0E
		move.b	#0,(a5)+				; $0F
		bsr	System_MdMcd_GiveWRAM
		move.w	d0,-(sp)
		move.w	#$02,d0					; COMMAND $02
		bsr	System_MdMcd_SubTask
		move.w	(sp)+,d0
		bsr	System_MdMcd_SubWait
		bsr	System_MdMcd_WaitWRAM
		movem.l	(sp)+,d7/a5-a6
	endif
		rts

; --------------------------------------------------------
; System_MdMcd_CheckHome
;
; Checks if the player is holding A, B, C and
; then presses the START button.
;
; Returns:
; bcc | Combo input not pressed
; bcs | User did the combo presses
;
; Notes:
; If you call this from your Title Screen, carry
; should JUMP (not call) to System_MdMcd_ExitShell,
; for other modes change your Screen number to the
; Title Screen and return.
; --------------------------------------------------------

System_MdMcd_CheckHome:
		movem.w	d6-d7,-(sp)
		move.w	(Controller_1+on_press).w,d7
		move.w	(Controller_1+on_hold).w,d6
		andi.w	#JoyA+JoyB+JoyC,d6
		cmpi.w	#JoyA+JoyB+JoyC,d6
		bne.s	.not_press
		andi.w	#JoyStart,d7
		beq.s	.not_press
		movem.w	(sp)+,d6-d7
		or	#1,ccr
		rts
.not_press:
		movem.w	(sp)+,d6-d7
		and	#%11110,ccr
		rts

; --------------------------------------------------------
; System_MdMcd_ExitShell
;
; Exits the entire program and goes to
; the BIOS/Shell.
;
; *** JUMP ONLY ***
; --------------------------------------------------------

; jmp $0280: Hot restart, Stops PSG and Clears VDP
; jmp $0284: Entry point
; jmp $0288: CD player
; jmp $028C: CD player, resets SP (safer)

System_MdMcd_ExitShell:
	if MCD|MARSCD
		bsr	Video_MdMcd_StampDisable
		bsr	System_MdMcd_CddaStop
	if MARSCD
		bsr	Video_MdMars_VideoOff
	endif
		jmp	$028C		; Exit jump
	else
		rts
	endif

; ------------------------------------------------------------
; CDDA PLAYBACK
; ------------------------------------------------------------

; --------------------------------------------------------
; System_MdMcd_CddaPlay, System_MdMcd_CddaPlayL
;
; Play CDDA track, normal or looped.
;
; Input:
; d0.w | CD track number
;
; This calls Sub-Task $10 for normal playback
; and $11 for looped
;
; Uses:
; d4
;
; Notes:
; Tracks $00, $01 and any negative values are
; ignored.
; --------------------------------------------------------

System_MdMcd_CddaPlay:
		movem.l	d0/d7/a6,-(sp)
		move.w	#$0010,d4
		bra	sysMdMcd_SetCdda
System_MdMcd_CddaPlayL:
		movem.l	d0/d7/a6,-(sp)
		move.w	#$0011,d4
sysMdMcd_SetCdda:
	if MCD|MARSCD
		tst.w	d0
		beq.s	.fail_safe
		bmi.s	.fail_safe
		cmp.w	#$0001,d0
		beq.s	.fail_safe
		move.w	d0,(sysmcd_reg+mcd_dcomm_m).l
		move.w	d4,d0
		bsr	System_MdMcd_SubTask
.fail_safe:
	endif
		movem.l	(sp)+,d0/d7/a6
		rts

; --------------------------------------------------------
; System_MdMcd_CdStop
;
; Stop CDDA track
; --------------------------------------------------------

System_MdMcd_CddaStop:
	if MCD|MARSCD
		move.l	d0,-(sp)
		move.w	#$0014,d0
		bsr	System_MdMcd_SubTask
		move.l	(sp)+,d0
	endif
		rts

; --------------------------------------------------------
; System_MdMcd_CdFade
;
; Fade the CDDA Volume
;
; Input:
; d0.w | Target volume:
;        $000-$400 - Min to Max
; d1.w | Fading speed:
;        $001-$200 - Slow to Fast
;             $400 - Set quick
;
; This calls Sub-Task $16
; --------------------------------------------------------

System_MdMcd_CddaFade:
	if MCD|MARSCD
		movem.l	d0-d1/d7/a6,-(sp)
		move.w	d0,(sysmcd_reg+mcd_dcomm_m).l
		move.w	d1,(sysmcd_reg+mcd_dcomm_m+2).l
		move.w	#$0016,d0
		bsr	System_MdMcd_SubTask
		movem.l	(sp)+,d0-d1/d7/a6
	endif
		rts

; --------------------------------------------------------
; DEFAULT Save filename for SEGA CD / CD32X
; --------------------------------------------------------

def_SaveInfo:
	if MARSCD
		dc.b HTAG_MARSCDSAV,0
	else
		dc.b HTAG_CDSAVE,0
	endif
		dc.w (SET_SRAMSIZE/$40)
		dc.w 0
		align 2

; ====================================================================
; ----------------------------------------------------------------
; 32X and CD32X ONLY
; ----------------------------------------------------------------

; --------------------------------------------------------
; System_MdMars_SendData
;
; Transfers Genesis data to the 32X's SDRAM
; using DREQ
;
; Input:
; a0   | Source data
; a1.l | Destination in SH2's SDRAM area ($00xxxxxx)
; d0.l | Size, only 8-byte-aligned sizes allowed.
;
; Returns:
; a1   | New output SDRAM location
;
; Uses:
; d0/a4-a5,d5-d7
;
; Notes:
; - Call this during DISPLAY ONLY, NOT during VBlank.
; - POPULAR 32X EMULATORS WILL GET STUCK HERE
; --------------------------------------------------------

System_MdMars_SendData:
	if MARS|MARSCD
		movem.l	d3-d4,-(sp)
		move.l	#$00FFF8,d3	; Maximum packet sizes
		moveq	#-8,d4
		and.l	d4,d0
		move.l	d0,d4
		cmp.l	d3,d4
		bgt.s	.large_pack
		bsr	sys_MSendData_0	; Small packet
		bra.s	.exit_now
.large_pack:
		move.w	d3,d0
		bsr	sys_MSendData_0
		sub.l	d3,d4
		cmp.l	d3,d4
		bge.s	.large_pack
		tst.l	d4
		beq.s	.exit_now
		bmi.s	.exit_now
		move.w	d4,d0
		bsr	sys_MSendData_0
.exit_now:
		movem.l	(sp)+,d3-d4
	endif
		rts

; ------------------------------------------------------------
; DREQ Genesis-to-32X code
; ------------------------------------------------------------

	if MARS|MARSCD

sys_MSendData_0:
		movem.l	a5-a6/d5-d7,-(sp)
		moveq	#0,d6				; Mode 0: Normal data transfer
		bsr.s	sys_MSendData
		movem.l	(sp)+,a5-a6/d5-d7
		rts

; --------------------------------------------------------
; System_MdMars_Update
;
; Send a section of MD RAM to 32X's SDRAM
;
; Notes:
; Call this during DISPLAY ONLY
; --------------------------------------------------------

System_MdMars_Update:
		movem.l	d5-d7/a0/a5-a6,-(sp)
		move.w	d0,-(sp)
		lea	(RAM_MdMars_CommBuff).w,a0
		move.w	#Dreq_len,d0
		moveq	#1,d6				; Mode 1: Per-frame RAM send
		bsr.s	sys_MSendData
		move.w	(sp)+,d0
		movem.l	(sp)+,d5-d7/a0/a5-a6
		bset	#5,(sysmars_reg+comm12+1).l	; Swap DREQ-RAM buffer on SH2
		rts
; --------------------------------------------------------

; updates a1
sys_MSendData:
		move.w	sr,d5
		ori.w	#$0700,sr			; Disable interrupts
		lea	(sysmars_reg).l,a6		; a6 - sysmars_reg
		lea	dreqfifo(a6),a5			; a5 - FIFO port
		moveq	#0,d7
		move.w	d0,d7				; d7.l - Size
		tst.w	d6				; CMD mode 0?
		bne.s	.no_src
		move.l	a1,dreqdest(a6)
		add.l	d7,a1				; Update a1
.no_src:
		move.b	d6,comm12(a6)			; d6 - Set CMD mode (target output)
		move.w	#%000,dreqctl(a6)		; Reset 68S, RV off
		lsr.w	#1,d7				; length >> 2
		move.w	d7,dreqlen(a6)			; Set transfer lenght
		lsr.w	#2,d7				; lenght/2 >> 4
		subi.w	#1,d7
		bset	#0,standby(a6)			; Call CMD interrupt to MASTER
.wait_bit:	btst	#6,comm12(a6)			; Wait ENTRANCE signal
		beq.s	.wait_bit
		move.w	#%100,dreqctl(a6)		; Enable 68S, RV off
	; *** CRITICAL PART ***
.loop_fifo:
		btst	#7,dreqctl(a6)			; FIFO full?
		bne.s	.loop_fifo
		move.w  (a0)+,(a5)
		move.w  (a0)+,(a5)
		move.w  (a0)+,(a5)
		move.w  (a0)+,(a5)
		dbf	d7,.loop_fifo
	if EMU=0
.wait_bit_e:	btst	#6,comm12(a6)			; Wait EXIT signal
		bne.s	.wait_bit_e
	endif
		move.w	#%000,dreqctl(a6)		; Disable 68S, RV off
		move.w	d5,sr				; Restore interrupts
	endif
		rts

; ====================================================================
; ----------------------------------------------------------------
; SHARED for all
; ----------------------------------------------------------------

; --------------------------------------------------------
; System_SetDataBank
;
; Sets the data bank depending of the system
;
; Input:
; a0   | Pointer and filename:
;        dc.l bank_pointer
;        dc.b "FILENAME.BIN"
;
; Uses:
; a4-a5,d5-d7
;
; Notes:
; - ONLY call this if you have the opportunity to
;   do it.
; - SEGA CD / CD32X: This sets the WORD-RAM
;   to load from disc
;   * DO NOT USE THIS WHEN STAMPS ARE ACTIVE
;   Call Video_Mcd_StampDisable If neeeded. *
; --------------------------------------------------------

System_SetDataBank:
	if MCD|MARSCD
		adda	#4,a0
		bsr	System_MdMcd_RdFile_WRAM
	elseif MARS
		move.l	d7,-(sp)
	rept 3
		bsr	Video_MdMars_WaitSync
		bsr	Video_MdMars_SetSync
	endm
		move.l	(a0),d7
		swap	d7
		lsr.w	#4,d7
		andi.w	#%11,d7
		move.w	d7,(sysmars_reg+bankset).l
		move.l	(sp)+,d7
	endif
		rts

; ====================================================================
; ----------------------------------------------------------------
; Objects system
; ----------------------------------------------------------------

; --------------------------------------------------------
; Init/Clear Objects system
; --------------------------------------------------------

Object_Init:
		lea	(RAM_Objects).w,a6
		move.w	#(obj_len*MAX_MDOBJ)-1,d7
.clr:
		clr.b	(a6)+
		dbf	d7,.clr
		rts

; --------------------------------------------------------
; Process objects
;
; ONLY CALL THIS ONCE PER FRAME
; --------------------------------------------------------

Object_Run:
		lea	(RAM_Objects).w,a6
		move.w	#MAX_MDOBJ-1,d7
.next_one:
		move.l	obj_code(a6),d6
		beq.s	.no_code	; Free slot
		move.l	d7,-(sp)
		move.l	d6,a5
		jsr	(a5)
		move.l	(sp)+,d7
.no_code:
		adda	#obj_len,a6
		dbf	d7,.next_one
		rts

; --------------------------------------------------------
; Object_Set, Object_Make
;
; Set a new object into a specific slot.
;
; Input:
; d0.l | Object code pointer
;        If 0: DELETE the object including it's memory
; d1.w | Object slot
;        If -1: Auto-search starting from FIRST slot.
; d2.b | Object sub-type (obj_subid)
;
; Returns:
; bcc | Found free slot
; bcs | Ran-out of object slots
;
; Notes:
; If you are not using obj_subid you can ignore it,
; but it will contain the remains of d2 when you
; called this.
; --------------------------------------------------------

Object_Set:
		movem.l	d6-d7/a5-a6,-(sp)
		lea	(RAM_Objects).w,a6
		moveq	#0,d7
		move.w	d1,d7
		mulu.w	#obj_len,d7
		adda	d7,a6
		bra.s	objSet_Go

Object_Make:
		movem.l	d6-d7/a5-a6,-(sp)
		lea	(RAM_Objects).w,a6
		move.w	#MAX_MDOBJ-1,d7
		moveq	#0,d6
.search:
		cmp.w	#MAX_MDOBJ,d6
		bge.s	objSet_Error
		tst.l	obj_code(a6)
		beq.s	objSet_Go
		adda	#obj_len,a6
		addq.w	#1,d6
		dbf	d7,.search
objSet_Error:
		movem.l	(sp)+,d6-d7/a5-a6
		move	#1,ccr			; Return carry (No slots)
		rts

objSet_Go:
		tst.l	d0
		beq.s	.from_del
		move.l	d0,d7
		move.l	d7,obj_code(a6)
		move.b	d2,obj_subid(a6)
		bra.s	.exit_this
.from_del:
		move.l	a6,a5			; Delete entire object
		move.w	#obj_len-1,d7
.clr:		clr.b	(a5)+
		dbf	d7,.clr
.exit_this:
		movem.l	(sp)+,d6-d7/a5-a6
		or	#1,ccr
		rts

; ====================================================================
; --------------------------------------------------------
; Object subroutines
;
; These can ONLY be called on the current object's code
; --------------------------------------------------------

; --------------------------------------------------------
; object_ResetVars
;
; Resets the current object's memory, call this
; at very beginning of your object's init code
;
; Input:
; a6 | This object
; --------------------------------------------------------

object_ResetVars:
		movem.l	d6-d7/a5,-(sp)
		lea	obj_ram(a6),a5
		move.w	#(obj_len-obj_ram)-1,d6
		moveq	#0,d7
.clr_ram:	move.b	d7,(a5)+
		dbf	d6,.clr_ram
		movem.l	(sp)+,d6-d7/a5
		rts

; --------------------------------------------------------
; object_ResetAnim
;
; Reset animation variables, call this BEFORE using
; object_Animate.
;
; Input:
; a6 | This object
; --------------------------------------------------------

object_ResetAnim:
;  		clr.w	obj_anim_indx(a6)
;  		clr.b	obj_anim_spd(a6)
		move.b	#-1,obj_anim_icur(a6)
		rts

; --------------------------------------------------------
; object_Speed
;
; Moves the object using speed values set on
; obj_x_spd and obj_y_spd, updates obj_x and obj_y.
;
; Input:
; a6 | This object
; --------------------------------------------------------

object_Speed:
		move.l	d7,-(sp)
		moveq	#0,d7
		move.w	obj_x_spd(a6),d7
		ext.l	d7
		asl.l	#8,d7
		add.l	d7,obj_x(a6)
		moveq	#0,d7
		move.w	obj_y_spd(a6),d7
		ext.l	d7
		asl.l	#8,d7
		add.l	d7,obj_y(a6)
		moveq	#0,d7
		move.w	obj_z_spd(a6),d7
		ext.l	d7
		asl.l	#8,d7
		add.l	d7,obj_z(a6)
		move.l	(sp)+,d7
		rts

; --------------------------------------------------------
; object_Animate
;
; Animates the sprite with a animation script,
; modifies obj_frame with the frame to use.
;
; Input:
; a6 | This object
; a0 | Animation data
; --------------------------------------------------------

; anim_data:
; 	dc.w .frame_1-anim_data
; 	dc.w .frame_2-anim_data
; 	;...
;
; .frame_num:
; 	dc.w speed			; Animation speed/delay
; 	dc.w frame_0,frame_1,...	; Frames list
; 	dc.w command			; End-of-data command
;
; commands:
; dc.w -1 		; Finish animation, stops at last frame.
; dc.w -2 		; Loop animation, goes back to index 0
; dc.w -3,to_indx	; Jump to index

object_Animate:
		movem.l	a0/d5-d7,-(sp)
		moveq	#0,d7
 		move.b	obj_anim_icur(a6),d7
 		cmp.w	obj_anim_num(a6),d7
 		beq.s	.sameThing
 		move.b	obj_anim_num+1(a6),obj_anim_icur(a6)
 		clr.w	obj_anim_indx(a6)
 		clr.b	obj_anim_spd(a6)
.sameThing:
 		move.w	obj_anim_num(a6),d7
 		cmpi.b	#-1,d7
 		beq.s	.return
 		add.w	d7,d7
 		move.w	(a0,d7.w),d7
 		lea	(a0,d7.w),a0
 		move.w	(a0)+,d7
 		cmpi.w	#-1,d7
 		beq.s	.keepspd
 		subi.b	#1,obj_anim_spd(a6)
 		bpl.s	.return
		move.b	d7,obj_anim_spd(a6)
.keepspd:
 		moveq	#0,d6
 		move.w	obj_anim_indx(a6),d7
 		add.w	d7,d7
 		move.w	(a0),d6
 		adda	d7,a0
 		move.w	(a0),d5
 		cmpi.w	#-1,d5
 		beq.s	.lastFrame	; finish
 		cmpi.w	#-2,d5
 		beq.s	.noAnim		; loop animation
 		cmpi.w	#-3,d5
 		beq.s	.goToFrame
 		move.w	d5,obj_frame(a6)
 		add.w	#1,obj_anim_indx(a6)
.return:
 		bra.s	.exit_anim
.noAnim:
 		move.w	#1,obj_anim_indx(a6)
 		move.w	d6,d5
 		move.w	d5,obj_frame(a6)
		bra.s	.exit_anim
.goToFrame:
		clr.w	obj_anim_indx(a6)
		move.w	2(a0),obj_anim_indx(a6)
.lastFrame:
 		clr.b	obj_anim_spd(a6)
.exit_anim:
		movem.l	(sp)+,a0/d5-d7
		rts

; --------------------------------------------------------
; object_Touch
;
; Detects collision with another Object
; from the Object's list, reads TOP to BOTTOM
;
; Input:
; a6   | This object
;
; Returns:
; d0.l | If Nothing: 0
;        If Found:   The target's RAM location
; --------------------------------------------------------

object_Touch:
		movem.l	d1-d7/a5,-(sp)
		moveq	#0,d0
		move.w	obj_size_x(a6),d6	; Check if we have a valid size
		move.w	obj_size_y(a6),d5
		or.w	d5,d6
		beq	.exit_this
		lea	(RAM_Objects).w,a5
		moveq	#MAX_MDOBJ-1,d7
.next:
		cmp.l	a6,a5			; If reading THIS object, skip
		beq.s	.skip
		tst.l	obj_code(a5)		; This object has code?
		beq.s	.skip
		bsr.s	.check_this
		tst.w	d0			; Exit if Found.
		bne.s	.exit_this
.skip:		adda	#obj_len,a5
		dbf	d7,.next
		moveq	#0,d0
.exit_this:
		movem.l	(sp)+,d1-d7/a5
		rts

; main check
.check_this:
		moveq	#0,d0			; Reset Return
	; d6 - Y current top
	; d5 - Y current bottom
	; d4 - Y target top
	; d3 - Y target bottom
	; Check X
		move.w	obj_size_x(a6),d1	; $LLRR
		beq	.not_ytop
		move.w	obj_x(a6),d6		; d6 - Left point
		move.w	d6,d5			; d5 - Right point
		move.w	d1,d2
		lsr.w	#8,d1			; d1 - Left size
		andi.w	#$FF,d2			; d2 - Right size
; 		lsl.w	#3,d1
; 		lsl.w	#3,d2
		subq.w	#1,d2			; X right adjust
		sub.w	d1,d6
		add.w	d2,d5
		move.w	obj_size_x(a5),d1	; $LLRR
		beq	.not_ytop
		move.w	obj_x(a5),d4		; d4 - Left point
		move.w	d4,d3			; d3 - Right point
		move.w	d1,d2
		lsr.w	#8,d1			; d1 - Left size
		andi.w	#$FF,d2			; d2 - Right size
; 		lsl.w	#3,d1
; 		lsl.w	#3,d2
		subq.w	#1,d2
		sub.w	d1,d4
		add.w	d2,d3
		cmp.w	d6,d3
		blt	.not_ytop
		cmp.w	d5,d4
		bge	.not_ytop

	; Check Y
		move.w	obj_size_y(a6),d1	; $LLRR
		beq	.not_ytop
		move.w	obj_y(a6),d6		; d6 - Left point
		move.w	d6,d5			; d5 - Right point
		move.w	d1,d2
		lsr.w	#8,d1			; d1 - Left size
		andi.w	#$FF,d2			; d2 - Right size
; 		lsl.w	#3,d1
; 		lsl.w	#3,d2
		subq.w	#1,d2
		sub.w	d1,d6
		add.w	d2,d5
		move.w	obj_size_y(a5),d1	; $LLRR
		beq	.not_ytop
		move.w	obj_y(a5),d4		; d4 - Left point
		move.w	d4,d3			; d3 - Right point
		move.w	d1,d2
		lsr.w	#8,d1			; d1 - Left size
		andi.w	#$FF,d2			; d2 - Right size
; 		lsl.w	#3,d1
; 		lsl.w	#3,d2
		subq.w	#1,d2
		sub.w	d1,d4
		add.w	d2,d3
		cmp.w	d6,d3
		blt.s	.not_ytop
		cmp.w	d5,d4
		bge.s	.not_ytop

	; Special Z check
		move.w	obj_size_z(a6),d1	; $LLRR
		beq.s	.set_ok
		move.w	obj_z(a6),d6		; d6 - Left point
		move.w	d6,d5			; d5 - Right point
		move.w	d1,d2
		lsr.w	#8,d1			; d1 - Left size
		andi.w	#$FF,d2			; d2 - Right size
; 		lsl.w	#3,d1
; 		lsl.w	#3,d2
		subq.w	#1,d2
		sub.w	d1,d6
		add.w	d2,d5
		move.w	obj_size_z(a5),d1	; $LLRR
		beq.s	.set_ok
		move.w	obj_z(a5),d4		; d4 - Left point
		move.w	d4,d3			; d3 - Right point
		move.w	d1,d2
		lsr.w	#8,d1			; d1 - Left size
		andi.w	#$FF,d2			; d2 - Right size
; 		lsl.w	#3,d1
; 		lsl.w	#3,d2
		subq.w	#1,d2
		sub.w	d1,d4
		add.w	d2,d3
		cmp.w	d6,d3
		blt	.not_ytop
		cmp.w	d5,d4
		bge	.not_ytop
.set_ok:
		move.l	a5,d0			; FOUND OBJECT
.not_ytop:
		rts

; ============================================================
; --------------------------------------------------------
; object_GetSprInfo
;
; Call this before using
; Video_MdMars_MakeSpr2D or Video_MdMars_MakeSpr3D
;
; Input:
; a6   | This object
; d0.l | X/Y center: splitw(center_x,center_y)
;        - Set to 0 for 3D Sprites
; d1.w | Flags
;
; Output:
; d0.l | X and Y position
; d1.l | Flags and Z Position
; d4.w | Current frame
; --------------------------------------------------------

object_MdMars_GetSprInfo:
	if MARS|MARSCD
		swap	d1
		move.w	obj_z(a6),d1
		swap	d0
		move.w	obj_x(a6),d4
		sub.w	d0,d4
		swap	d4
		swap	d0
		move.w	obj_y(a6),d4		; d0 - Xpos | Ypos
		sub.w	d0,d4
		exg.l	d4,d0
		moveq	#0,d4
		move.w	obj_frame(a6),d4
	endif
		rts
