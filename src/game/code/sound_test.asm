; ===========================================================================
; ----------------------------------------------------------------
; GEMA SOUND TESTER
; ----------------------------------------------------------------

; ====================================================================
; ------------------------------------------------------
; Settings
; ------------------------------------------------------

VIEW_GEMAINFO		equ 0		; ** Using this causes loss of DAC quality **
VIEW_FAIRY		equ 1		; Show status Dodo/Mifi/Fifi

; ====================================================================
; ------------------------------------------------------
; Variables
; ------------------------------------------------------

MAX_SNDPICK		equ 7
SET_SNDVIEWY		equ 16

; ====================================================================
; ------------------------------------------------------
; Structs
; ------------------------------------------------------

			memory 2
setVram_Dodo		ds.b $30
setVram_Mimi		ds.b $30
setVram_Fifi		ds.b $30
			endmemory

; ====================================================================
; ------------------------------------------------------
; This mode's RAM
; ------------------------------------------------------

			memory RAM_ScrnBuff
RAM_GemaCache_PSG	ds.l 3
RAM_GemaCache_PSGN	ds.l 1
RAM_GemaCache_FM	ds.l 4
RAM_GemaCache_FM3	ds.l 1
RAM_GemaCache_FM6	ds.l 1
RAM_GemaCache_PCM	ds.l 8
RAM_GemaCache_PWM	ds.l 8

RAM_CurrPick		ds.w 1
RAM_LastPick		ds.w 1
RAM_GemaIndx		ds.w 1		; DONT MOVE
RAM_GemaSeq		ds.w 1		; ''
RAM_GemaBlk		ds.w 1		; ''
RAM_GemaStatus		ds.w 4
RAM_FairyVars		ds.w 1
RAM_CurrBeats		ds.w 1
RAM_Copy_fmSpecial	ds.w 1
RAM_Copy_HasDac		ds.w 1

sizeof_thisbuff		ds.l 0
			endmemory

	erreport "THIS SCREEN",sizeof_thisbuff-RAM_ScrnBuff,MAX_ScrnBuff

; ====================================================================
; ------------------------------------------------------
; Init
; ------------------------------------------------------

		bsr	Video_DisplayOff
		bsr	System_Default
	; ----------------------------------------------
	; Load assets
; 	if MARS|MARSCD
; 		lea	file_tscrn_mars(pc),a0			; Load DATA BANK for 32X stuff
; 		bsr	System_SetDataBank
; 		lea	(PalMars_STest),a0
; 		move.w	#0,d0
; 		move.w	#256,d1
; 		moveq	#0,d2
; 		bsr	Video_MdMars_FadePal
; 		clr.w	(RAM_MdMars_PalFd).w
; 		lea	(ArtMars_Test2D),a0
; 		move.l	#0,a1
; 		move.l	#ArtMars_Test2D_e-ArtMars_Test2D,d0
; 		bsr	Video_MdMars_LoadVram
; 		lea	(RAM_MdMars_Models).w,a0
; 		move.l	#MarsObj_test_2,mmdl_data(a0)
; 		move.l	#0,mmdl_z_pos(a0)
; 		moveq	#2,d0					; 32X 3D mode
; 		bsr	Video_MdMars_VideoMode
; 	endif
	; ----------------------------------------------
	; Load assets
		lea	file_tscrn_main(pc),a0		; ** LOAD BANK **
		bsr	System_SetDataBank
	; ----------------------------------------------
		move.l	#ASCII_FONT,d0			; Load and setup PRINT system
		move.w	#DEF_PrintVram|$6000,d1
		bsr	Video_PrintInit
		move.l	#ASCII_FONT_W,d0
		move.w	#DEF_PrintVramW|$6000,d1
		bsr	Video_PrintInitW
		lea	(RAM_PaletteFade+$40).w,a0	; Palette line 4:
		move.w	#$0000,(a0)
		move.w	#$00E0,2(a0)
		move.w	#$00A0,4(a0)
		move.w	#$0080,4(a0)
		adda	#$20,a0
		move.w	#$0000,(a0)
		move.w	#$0EEE,2(a0)
		move.w	#$0AAA,4(a0)
		move.w	#$0888,4(a0)
		lea	(objPal_Dodo+2),a0
		moveq	#1,d0
		move.w	#15,d1
		bsr	Video_FadePal
		lea	ArtList_Stuff(pc),a0
		bsr	Video_LoadArt_List

	; ----------------------------------------------
		lea	str_TesterTitle(pc),a0
		moveq	#6,d0
		moveq	#2,d1
		move.w	#DEF_PrintVramW|DEF_PrintPal,d2
		move.l	#splitw(DEF_HSIZE_64,DEF_VRAM_FG),d3
		bsr	Video_PrintW
		lea	str_TesterInfo(pc),a0
	if VIEW_FAIRY
		moveq	#6,d0
	else
		moveq	#13,d0
	endif
		moveq	#7,d1
		move.w	#DEF_PrintVram|$4000,d2
		bsr	Video_Print
		lea	str_Instruc(pc),a0
		moveq	#2,d0
