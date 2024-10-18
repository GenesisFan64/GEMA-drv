; ===========================================================================
; NikonaMD
; by GenesisFan64 2023-2024
;
; A devkit for developing software on the SEGA 16-bit family
; of systems: Genesis, Sega CD, Sega 32X, Sega CD32X and Sega Pico.
; ===========================================================================

; ====================================================================
; ----------------------------------------------------------------
; NIKONA SETTINGS
; ----------------------------------------------------------------

SET_INITMODE	equ 0		; Starting screen mode number on boot

; ====================================================================
; ----------------------------------------------------------------
; 68000 RAM SIZES (MAIN-CPU in SegaCD/CD32X)
; ----------------------------------------------------------------

MAX_StackSize	equ $0200	; Maximum Stack a7
MAX_Globals	equ $0800	; USER Global variables
MAX_ScrnBuff	equ $1000	; Current Screen's variables

; ----------------------------------------------------
; SCD, 32X and CD32X ONLY
;
; These sections are unused(free) on Genesis/Pico
MAX_SysCode	equ $2C00	; SCD/32X/CD32X: Nikona lib
MAX_UserCode	equ $8400	; SCD/32X/CD32X: Current SCREEN's CODE+small DATA

; ====================================================================
; ----------------------------------------------------------------
; AS Assembler starting settings
; ----------------------------------------------------------------

		cpu 		68000		; Starting CPU is 68000
		padding		off		; Don't pad dc.b
		listing 	purecode
		supmode 	on 		; Supervisor mode (68000)
		page 		0

; ====================================================================
; ----------------------------------------------------------------
; Includes
; ----------------------------------------------------------------

		include	"rominfo.asm"		; ROM info
		include	"macros.asm"		; Assembler macros
		include	"system/shared.asm"	; Shared variables and specials
		include	"system/mcd/map.asm"	; Sega CD hardware map (shared with Sub-CPU)
		include	"system/mars/map.asm"	; 32X hardware map (shared with SH2)
		include	"system/md/map.asm"	; Genesis hardware map and other areas
		include	"system/ram.asm"	; Genesis RAM sections

; ====================================================================
; ----------------------------------------------------------------
; GLOBAL variables
; ----------------------------------------------------------------

		memory RAM_MdGlobal
	; ------------------------------------------------
		include "game/globals.asm"
	; ------------------------------------------------
sizeof_MdGlbl	ds.l 0
	if (sizeof_MdGlbl&1 == 1)
		error "GLOBALS ARE MISALIGNED"
	endif
; 		erreport "USER Globals",(sizeof_MdGlbl-RAM_MdGlobal),MAX_Globals	; Report error if ran out
		endmemory

; ====================================================================
; ----------------------------------------------------------------
; SAVE data structure
; ----------------------------------------------------------------

		memory RAM_SaveData
	; ------------------------------------------------
		include "game/savemem.asm"
	; ------------------------------------------------
sizeof_SaveInfo	ds.l 0
	if (sizeof_MdGlbl&1 == 1)
		error "SAVE STRUCT IS MISALIGNED"
	endif
; 		erreport "USER Globals",(sizeof_SaveInfo-RAM_SaveData),SET_SRAMSIZE	; Report error if ran out
		endmemory

; ====================================================================
; ----------------------------------------------------------------
; Init procedures for all systems
; ----------------------------------------------------------------

		!org 0						; Start at 0
; ---------------------------------------------
; SEGA 32X
; ---------------------------------------------

	if MARS
		include	"system/head_mars.asm"			; 32X header
		lea	($880000|Md_SysCode),a0			; Copy SYSTEM routines
		lea	(RAM_SystemCode),a1
		move.w	#((Md_SysCode_e-Md_SysCode))-1,d0
.copy_code:
		move.b	(a0)+,(a1)+
		dbf	d0,.copy_code
		jsr	(Sound_init).l				; Init Sound driver (FIRST)
		jsr	(Video_init).l				;  ''  Video
		jsr	(System_Init).l				;  ''  System
		move.w	#SET_INITMODE,(RAM_ScreenMode).w	; Reset screen mode
		jmp	(Md_ReadModes).l			; Go to SCREEN LOAD section

; ---------------------------------------------
; SEGA CD and CD32X
; ---------------------------------------------

	elseif MCD|MARSCD
		include	"system/head_mcd.asm"			; Sega CD header
		lea	Md_SysCode(pc),a0			; Copy SYSTEM routines
		lea	(RAM_SystemCode),a1
		move.w	#((Md_SysCode_e-Md_SysCode))-1,d0
