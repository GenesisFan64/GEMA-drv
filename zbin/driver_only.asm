; ===========================================================================

		padding		off		; Don't pad dc.b
		listing 	purecode
		supmode 	on 		; Supervisor mode (68000)
		page 		0

		include	"../tester/macros.asm"			; Assembler macros
		include	"../tester/system/mcd/map.asm"	; Sega CD hardware map (shared with Sub-CPU)
		include	"../tester/system/mars/map.asm"	; 32X hardware map (shared with SH2)
		include	"../tester/system/md/map.asm"	; Genesis hardware map and other areas

; ====================================================================
; ----------------------------------------------------------------
; EXTERNAL
; ----------------------------------------------------------------

; 68K RAM location to write a flag for the readRom RAM-area
; patch

RAM_ZCdFlag_D	equ $FFFFFF00

; ====================================================================
; ----------------------------------------------------------------
; AS Assembler starting settings
; ----------------------------------------------------------------

		cpu Z80
		org 0
		include "../sound/driver/gema_zdrv.asm"