; 		moveq	#14,d1
		moveq	#21,d1
		move.w	#DEF_PrintVram|$4000,d2
		bsr	Video_Print
		bsr	.gema_viewinit
; 		bsr	.show_cursor
	; ----------------------------------------------
		bsr	gemaReset				; Load default GEMA sound data
; 		moveq	#1,d0
; 		moveq	#%10,d1
; 		bsr	Video_Resolution
	; ----------------------------------------------
		bsr	.show_me
		bsr	.gema_view
; 		bsr	.steal_vars
	; ----------------------------------------------
		bsr	Video_DisplayOn
		bsr	Object_Run
		bsr	Video_BuildSprites
		bsr	System_Render
		bsr	Video_FadeIn_Full

; ====================================================================
; ------------------------------------------------------
; Loop
; ------------------------------------------------------

.loop:
		bsr	System_Render
; 		bsr	.show_cursor
		bsr	.gema_view
		bsr	Object_Run
		bsr	Video_BuildSprites
; 	if MARS|MARSCD
; 		lea	(RAM_MdMars_Models).w,a0
; 		add.l	#1,mmdl_y_rot(a0)
; 		add.l	#1,mmdl_x_rot(a0)
; 	endif


; 		lea	str_Info(pc),a0
; 		moveq	#31,d0
; 		moveq	#4,d1
; 		move.w	#DEF_PrintVramW|DEF_PrintPal,d2
; 		move.l	#splitw(DEF_HSIZE_64,DEF_VRAM_FG),d3
; 		bsr	Video_PrintW

	; NEW controls
		lea	(Controller_1).w,a6
	; LEFT/RIGHT
		move.w	on_press(a6),d7
		andi.w	#JoyLeft+JoyRight,d7
		beq.s	.lr_seq
		moveq	#1,d0
		andi.w	#JoyLeft,d7
		beq.s	.lr_right
		tst.w	(RAM_GemaSeq).w
		beq.s	.lr_seq
		neg.w	d0
.lr_right:
		add.w	d0,(RAM_GemaSeq).w
		bsr	.show_me
.lr_seq:

	; UP/DOWN
		move.w	on_press(a6),d7
		andi.w	#JoyUp+JoyDown,d7
		beq.s	.ud_seq
		moveq	#1,d0
; 		andi.w	#JoyUp,d7
		andi.w	#JoyUp,d7
		beq.s	.ud_right
		tst.w	(RAM_GemaBlk).w
		beq.s	.ud_seq
		neg.w	d0
.ud_right:
		add.w	d0,(RAM_GemaBlk).w
		bsr	.show_me
.ud_seq:

	; X/Y
		move.w	on_press(a6),d7
		andi.w	#JoyX+JoyY,d7
		beq.s	.xy_seq
		moveq	#1,d0
		andi.w	#JoyX,d7
		beq.s	.xy_right
		tst.w	(RAM_GemaIndx).w
		beq.s	.xy_seq
		neg.w	d0
.xy_right:
		add.w	d0,(RAM_GemaIndx).w
		bsr	.show_me
.xy_seq:

	; C BUTTON
		move.w	on_press(a6),d7
		andi.w	#JoyC+JoyZ,d7
		beq.s	.c_press
		lea	(RAM_GemaIndx).w,a5

		move.w	(a5)+,d2
		andi.w	#JoyZ,d7
		beq.s	.not_auto
		moveq	#-1,d2