.copy_code:
		move.b	(a0)+,(a1)+
		dbf	d0,.copy_code
	if MARSCD						; CD32X boot code
		lea	filen_marscode(pc),a0			; Load SH2 code from disc to WORD-RAM
		jsr	(System_MdMcd_RdFile_WRAM).l
		include "system/mcd/marscd.asm"
	endif
		lea	filen_z80file(pc),a0			; Load Z80 data to Word-RAM
		jsr	(System_MdMcd_RdFile_WRAM).l		; Sound_Init will read from there.
		lea	(RAM_MdVideo).w,a0			; Clean our "work" RAM starting from here
		move.l	#sizeof_mdram,d1
		moveq	#0,d0
.loop_ram:	move.w	d0,(a0)+
		cmp.l	d1,a0
		bcs.s	.loop_ram
		jsr	(System_MdMcd_SubWait).l		; Wait Sub-CPU first.
		jsr	(Sound_Init).l				; Init Sound driver (FIRST)
		jsr	(Video_Init).l				; Init Video
		jsr	(System_Init).l				; Init System
		move.w	#SET_INITMODE,(RAM_ScreenMode).w	; Reset screen mode
		jmp	(Md_ReadModes).l			; Go to SCREEN LOAD section
filen_z80file:	dc.b "GEMA_Z80.BIN",0
		align 2
filen_marscode:	dc.b "NKNAMARS.BIN",0
		align 2

; ---------------------------------------------
; SEGA PICO
;
; This recycles the MD's routines.
; ---------------------------------------------
	elseif PICO
		include	"system/head_pico.asm"			; Pico header
		bsr	Sound_init				; Init Sound driver FIRST
		bsr	Video_init				;  ''  Video
		bsr	System_Init				;  ''  Values
		move.w	#SET_INITMODE,(RAM_ScreenMode).w	; Reset screen mode
		bra.w	Md_ReadModes				; Go to SCREEN LOOP section

; ---------------------------------------------
; MD
; ---------------------------------------------
	else
		include	"system/head_md.asm"			; Genesis header
		bsr	Sound_init				; Init Sound driver FIRST
		bsr	Video_init				;  ''  Video
		bsr	System_Init				;  ''  Values
		move.w	#SET_INITMODE,(RAM_ScreenMode).w	; Reset screen mode
		bra.w	Md_ReadModes				; Go to SCREEN LOAD section

; ---------------------------------------------
	endif

; ====================================================================
; --------------------------------------------------------
; SYSTEM routines
;
; MD/PICO:  Normal ROM locations
; 32X:      Loaded into RAM to prevent bus-conflicts
;           with the SH2's view of ROM
; CD/CD32X: Loaded into RAM for safe access.
; --------------------------------------------------------

	if MCD|MARS|MARSCD
Md_SysCode:
		phase RAM_SystemCode
	endif
; ---------------------------------------------

		include	"sound/drv/gema_macros.asm"
		include	"sound/drv/gema.asm"
		include	"system/md/video.asm"
		include	"system/md/system.asm"

; --------------------------------------------------------
; SCREEN MODE MAIN LOOP
;
;  MD/Pico: Direct ROM jump
; CD/CD32X: Reads file from DISC and
;           transfers code to RAM
;      32X: Code is stored on ROM but runs in
;           RAM to prevent bus-conflicts with the
;           SH2's view of ROM at CS1
;
; - Returning in your current screen code loops here
; - 32X/CD32X:
;   This will turn OFF the 32X's current video mode
; --------------------------------------------------------

Md_ReadModes:
		ori.w	#$0700,sr			; Disable interrupts
	if MCD|MARSCD					; CD/CD32X:
		bsr	Video_MdMcd_StampDisable	; Disable Stamps
		bsr	System_MdMcd_CddaStop		; Stop CDDA
	endif
	if MARS|MARSCD
		bsr	Video_MdMars_VideoOff		; Turn OFF all 32X visuals
	endif
		moveq	#0,d0
		move.w	(RAM_ScreenMode).w,d0		; Read current screen number
		and.w	#$7F,d0				; <-- CURRENT LIMIT
		lsl.w	#4,d0				; number*$10
		lea	.pick_mode(pc,d0.w),a0		; Read list
	; SCD/CD32X
	if MCD|MARSCD					; CD/CD32X:
		adda	#4,a0				; a0 - Filename string
		bsr	System_MdMcd_SubWait
		lea	(RAM_UserCode).l,a1		; a1 - Output location
		move.w	#MAX_UserCode,d0		; Maximum code size
		bsr	System_MdMcd_RdFile_RAM		; Load CODE from disc
		bsr	System_MdMcd_SubWait		; Wait Sub-CPU
		jsr	(RAM_UserCode).l
	; 32X Cartridge
	elseif MARS
		movea.l	.pick_mode(pc,d0.w),a0		; a0 - ROM Location(+$880000)
		lea	(RAM_UserCode).l,a1		; a1 - Output location
		move.w	#(MAX_UserCode)-1,d7		; Copy manually
