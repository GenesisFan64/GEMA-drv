; ------------------------------------------------------------
; MACROS
; ------------------------------------------------------------

; ----------------------------------------------------
; gSmplData - Include .WAV sample data, applies to
;             DAC, PCM* and PWM
;
;             * No need to convert data, Sub-CPU
;             converts the data manually.
;
; labl | 24-bit Pointer, depending of the
;        current CPU
; file | File path for the WAV sample file
; loop | Loop start point if sample loop is enabled
;        Set to 0 if not using loop.
; ----------------------------------------------------

gSmplData macro labl,file,loop
	if MARS|MARSCD		; <-- label align for 32X
		align 4
	endif
labl	label *
	dc.b ((labl_e-labl_s)&$FF),(((labl_e-labl_s)>>8)&$FF),(((labl_e-labl_s)>>16)&$FF)
	dc.b ((loop)&$FF),(((loop)>>8)&$FF),(((loop)>>16)&$FF)
labl_s:
	binclude file,$2C
labl_e:
	if MARS|MARSCD		; <-- label align for 32X
		align 4
	endif
	endm

; ----------------------------------------------------
; gemaList - Make a tracklist label
; ----------------------------------------------------

; gemaList macro thislbl
; 	align 2
; thislbl	label *
; GLBL_GEMABASE := *
; 	endm

; ----------------------------------------------------
; gemaTrk - Sequence entry on Gema_MasterList
;
; enblt | Disable/Enable global beats on this Sequence
;         0 - Don't Use beats, 1 - Use beats
; ticks | Ticks (Default tempo: 150-NTSC 120-PAL)
;   loc | Direct location of the sequence data
; ----------------------------------------------------

gemaTrk macro enbltp,ticks,loc
	dc.l ((enbltp&$01)<<31)|((ticks&$7F)<<24)|(loc&$FFFFFF)
	endm

; ----------------------------------------------------
; gemaHead - Track pointers to their respective data
;
; blk_data  | Block data pointer
; patt_data | Pattern data pointer
; ins_list  | instrument list pointer
; num_chnls | Number of channels used in the track
;             If 0: Read ALL channels
;                   (NOT recommended, UNSTABLE)
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
; NOTE: UNUSED instruments MUST use gInsNull or
; the Z80 gets unexpected results and probably crash.
; ------------------------------------------------------------

; ----------------------------------------------------
; gInsNull - Null instrument
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
; vib   | Set to 0, planned vibrato for later.
; ----------------------------------------------------

gInsPsg	macro pitch,alv,atk,slv,dky,rrt,vib
	dc.b $80,pitch,alv,atk
	dc.b slv,dky,rrt,vib
	endm

; ----------------------------------------------------
; gInsPsg - PSG noise
;
; pitch | Pitch/Octave
;         If using Tone3: set to 47 for a full noise
; alv   | Attack level
; atk   | Attack rate
; slv   | Sustain
; dky   | Decay rate (up)
; rrt   | Release rate (down)
; vib   | Set to 0, planned vibrato for later.
; mode  | Noise mode: %tmm
;        t - Bass(0)|Noise(1)
;        m - Clock(0)|Clock/2(1)|Clock/4(2)|Tone3(3)
;        Using Tone3 will disable PSG Channel 3.
;
; Note:
; Tone3 WILL silence PSG3 as it steals the
; frequency from it, chip limitation.
; ----------------------------------------------------

gInsPsgN macro pitch,alv,atk,slv,dky,rrt,vib,mode
	dc.b $90|mode,pitch,alv,atk
	dc.b slv,dky,rrt,vib
	endm

; ----------------------------------------------------
; gInsFm - FM Normal instrument/patch
;
; pitch | Pitch/Octave
; fmins | 24-bit pointer to FM patch data
; ----------------------------------------------------

gInsFm macro pitch,fmins
	dc.b $A0,pitch,((fmins>>16)&$FF),((fmins>>8)&$FF)
	dc.b fmins&$FF,$00,$00,$00
	endm

; ----------------------------------------------------
; gInsFm - FM3 Special instrument/patch
;
; pitch | UNUSED, set to 0
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
; start | 24-bit pointer to DAC sample
; flags | Flags: %0000000l
;         l - Use loop enable: No(0) or Yes(1)
; ----------------------------------------------------

gInsDac	macro pitch,start,flags
	dc.b $C0|flags,pitch,((start>>16)&$FF),((start>>8)&$FF)
	dc.b start&$FF,0,0,0
	endm

; ----------------------------------------------------
; gInsPcm - Sega CD PCM Sample
;
; pitch | Pitch/Octave
; start | 24-bit pointer to DAC sample
; flags | Flags: %0000000l
;         l - Use loop enable: No(0) or Yes(1)
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
; gInsPwm - Sega 32X PWM Sample
;
; pitch | Pitch/Octave
; start | 24-bit pointer to DAC sample
; flags | Flags: %000000sl
;         l - Use loop enable: No(0) or Yes(1)
;         s - Sample data is in Stereo
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