.not_auto:
		move.w	(a5)+,d0
		move.w	(a5)+,d1
		bsr	gemaPlaySeq

		move.w	(RAM_GemaSeq).w,d0	; External beats
		move.w	d0,d1
		add.w	d1,d1
		lea	exgema_beats(pc),a0
		move.w	(a0,d1.w),d0
		move.w	d0,(RAM_CurrBeats).w
		bsr	gemaSetBeats
.c_press:
	; B BUTTON
		move.w	on_press(a6),d7
		andi.w	#JoyB,d7
		beq.s	.b_press
		lea	(RAM_GemaIndx).w,a5
		move.w	(a5)+,d1
		move.w	(a5)+,d0
		bsr	gemaStopSeq
.b_press:
		move.w	on_press(a6),d7
		andi.w	#JoyA,d7
		beq.s	.a_press
		bsr	gemaStopAll
.a_press:


; 		move.w	on_hold(a6),d7
; 		andi.w	#JoyA+JoyB+JoyC,d7
; 		bne.s	.n_up
; 		move.w	on_press(a6),d7
; 		btst	#bitJoyDown,d7
; 		beq.s	.n_down
; 		addq.w	#1,(a5)
; 		cmp.w	#MAX_SNDPICK,(a5)		; MAX OPTIONS
; 		ble.s	.n_downd
; 		clr.w	(a5)
; .n_downd:
; 		bsr.s	.show_me
; .n_down:
; 		move.w	on_press(a6),d7
; 		btst	#bitJoyUp,d7
; 		beq.s	.n_up
; 		subq.w	#1,(a5)
; 		bpl.s	.n_ups
; 		move.w	#MAX_SNDPICK,(a5)
; .n_ups:
; 		bsr.s	.show_me
; .n_up:
; 		move.w	(RAM_CurrPick).w,d7
; 		lsl.w	#2,d7
; 		jsr	.jump_list(pc,d7.w)
; 		tst.w	(RAM_ScreenMode).w	; Check -1
; 		bpl.s	.n_cbtn

; .n_cbtn:
		bra	.loop

; ------------------------------------------------------

.exit_all:
		bsr	gemaStopAll
		bsr	Video_FadeOut_Full
		move.w	#0,(RAM_ScreenMode).w	; Return to mode 0
		rts				; EXIT

; ------------------------------------------------------

.show_me:
		move.w	(RAM_GemaSeq).w,d0	; External beats
		move.w	d0,d1
		add.w	d1,d1
		lea	exgema_beats(pc),a0
		move.w	(a0,d1.w),d0
		move.w	d0,(RAM_CurrBeats).w

		lea	str_ShowBeats(pc),a0
	if VIEW_FAIRY
		moveq	#13,d0
	else
		moveq	#20,d0
	endif
		moveq	#12,d1
		move.w	#DEF_PrintVram|DEF_PrintPal,d2
		move.l	#splitw(DEF_HSIZE_64,DEF_VRAM_FG),d3
		bsr	Video_Print
		lea	str_ShowVars(pc),a0
	if VIEW_FAIRY
		moveq	#7,d0
	else
		moveq	#14,d0
	endif
		moveq	#9,d1
		move.w	#DEF_PrintVramW|DEF_PrintPal,d2
		move.l	#splitw(DEF_HSIZE_64,DEF_VRAM_FG),d3
		bra	Video_PrintW

; ; ------------------------------------------------------
;
; .jump_list:
; 		bra.w	.nothing
; 		bra.w	.option_1
; 		bra.w	.option_2
; 		bra.w	.option_3
; 		bra.w	.option_4
; 		bra.w	.option_5
; 		bra.w	.option_6
; 		bra.w	.option_7
;
; ; ------------------------------------------------------
; ; OPTION 0
; ; ------------------------------------------------------
;
; .nothing:
; 		move.w	on_press(a6),d7
; 		btst	#bitJoyStart,d7
; 		beq.s	.no_press
; 		bsr.s	.show_me
; 		bra	gemaTest
; .no_press:
; 		rts
;
; ------------------------------------------------------
; OPTION 1
; ------------------------------------------------------

