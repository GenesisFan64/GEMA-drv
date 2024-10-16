; ===========================================================================
; -------------------------------------------------------------------
; MACROS Section
;
; *** THIS MUST BE INCLUDED AT START OF THE CODE ***
; -------------------------------------------------------------------

; ====================================================================
; ------------------------------------------------------------
; AS Functions
; ------------------------------------------------------------

splitw		function l,r,(((l))<<16&$FFFF0000|((r))&$FFFF)		; Two WORDS stored in a single LONG: $12341234

; Common functions
cell_vram	function a,(a<<5)					; Cell position to real VRAM position
color_indx	function a,a<<1						; Applies to both VDP and SuperVDP
pstr_mem	function a,b,((a|$80)<<24)|b&$FFFFFF			; PRINT memory: pstr_mem(type,mem_pos)
full_loc	function a,-(-a)&$FFFFFFFF

SET_WRAMSIZE	equ $3C000

; ====================================================================
; ------------------------------------------------------------
; Macros
; ------------------------------------------------------------

; --------------------------------------------
; Memory reference labels
;
; Example:
; 		memory RAM_Somewhere
; RAM_ThisLong	ds.l 1
; RAM_ThisWord	ds.w 1
; RAM_ThisByte	ds.b 1		; <-- careful with alignment
; 		endmemory ; finish
; --------------------------------------------

memory		macro thisinput			; Reserve memory address
GLBL_LASTPC	:= *
		dephase
		phase thisinput
GLBL_LASTORG	:= *
		endm

; --------------------------------------------

endmemory	macro				; Then finish.
.here:		dephase
		ds.b -(.here-GLBL_LASTORG)
		phase GLBL_LASTPC
		endm

; --------------------------------------------
; Report memory usage
; --------------------------------------------

report		macro text,this,that
	if MOMPASS == 2
		if that == -1
			message text+": \{(this)&$FFFFFF}"
		else
			if this > that
				warning "RAN OUT OF "+text+" SPACE (\{(this)&$FFFFFF} of \{(that)&$FFFFFF})"
			else
				message text+" uses \{(this)&$FFFFFF} of \{(that)&$FFFFFF}"
			endif
		endif
	endif
		endm

; --------------------------------------------
; Same as report but only show on error
; --------------------------------------------

erreport	macro text,this,that
	if MOMPASS == 2
		if this > that
			error "RAN OUT OF "+text+" (\{(this)&$FFFFFF} of \{(that)&$FFFFFF})"
		endif
	endif
		endm

; --------------------------------------------
; ZERO Fill padding
; --------------------------------------------

rompad		macro target
.this_sz := target - *
		if .this_sz < 0
			error "Too much data at $\{target} ($\{(-.this_sz)} bytes)"
		else
			dc.b [.this_sz]0
		endif
	endm

; ====================================================================
; ------------------------------------------------------------
; Filesystem macros
;
; NOTE: A pre-generated ISO head is required
;       at $8000 until $B7FF
; ------------------------------------------------------------

; ------------------------------------------------------------
; FS setup
; ------------------------------------------------------------

fs_mkList	macro type,start,end
.fstrt:
		dc.b .fend-.fstrt				; Block size
		dc.b 0						; Zero
		dc.b (start>>11&$FF),(start>>19&$FF)		; Start sector, little endian
		dc.b (start>>27&$FF),(start>>35&$FF)
		dc.l start>>11					; Start sector, big endian
		dc.b ((end-start)&$FF),((end-start)>>8&$FF)	; Filesize, little endian
		dc.b ((end-start)>>16&$FF),((end-start)>>24&$FF)
		dc.l end-start					; Filesize, big endian
		dc.b (2024-1900)+1				; Year
		dc.b 0,0,0,0,0,0				; **never done**
		dc.b 2						; File flags
		dc.b 0,0
		dc.b 1,0					; Volume sequence number, little
		dc.b 0,1					; Volume sequence number, big
		dc.b 1,type
.fend:
		endm

; ------------------------------------------------------------
; FS File
; ------------------------------------------------------------

fs_file		macro filename,start,end
.fstrt:		dc.b .fend-.fstrt				; Block size
		dc.b 0						; zero
		dc.b (start>>11&$FF),(start>>19&$FF)		; Start sector, little
		dc.b (start>>27&$FF),(start>>35&$FF)
		dc.l start>>11					; Start sector, big
		dc.b ((end-start)&$FF),((end-start)>>8&$FF)	; Filesize, little
		dc.b ((end-start)>>16&$FF),((end-start)>>24&$FF)
		dc.l end-start					; Filesize, big
		dc.b (2024-1900)+1				; Year
		dc.b 0,0,0,0,0,0				; (filler)
		dc.b 0						; File flags
		dc.b 0,0
		dc.b 1,0					; Volume sequence number, little
		dc.b 0,1					; Volume sequence number, big
		dc.b .flend-.flen
