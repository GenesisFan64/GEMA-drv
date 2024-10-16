; ===========================================================================
; -------------------------------------------------------------------
; Shared variables
; -------------------------------------------------------------------

; ====================================================================
; ----------------------------------------------------------------
; MCD SECTION
; ----------------------------------------------------------------

		if MCD|MARSCD

; --------------------------------------------------------
; Settings
; --------------------------------------------------------

MAX_MCDSTAMPS	equ 32		; !! Maximum SCD Stamps

; --------------------------------------------------------
; Structs
; --------------------------------------------------------

; Stamp data buffer
; Fixed size of $20 bytes

cdstamp		struct
flags		ds.b 1		; Flags
map		ds.b 1		; Map slot index (in WRAM_MdStampList)
cx		ds.w 1		; Center Texture X
cy		ds.w 1		; Center Texture Y
x		ds.w 1		; Stamp X position
y		ds.w 1		; Stamp Y position
wdth		ds.w 1		; Stamp width
hght		ds.w 1		; Stamp height
scale		ds.w 1
rot		ds.w 1
		ds.w 1
		ds.w 1
		ds.w 1
		ds.w 1
		ds.w 1
		ds.w 1
		ds.w 1
; len		ds.l 0
		endstruct

; ============================================================

		endif	; end MCD|MARSCD

; ====================================================================
; ----------------------------------------------------------------
; 32X SECTION
; ----------------------------------------------------------------

		if MARS|MARSCD

; --------------------------------------------------------
; Settings
; --------------------------------------------------------

MAX_MARSSPR	equ 32		; !! Maximum 2D-mode Sprites
MAX_MARSMSPR	equ 32		; !! Maximum 3D-mode Sprites
MAX_MARSOBJ	equ 24		; !! Maximum 3D-mode Objects (models)

; --------------------------------------------------------
; Structs
; --------------------------------------------------------

; ----------------------------------------
; RAM_MdMars_ScrlSett
;
; Maximum size: $20 bytes
; ----------------------------------------

sscrl		struct
x_pos		ds.l 1		; $xxxx.0000
y_pos		ds.l 1		; $yyyy.0000
vram		ds.l 1		; VRAM
		endstruct

; ----------------------------------------
; RAM_MdMars_SuperSpr
;
; sspr_Flags: %ET0000yx
;	| E - Enabled sprite
;	| T - Delete on next frame (68k clears bit)
; 	| x - Flip X
; 	| y - Flip Y
; sspr_Size: $xxyy
; 	| xx - Width/8
; 	| yy - Height/8
;
; Maximum size: $10 bytes
; ----------------------------------------

sspr		struct
flags		ds.b 1		; %ET0000yx
		ds.b 1
frame		ds.w 1		; Current frame
size		ds.w 1		; Size in cells $XXYY
indx		ds.w 1		; 256-index color
x_pos		ds.w 1		; X position
y_pos		ds.w 1		; Y position
vram		ds.l 1		; Graphics VRAM position (in RAM_Mars_VramData)
; len		ds.l 0
		endstruct

; ----------------------------------------
; RAM_MdMars_Models
;
; X/Y/Z are in 10mm steps (1meter = $100)
;
; Maximum size: $20 bytes
; ----------------------------------------

mmdl		struct
frame		ds.w 1
		ds.w 1
data		ds.l 1		; Model data pointer, 0: No model
x_pos		ds.l 1		; X position
y_pos		ds.l 1		; Y position
z_pos		ds.l 1		; Z position
x_rot		ds.l 1		; X rotation
z_rot		ds.l 1		; Y rotation
y_rot		ds.l 1		; Z rotation
; len		ds.l 0
		endstruct

; ----------------------------------------
; RAM_MdMars_MSprites
;
; X/Y/Z are in 10mm steps (1meter = $100)
;
; Maximum size: $20 bytes
; ----------------------------------------

mspr		struct
flags		ds.b 1		; %EIF00000 E-enable | I-Normal/3D-field | F-Face to the camera
indx		ds.b 1		; Palette starting index
size_w		ds.b 1		; Size width
size_h		ds.b 1		; Size height
src_w		ds.b 1		; Texture frame width
src_h		ds.b 1		; Texture frame height
srcwdth		ds.b 1		; Texture width
frame_x		ds.b 1		; X frame
frame_y		ds.b 1		; Y frame
		ds.b 1
		ds.b 1
		ds.b 1
		ds.b 1
		ds.b 1
		ds.b 1
		ds.b 1
x_pos		ds.w 1		; X position
y_pos		ds.w 1		; Y position
z_pos		ds.w 1		; Z position
x_rot		ds.w 1		; X rotation
z_rot		ds.w 1		; Y rotation
y_rot		ds.w 1		; Z rotation
vram		ds.l 1		; VRAM texture location
; len		ds.l 0
		endstruct

; ----------------------------------------
; RAM_MdMars_MdlCamera
;
; X/Y/Z are in 10mm steps (1meter = $100)
;
; Maximum size: $20 bytes
; ----------------------------------------

mcam		struct
x_pos		ds.l 1		; X position
y_pos		ds.l 1		; Y position
z_pos		ds.l 1		; Z position
x_rot		ds.l 1		; X rotation
y_rot		ds.l 1		; Y rotation
z_rot		ds.l 1		; Z rotation
; len		ds.l 0
		endstruct

; ----------------------------------------------------------------
; DREQ RAM section
;
; To read these labels:
;
; On the Genesis:
; 	lea	(RAM_MdMars_Comm+DREQ_LABEL).w,aX
; On the 32X:
; 	mov	#DREQ_LABEL,rX
; 	mov	@(marsGbl_DreqRead,gbr),r0
;	add	r0,rX
;
; List MUST be aligned by 8bytes.
; ----------------------------------------------------------------

Dreq		struct
Palette		ds.w 256				; 256-color palette *DON'T MOVE THIS*
Buff0		ds.b $20				; Buffer 0 | $020 bytes
Buff1		ds.b $400				; Buffer 1 | $400 bytes
Buff2		ds.b $400				; Buffer 2 | $400 bytes
; len		ds.l 0
		endstruct
	if (Dreq_len&7) <> 0
		error "32X DREQ IS MISALIGNED: \{Dreq_len}"
	endif

; ====================================================================
; ----------------------------------------------------------------
; Mode 1: 2D scrolling with sprites
; ----------------------------------------------------------------

			memory RAM_MdMars_CommBuff
			ds.w 256			; pallete skip
RAM_MdMars_ScrlSett	ds.b $20
RAM_MdMars_ScrlData	ds.w (512/16)*(256/16)
RAM_MdMars_SuperSpr	ds.b sspr_len*MAX_MARSSPR
.sizeof_this		ds.l 0
			endmemory
			erreport "This DREQ MEMORY: 2D",.sizeof_this-RAM_MdMars_CommBuff,Dreq_len

; ====================================================================
; ----------------------------------------------------------------
; Mode 2: 3D polygons mode
; ----------------------------------------------------------------

			memory RAM_MdMars_CommBuff
			ds.w 256			; pallete skip
RAM_MdMars_MdlCamera	ds.b $20
RAM_MdMars_MSprites	ds.b mspr_len*MAX_MARSMSPR	; $400
RAM_MdMars_Models	ds.b mmdl_len*MAX_MARSOBJ	; $400
.sizeof_this		ds.l 0
			endmemory
			erreport "This DREQ MEMORY: 3D",.sizeof_this-RAM_MdMars_CommBuff,Dreq_len

; ============================================================

		endif	; end MARS|MARSCD