; 		bra.s	.show_me
; .option1_args:
; 		move.w	on_hold(a6),d7
; 		move.w	d7,d6
; 		andi.w	#JoyA+JoyB+JoyC,d6
; 		beq.s	.no_press
; 		btst	#bitJoyB,d7
; 		beq.s	.d2_opt
; 		adda	#2,a5
; .d2_opt:
; 		btst	#bitJoyC,d7
; 		beq.s	.d3_opt
; 		adda	#4,a5
; .d3_opt:
; 		move.w	on_press(a6),d7
; 		btst	#bitJoyRight,d7
; 		beq.s	.op1_right
; 		addq.w	#1,(a5)
; 		bra	.show_me
; .op1_right:
; 		btst	#bitJoyLeft,d7
; 		beq.s	.op1_left
; 		subq.w	#1,(a5)
; 		bra	.show_me
; .op1_left:
; 		move.w	on_hold(a6),d7
; 		btst	#bitJoyUp,d7
; 		beq.s	.op1_down
; 		addq.w	#1,(a5)
; 		bra	.show_me
; .op1_down:
; 		btst	#bitJoyDown,d7
; 		beq.s	.op1_up
; 		subq.w	#1,(a5)
; 		bra	.show_me
; .op1_up:
;
; 		rts
;
; ; ------------------------------------------------------
; ; OPTION 2
; ; ------------------------------------------------------
;
; .option_2:
; 		lea	(RAM_GemaIndx).w,a5
; 		move.w	on_press(a6),d7
; 		btst	#bitJoyStart,d7
; 		beq.s	.option1_args
; 		move.w	(a5)+,d0
; 		move.w	(a5)+,d1
; 		bra	gemaStopSeq
;
; ; ------------------------------------------------------
; ; OPTION 3
; ; ------------------------------------------------------
;
; .option_3:
; 		lea	(RAM_GemaArg3).w,a5
; 		move.w	on_press(a6),d7
; 		btst	#bitJoyStart,d7
; 		beq	.option1_args
; 		move.w	(a5)+,d0
; 		move.w	(a5)+,d1
; 		bra	gemaFadeSeq
;
; ; ------------------------------------------------------
; ; OPTION 4
; ; ------------------------------------------------------
;
; .option_4:
; 		lea	(RAM_GemaArg3).w,a5
; 		move.w	on_press(a6),d7
; 		btst	#bitJoyStart,d7
; 		beq	.option1_args
; 		move.w	(a5)+,d0
; 		move.w	(a5)+,d1
; 		bra	gemaSetSeqVol
;
; ; ------------------------------------------------------
; ; OPTION 5
; ; ------------------------------------------------------
;
; .option_5:
; 		move.w	on_press(a6),d7
; 		btst	#bitJoyStart,d7
; 		beq.s	.no_press2
; 		bsr	.show_me
; 		bra	gemaStopAll
; .no_press2:
; 		rts
;
; ; ------------------------------------------------------
; ; OPTION 6
; ; ------------------------------------------------------
;
; .option_6:
; 		lea	(RAM_GemaArg6).w,a5
; 		move.w	on_hold(a6),d7
; 		andi.w	#JoyA,d7
; 		beq.s	.no_press2
; 		move.w	on_press(a6),d7
; 		btst	#bitJoyRight,d7
; 		beq.s	.op2_right
; 		addq.w	#1,(a5)
; 		bra	.show_me_2
; .op2_right:
; 		btst	#bitJoyLeft,d7
; 		beq.s	.op2_left
; 		subq.w	#1,(a5)
; 		bsr	.show_me_2
; .op2_left:
; 		move.w	on_hold(a6),d7
; 		btst	#bitJoyDown,d7
; 		beq.s	.op2_down
; 		addq.w	#1,(a5)
; 		bsr	.show_me_2
; .op2_down:
; 		btst	#bitJoyUp,d7
; 		beq.s	.op2_up
; 		subq.w	#1,(a5)
; 		bsr	.show_me_2
; .op2_up:
; 		move.w	on_press(a6),d7
; 		btst	#bitJoyStart,d7
; 		beq.s	.no_press2
; .show_me_2:
; 		bsr	.show_me
; 		move.w	(a5),d0
; 		bra	gemaSetBeats
;
; ; ------------------------------------------------------
; ; OPTION 7
; ; ------------------------------------------------------
;
; .option_7:
; 		move.w	on_press(a6),d7
; 		btst	#bitJoyStart,d7
; 		beq.s	.no_press2
; 		move.w	#-1,(RAM_ScreenMode).w	; risky but works.
; 		rts

