; ===========================================================================
; -------------------------------------------------------------------
; 32X Sound, Slave CPU side
; -------------------------------------------------------------------

; --------------------------------------------------------
; Settings
; --------------------------------------------------------

MAX_PWMCHNL	equ 8		; Maximum channels to use
SAMPLE_RATE	equ 16000

; --------------------------------------------------------
; Structs
; --------------------------------------------------------

; 32X sound channel
marspwm		struct
enbl		ds.l 1		; %EB00 SLlr | StereoEnable,Loop,left,right
read		ds.l 1		; READ point
bank		ds.l 1		; CS1 or CS3
start		ds.l 1		; Start point $00xxxxxx << 8
length		ds.l 1		; Lenght << 8
loop		ds.l 1		; Loop point << 8
pitch		ds.l 1		; Pitch $xx.xx
vol		ds.l 1		; Volume ($0000-Max)
cbank		ds.l 1
cread		ds.l 1
; len		ds.l 0
		endstruct

; ====================================================================
; --------------------------------------------------------
; Init Sound PWM
;
; Cycle register formulas:
; NTSC ((((23011361<<1)/SAMPLE_RATE+1)>>1)+1)
; PAL  ((((22801467<<1)/SAMPLE_RATE+1)>>1)+1)
;
; NOTE: The CLICK sound after calling this is normal.
; --------------------------------------------------------

		align 4
MarsSound_Init:
		stc	gbr,@-r15
		mov	#_sysreg,r0
		ldc	r0,gbr
		mov	#$0105,r0					; Timing interval $01, Output L/R
		mov.w	r0,@(timerctl,gbr)
		mov	#((((23011361<<1)/SAMPLE_RATE+1)>>1)+1),r0	; Sample rate
		mov.w	r0,@(cycle,gbr)
		mov	#1,r0
		mov.w	r0,@(monowidth,gbr)
		mov.w	r0,@(monowidth,gbr)
		mov.w	r0,@(monowidth,gbr)
		mov	#RAM_Mars_PwmList,r4
		mov	#marspwm_len,r3
		mov	#MAX_PWMCHNL,r2
		mov	#$200,r1
		mov	#RAM_Mars_PwmBackup,r0
.next_one:
		mov	r0,@(marspwm_cbank,r4)
		add	r3,r4
		dt	r2
		bf/s	.next_one
		add	r1,r0

		ldc	@r15+,gbr
		rts
		nop
		align 4

; ====================================================================

; PWM playback code is located at cache_slv.asm

; ====================================================================

		ltorg			; Save literals