.flen:		dc.b filename,";1"
.flend:		dc.b 0
.fend:
		endm

; ------------------------------------------------------------
; Make filler sector at the end-of-file
; ------------------------------------------------------------

fs_end		macro
		dc.b 0
		align $800			; Filler sector
		endm

; ====================================================================
; ------------------------------------------------------------
; Nikona storage macros
; ------------------------------------------------------------

; --------------------------------------------
; Screen mode code
;
; screen_code START_LABEL,END_LABEL,CODE_PATH
; --------------------------------------------

screen_code macro lblstart,lblend,path
	if MCD|MARSCD
		align $800		; SCD/CD32X sector align
	elseif MARS
		phase $880000+*		; 32X ROM-area
		align 4
	endif
lblstart label *
	if MARS
		dephase
	endif

mctopscrn:
	if MARS|MCD|MARSCD
		phase RAM_UserCode	; SCD/32X/CD32X code area
	endif
mcscrn_s:
	include path;"game/screenX/code.asm"
mcscrn_e:
	if MARS
		dephase	; dephase RAM section
		dephase ; dephase $880000+ section
	elseif MCD|MARSCD
		dephase
		phase mctopscrn+(mcscrn_e-RAM_UserCode)
		align $800
	endif
; Md_Screen00_e:
lblend label *
	erreport "SCREEN CODE: lblstart",mcscrn_e-mcscrn_s,MAX_UserCode
	endm

; --------------------------------------------
; Data bank
; --------------------------------------------

data_dset macro startlbl
	if MCD|MARSCD
		align $800
	endif
; MCD_DBANK0:
startlbl label *
	if MCD|MARSCD
		phase sysmcd_wram
	elseif MARS
		phase $900000+(startlbl&$0FFFFF)
		align 4
	endif
GLBL_MDATA_ST := *
	endm

; --------------------------------------------

data_dend macro endlbl
GLBL_MDATA_RP := *-GLBL_MDATA_ST	; save size for _dend

	if MCD|MARSCD
	if MOMPASS>2
		if GLBL_MDATA_RP > SET_WRAMSIZE
			warning "SCD/CD32X: THIS BANK SIZE IS TOO LARGE for WORD-RAM"
		endif
	endif
	endif

	if MARS
		if * >= $900000+$100000
			warning "32X: THIS DATA BANK IS TOO LARGE for $900000"
		endif

		dephase
	elseif MCD|MARSCD
		dephase

mlastpos := *	; <-- CD/CD32X ONLY
mpadlbl	:= (mlastpos&$FFF800)+$800
		rompad mpadlbl
endlbl label *	; <-- CD/CD32X ONLY
		erreport "68K DATA BANK",GLBL_MDATA_RP,SET_WRAMSIZE	; <- Lowest size compatible for ALL
	endif
	endm

; --------------------------------------------

binclude_dma	macro lblstart,file
	if MARS
GLBL_LASTPHDMA	set *
	dephase
GLBL_PHASEDMA	set *
		endif

		align 2
lblstart	label *
		binclude file
		align 2

	if MARS
GLBL_ENDPHDMA	set *-GLBL_PHASEDMA
		phase GLBL_LASTPHDMA+GLBL_ENDPHDMA
	endif
		endm

binclude_dma_e	macro lblstart,lblend,file
	if MARS
GLBL_LASTPHDMA	set *
	dephase
GLBL_PHASEDMA	set *
		endif

		align 2
lblstart	label *
		binclude file
lblend		label *
		align 2

	if MARS
GLBL_ENDPHDMA	set *-GLBL_PHASEDMA
		phase GLBL_LASTPHDMA+GLBL_ENDPHDMA
	endif
		endm

; --------------------------------------------
; 32X graphics pack Enter/Exit
; --------------------------------------------

mars_VramStart	macro thelabel
thelabel label *
		phase 0
		endm

mars_VramEnd	macro thelabel
		align 8
.end:
; 		if MOMPASS == 1
			erreport "32X VRAM DATA",.end,$18000
; 		endif
		dephase
thelabel label *
		endm

; --------------------------------------------
; Fill CD sectors
; --------------------------------------------

fillSectors macro num
	rept num
		align $800-1
		dc.b 0
	endm
	endm

; ====================================================================
; ------------------------------------------------------------
; Nikona CODE macros
; ------------------------------------------------------------

; --------------------------------------------
; VDP color debug
; --------------------------------------------

vdp_showme	macro color
		move.l	#$C0000000,(vdp_ctrl).l
		move.w	#color,(vdp_data).l
		endm