; ------------------------------------------------------

.gema_viewinit:
	if VIEW_FAIRY
		move.l	#obj_Fairy,d0		; <-- If you don't like the fairies comment out or
		moveq	#0,d2			; delete all of this
		bsr	Object_Make		;
		addq.w	#1,d2			;
		bsr	Object_Make		;
		addq.w	#1,d2			;
		bsr	Object_Make		; <-- until here
	endif

	if VIEW_GEMAINFO
		lea	str_VmInfo(pc),a0
		moveq	#2,d0
		moveq	#SET_SNDVIEWY,d1
		move.w	#DEF_PrintVram|DEF_PrintPal,d2
		move.l	#splitw(DEF_HSIZE_64,DEF_VRAM_FG),d3
		bsr	Video_Print
	endif

.gema_view:
		move.w	#$0100,(z80_bus).l
		lea	(RAM_GemaStatus),a1
		moveq	#0,d0
		moveq	#0,d1
		moveq	#0,d2
.wait:		btst	#0,(z80_bus).l
		bne.s	.wait
		move.b	(z80_cpu+trkBuff_0),d0
		move.b	(z80_cpu+trkBuff_1),d1
		move.b	(z80_cpu+trkBuff_2),d2
		bsr	sndUnlockZ80
		move.w	d0,(a1)+
		move.w	d1,(a1)+
		move.w	d2,(a1)+

	if VIEW_GEMAINFO
		bsr	sndLockZ80
		lea	(z80_cpu+tblPSG),a0
		lea	(RAM_GemaCache_PSG),a1
		moveq	#3-1,d7
		bsr	.copy_me
		lea	(z80_cpu+tblPSGN),a0
		lea	(RAM_GemaCache_PSGN),a1
		moveq	#1-1,d7
		bsr	.copy_me
		lea	(z80_cpu+tblFM),a0
		lea	(RAM_GemaCache_FM),a1
		moveq	#6-1,d7
		bsr	.copy_me
		lea	(z80_cpu+tblPCM),a0
		lea	(RAM_GemaCache_PCM),a1
		moveq	#8-1,d7
		bsr	.copy_me
		lea	(z80_cpu+tblPWM),a0
		lea	(RAM_GemaCache_PWM),a1
		moveq	#8-1,d7
		bsr	.copy_me
		moveq	#0,d7
		move.b	(z80_cpu+fmSpecial),d7
		move.w	d7,(RAM_Copy_fmSpecial).w
		move.b	(z80_cpu+8),d7
		move.w	d7,(RAM_Copy_HasDac).w
		bsr	sndUnlockZ80
	endif

	if VIEW_GEMAINFO
		move.w	#DEF_PrintVram|DEF_PrintPal,d2
		move.l	#splitw(DEF_HSIZE_64,DEF_VRAM_FG),d3
		lea	(RAM_GemaCache_PSG),a3
		moveq	#7,d0
		moveq	#SET_SNDVIEWY,d1
		moveq	#3-1,d7
		bsr	.show_table
		lea	(RAM_GemaCache_PSGN),a3
		moveq	#7+12,d0
		moveq	#SET_SNDVIEWY,d1
		moveq	#1-1,d7
		bsr	.show_table
		lea	(RAM_GemaCache_FM),a3
		moveq	#7,d0
		moveq	#SET_SNDVIEWY+1,d1
		moveq	#5-1,d7
		bsr	.show_table_fm
		lea	(RAM_GemaCache_FM3),a3
		moveq	#7+16,d0
		moveq	#SET_SNDVIEWY+1,d1
		move.w	(RAM_Copy_fmSpecial).w,d7
		tst.b	d7
		beq.s	.no_spec
		lea	(strL_FmOnly),a0
		tst.w	(a3)
		bmi.s	.no_prnt3
		lea	(str_Speci),a0
.no_prnt3:
		bsr	Video_Print
		bra.s	.b_sampl
