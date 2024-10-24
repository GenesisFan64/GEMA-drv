; ===========================================================================

		padding		off		; Don't pad dc.b
		listing 	purecode
		supmode 	on 		; Supervisor mode (68000)
		page 		0

		include	"macros.asm"			; Assembler macros
		include	"system/mcd/map.asm"	; Sega CD hardware map (shared with Sub-CPU)
		include	"system/mars/map.asm"	; 32X hardware map (shared with SH2)
		include	"system/md/map.asm"	; Genesis hardware map and other areas

; ====================================================================
; ----------------------------------------------------------------
; EXTERNAL
; ----------------------------------------------------------------

; 68K RAM location at the area $FF8000-$FFFFFF
; to write a flag for the readRom RAM-area patch

RAM_ZCdFlagD	equ $FFFFFF00

; ====================================================================
; ----------------------------------------------------------------
; AS Assembler starting settings
; ----------------------------------------------------------------

		cpu Z80
		org 0
		include "../sound/drv/gema_zdrv.asm"

