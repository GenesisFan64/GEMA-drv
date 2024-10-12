; ===========================================================================
; ----------------------------------------------------------------
; Genesis/Pico 68000 RAM section (SCD: "MAIN-CPU")
;
; RESERVED RAM areas:
; $FFF700-$FFFC00 | Buffer data used by Boot ROM
;                   * FREE on Cartridge
; $FFFC00-$FFFD00 | Stack area a7
; $FFFD00-$FFFDFF | RESERVED for the Sega CD Vector jumps
;                   * FREE on Cartridge
; $FFFE00-$FFFFFF | USED by the BIOS as temporals
;                   * FREE on Cartridge
; ----------------------------------------------------------------

SET_RAMLIMIT		equ $FFFC00

; --------------------------------------------------------
; MAIN USER RAM
; --------------------------------------------------------

			memory $FFFF0000
RAM_SystemCode		ds.b MAX_SysCode	; CD/32X/CD32X only
RAM_UserCode		ds.b MAX_UserCode	; CD/32X/CD32X only
.end:
			endmemory
		if .end&$FFFF > $B000
			error "RAN OUT OF SPACE FOR _SystemCode/_UserCode \{.end&$FFFF}"
		endif

; ------------------------------------------------
; Nikona .w section of RAM
;
; MUST BE AFTER $FF8000
; ------------------------------------------------

			memory $FFFFB000
RAM_MdGlobal		ds.b MAX_Globals
RAM_ScrnBuff		ds.b MAX_ScrnBuff

; ----------------------------------------
; * FIRST PASS LABELS *
	if MOMPASS=1
	if MCD|MARS|MARSCD
RAM_MdMisc		ds.l 0
	endif
RAM_MdVideo		ds.l 0
RAM_MdSystem		ds.l 0
sizeof_MdRam		ds.l 0
	else
; ----------------------------------------
; * AUTOMATIC SIZES *
	if MCD|MARS|MARSCD
RAM_MdMisc		ds.b sizeof_mdmisc-RAM_MdMisc
	endif
RAM_MdVideo		ds.b sizeof_mdvid-RAM_MdVideo	; $FF8000
RAM_MdSystem		ds.b sizeof_mdsys-RAM_MdSystem	;
sizeof_MdRam		ds.l 0
	endif
; ------------------------------------------------
			endmemory
		if (sizeof_MdRam&$FF0000 == 0) | (sizeof_MdRam&$FFFFFF>(SET_RAMLIMIT))
			error "RAN OUT OF GENESIS RAM FOR THIS SYSTEM"
		endif

; --------------------------------------------------------
; SCD and 32X special section
; --------------------------------------------------------

	if MCD|MARS|MARSCD
			memory RAM_MdMisc
; ----------------------------------------
; * FIRST PASS LABELS *
	if MOMPASS=1
RAM_MdMcd_Stamps	ds.l 0
RAM_MdMcd_StampSett	ds.l 0
RAM_MdMars_CommBuff	ds.l 0
RAM_MdMars_PalFd	ds.l 0
RAM_MdMars_MPalFdList	ds.l 0
sizeof_mdmisc		ds.l 0
	else
; ----------------------------------------
; * AUTOMATIC SIZES *
	if MCD|MARSCD
RAM_MdMcd_Stamps	ds.b $20*MAX_MCDSTAMPS		; SCD Stamps
RAM_MdMcd_StampSett	ds.b mdstmp_len			; SCD Stamp dot-screen control
	endif
	if MARS|MARSCD
RAM_MdMars_IndxPalFd	ds.w 1				; ''
RAM_MdMars_PalFd	ds.w 256			; Target 32X palette for FadeIn/Out
RAM_MdMars_MPalFdList	ds.b palfd_len*MAX_PALFDREQ	; '' same but for 32X
RAM_MdMars_CommBuff	ds.b Dreq_len			; 32X DREQ-RAM size
	endif
sizeof_mdmisc		ds.l 0
; ----------------------------------------
	endif
			endmemory
	endif

; --------------------------------------------------------
; Fixed areas
; --------------------------------------------------------

RAM_Stack		equ RAM_MegaCd		; <-- Goes backwards
RAM_MegaCd		equ $FFFFFD00		; SCD's vector jumps
RAM_SoundBuff		equ $FFFFFF00