.no_spec:
		moveq	#1-1,d7
		bsr	.show_table_fm
.b_sampl:

		moveq	#7+20,d0
		moveq	#SET_SNDVIEWY+1,d1
		move.w	(RAM_Copy_HasDac).w,d7
		cmp.b	#$D9,d7
		bne.s	.no_sampl
		lea	(str_Sampl),a0
		bsr	Video_Print
		bra.s	.c_sampl
.no_sampl:
		lea	(RAM_GemaCache_FM6),a3
		moveq	#1-1,d7
		bsr	.show_table_fm
.c_sampl:
		lea	(RAM_GemaCache_PCM),a3
		moveq	#7,d0
		moveq	#SET_SNDVIEWY+2,d1
		moveq	#8-1,d7
		bsr	.show_table
		lea	(RAM_GemaCache_PWM),a3
		moveq	#7,d0
		moveq	#SET_SNDVIEWY+3,d1
		moveq	#8-1,d7
		bsr	.show_table
	endif

		rts

; ----------------------------------------------

.copy_me:
		moveq	#0,d1
; 		bsr	sndLockZ80
		move.b	ztbl_FreqIndx(a0),d1
		move.b	ztbl_Link+1(a0),d2
		move.b	ztbl_Link(a0),d0
; 		bsr	sndUnlockZ80
		or.b	d2,d0
		bne.s	.link_ok
		moveq	#-1,d1
.link_ok:
		move.w	d1,(a1)
		adda	#MAX_TBLSIZE,a0		; *** EXTERNAL LABEL
		adda	#4,a1
		dbf	d7,.copy_me
		rts

; ----------------------------------------------

.show_table_fm:
		lea	(strL_FmOnly),a0
		moveq	#0,d6
		moveq	#0,d5
		move.w	(a3),d6
		bpl.s	.is_fmgood
		bsr	Video_Print
		bra.s	.from_fmbad
.is_fmgood:
		move.w	d6,d5
		adda	#4,a0
		andi.w	#%00011111,d6
		lsl.w	#1,d6
		adda	d6,a0
		bsr	Video_Print
		move.w	d0,d4
		addq.w	#2,d0
		andi.w	#%11100000,d5
		lsr.w	#4,d5
		lea	(strL_LazyVal),a0
		adda	d5,a0
		bsr	Video_Print
		move.w	d4,d0
.from_fmbad:
; 		addq.w	#1,d1
		addq.w	#4,d0
		adda	#4,a3
		dbf	d7,.show_table_fm
		rts

.show_table:
		lea	(strL_NoteList),a0
		moveq	#0,d6
		move.w	(a3),d6
		bmi.s	.val_bad
		adda	#4,a0
		add.w	d6,d6
		adda	d6,a0
.val_bad:
		bsr	Video_Print
; 		addq.w	#1,d1
		addq.w	#4,d0
		adda	#4,a3
		dbf	d7,.show_table
		rts

; ====================================================================
; ------------------------------------------------------
; DATA asset locations
; ------------------------------------------------------

file_tscrn_main:
		dc.l DATA_BANK0
		dc.b "BNK_MAIN.BIN",0
		align 2
; file_tscrn_mars:
; 		dc.l DATA_BANK1
; 		dc.b "BNK_MARS.BIN",0
; 		align 2

; ====================================================================
; ------------------------------------------------------
; Objects
; ------------------------------------------------------

; ====================================================================
; ------------------------------------------------------
; Objects
; ------------------------------------------------------

; --------------------------------------------------
; Sisi
; --------------------------------------------------

obj_Fairy:
		moveq	#0,d0
		move.b	obj_index(a6),d0
		add.w	d0,d0
		move.w	.list(pc,d0.w),d1
		jmp	.list(pc,d1.w)
; ----------------------------------------------
.list:		dc.w .init-.list
		dc.w .main-.list
; ----------------------------------------------
.init:
		move.b	#1,obj_index(a6)
		clr.w	obj_frame(a6)
		bsr	object_ResetAnim

		move.b	obj_subid(a6),d7
		move.w	d7,d6
		lsl.w	#2,d6
		lea	.fixd_pos(pc),a0
		lea	obj_ram(a6),a1
		adda	d6,a0
		move.w	(a0)+,(a1)+
		move.w	(a0)+,(a1)+

		move.b	obj_subid(a6),d7
		mulu.w	#42,d7
		lsl.w	#4,d7
		neg.w	d7
		move.w	d7,4(a1)

