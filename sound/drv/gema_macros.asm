; ===========================================================================
; ------------------------------------------------------------
; GEMA MACROS
;
; Variables used:
; MCD, MARS, MARSCD
; ------------------------------------------------------------

; ----------------------------------------------------
; gSmplData - Special include for .wav files,
;
; labl | Label used in this sample
; file | WAV file location
; loop | Loop start point
; ----------------------------------------------------

gSmplData macro labl,file,loop
	if MARS|MARSCD		; <-- label align for 32X
		align 4
	endif
labl	label *
	dc.b ((labl_e-labl_s)&$FF),(((labl_e-labl_s)>>8)&$FF),(((labl_e-labl_s)>>16)&$FF)	; dc.b 1,2,3 Length
	dc.b ((loop)&$FF),(((loop)>>8)&$FF),(((loop)>>16)&$FF)					; dc.b 4,5,6 Start loop
labl_s:
	binclude file,$2C	; dc.b (data)
labl_e:
	if MARS|MARSCD		; <-- label align for 32X
		align 4
	endif
	endm

; ----------------------------------------------------
; gSmplRaw - Special include for raw files
;
; labl | Label used in this sample
; file | RAW file location
; loop | Loop start point
; ----------------------------------------------------

gSmplRaw macro labl,file,loop
	if MARS|MARSCD		; <-- label align for 32X
		align 4
	endif
labl	label *
	dc.b ((labl_e-labl_s)&$FF),(((labl_e-labl_s)>>8)&$FF),(((labl_e-labl_s)>>16)&$FF)	; dc.b 1,2,3 Length
	dc.b ((loop)&$FF),(((loop)>>8)&$FF),(((loop)>>16)&$FF)					; dc.b 4,5,6 Start loop
labl_s:
	binclude file		; dc.b (data)
labl_e:
	if MARS|MARSCD		; <-- label align for 32X
		align 4
	endif
	endm

; ----------------------------------------------------
; gemaTrk - Sequence entry in the current master
;           list
;
; enblt | Disable/Enable global beats on this Sequence:
;         0 - Don't use beats
;         1 - Use beats
; ticks | Ticks (Default tempo: 150-NTSC 120-PAL)
;   loc | Direct 24-bit location of the sequence data
; ----------------------------------------------------

gemaTrk macro enblt,ticks,loc
	dc.l ((enblt&$01)<<31)|((ticks&$7F)<<24)|(loc&$FFFFFF)
	endm

; ----------------------------------------------------
; gemaHead - Sequence data header
;
; blk_data  | Block data pointer
; patt_data | Pattern data pointer
; ins_list  | instrument list pointer
; num_chnls | Number of channels used in the track
;             If 0: Read ALL channels
;                   (NOT recommended, UNSTABLE)
;
; Note:
; Pointers are in 68k map area
; ----------------------------------------------------

gemaHead macro blk,pat,ins,num
	dc.w num
	dc.l blk
	dc.l pat
	dc.l ins
	endm

; ------------------------------------------------------------
; Instrument macros, instrument_num-1
; (ex. Instrument 1 is 0 here)
;
; Note:
; UNUSED instruments MUST use gInsNull or
; the Z80 gets unexpected results and probably crash.
; ------------------------------------------------------------

; ----------------------------------------------------
; gInsNull - Null instrument
;
; You MUST use this on unused instruments.
; ----------------------------------------------------

gInsNull macro
	dc.b $00,$00,$00,$00
	dc.b $00,$00,$00,$00
	endm

; ----------------------------------------------------
; gInsPsg - PSG tone
;
; pitch | Pitch/Octave
; alv   | Attack level
; atk   | Attack rate
; slv   | Sustain
; dky   | Decay rate (up)
; rrt   | Release rate (down)
; vib   | Set to 0, reserved for vibrato
; ----------------------------------------------------

gInsPsg	macro pitch,alv,atk,slv,dky,rrt,vib
	dc.b $80,pitch,alv,atk
	dc.b slv,dky,rrt,vib
	endm

; ----------------------------------------------------
; gInsPsg - PSG noise
;
; pitch | Pitch/Octave
; alv   | Attack level
; atk   | Attack rate
; slv   | Sustain
; dky   | Decay rate (up)
; rrt   | Release rate (down)
; vib   | Set to 0, reserved for vibrato
; mode  | Noise mode: %tmm
;         t - Bass(0)|Noise(1)
;         m - Clock(00)|Clock/2(01)|Clock/4(10)|Tone3(11)
;
; Note:
; Using Tone3 will turn OFF channel 3.
; ----------------------------------------------------

gInsPsgN macro pitch,alv,atk,slv,dky,rrt,vib,mode
	dc.b $90|mode,pitch,alv,atk
	dc.b slv,dky,rrt,vib
	endm

; ----------------------------------------------------
; gInsFm - YM2612 FM normal instrument/patch
;
; pitch | Pitch/Octave
; fmins | 24-bit pointer to FM patch data
; ----------------------------------------------------

gInsFm macro pitch,fmins
	dc.b $A0,pitch,((fmins>>16)&$FF),((fmins>>8)&$FF)
	dc.b fmins&$FF,$00,$00,$00
	endm

; ----------------------------------------------------
; gInsFm - YM2612 FM special instrument/patch
;
; pitch | UNUSED, value ignored (set to 0)
; fmins | 24-bit pointer to FM patch data
; ----------------------------------------------------

gInsFm3	macro pitch,fmins
	dc.b $B0,pitch,((fmins>>16)&$FF),((fmins>>8)&$FF)
	dc.b fmins&$FF,$00,$00,$00
	endm

; ----------------------------------------------------
; gInsDac - DAC instrument
;
; pitch | Pitch/Octave
; start | 24-bit pointer
; flags | Flags: %0000000l
;         | l - Enable loop: No(0)/Yes(1)
; ----------------------------------------------------

gInsDac	macro pitch,start,flags
	dc.b $C0|flags,pitch,((start>>16)&$FF),((start>>8)&$FF)
	dc.b start&$FF,0,0,0
	endm

; ----------------------------------------------------
; gInsPcm - RF5C164 PCM Sample (SEGA CD)
;
; pitch | Pitch/Octave
; start | 24-bit direct pointer to
;         Sub-CPU's memory area.
; flags | Flags: %0000000l
;         | l - Enable loop: No(0)/Yes(1)
; ----------------------------------------------------

gInsPcm	macro pitch,start,flags
 if MCD|MARSCD
	dc.b $D0|flags,pitch,((start>>16)&$FF),((start>>8)&$FF)
	dc.b start&$FF,0,0,0
 else
	dc.b $00,$00,$00,$00
	dc.b $00,$00,$00,$00
 endif
	endm

; ----------------------------------------------------
; gInsPwm - PWM Sample (SEGA 32X)
;
; pitch | Pitch/Octave
; start | 32-bit pointer to
;         SH2's map view: CS1(ROM) or CS3(SDRAM)
; flags | Flags: %000000sl
;         | l - Enable loop: No(0)/Yes(1)
;         | s - Sample data is in Stereo: No(0)/Yes(1)
; ----------------------------------------------------

gInsPwm	macro pitch,start,flags
 if MARS|MARSCD
	dc.b $E0|flags,pitch,((start>>24)&$FF),((start>>16)&$FF)
	dc.b ((start>>8)&$FF),start&$FF,0,0
 else
	dc.b $00,$00,$00,$00
	dc.b $00,$00,$00,$00
 endif
	endm