.copyme2:
		move.b	(a0)+,(a1)+
		dbf	d7,.copyme2
		jsr	(RAM_UserCode).l
	; Genesis and Pico
	else
		movea.l	.pick_mode(pc,d0.w),a0		; a0 - ROM location
		jsr	(a0)
	endif
		bra.s	Md_ReadModes			; Loop on rts

; ====================================================================
; ---------------------------------------------
; ADD YOUR SCREEN MODE JUMPS GO HERE
; ---------------------------------------------

.pick_mode:
		include "game/screens.asm"

; ====================================================================

	if MCD|MARS|MARSCD
.end:
		erreport "NIKONA RAM-CODE",(.end-RAM_SystemCode),MAX_SysCode
		dephase
		phase (.end-RAM_SystemCode)+Md_SysCode
	endif

Md_SysCode_e:
		align 2

; ===========================================================================
; ----------------------------------------------------------------
; DATA section shared on both Cartridge or Disc
; ----------------------------------------------------------------

; --------------------------------------------------------
; CD/CD32X ISO header and files
; --------------------------------------------------------

	if MCD|MARSCD
		align $8000
		binclude "system/mcd/fshead.bin"		; Pre-generated ISO header
		fs_mkList 0,IsoFileList,IsoFileList_e		; TWO pointers to the filelist
		fs_mkList 1,IsoFileList,IsoFileList_e
IsoFileList:
		fs_file "NKNA_SUB.BIN",MCD_SMPDATA,MCD_SMPDATA_e
		fs_file "NKNAMARS.BIN",MARS_RAMCODE,MARS_RAMCODE_EOF
		fs_file "GEMA_Z80.BIN",Z80_CODE_FILE,Z80_CODE_FILE_E
	; ******
		include "game/iso_files.asm"
	; ******
		fs_end
IsoFileList_e:
	endif

; ===========================================================================
; --------------------------------------------------------
; Z80 driver include
;
; SCD/CD32X: Stored on DISC
; --------------------------------------------------------

	if MCD|MARSCD
		align $800
Z80_CODE_FILE:
		phase sysmcd_wram
	elseif MARS
		phase $880000+*
	endif
Z80_CODE:
	if MARS
		dephase
	endif
		include "sound/drv/gema_zdrv.asm"
	if MARS
		phase $880000+*
	endif
Z80_CODE_END:
	if MARS
		dephase
	elseif MCD|MARSCD
		dephase
		fs_end
	endif
Z80_CODE_FILE_E:

; ====================================================================
; --------------------------------------------------------
; SEGA CD SUB-CPU data
; --------------------------------------------------------

	if MCD|MARSCD
		align $800
MCD_SMPDATA:
		phase $20000				; <-- MANUAL location on Sub-CPU area
	; ------------------------------------------------
		include "sound/smpl_pcm.asm"		; PCM samples
	; ------------------------------------------------
.here:		erreport "SUB-CPU DATA",.here,$80000
		dephase
		phase MCD_SMPDATA+(.here-$20000)
		fs_end
MCD_SMPDATA_E:
		fs_end
	endif

; ====================================================================
; ----------------------------------------------------------------
; SH2 code sent to SDRAM area
; ----------------------------------------------------------------

	if MCD|MARSCD
		align $800
	elseif MARS
		align 4
	endif
MARS_RAMCODE:
	if MARS|MARSCD
	; ------------------------------------------------
		include "system/mars/code.asm"
	; ------------------------------------------------
	else
		align 4
	endif
MARS_RAMCODE_E:
	if MCD|MARSCD
		fs_end
MARS_RAMCODE_EOF:
	endif

; ====================================================================
; --------------------------------------------------------
; CODE BLOCK (banks)
; --------------------------------------------------------

		include "game/incl_code.asm"

; ====================================================================
; ----------------------------------------------------------------
; DATA BLOCK (banks)
; ----------------------------------------------------------------

		include "game/incl_data.asm"

; ====================================================================
; ----------------------------------------------------------------
; Cartridge-ONLY Section, direct label access
;
; Genesis, 32X Cartridge and Pico ONLY.
; ----------------------------------------------------------------

	if MCD|MARSCD=0

; --------------------------------------------------------
; ROM only DMA graphics data
; --------------------------------------------------------

		include "game/data/ROM_dma_vdp.asm"

; --------------------------------------------------------
; ROM-only 32X data
;
; In the case of RV bit (during DMA):
; Only the PWM samples are protected, everything else
; will be trashed.
; --------------------------------------------------------

		phase CS1+*
; ------------------------------------------------
		align 4
		include "game/data/mars/objects/list_ROM.asm"	; 3D objects
		include "sound/ROM_smpl_pwm.asm"		; PWM samples
; ------------------------------------------------
		dephase

; ----------------------------------------------------------------

	endif

; ====================================================================
; ------------------------------------------------
; End
; ------------------------------------------------

ROM_END:
		dc.b 0
		align $8000