; ----------------------------------------------
.main:
		lea	obj_ram(a6),a5
		lea	(RAM_GemaStatus).w,a4
	; a5
	; 0 - X base
	; 2 - Y base
	; 4 - Tan
		moveq	#0,d3
		move.b	obj_subid(a6),d3
		add.w	d3,d3
		adda	d3,a4
; 		lsl.w	#3,d3
		move.w	(a5),d2
		move.w	2(a5),d3
		move.w	#1,d4			; Multiply
		btst	#7,1(a4)
		beq.s	.not_enbls
		move.w	#4,d4
.not_enbls:
		move.w	4(a5),d0
		lsr.w	#4,d0
		bsr	System_SineWave
		muls.w	d4,d1
		asr.w	#8,d1
		sub.w	d1,d2
		move.w	4(a5),d0
		lsr.w	#4,d0
		btst	#0,1(a4)
		beq.s	.not_enbl2
		add.w	d0,d0
.not_enbl2:
		bsr	System_SineWave_Cos
		muls.w	d4,d1
		asr.w	#8,d1
		sub.w	d1,d3

		move.w	#$40,d4
		btst	#7,1(a4)
		beq.s	.not_enbl
		move.w	#$90,d4
.not_enbl:
		addi.w	d4,4(a5)
		move.w	d2,obj_x(a6)
		move.w	d3,obj_y(a6)

.not_mouse:
		lea	.anim_data(pc),a0
		bsr	object_Animate

		moveq	#0,d0
		move.b	obj_subid(a6),d0
		lsl.w	#3,d0
		lea	.sub_ids(pc,d0.w),a0
		move.w	4(a0),d2
		move.l	(a0),a1
		move.l	#0,a0
		move.w	obj_x(a6),d0
		move.w	obj_y(a6),d1
		move.w	obj_frame(a6),d3
		bra	Video_MakeSprMap

; ----------------------------------------------

.anim_data:
		dc.w .anim_00-.anim_data
.anim_00:
		dc.w 8
		dc.w 0,1,2,1
		dc.w -2
		align 2
.sub_ids:
		dc.l objMap_Dodo
		dc.w setVram_Dodo,0
		dc.l objMap_Mimi
		dc.w setVram_Mimi,0
		dc.l objMap_Fifi
		dc.w setVram_Fifi,0
		align 2

.fixd_pos:
		dc.w $B8,$50
		dc.w $B8+$24,$50
		dc.w $B8+$48,$50
		align 2

; ====================================================================
; ------------------------------------------------------
; Subroutines
; ------------------------------------------------------

; ====================================================================
; ------------------------------------------------------
; Includes for this screen
; ------------------------------------------------------

; ====================================================================
; ------------------------------------------------------
; Custom VBlank
; ------------------------------------------------------

; ------------------------------------------------------
; Custom HBlank
; ------------------------------------------------------

; ====================================================================
; ------------------------------------------------------
; Small data section
; ------------------------------------------------------

; EXTERNAL BEATS FOR EACH TRACK
exgema_beats:
	dc.w 214
	dc.w 214+18
	dc.w 214
	dc.w 214
	dc.w 214
	dc.w 214
	dc.w $00B8
	dc.w 192
	dc.w 192
	dc.w 214
	dc.w 214
	dc.w 214
	dc.w 214
	dc.w 214
	dc.w 214
	dc.w 214
	dc.w 214
	dc.w 214
	dc.w 214
	dc.w 214
	dc.w 214
	dc.w 214
	dc.w 214
	dc.w 214

ArtList_Stuff:
		dc.w 3
		dc.l Art_FairyDodo
		dc.w cell_vram(setVram_Dodo)
		dc.w cell_vram($30)
		dc.l Art_FairyMimi
		dc.w cell_vram(setVram_Mimi)
		dc.w cell_vram($30)
		dc.l Art_FairyFifi
		dc.w cell_vram(setVram_Fifi)
		dc.w cell_vram($30)

str_TesterTitle:
		dc.b "GEMA Sound Driver       V1.0",0
		align 2
str_TesterInfo:
		dc.b "Seq# Blk# Indx",$0A
		dc.b $0A,$0A,$0A,$0A
		dc.b "Beats: "
		dc.b 0
		align 2
str_Instruc:
		dc.b "LR - Seq. Num#   XY - Track index",$0A
		dc.b "UD - Seq. Blk#",$0A
		dc.b " A - STOP ALL",$0A
		dc.b " B - STOP Seq.",$0A
		dc.b " C - PLAY Seq.    Z - PLAY auto-fill"
		dc.b 0
		align 2

str_VmInfo:
		dc.b "PSG",$0A
		dc.b "FM",$0A
		dc.b "PCM",$0A
		dc.b "PWM"
		dc.b 0
		align 2

strL_NoteList:	dc.b "---",0
		dc.b "C-0",0,"C#0",0,"D-0",0,"D#0",0,"E-0",0,"F-0",0,"F#0",0,"G-0",0,"G#0",0,"A-0",0,"A#0",0,"B-0",0
		dc.b "C-1",0,"C#1",0,"D-1",0,"D#1",0,"E-1",0,"F-1",0,"F#1",0,"G-1",0,"G#1",0,"A-1",0,"A#1",0,"B-1",0
		dc.b "C-2",0,"C#2",0,"D-2",0,"D#2",0,"E-2",0,"F-2",0,"F#2",0,"G-2",0,"G#2",0,"A-2",0,"A#2",0,"B-2",0
		dc.b "C-3",0,"C#3",0,"D-3",0,"D#3",0,"E-3",0,"F-3",0,"F#3",0,"G-3",0,"G#3",0,"A-3",0,"A#3",0,"B-3",0
		dc.b "C-4",0,"C#4",0,"D-4",0,"D#4",0,"E-4",0,"F-4",0,"F#4",0,"G-4",0,"G#4",0,"A-4",0,"A#4",0,"B-4",0
		dc.b "C-5",0,"C#5",0,"D-5",0,"D#5",0,"E-5",0,"F-5",0,"F#5",0,"G-5",0,"G#5",0,"A-5",0,"A#5",0,"B-5",0
		dc.b "C-6",0,"C#6",0,"D-6",0,"D#6",0,"E-6",0,"F-6",0,"F#6",0,"G-6",0,"G#6",0,"A-6",0,"A#6",0,"B-6",0
		dc.b "C-7",0,"C#7",0,"D-7",0,"D#7",0,"E-7",0,"F-7",0,"F#7",0,"G-7",0,"G#7",0,"A-7",0,"A#7",0,"B-7",0
		dc.b "C-8",0,"C#8",0,"D-8",0,"D#8",0,"E-8",0,"F-8",0,"F#8",0,"G-8",0,"G#8",0,"A-8",0,"A#8",0,"B-8",0
		dc.b "C-9",0,"C#9",0,"D-9",0,"D#9",0,"E-9",0,"F-9",0,"F#9",0,"G-9",0,"G#9",0,"A-9",0,"A#9",0,"B-9",0
strL_FmOnly:	dc.b "---",0
		dc.b "C- ",0,"C# ",0,"D- ",0,"D# ",0,"E- ",0,"F- ",0,"F# ",0,"G- ",0,"G# ",0,"A- ",0,"A# ",0,"B- ",0
strL_LazyVal:	dc.b "0",0,"1",0,"2",0,"3",0,"4",0,"5",0,"6",0,"7",0,"8",0,"9",0

str_Speci:	dc.b "FM3",0
str_Sampl:	dc.b "DAC",0

str_ShowVars:
		dc.l pstr_mem(0,RAM_GemaSeq+1)
		dc.b "   "
		dc.l pstr_mem(0,RAM_GemaBlk+1)
		dc.b "   "
		dc.l pstr_mem(0,RAM_GemaIndx+1)
		dc.b 0
		align 2
str_ShowBeats:
		dc.l pstr_mem(1,RAM_CurrBeats)
		dc.b 0
		align 2

str_Info:
		dc.l pstr_mem(3,RAM_Framecount)
		dc.b 0
		align 2
