; ===========================================================================
; ----------------------------------------------------------------
; 32X Video, Master CPU side.
; ----------------------------------------------------------------

; ====================================================================
; --------------------------------------------------------
; Settings
; --------------------------------------------------------

MAX_MarsVram		equ $18000	; !! Maximum 32X graphics data stored on SDRAM for both 2D/3D

; ------------------------------------------------
; 2D scrolling mode
SET_MSCRLSIZE		equ 16		; !! Hard-coded, requires code modifications
SET_MSCRLWDTH		equ 320+16	; !! Affects 2D Scrolling, Super-Sprites and 3D Polygons
SET_MSCRLHGHT		equ 240		; !! ''
SET_TILEMAX		equ $0200	; Maximum block tiles to use (1-bit SIZES ONLY)
SET_FBVRAM_PATCH	equ $1E000	; Framebuffer location to store the affected XShift lines
; SET_FBVRAM_BLANK	equ $1FD80	; Framebuffer location for the BLANK line

; ------------------------------------------------
; 3D polygons mode
; MAX_MOBJ		equ 64		; see system/shared.asm
SET_3DFIELD_WDTH	equ 320
SET_3DFIELD_HGHT	equ 224
MAX_FACES		equ 256		; Maximum 3D polygon faces to read
MAX_ZDIST		equ -$280	; Maximum 3D field distance (-value)

; --------------------------------------------------------
; Variables
; --------------------------------------------------------

PLGN_TEXURE		equ %10000000	; plypz_type (MSB)
PLGN_TRI		equ %01000000
; ** MORE variables system/shared.asm

; --------------------------------------------------------
; Structs
; --------------------------------------------------------

; FIXED SIZE: $40
plypz		struct
type		ds.l 1		; Type + Material settings (width + index add)
mtrl		ds.l 1		; Material data (ROM or SDRAM)
ytb		ds.l 1		; $YYYYyyyy: Y-Top Y / y-Bottom Y
xl		ds.l 1		;  Screen X-Left | X-Right  16-bit
src_xl		ds.l 1		; Texture X-Left | X-Right  16-bit
src_yl		ds.l 1		; Texture Y-Top  | Y-Bottom 16-bit
xl_dx		ds.l 1		; 0000.0000
xr_dx		ds.l 1		; 0000.0000
src_xl_dx	ds.l 1
src_xr_dx	ds.l 1
src_yl_dx	ds.l 1
src_yr_dx	ds.l 1
		endstruct

; ** MORE strcts on system/shared.asm

; ------------------------------------------------
; Polygon
plygn		struct
type		ds.l 1		; %MTww wwww aaaa aaaa | m-Solid/Tex t-Triangle
mtrl		ds.l 1		; Material data: Color or VRAM position (RAM_Mars_VramData)
points		ds.l 4*2	; X/Y positions
srcpnts		ds.w 4*2	; X/Y texture points 16-bit, UNUSED on solid color
; len		ds.l 0
		endstruct

; ====================================================================
; --------------------------------------------------------
; Init MARS Video
;
; Breaks:
; r1-r4
; --------------------------------------------------------

		align 4
MarsVideo_Init:
		mov	#SET_MSCRLWDTH+SET_MSCRLSIZE,r1	; Set scroll-area settings
		mov	#SET_MSCRLHGHT+SET_MSCRLSIZE,r2
		mulu	r1,r2
		mov	r1,r0
		mov	r0,@(marsGbl_Scrl_Wdth,gbr)
		mov	r2,r0
		mov	r0,@(marsGbl_Scrl_Hght,gbr)
		sts	macl,r0
		mov	r0,@(marsGbl_Scrl_Size,gbr)
		mov	#$200,r0
		mov	r0,@(marsGbl_Scrl_FbOut,gbr)
		mov	#0,r0
		mov.w	r0,@(marsGbl_ThisFrame,gbr)
		mov	r0,@(marsGbl_Scrl_FbY,gbr)
		mov	r0,@(marsGbl_Scrl_FbTL,gbr)
		mov	#SET_3DFIELD_WDTH,r0
		mov	r0,@(marsGbl_3D_OutWidth,gbr)
		mov	#SET_3DFIELD_HGHT,r0
		mov	r0,@(marsGbl_3D_OutHeight,gbr)
		rts
		nop
		align 4

; ====================================================================
; ----------------------------------------------------------------
; Subroutines
; ----------------------------------------------------------------

; --------------------------------------------------------
; MarsVideo_FixTblShift
;
; Fix the affected $xxFF lines (solve that HW errata),
; Call this BEFORE flipping the Framebuffer.
;
; Input:
; r1 | Start line
; r2 | Number of lines
; r3 | Location for the fixed lines
;
; Breaks:
; r7-r14
; --------------------------------------------------------

		align 4
MarsVideo_FixTblShift:
		mov	#_vdpreg,r14
		mov.b	@(bitmapmd,r14),r0		; Check if we are on indexed mode
		and	#%11,r0
		cmp/eq	#1,r0
		bf	.ptchset
		mov.w	@(marsGbl_XShift,gbr),r0	; XShift is set? (EXTERNAL value)
		and	#1,r0
		tst	r0,r0
		bt	.ptchset

		mov	#_framebuffer,r14		; r14 - Framebuffer BASE
		mov	r14,r12				; r12 - Framebuffer output for the patched pixel lines
		add	r3,r12
		mov	r1,r0
		shll2	r0
		add	r0,r14
		mov	r14,r13				; r13 - Framebuffer lines to check
		mov	r2,r11				; r11 - Lines to check
		mov	#-1,r0
		extu.b	r0,r10				; r10 - AND byte to check ($FF)
		extu.w	r0,r9				;  r9 - AND word limit ($FFFF)
.loop:
		mov.w	@r13,r0
		and	r9,r0
		mov	r0,r7
		and	r10,r0
		cmp/eq	r10,r0
		bf	.tblexit
		shll	r7
		add	r14,r7
		mov	r12,r0
		shlr	r0
		mov.w	r0,@r13
		mov	#(320+4)/2,r3
.copy:
		mov.w	@r7,r0
		mov.w	r0,@r12
		add	#2,r7
		dt	r3
		bf/s	.copy
		add	#2,r12
.tblexit:
		dt	r11
		bf/s	.loop
		add	#2,r13
.ptchset:
		rts
		nop
		align 4
		ltorg

; ====================================================================
; ----------------------------------------------------------------
; 2D scrolling-area section
; ----------------------------------------------------------------

; --------------------------------------------------------
; MarsVideo_ShowScrlBg
;
; Make a visible section of any scrolling area
; into the current framebuffer.
;
; Input:
; r1 | Top Y
; r2 | Bottom Y
;
; Breaks:
; r4-r14
;
; NOTE:
; After endstrcting all your screens call
; MarsVideo_FixTblShift before doing frameswap
; --------------------------------------------------------

		align 4
MarsVideo_ShowScrlBg:
		mov	#_framebuffer,r14		; r14 - Framebuffer BASE
		mov	#0,r11				; r11 - line counter
		mov	@(marsGbl_Scrl_FbOut,gbr),r0	; r13 - Framebuffer pixeldata position
		mov	r0,r13
		mov	@(marsGbl_Scrl_Size,gbr),r0	; r12 - Full size of screen-scroll
		mov	r0,r12
		mov	@(marsGbl_Scrl_Wdth,gbr),r0
		mov	r0,r10
		mov	@(marsGbl_Scrl_FbTL,gbr),r0
		mov	r0,r9
		mov	@(marsGbl_Scrl_FbY,gbr),r0
		mov	r0,r8
		cmp/eq	r2,r1
		bt	.bad_y
		cmp/ge	r2,r1
		bt	.bad_y
		mov	r1,r6
		mov	r1,r0
		shll	r0
		add	r0,r14
		mulu	r10,r8
		sts	macl,r0
		add	r0,r9
.ln_loop:
		mov	r9,r8
		cmp/ge	r12,r8
		bf	.xl_r
		sub	r12,r8
.xl_r:
		mov	r8,r9
		add	r10,r9			; Add Y
		add	r13,r8			; Add Framebuffer position
		shlr	r8			; Divide by 2, use Xshift for the missing bit
		mov.w	r8,@r14			; Send to FB's table
		add	#2,r14
		add	#1,r6
		cmp/eq	r2,r6
		bf/s	.ln_loop
		add	#2,r11
.bad_y:
		rts
		nop
		align 4

; --------------------------------------------------------
; Call this AFTER after drawing to the scrolling area.
; --------------------------------------------------------

		align 4
marsScrl_CopyTopBot:
		mov	@(marsGbl_Scrl_FbOut,gbr),r0
		mov	r0,r1
		mov	@(marsGbl_Scrl_Size,gbr),r0
		mov	r0,r3
		mov	#_framebuffer,r0
		add	r0,r1
		mov	r1,r2
		add	r3,r2
		mov	#320/4,r3
		nop
.copy_top:
		mov	@r1+,r0
		nop
		mov	r0,@r2
		add	#4,r2
		dt	r3
		bf	.copy_top
		rts
		nop
		align 4
		ltorg

; ====================================================================
; ----------------------------------------------------------------
; Super sprites
; ----------------------------------------------------------------

; --------------------------------------------------------
; MarsVideo_SuperSpr_Make
; --------------------------------------------------------

		align 4
MarsVideo_SuperSpr_Make:
		sts	pr,@-r15
		mov	#$C0000000|RAM_Mars_SVdpSprInfo,r14
		mov	@(marsGbl_Scrl_Size,gbr),r0
		mov	r0,r13
		mov	@(marsGbl_Scrl_Hght,gbr),r0
		mov	r0,r12
		mov	@(marsGbl_Scrl_Wdth,gbr),r0
		mov	r0,r11
		mov	@(marsGbl_Scrl_FbTL,gbr),r0
		mov	r0,r10
		mov	@(marsGbl_Scrl_FbY,gbr),r0
		mov	r0,r9
		mov	@(marsGbl_Scrl_FbOut,gbr),r0
		mov	r0,r2
		mov	@(marsGbl_DreqRead,gbr),r0
		mov	#Dreq_Buff2,r8				; ** DREQ READ **
		add	r0,r8
		mov	#sspr_len*(MAX_MARSSPR-1),r0	; <-- LAZY REVERSE ORDER
		add	r0,r8					; <--
	; ----------------------------------------
	; r14 - Sprite draw list
	; r13 - Scroll size W*H
	; r12 - Scroll height
	; r11 - Scroll width
	; r10 - Scroll TL-pos read *
	;  r9 - Scroll Y-pos read *
	;  r8 - Current SuperSprite
		mov	#MAX_MARSSPR,r7
.next_sspr:
		mov.b	@(sspr_flags,r8),r0
		tst	#$80,r0
		bt	.off_sspr
		extu.b	r0,r6
		mov	@(sspr_vram,r8),r0
		lds	r0,mach
		mov.w	@(sspr_indx,r8),r0
		extu.b	r0,r0
		shll16	r6
		or	r0,r6			; r6 - $000f00ii: f-Flags i-Index
		mov.w	@(sspr_size,r8),r0
		extu.b	r0,r5			; Y size
		shlr8	r0
		extu.b	r0,r4			; X size
		mov.w	@(sspr_x_pos,r8),r0
		exts.w	r0,r2
		mov.w	@(sspr_y_pos,r8),r0
		exts.w	r0,r3
		add	#1,r4
		add	#1,r5
		shll2	r4			; Expand sizes to 8pixels(cells)
		shll2	r5
		shll	r4
		shll	r5
		mov	r2,r0			; Offscreen checks
		add	r4,r0
		cmp/pl	r0
		bf	.off_sspr
		mov	r3,r0
		add	r5,r0
		cmp/pl	r0
		bf	.off_sspr
		mov	#SET_MSCRLWDTH>>2,r0
		shll2	r0
		cmp/ge	r0,r2
		bt	.off_sspr
		mov	#SET_MSCRLHGHT>>2,r0
		shll2	r0
		cmp/ge	r0,r3
		bt	.off_sspr
		mov.w	@(sspr_frame,r8),r0
		muls	r4,r5
		sts	macl,r1
		muls	r0,r1
		sts	macl,r0
		sts	mach,r1
		add	r0,r1
		mov	#CS1>>24,r0
		shll16	r0
		shll8	r0
		cmp/ge	r0,r1
		bt	.from_rom
		mov	#RAM_Mars_VramData,r0
		add	r0,r1
.from_rom:
	; r1 | Graphics data *
	; r2 | Xpos *
	; r3 | Ypos *
	; r4 | Xsize *
	; r5 | Ysize *
	; r6 | Flags + Pixel increment *
		add	#$10,r14
		mov	r14,r0
		mov	r6,@-r0
		mov.w	r5,@-r0
		mov.w	r4,@-r0
		mov.w	r3,@-r0
		mov.w	r2,@-r0
		mov	r1,@-r0
.off_sspr:
		mov	#sspr_len,r0
		dt	r7
		bf/s	.next_sspr
		sub	r0,r8			; <-- LAZY REVERSE ORDER
.exit_sspr:
		lds	@r15+,pr
		rts
		nop
		align 4
		ltorg

; --------------------------------------------------------
; MarsVideo_SuperSpr_Draw
; --------------------------------------------------------

		align 4
MarsVideo_SuperSpr_Draw:
		sts	pr,@-r15
		mov	#_overwrite,r14			; <--
		mov	@(marsGbl_Scrl_Size,gbr),r0
		mov	r0,r13
		mov	@(marsGbl_Scrl_Hght,gbr),r0
		mov	r0,r12
		mov	@(marsGbl_Scrl_Wdth,gbr),r0
		mov	r0,r11
		mov	@(marsGbl_Scrl_FbTL,gbr),r0
		mov	r0,r10
		mov	@(marsGbl_Scrl_FbY,gbr),r0
		mov	r0,r9
		mov	@(marsGbl_Scrl_FbOut,gbr),r0
		mov	r0,r8
		mov	@(marsGbl_DreqRead,gbr),r0
		add	r8,r14
		mov	#$C0000000|RAM_Mars_SVdpSprInfo,r8
		mov	#MAX_MARSSPR,r7
.next_piece:
		mov	#0,r0
		mov	@r8,r1
		mov	r0,@r8
		tst	r1,r1
		bt	.no_slot
		mov	r8,r0
		add	#4,r0
		mov.w	@r0+,r2
		mov.w	@r0+,r3
		mov.w	@r0+,r4
		mov.w	@r0+,r5
		bsr	scrlDrw_SSprDraw
		mov	@r0+,r6
.no_slot:
		dt	r7
		bf/s	.next_piece
		add	#$10,r8
		lds	@r15+,pr
		rts
		nop
		align 4

; 		mov	#_DMASOURCE1,r12
; 		mov	#%0101001011100000,r0
; 		mov	r0,@($0C,r12)
; 		mov	#_overwrite+$200,r0
; 		mov	r0,@($04,r12)
; 		mov	#CS3,r0
; 		mov	r0,@r12
; 		mov	#320*96,r0
; 		mov	r0,@($08,r12)
; 		mov	#%0101001011100000|1,r0
; 		mov	r0,@($0C,r12)
; .wait_dma:	mov	@($C,r12),r0		; Still on DMA?
; 		tst	#%10,r0
; 		bt	.wait_dma
; 		mov	#%0101001011100000,r0
; 		mov	r0,@($C,r12)

; --------------------------------------------------------
; scrlDrw_SSprDraw
;
; Inputs:
; r1 | Graphics data *
; r2 | Xpos *
; r3 | Ypos *
; r4 | Xsize *
; r5 | Ysize *
; r6 | Flags + Pixel increment *
;
; In Loop:
; r14 - Framebuffer output
; r13 - Scroll size W*H
; r12 - Scroll height
; r11 - Scroll width
; r10 - Scroll TL-pos read
;  r9 - Scroll Y-pos read
;
; Breaks:
; r1-r6
; --------------------------------------------------------

		align 4
scrlDrw_SSprDraw:
		mov	r7,@-r15
		mov	r8,@-r15
		mov	r9,@-r15
		mov	r10,@-r15
		mov	r12,@-r15
	; Y limits
		mov	r3,r0
.y_low:		cmp/pz	r0
		bt	.y_mid
		mov	#0,r0
.y_mid:		cmp/ge	r12,r0
		bf	.y_ok
		mov	#SET_MSCRLHGHT>>2,r0	; 240
		shll2	r0
.y_ok:
		add	r9,r0
		muls	r11,r0			; macl - Y pos
	; No X limits
		mov	r2,r12			; X-pos
		add	r10,r12
		sts	macl,r0
		add	r0,r12
.xy_xwrap:	cmp/ge	r13,r12
		bf	.xy_flip
		bra	.xy_xwrap
		sub	r13,r12
.xy_flip:
		mov	#-4,r0
		and	r0,r12
	; ---------------------------------------
		swap	r6,r0			; Y flip? start
		tst	#%10,r0
		bt	.y_flip
		muls	r4,r5
		sts	macl,r0
		add	r0,r1			; Flip Y src
		sub	r4,r1
.y_flip:
		mov	#4,r8
		swap	r6,r0			; X flip?
		tst	#%01,r0
		bt	.x_flip
		neg	r8,r8
		mov	r4,r0
		add	#-4,r0
		add	r0,r1
.x_flip:
		cmp/pz	r3
		bt	.y_top
		add	r3,r5
		muls	r4,r3
		swap	r6,r0
		tst	#%10,r0
		bt	.y_rflip
		sts	macl,r0
		bra	.y_rflipc
		neg	r0,r0
.y_rflip:
		sts	macl,r0
.y_rflipc:
		sub	r0,r1
.y_top:
		mov	r3,r0
		add	r5,r0
		mov	#SET_MSCRLHGHT>>2,r9	; 240
		shll2	r9
		cmp/ge	r9,r0
		bf	.y_bot
		sub	r9,r0
		sub	r0,r5
.y_bot:
		nop
		mov	r2,r9		; r9 - X size
		add	r4,r9
		swap	r6,r0		; Y flip? start
		tst	#%10,r0
		bt	.y_flipr
		neg	r4,r4
.y_flipr:
		mov	#-4,r0
		and	r0,r1

	; ---------------------------------------
	; LOOP
	; ---------------------------------------
	; r1 - Frame data line pos
	; r2 - X pos read
	; r3 -
	; r4 - Y increment f/b
	; r5 - Y lines / X current beam
	; r6 - flags (X flip only) | pixel increment
	; r7 - current TL pos
	; r8 - X increment f/b
	; r9 - X end
	; r10 -
	; r11
	; r12
.y_loop:
		cmp/ge	r13,r12
		bf	.tl_snap
		sub	r13,r12
.tl_snap:
		mov	r1,@-r15
		mov	r2,@-r15
		mov	r4,@-r15
		mov	r5,@-r15
		mov	r12,@-r15
		mov	#(320+4)>>2,r5
		shll2	r5

; ---------------------------------------

.x_loop:
		cmp/ge	r13,r12
		bf	.tl_x
		sub	r13,r12
.tl_x:
		mov	@r1,r0
		extu.b	r6,r3
		tst	#$FF,r0
		bt	.z_0
		add	r3,r0
.z_0:		swap.b	r0,r0
		tst	#$FF,r0
		bt	.z_1
		add	r3,r0
.z_1:		swap.w	r0,r0
		tst	#$FF,r0
		bt	.z_2
		add	r3,r0
.z_2:		swap.b	r0,r0
		tst	#$FF,r0
		bt	.z_3
		add	r3,r0
.z_3:		mov	r0,r3
		swap	r6,r0
		tst	#%01,r0
		bf	.x_mswap	; <--
		swap.b	r3,r3
		swap.w	r3,r3
		swap.b	r3,r3
.x_mswap:
		mov	r3,r4

	; r3 - left copy
	; r4 - right copy
	; 	1234 ----
	; 	-123 4---
	; 	--12 34--
	; 	---1 234-
		mov	r2,r0
		add	r10,r0
		and	#%11,r0
		tst	r0,r0
		bt	.wrt_0
		cmp/eq	#2,r0
		bt	.half_2
		cmp/eq	#3,r0
		bt	.half_3
		bra	.half_1
		shll16	r4
.half_2:
		shll16	r4
		bra	.drw_half
.half_3:
		shlr16	r3
.half_1:	shlr8	r3
		shll8	r4
.drw_half:
		mov	r2,r0
		cmp/ge	r5,r0
		bt	.wrt_0
		add	#4+4,r0
		cmp/pz	r0
		bf	.wrt_0
		mov	r12,r0		; Right half
		add	#4,r0
		cmp/ge	r13,r0
		bf	.tl_h
		sub	r13,r0
.tl_h:		add	r14,r0
		mov	r4,@r0
.wrt_0:
		mov	r2,r0
		cmp/ge	r5,r0
		bt	.x_giveup
		add	#4,r0
		cmp/pz	r0
		bf	.xr_left
		mov	r12,r0
		add	r14,r0
		mov	r3,@r0
.xr_left:
		add	r8,r1
		add	#4,r2
		cmp/ge	r9,r2
		bf/s	.x_loop
		add	#4,r12
.x_giveup:

; ---------------------------------------
		mov	@r15+,r12
		mov	@r15+,r5
		mov	@r15+,r4
		mov	@r15+,r2
		mov	@r15+,r1
		add	r4,r1		; Next line FOWARD
		dt	r5
		bf/s	.y_loop
		add	r11,r12
.y_last:

.y_end:
		mov	@r15+,r12
		mov	@r15+,r10
		mov	@r15+,r9
		mov	@r15+,r8
		mov	@r15+,r7
		rts
		nop
		align 4
		ltorg

; 		align 4
; 		ltorg

; MarsVideo_DmaDraw:
; 		mov	#_DMASOURCE1,r4
; 		mov	#%0101001011100000,r0
; 		mov	r0,@($0C,r4)
; 		mov	r1,r0
; 		mov	r0,@r4
; 		mov	r2,r0			; <-- point fbdata here
; 		mov	r0,@($04,r4)
; 		mov	r3,r0
; 		mov	r0,@($08,r4)
; 		mov	#%0101001011100000|1,r0
; 		mov	r0,@($0C,r4)
; .wait_dma:	mov	@($C,r4),r0		; Still on DMA?
; 		tst	#%10,r0
; 		bt	.wait_dma
; 		mov	#%0101001011100000,r0
; 		mov	r0,@($C,r4)
; 		rts
; 		nop
; 		align 4
; 		ltorg

; --------------------------------------------------------
; MarsVideo_MkFillBlk
;
; Generate Block-Refill blocks to be processed on
; the next frame
;
; 16x16 blocks.
; --------------------------------------------------------

		align 4
MarsVideo_MkFillBlk:
		sts	pr,@-r15
		mov	#$C0000000|RAM_Mars_ScrlRefill,r14

	; First pass: Redraw bits from DREQ-RAM
		mov	r14,r2
		mov	#Dreq_Buff1,r1			; ** DREQ READ **
		mov	@(marsGbl_DreqRead,gbr),r0
		add	r0,r1
		mov	#(512/16)*(256/16),r4
		mov	#%11,r3			; Write flag
.copy_bit:
		mov.w	@r1+,r0
		exts.w	r0,r0
		cmp/pz	r0
		bt	.no_flip
		mov.w	@r2,r0
		or	r3,r0
		mov.w	r0,@r2
.no_flip:
		dt	r4
		bf/s	.copy_bit
		add	#2,r2

	; Last pass: SuperSprites
	; r14 is gone here
		mov	#Dreq_Buff2,r13			; ** DREQ READ **
		mov	@(marsGbl_DreqRead,gbr),r0
		add	r0,r13
		mov	#MAX_MARSSPR,r12
.next_sspr:
		mov.b	@(sspr_flags,r13),r0
		tst	#$80,r0				; Sprite enabled?
; 		bt	.exit_sspr			; end of list
		bt	.off_sspr			; sprite is off, keep checking
		nop
		mov.w	@(sspr_size,r13),r0
		extu.b	r0,r5				; Y size
		shlr8	r0
		extu.b	r0,r4				; X size
		cmp/pl	r5				; Y size <= 0?
		bf	.exit_sspr
		cmp/pl	r4				; X size <= 0?
		bf	.exit_sspr
		mov.w	@(sspr_x_pos,r13),r0
		exts.w	r0,r2
		mov.w	@(sspr_y_pos,r13),r0
		exts.w	r0,r3

	; off-screen checks
; 		mov	r4,r0
; 		shll2	r0
; 		shll2	r0
; 		add	r2,r0
; 		cmp/pz	r0
; 		bf	.exit_sspr
; 		mov	#SET_MSCRLWDTH>>2,r0
; 		shll2	r0
; 		cmp/ge	r0,r2
; 		bt	.exit_sspr
; 		mov	r5,r0
; 		shll2	r0
; 		shll	r0
; 		add	r3,r0
; 		cmp/pz	r0
; 		bf	.exit_sspr
; 		mov	#SET_MSCRLHGHT>>2,r0
; 		shll2	r0
; 		cmp/ge	r0,r3
; 		bt	.exit_sspr

		shlr	r4			; /2 for 16x16
		shlr	r5
		add	#1,r4
		add	#1,r5
		mov	@(marsGbl_Scrl_Xpos,gbr),r0
		exts.w	r0,r8
		mov	#16-1,r6		; MANUAL SIZE 16x16
		nop
		mov	@(marsGbl_Scrl_Ypos,gbr),r0
		exts.w	r0,r9
		mov	r2,r0
		add	r8,r0
		and	r6,r0
		tst	r0,r0
		bt	.x_szex
		add	#1,r4
.x_szex:
		mov	r3,r0
		add	r9,r0
		and	r6,r0
		tst	r0,r0
		bt	.y_szex
		add	#1,r5
.y_szex:
		shll2	r4		; Expand sizes to 16pixels
		shll2	r4
		shll2	r5
		shll2	r5
		add	r2,r4
		add	r3,r5
		mov	#SET_MSCRLWDTH>>2,r6
		mov	#SET_MSCRLHGHT>>2,r7
		shll2	r6
		shll2	r7
	; Off-screen limits
		cmp/pl	r4
		bf	.off_sspr
		cmp/pl	r5
		bf	.off_sspr
		cmp/ge	r6,r2		; Xleft < 0?
		bt	.off_sspr
		cmp/ge	r7,r3		; Yup < 0?
		bt	.off_sspr
	; Squeeze screen coords
		mov	#16,r0
		add	r0,r6
		add	r0,r7
		cmp/pl	r2
		bt	.x_sqz
		mov	#0,r2
.x_sqz:		cmp/pl	r3
		bt	.y_sqz
		mov	#0,r3
.y_sqz:		cmp/ge	r6,r4
		bf	.x_sqend
		mov	r6,r4
.x_sqend:	cmp/ge	r7,r5
		bf	.y_sqend
		mov	r7,r5
.y_sqend:

	; r2 - X pos
	; r3 - Y pos
	; r4 - X end
	; r5 - Y end
.y_row:
		mov	r2,r6
.x_row:
		mov	r3,r0
		add	r9,r0
		shlr2	r0
		shlr2	r0
		and	#(256/16)-1,r0
		shll2	r0
		shll2	r0
		shll2	r0
		mov	r0,r7
		mov	r6,r0
		add	r8,r0
		shlr2	r0
		shlr2	r0
		and	#(512/16)-1,r0
		shll	r0
		add	r0,r7
		add	r14,r7
		mov.w	@r7,r0
		or	#%11,r0
		mov.w	r0,@r7
		add	#16,r6
		cmp/ge	r4,r6
		bf	.x_row
		add	#16,r3
		cmp/ge	r5,r3
		bf	.y_row
.off_sspr:
		mov	#sspr_len,r0
		dt	r12
		bf/s	.next_sspr
		add	r0,r13
.exit_sspr:
		lds	@r15+,pr
		rts
		nop
		align 4
		ltorg

; --------------------------------------------------------
; MarsVideo_DrawFillBlk
;
; r14 - Svdp queue base
; r13 - Scroll size W*H
; r12 - Scroll height
; r11 - Scroll width
; r10 - Scroll TL-pos read / 16 *
;  r9 - Scroll Y-pos read / 16 *
;  r8 - Graphics data
;  r7 - Map data
;  r6 - Map Y read index
;  r5 - Map X read index
; --------------------------------------------------------

		align 4
MarsVideo_DrawFillBlk:
		sts	pr,@-r15

		mov	#_framebuffer,r14
		mov	@(marsGbl_Scrl_Size,gbr),r0
		mov	r0,r13
		mov	@(marsGbl_Scrl_Hght,gbr),r0
		mov	r0,r12
		mov	@(marsGbl_Scrl_Wdth,gbr),r0
		mov	r0,r11
		mov	@(marsGbl_Scrl_FbTL,gbr),r0
		mov	r0,r10
		mov	@(marsGbl_Scrl_FbY,gbr),r0
		mov	r0,r9
		mov	@(marsGbl_Scrl_Vram,gbr),r0
		mov	r0,r6
		mov	@(marsGbl_Scrl_Ypos,gbr),r0
		mov	r0,r7
		mov	@(marsGbl_Scrl_Xpos,gbr),r0
		mov	r0,r8
		mov	@(marsGbl_Scrl_FbOut,gbr),r0
		add	r0,r14
		mov	@(marsGbl_DreqRead,gbr),r0
		mov	#Dreq_Buff1,r5			; ** DREQ READ **
		add	r0,r5
		mov	#RAM_Mars_VramData,r0
		add	r0,r6
		mov	#-SET_MSCRLSIZE,r0		; -MSCRL_BLKSIZE
		and	r0,r10				; Set FB top-left
		and	r0,r9
		mov	#$C0000000|RAM_Mars_ScrlRefill,r4
; 		mov.w	@(marsGbl_DrawAll,gbr),r0
; 		tst	r0,r0
; 		bt	.keep_normal
; 		mov	#0,r4
; .keep_normal:

	; r14 - Svdp queue base
	; r13 - Scroll size W*H
	; r12 - Scroll height
	; r11 - Scroll width
	; r10 - Scroll TL-pos read / 16 *
	;  r9 - Scroll Y-pos read / 16 *
	;  r8 - Map X read index
	;  r7 - Map Y read index
	;  r6 - Graphics data
	;  r5 - Map data
	;  r4 - Refill map
	;  r3 -
		muls	r9,r11
		sts	macl,r0
		add	r0,r10
		mov	#-4,r1
		and	r1,r10
		mov	r11,r3
		shlr2	r3
		shlr2	r3
.x_loop:
		cmp/ge	r13,r10
		bf	.tl_snap_x
		sub	r13,r10
.tl_snap_x:
		mov	r3,@-r15
		mov	r7,@-r15
		mov	r10,@-r15
		mov	r12,@-r15
		shlr2	r12
		shlr2	r12
.y_loop:
		cmp/ge	r13,r10
		bf	.tl_snap_y
		sub	r13,r10
.tl_snap_y:
		mov	r10,r2
		mov	#(256/16)-1,r0
		mov	r7,r3		; Y pos
		shlr2	r3
		shlr2	r3
		and	r0,r3
		shll2	r3
		shll2	r3
		shll	r3
		mov	#(512/16)-1,r0
		mov	r8,r1		; X pos
		shlr2	r1
		shlr2	r1
		and	r0,r1
		add	r3,r1
		shll	r1
		tst	r4,r4
		bt	.always_on
		lds	r1,macl
		add	r4,r1
		mov.w	@r1,r0
		tst	r0,r0
		bt	.no_flag
		shlr	r0
		tst	r0,r0
		mov.w	r0,@r1
		sts	macl,r1
.always_on:
		add	r5,r1
		lds	r4,mach
		mov.w	@r1,r0
		mov	#SET_TILEMAX-1,r1
		mov	r0,r4
		and	r1,r4
		mov	#0,r1
		tst	r4,r4
		bt	.blank_req
		dt	r4
		shll8	r4			; 16x16
		mov	r4,r1
		add	r6,r1
.blank_req:
		sts	mach,r4

; 		mov	#0,r1			; TEMPORAL
		bsr	scrlDrw_DrawBlk
		mov	r3,@-r15
		mov	@r15+,r3
.no_flag:
		mov	#16,r0
		mulu	r11,r0
		sts	macl,r0
		add	r0,r10
		add	#16,r7
		dt	r12
		bf/s	.y_loop
		add	#16,r9

		mov	@r15+,r12
		mov	@r15+,r10
		mov	@r15+,r7
		mov	@r15+,r3
		add	#16,r10
		dt	r3
		bf/s	.x_loop
		add	#16,r8

.exit_lr:
		lds	@r15+,pr
		rts
		nop
		align 4
		ltorg

; --------------------------------------------------------
; scrlDrw_DrawBlk
;
; Currents:
; r0 - Block data
; r1 - Graphics data, 0 = blank mode
; r2 - FB TL position
;
; InLoop:
; r14 - Framebuffer BASE
; r13 - Scrl W*H
; r11 - Scrl width
;
; Uses:
; r2,macl,mach
; --------------------------------------------------------

		align 4
scrlDrw_DrawBlk:
		tst	r1,r1
		bf	.normal
		mov	#16,r3
.next_zline:
		cmp/ge	r13,r2
		bf	.tl_snapz
		sub	r13,r2
.tl_snapz:
		lds	r2,macl
		add	r14,r2
	rept 16/4
		mov	r1,@r2
		add	#4,r2
	endm
		sts	macl,r2
		dt	r3
		bf/s	.next_zline
		add	r11,r2
		rts
		nop
		align 4

; ----------------------------------------------------

.normal:
		lds	r4,mach
		shlr8	r0		; Get index increment
		shll	r0
		and	#$FC,r0		; Filter these bits only
		mov	r0,r3
		mov	#16,r4
.next_line:
		cmp/ge	r13,r2
		bf	.tl_snap
		sub	r13,r2
.tl_snap:
		lds	r2,macl
		add	r14,r2
	rept 16/4
		mov	@r1,r0
		swap.w	r0,r0		; 3 4 1 2
		swap.b	r0,r0		; 3 4 2 1
		tst	#$FF,r0
		bt	.z_0
		add	r3,r0
.z_0:		swap.b	r0,r0		; 3 4 1 2
		tst	#$FF,r0
		bt	.z_1
		add	r3,r0
.z_1:		swap.w	r0,r0		; 1 2 3 4
		swap.b	r0,r0		; 1 2 4 3
		tst	#$FF,r0
		bt	.z_2
		add	r3,r0
.z_2:		swap.b	r0,r0		; 1 2 3 4
		tst	#$FF,r0
		bt	.z_3
		add	r3,r0
.z_3:
		add	#4,r1		; <-- src incr
		mov	r0,@r2
		add	#4,r2
	endm
		sts	macl,r2

		dt	r4
; 		bt	.end_line
; 		bra	.next_line
; 		nop
		bf/s	.next_line
		add	r11,r2
.end_line:
		sts	mach,r4
		rts
		nop
		align 4
		ltorg

; ====================================================================
; ----------------------------------------------------------------
; Polygon rendering subroutines
; ----------------------------------------------------------------

; ------------------------------------------------
; MarsVideo_SlicePlgn
;
; This slices polygons into pieces.
;
; Input:
; r14 | Polygon data to read
; ------------------------------------------------

		align 4
MarsVideo_SlicePlgn:
		mov	@(marsGbl_PlgnPzIndx_W,gbr),r0
		mov	r0,r2
		mov	@(marsGbl_PlgnPzIndx_R,gbr),r0
		cmp/ge	r2,r0
		bf	MarsVideo_SlicePlgn

		sts	pr,@-r15
		mov	#$C0000000|Cach_DDA_Last,r13		; r13 - DDA last point
		mov	#$C0000000|Cach_DDA_Top,r12		; r12 - DDA first point
		mov	@(plygn_type,r14),r0			; Read type settings ($F000 0000)
		shlr16	r0					; 0000 F000
		shlr8	r0					; 0000 00F0
		tst	#PLGN_TRI,r0				; PLGN_TRI set?
		bf	.tringl
		add	#8,r13					; If quad: add 8
.tringl:
		mov	r14,r1
		mov	r12,r2
		mov	#$C0000000|Cach_DDA_Src,r3
		add	#plygn_points,r1
		lds	r0,mach
		nop

	; ----------------------------------------
	; Polygon points
	; ----------------------------------------

		mov	@(marsGbl_3D_OutWidth,gbr),r0
		shlr	r0
		mov	r0,r6
		mov	#4,r8
		mov	@(marsGbl_3D_OutHeight,gbr),r0
		shlr	r0
		mov	r0,r7
		nop
.setpnts:
		mov	@r1+,r4
		add	r6,r4			; X + width
		mov	@r1+,r5
		add	r7,r5			; Y + height
		mov	r4,@r2
		nop
		mov	r5,@(4,r2)
		dt	r8
		bf/s	.setpnts
		add	#8,r2
		mov	#4,r8			; Copy texture source points to Cache
.src_pnts:
		mov	@r1+,r4
		extu.w	r4,r5
		shlr16	r4
		extu.w	r4,r4
; 		mov.w	@r1+,r4
; 		mov.w	@r1+,r5
; 		extu.w	r4,r4
; 		extu.w	r5,r5

		mov	r4,@r3
		mov	r5,@(4,r3)
		dt	r8
		bf/s	.src_pnts
		add	#8,r3

	; Search for the lowest Y and highest Y
	; r10 - Top Y
	; r11 - Bottom Y
		sts	mach,r0
.start_math:
		mov	#3,r9
		tst	#PLGN_TRI,r0		; PLGN_TRI set?
		bf	.ytringl
		add	#1,r9
.ytringl:
		mov	#$7FFFFFFF,r10
		mov	#-1,r11			; $FFFFFFFF
		mov 	r12,r7
		mov	r12,r8
.find_top:
		mov	@(4,r7),r0
		cmp/gt	r11,r0
		bf	.is_low
		mov 	r0,r11
.is_low:
		mov	@(4,r8),r0
		cmp/gt	r10,r0
		bt	.is_high
		mov 	r0,r10
		mov	r8,r1
.is_high:
		add 	#8,r7
		dt	r9
		bf/s	.find_top
		add	#8,r8
		cmp/ge	r11,r10			; Top larger than Bottom?
		bt	.exit
		cmp/pl	r11			; Bottom < 0?
		bf	.exit
; 		mov	#SET_3DFIELD_HGHT>>2,r0	; Top > 224?
; 		shll2	r0
		mov	@(marsGbl_3D_OutHeight,gbr),r0
		cmp/ge	r0,r10
		bt	.exit

	; r2 - Left DDA READ pointer
	; r3 - Right DDA READ pointer
	; r4 - Left X
	; r5 - Left DX
	; r6 - Right X
	; r7 - Right DX
	; r8 - Left width
	; r9 - Right width
	; r10 - Top Y, updates after calling put_piece
	; r11 - Bottom Y
	; r12 - First DST point
	; r13 - Last DST point
		mov	r1,r2				; r2 - X left to process
		bsr	set_left
		mov	r1,r3				; r3 - X right to process
		bsr	set_right
		nop

.next_pz:
; 		mov	#SET_3DFIELD_HGHT>>2,r0		; Current Y > 224?
; 		shll2	r0
		mov	@(marsGbl_3D_OutHeight,gbr),r0
		cmp/gt	r0,r10
		bt	.exit
		cmp/ge	r11,r10				; Y top >= Y bottom?
		bt	.exit

		mov	#$C0000000|RAM_Mars_SVdpDrwList,r1
		mov	@(marsGbl_PlgnPzIndx_W,gbr),r0
		and	#16-1,r0
		shll8	r0
		shlr2	r0
		add	r0,r1
		mov	@(4,r2),r8
		mov	@(4,r3),r9
		sub	r10,r8
		sub	r10,r9
		mov	r8,r0
		cmp/ge	r8,r9
		bt	.lefth
		mov	r9,r0
.lefth:
		mov	#$C0000000|Cach_Bkup_SPZ,r0
		mov	r2,@-r0
		mov	r3,@-r0
		mov	r5,@-r0
		mov	r7,@-r0
		mov	r8,@-r0
		mov	r9,@-r0
		mov	r11,@-r0
		bsr	put_piece
		nop
		mov	#$C0000000|Cach_Bkup_LPZ,r0
		mov	@r0+,r11
		mov	@r0+,r9
		mov	@r0+,r8
		mov	@r0+,r7
		mov	@r0+,r5
		mov	@r0+,r3
		mov	@r0+,r2
	; X direction update
		cmp/gt	r9,r8				; Left width > Right width?
		bf	.lefth2
		bsr	set_right
		nop
		bra	.next_pz
		nop
.lefth2:
		bsr	set_left
		nop
		bra	.next_pz
		nop
.exit:
		lds	@r15+,pr
		rts
		nop
		align 4
		ltorg

		align 4
set_left:
		mov	r2,r8				; Get a copy of Xleft pointer
		add	#$20,r8				; To read Texture SRC points
		mov	@r8,r4
		mov	@(4,r8),r5
		mov	#$C0000000|Cach_DDA_Src_L,r8
		mov	r4,r0
		shll16	r0
		mov	r0,@r8
		mov	r5,r0
		shll16	r0
		mov	r0,@(8,r8)
		mov	@r2,r1
		mov	@(4,r2),r8
		add	#8,r2
		cmp/gt	r13,r2
		bf	.lft_ok
		mov 	r12,r2
.lft_ok:
		mov	@(4,r2),r0
		sub	r8,r0
		cmp/eq	#0,r0
		bt	set_left
		cmp/pz	r0
		bf	.lft_skip
		lds	r0,mach
		mov	r2,r8
		add	#$20,r8
		mov 	@r8,r0
		sub 	r4,r0
		mov 	@(4,r8),r4
		sub 	r5,r4

		mov	r0,r5
		shll8	r4
		shll8	r5
		mov	#1,r0
		mov.w	r0,@(marsGbl_WdgDivLock,gbr)
		sts	mach,r8
		mov	#_JR,r0
		mov	r8,@r0
		mov	r5,@(4,r0)
		nop
; 		mov	@(4,r0),r5
		mov 	@($14,r0),r5
		mov	#_JR,r0
		mov	r8,@r0
		mov	r4,@(4,r0)
		nop
; 		mov	@(4,r0),r4
		mov 	@($14,r0),r4
		shll8	r4
		shll8	r5
		mov	#$C0000000|Cach_DDA_Src_L+$C,r0
		mov	r4,@r0
		mov	#$C0000000|Cach_DDA_Src_L+4,r0
		mov	r5,@r0
		mov	@r2,r5
		sub 	r1,r5
		mov 	r1,r4
		shll8	r5
		shll16	r4
		mov	#_JR,r0
		mov	r8,@r0
		mov	r5,@(4,r0)
		nop
; 		mov	@(4,r0),r5
		mov 	@($14,r0),r5
		shll8	r5
		mov	#0,r0
		mov.w	r0,@(marsGbl_WdgDivLock,gbr)
.lft_skip:
		rts
		nop
		align 4

; --------------------------------------------------------

set_right:
		mov	r3,r9
		add	#$20,r9
		mov	@r9,r6
		mov	@(4,r9),r7
		mov	#$C0000000|Cach_DDA_Src_R,r9
		mov	r6,r0
		shll16	r0
		mov	r0,@r9
		mov	r7,r0
		shll16	r0
		mov	r0,@(8,r9)

		mov	@r3,r1
		mov	@(4,r3),r9
		add	#-8,r3
		cmp/ge	r12,r3
		bt	.rgt_ok
		mov 	r13,r3
.rgt_ok:
		mov	@(4,r3),r0
		sub	r9,r0
		cmp/eq	#0,r0
		bt	set_right
		cmp/pz	r0
		bf	.rgt_skip
		lds	r0,mach
		mov	r3,r9
		add	#$20,r9
		mov 	@r9,r0
		sub 	r6,r0
		mov 	@(4,r9),r6
		sub 	r7,r6
		mov	r0,r7
		shll8	r6
		shll8	r7
		mov	#1,r0
		mov.w	r0,@(marsGbl_WdgDivLock,gbr)
		sts	mach,r9
		mov	#_JR,r0
		mov	r9,@r0
		mov	r7,@(4,r0)
		nop
; 		mov	@(4,r0),r7
		mov 	@($14,r0),r7
		mov	#_JR,r0
		mov	r9,@r0
		mov	r6,@(4,r0)
		nop
; 		mov	@(4,r0),r6
		mov 	@($14,r0),r6
		shll8	r6
		shll8	r7
		mov	#$C0000000|Cach_DDA_Src_R+4,r0
		mov	r7,@r0
		mov	#$C0000000|Cach_DDA_Src_R+$C,r0
		mov	r6,@r0
		mov	@r3,r7
		sub 	r1,r7
		mov 	r1,r6
		shll16	r6
		shll8	r7
		mov	#_JR,r0
		mov	r9,@r0
		mov	r7,@(4,r0)
		nop
; 		mov	@(4,r0),r7
		mov 	@($14,r0),r7
		shll8	r7
		mov	#0,r0
		mov.w	r0,@(marsGbl_WdgDivLock,gbr)
.rgt_skip:
		rts
		nop
		align 4

; --------------------------------------------------------

	; r2
	; r3
	; r4 - Left X
	; r5
	; r6 - Right X
	; r7
	; r8
	; r9
	; r10 - Top Y, gets updated after calling put_piece

put_piece:
		mov	#1,r0
		mov.w	r0,@(marsGbl_WdgHold,gbr)	; Tell watchdog we are mid-write
		mov	@(4,r2),r8			; Left DDA's Y
		mov	@(4,r3),r9			; Right DDA's Y
		sub	r10,r8
		sub	r10,r9
		cmp/gt	r9,r8
		bt	.lefth
		mov	r8,r9
.lefth:
		mov	r4,r8
		mov	r6,r0
		shlr16	r8
		xtrct	r8,r0
		mov	r0,@(plypz_xl,r1)
		mov 	r5,@(plypz_xl_dx,r1)
		mul	r9,r5
		mov 	r7,@(plypz_xr_dx,r1)
		sts	macl,r2
		mul	r9,r7
		sts	macl,r3
		add 	r2,r4
		add	r3,r6
		mov	r10,r2
		add	r9,r10
		mov	r10,r11
		shll16	r2
		or	r2,r11
		mov	r11,@(plypz_ytb,r1)

	; r9 - Y multiply
	;
	; free:
	; r2,r3,r5,r7,r8,r11
		mov	#$C0000000|Cach_DDA_Src_L,r8
		mov	#$C0000000|Cach_DDA_Src_R,r7
		mov	@r8,r2
		mov	@r7,r3
		mov	r2,r5
		mov	r3,r0
		shlr16	r5
		xtrct	r5,r0
		mov	r0,@(plypz_src_xl,r1)
; 		mov	r2,@(plypz_src_xl,r1)
; 		mov	r3,@(plypz_src_xr,r1)

		mov	@(4,r8),r0
		mov	@(4,r7),r5
		mov	r0,@(plypz_src_xl_dx,r1)
		mov	r5,@(plypz_src_xr_dx,r1)
		mul	r9,r0
		sts	macl,r0
		mul	r9,r5
		sts	macl,r5
		add 	r0,r2
		add	r5,r3
		mov	r2,@r8
		mov	r3,@r7
		add	#8,r8	; Go to Y/DY
		add	#8,r7
		mov	@r8,r2
		mov	@r7,r3
		mov	r2,r5
		mov	r3,r0
		shlr16	r5
		xtrct	r5,r0
		mov	r0,@(plypz_src_yl,r1)
; 		mov	r2,@(plypz_src_yl,r1)
; 		mov	r3,@(plypz_src_yr,r1)

		mov	@(4,r8),r0
		mov	@(4,r7),r5
		mov	r0,@(plypz_src_yl_dx,r1)
		mov	r5,@(plypz_src_yr_dx,r1)
		mul	r9,r0
		sts	macl,r0
		mul	r9,r5
		sts	macl,r5
		add 	r0,r2
		add	r5,r3
		mov	r2,@r8
		mov	r3,@r7
		cmp/pl	r11			; TOP check, 2 steps
		bt	.top_neg
		shll16	r11
		cmp/pl	r11
		bf	.bad_piece
.top_neg:
		mov	@(plygn_mtrl,r14),r0
		mov 	r0,@(plypz_mtrl,r1)
		mov	@(plygn_type,r14),r0
		mov 	r0,@(plypz_type,r1)
		mov	@(marsGbl_PlgnPzIndx_W,gbr),r0
		add	#1,r0
		mov	r0,@(marsGbl_PlgnPzIndx_W,gbr)
		mov.w	@(marsGbl_PlyPzCntr,gbr),r0
		add	#1,r0
		mov.w	r0,@(marsGbl_PlyPzCntr,gbr)
.bad_piece:
		mov	#0,r0
		mov.w	r0,@(marsGbl_WdgHold,gbr)	; Unlock.
		rts
		nop
		align 4
		ltorg

; =================================================================
; ------------------------------------------------
; WATCHDOG INTERRUPT
; ------------------------------------------------

		align 4
m_irq_wdg:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov.w	@(marsGbl_WdgHold,gbr),r0
		tst	r0,r0
		bf	.exit_wdg
; ------------------------------------------------

		mov.w	@(marsGbl_WdgTask,gbr),r0
		cmp/eq	#7,r0
		bf	.wdg_main

; ------------------------------------------------
; Special...
		mov	#_vdpreg,r1
.wait_fb:	mov.w   @($0A,r1),r0			; Framebuffer locked?
		tst     #%10,r0
		bf      .wait_fb
		mov.w   @(6,r1),r0			; SVDP-fill address
		add     #$5F,r0				; Pre-increment
		mov.w   r0,@(6,r1)
		mov.w   #320/2,r0			; SVDP-fill size (320+ pixels)
		mov.w   r0,@(4,r1)
		mov.w	#$0000,r0			; SVDP-fill pixel data
; 		mov.w	#$1000,r0
		mov.w   r0,@(8,r1)			; now SVDP-fill is working.
		mov.w	@(marsGbl_WdgClLines,gbr),r0	; Decrement a line to progress
		dt	r0
		bf/s	.exit_wdg
		mov.w	r0,@(marsGbl_WdgClLines,gbr)	; Write new value before branch
		mov	#5,r0				; Set watchdog task $05
		mov.w	r0,@(marsGbl_WdgTask,gbr)
.on_clr:
		rts
		nop
		align 4
.exit_wdg:
		mov.w   #$FE80,r1
		mov.w   #$A518,r0		; OFF
		mov.w   r0,@r1
		or      #$20,r0			; ON
		mov.w   r0,@r1
		mov.w   #$5A20,r0		; Wdg-timer: $20
		rts
		mov.w   r0,@r1
		align 4

; ------------------------------------------------
; Process drawing now.
.wdg_main:
		shll2	r0
		mov	#.list,r1
		mov	@(r1,r0),r0
		jmp	@r0
		nop
		align 4
.list:
		dc.l slvplgn_00		; NULL task, exit.
		dc.l slvplgn_01		; 2D SVDP fast write
		dc.l slvplgn_00
		dc.l slvplgn_00
		dc.l slvplgn_00		; $04 -
		dc.l slvplgn_05		; Main drawing routine
		dc.l slvplgn_06		; Resume from solid color
		dc.l slvplgn_00		; ***

; ------------------------------------------------
; 2D MODE
; ------------------------------------------------

slvplgn_01:
		mov	r2,@-r15
; 		mov	r3,@-r15
; 		mov	r4,@-r15
; 		mov.w	@(marsGbl_SVdpQWrt,gbr),r0
; 		mov	r0,r1
; 		mov.w	@(marsGbl_SVdpQRead,gbr),r0
; 		cmp/eq	r1,r0
; 		bt	.no_finish
; 		and	#%111111,r0
; 		shll2	r0
; 		shll	r0
; 		mov	#$C0000000|RAM_Mars_SVdpDrwList,r4
; 		mov	#_framebuffer,r3
; 		add	r0,r4
; 		mov	@r4+,r1		; Dest
; 		mov	@r4+,r2		; Data
; 		add	r3,r1
; 		mov	r2,@r1		; <--
; 		mov.w	@(marsGbl_SVdpQRead,gbr),r0
; 		add	#1,r0
; 		mov.w	r0,@(marsGbl_SVdpQRead,gbr)
; .no_finish:
; 		mov	#CS3+$40,r1
; 		mov	@r1,r0
; 		add	#1,r0
; 		mov	r0,@r1
; .no_queue:
; 		mov	@r15+,r4
; 		mov	@r15+,r3
		bra	drwtask_exit
		mov	#$20,r2

; ------------------------------------------------
; Task $06
;
; Resume from solid color
; ------------------------------------------------

slvplgn_06:
		mov	r2,@-r15
		mov	r3,@-r15
		mov	r4,@-r15
		mov	r5,@-r15
		mov	r6,@-r15
		mov	r7,@-r15
		mov	r8,@-r15
		mov	r9,@-r15
		mov	r10,@-r15
		mov	r11,@-r15
		mov	r12,@-r15
		mov	r13,@-r15
		mov	r14,@-r15
		sts	macl,@-r15
		sts	mach,@-r15
		mov	#$C0000000|Cach_LnDrw_L,r0
		mov	@r0+,r14
		mov	@r0+,r13
		mov	@r0+,r12
		mov	@r0+,r11
		mov	@r0+,r10
		mov	@r0+,r9
		mov	@r0+,r8
		mov	@r0+,r7
		mov	@r0+,r6
		mov	@r0+,r5
		mov	@r0+,r4
		mov	@r0+,r3
		mov	@r0+,r2
		mov	@r0+,r1
		mov	#5,r0
		bra	drwsld_updline
		mov.w	r0,@(marsGbl_WdgTask,gbr)	; Set task $05

; ------------------------------------------------
; Task $05
;
; Draw polygon piece
; ------------------------------------------------

slvplgn_05:
		mov	r2,@-r15
		mov.w	@(marsGbl_PlyPzCntr,gbr),r0	; Any pieces to draw?
		cmp/pl	r0
		bt	.has_pz
		mov.w	@(marsGbl_WdgReady,gbr),r0	; Finished slicing?
		tst	r0,r0
		bt	.exit
		mov	#0,r0				; Watchdog out.
		mov.w	r0,@(marsGbl_WdgTask,gbr)
.exit:		bra	drwtask_exit
		mov	#$20,r2				; Wdg-timer: $20
		align 4
.has_pz:
		mov	r3,@-r15			; Save all these regs
		mov	r4,@-r15
		mov	r5,@-r15
		mov	r6,@-r15
		mov	r7,@-r15
		mov	r8,@-r15
		mov	r9,@-r15
		mov	r10,@-r15
		mov	r11,@-r15
		mov	r12,@-r15
		mov	r13,@-r15
		mov	r14,@-r15
		sts	macl,@-r15
		sts	mach,@-r15
drwtsk1_newpz:
		mov	#$C0000000|RAM_Mars_SVdpDrwList,r14
		mov	@(marsGbl_PlgnPzIndx_R,gbr),r0
		and	#16-1,r0
		shll8	r0
		shlr2	r0
		add	r0,r14
		mov	@(plypz_ytb,r14),r9	; Start grabbing StartY/EndY positions
		exts.w	r9,r10			; r10 - Bottom
		shlr16	r9			;  r9 - Top
		exts.w	r9,r9
		cmp/eq	r9,r10			; if Top == Bottom, exit
		bt	.invld_y
; 		mov	#SET_3DFIELD_HGHT>>2,r0	; if Top > 224, skip
; 		shll2	r0
		mov	@(marsGbl_3D_OutHeight,gbr),r0
		cmp/ge	r0,r9
		bt	.invld_y		; if Bottom > 224, add max limit
		cmp/gt	r0,r10
		bf	.len_max
		mov	r0,r10
.len_max:
		sub	r9,r10			; Turn r10 into line lenght (Bottom - Top)
		cmp/pl	r10
		bt	.valid_y
.invld_y:
		bra	drwsld_nextpz		; if LEN < 0 then check next one instead.
		nop
		align 4
.no_pz:
		bra	drwtask_exit
		mov	#$10,r2
		align 4
.valid_y:
		mov	@(plypz_xl,r14),r1
		mov	r1,r3
		mov	@(plypz_xl_dx,r14),r2		; r2 - DX left
		shlr16	r1
		mov	@(plypz_xr_dx,r14),r4		; r4 - DX right
		shll16	r1
		mov	@(plypz_type,r14),r0		; Check material options
		shll16	r3
		shlr16	r0
		shlr8	r0
 		tst	#PLGN_TEXURE,r0			; Texture mode?
 		bf	drwtsk_texmode
		bra	drwtsk_solidmode
		nop
		align 4
		ltorg

; ------------------------------------
; Texture mode
;
; r1  - XL
; r2  - XL DX
; r3  - XR
; r4  - XR DX
; r5  - SRC XL
; r6  - SRC XR
; r7  - SRC YL
; r8  - SRC YR
; r9  - Y current
; r10  - Number of lines
; ------------------------------------

		align 4
go_drwsld_updline_tex:
		bra	drwsld_updline_tex
		nop
go_drwtex_gonxtpz:
		bra	drwsld_nextpz
		nop
		align 4
drwtsk_texmode:
		mov.w	@(marsGbl_WdgDivLock,gbr),r0	; Waste interrupt if MarsVideo_MakePolygon is in the
		cmp/eq	#1,r0				; middle of HW-division
		bf	.tex_valid
		bra	drwtask_return
		mov	#$10,r2				; Exit Wdg-timer: $10 (comeback quickly)
		align 4
.tex_valid:
		mov	@(plypz_src_xl,r14),r5		; Texture X left/right
		mov	r5,r6
		mov	@(plypz_src_yl,r14),r7		; Texture Y up/down
		shlr16	r5
		mov	r7,r8
		shlr16	r7

		shll16	r5
		shll16	r6
		shll16	r7
		shll16	r8
drwsld_nxtline_tex:
		cmp/pz	r9				; Y Start below 0?
		bf	go_drwsld_updline_tex
; 		mov	#SET_3DFIELD_HGHT>>2,r0		; Y Start after 224?
; 		shll2	r0
		mov	@(marsGbl_3D_OutHeight,gbr),r0
		cmp/ge	r0,r9
		bt	go_drwtex_gonxtpz

		mov	#$C0000000|Cach_Bkup_S,r0
		mov	r1,@-r0
		mov	r2,@-r0
		mov	r3,@-r0
		mov	r4,@-r0
		mov	r5,@-r0
		mov	r6,@-r0
		mov	r7,@-r0
		mov	r8,@-r0
		mov	r9,@-r0
		mov	r10,@-r0
		mov	r11,@-r0
	; r10-r11 are usable
		mov	@(marsGbl_3D_OutWidth,gbr),r0
		mov	r0,r11			; r11 - Width
		shlr16	r1
		shlr16	r3
		exts.w	r1,r1
		exts.w	r3,r3
		mov	r3,r0			; r0: X Right - X Left
		sub	r1,r0
		cmp/pl	r0			; Line reversed?
		bt	.txrevers
		mov	r3,r0			; Swap XL and XR values
		mov	r1,r3
		mov	r0,r1
		mov	r5,r0
		mov	r6,r5
		mov	r0,r6
		mov	r7,r0
		mov	r8,r7
		mov	r0,r8
.txrevers:
		cmp/eq	r1,r3				; Same X position?
		bt	.tex_skip_line
; 		mov	#SET_3DFIELD_WDTH>>2,r0		; Y Start after 224?
; 		shll2	r0
		cmp/pz	r3
		bf	.tex_skip_line
		cmp/gt	r11,r1				; X left > 320?
		bt	.tex_skip_line
		mov	r3,r2
		mov 	r1,r0
		sub 	r0,r2
		sub	r5,r6
		sub	r7,r8

	; Calculate new DX values
	; make sure DIV is not in use
	; before getting here.
	; (set marsGbl_WdgDivLock to 1)
		mov	#_JR,r0				; r6 / r2
		mov	r2,@r0
		mov	r6,@(4,r0)
		nop
; 		mov	@(4,r0),r6			; r8 / r2
		mov 	@($14,r0),r6
		mov	r2,@r0
		mov	r8,@(4,r0)
		nop
; 		mov	@(4,r0),r8
		mov 	@($14,r0),r8
	; Limit X destination points
	; and correct the texture's X positions
; 		mov	#SET_3DFIELD_WDTH>>2,r0		; XR point > 320?
; 		shll2	r0
		cmp/gt	r11,r3
		bf	.tr_fix
		mov	r11,r3				; Force XR to 320
.tr_fix:
		cmp/pz	r1				; XL point < 0?
		bt	.tl_fix
		neg	r1,r2				; Fix texture positions
		mul	r6,r2
		sts	macl,r0
		add	r0,r5
		mul	r8,r2
		sts	macl,r0
		add	r0,r7
		xor	r1,r1				; And reset XL to 0
.tl_fix:

	; Start
		mov	#-2,r0
		and	r0,r1
		and	r0,r3
		add	#1,r3				; LAZY PATCH
		sub 	r1,r3
		shar	r3
		cmp/pl	r3
		bf	.tex_skip_line

		mov	#_overwrite+$200,r10
		mov	@(plypz_type,r14),r4		;  r4 - texture width|palinc
		mov	r4,r13
		shlr16	r4
		extu.b	r13,r13
		mov	#$3FFF,r2
		and	r2,r4
		mov 	r9,r0				; Y position * $200
		shll8	r0
		shll	r0
		add 	r0,r10				; Add Y
		add 	r1,r10				; Add X
		mov	@(plypz_mtrl,r14),r1
		mov	#CS1>>24,r0
		shll16	r0
		shll8	r0
		cmp/ge	r0,r1
		bt	.from_rom
		mov	#RAM_Mars_VramData,r0		; <-- TEXTURE BUFFER
		add	r0,r1
.from_rom:

		mov	#_vdpreg,r2		; Any pending SVDP fill?
.w_fb:		mov.w	@(vdpsts,r2),r0
		tst	#%10,r0
		bf	.w_fb
.tex_xloop:
		mov	r7,r2
		shlr16	r2
		muls	r2,r4
		mov	r5,r2	   		; Build column index
		sts	macl,r0
		shlr16	r2
		add	r2,r0
		mov.b	@(r0,r1),r0		; Read left pixel
		tst	#$FF,r0
		bt	.trns_1
		add	r13,r0			; color-index increment
.trns_1:
		extu.b	r0,r0
		shll8	r0
		lds	r0,mach			; Save left pixel
		add	r6,r5			; Next X
		add	r8,r7			; Next Y

		mov	r7,r2
		shlr16	r2
		muls	r2,r4
		mov	r5,r2	   		; Build column index
		sts	macl,r0
		shlr16	r2
		add	r2,r0
		mov.b	@(r0,r1),r0		; Read right pixel
		tst	#$FF,r0
		bt	.trns2
		add	r13,r0			; color-index increment
.trns2:
		extu.b	r0,r0
		sts	mach,r2
		or	r2,r0

		mov.w	r0,@r10
		add	#2,r10
		add	r6,r5			; Next X
		dt	r3
		bf/s	.tex_xloop
		add	r8,r7			; Next Y
.tex_skip_line:
		mov	#$C0000000|Cach_Bkup_LB,r0
		mov	@r0+,r11
		mov	@r0+,r10
		mov	@r0+,r9
		mov	@r0+,r8
		mov	@r0+,r7
		mov	@r0+,r6
		mov	@r0+,r5
		mov	@r0+,r4
		mov	@r0+,r3
		mov	@r0+,r2
		mov	@r0+,r1
		nop
drwsld_updline_tex:
		mov	@(plypz_src_xl_dx,r14),r0	; Update DX postions
		add	r0,r5
		mov	@(plypz_src_xr_dx,r14),r0
		add	r0,r6
		mov	@(plypz_src_yl_dx,r14),r0
		add	r0,r7
		mov	@(plypz_src_yr_dx,r14),r0
		add	r0,r8
		add	r2,r1				; Update X postions
		dt	r10
		bt/s	drwtex_nextpz
		add	r4,r3
		bra	drwsld_nxtline_tex
		add	#1,r9
drwtex_nextpz:
		bra	drwsld_nextpz
		nop
		align 4
		ltorg

; ------------------------------------
; Solid Color
;
; r1  - XL
; r2  - XL DX
; r3  - XR
; r4  - XR DX
; r9  - Y current
; r10  - Number of lines
; ------------------------------------

drwtsk_solidmode:
; 		mov	#$FF,r0
		mov	@(plypz_mtrl,r14),r6
		mov	@(plypz_type,r14),r5
		extu.b	r5,r5
		extu.b	r6,r6
; 		and	r0,r5
; 		and	r0,r6
		add	r5,r6
		mov	#_vdpreg,r13
.wait:		mov.w	@(10,r13),r0
		tst	#2,r0
		bf	.wait
drwsld_nxtline:
		cmp/pz	r9			; Y pos < 0?
		bf	drwsld_updline
; 		mov	#SET_3DFIELD_HGHT,r0	; Y pos > 224?
		mov	@(marsGbl_3D_OutHeight,gbr),r0
		cmp/gt	r0,r9
		bt	drwsld_nextpz
		mov	r9,r0			; r10-r9 < 0?
		add	r10,r0
		cmp/pl	r0
		bf	drwsld_nextpz

		mov	r1,r11
		mov	r3,r12
		shlr16	r11
		shlr16	r12
		exts.w	r11,r11
		exts.w	r12,r12
		mov	#-2,r0		; WORD align
		and	r0,r11
		and	r0,r12
		mov	r12,r0
		sub	r11,r0
		cmp/pz	r0
		bt	.revers
		mov	r12,r0
		mov	r11,r12
		mov	r0,r11
.revers:
; 		mov	#SET_3DFIELD_WDTH>>2,r0
; 		shll2	r0
		mov	@(marsGbl_3D_OutWidth,gbr),r0
		cmp/pl	r12		; XR < 0?
		bf	drwsld_updline
		cmp/ge	r0,r11		; XL > 320?
		bt	drwsld_updline
		cmp/ge	r0,r12		; XR > 320?
		bf	.r_fix
		mov	r0,r12		; MAX XR
.r_fix:
		cmp/pl	r11		; XL < 0?
		bt	.l_fix
		xor	r11,r11		; MIN XL
.l_fix:
		mov.w	@(10,r13),r0	; Pending SVDP fill?
		tst	#%10,r0
		bf	.l_fix
		mov	r12,r0
		sub	r11,r0
		mov	r0,r12
		shlr	r0		; Len: (XR-XL)/2
		mov.w	r0,@(4,r13)	; Set SVDP-FILL len
		mov	r11,r0
		shlr	r0
		mov	r9,r5
		add	#1,r5
		shll8	r5
		add	r5,r0		; Address: (XL/2)*((Y+1)*$200)/2
		mov.w	r0,@(6,r13)	; Set SVDP-FILL address
		mov	r6,r0
		shll8	r0
		or	r6,r0		; Data: xxxx
		mov.w	r0,@(8,r13)	; Set pixels, SVDP-Fill begins
; .wait:	mov.w	@(10,r13),r0
; 		tst	#2,r0
; 		bf	.wait

; 	If the line is too large, leave it to VDP
; 	and exit watchdog, we will come back on
; 	next trigger.
		mov	#$28,r0					; If line > $28, leave the SVDP filling
		cmp/gt	r0,r12					; and wait for the next watchdog
		bf	drwsld_updline
		mov	#6,r0					; Set next mode on Resume
		mov.w	r0,@(marsGbl_WdgTask,gbr)		; Task $06
		mov	#$C0000000|Cach_LnDrw_S,r0		; Save ALL these regs for comeback
		mov	r1,@-r0
		mov	r2,@-r0
		mov	r3,@-r0
		mov	r4,@-r0
		mov	r5,@-r0
		mov	r6,@-r0
		mov	r7,@-r0
		mov	r8,@-r0
		mov	r9,@-r0
		mov	r10,@-r0
		mov	r11,@-r0
		mov	r12,@-r0
		mov	r13,@-r0
		mov	r14,@-r0
		bra	drwtask_return
		mov	#$28,r2			; Exit timer $20
; otherwise...
drwsld_updline:
		add	r2,r1			; Next X dst
		add	r4,r3			; Next Y dst
		dt	r10
		bf/s	drwsld_nxtline
		add	#1,r9

; ------------------------------------

drwsld_nextpz:
		xor	r0,r0
		mov	r0,@(plypz_type,r14)
		nop
		mov	@(marsGbl_PlgnPzIndx_R,gbr),r0
		add	#1,r0
		mov	r0,@(marsGbl_PlgnPzIndx_R,gbr)
		mov.w	@(marsGbl_PlyPzCntr,gbr),r0	; Decrement piece counter
		add	#-1,r0
		mov.w	r0,@(marsGbl_PlyPzCntr,gbr)
		bra	drwtask_purge
		mov	#$18,r2				; Exit Wdg-timer: $10

; --------------------------------
; Task $00
; --------------------------------

slvplgn_00:
		mov	r2,@-r15
		mov	#0,r0
		mov.w	r0,@(marsGbl_WdgTask,gbr)
		bra	drwtask_exit
		mov	#$28,r2
drwtask_purge:
; 		stc	sr,r3
; 		mov.b	#$F0,r0			; ** $F0
; 		extu.b	r0,r0
; 		ldc	r0,sr
; 		mov.w	#_CCR&$FFFF,r1		; Purge ON, Cache OFF
; 		mov	#%10000,r0
; 		mov.b	r0,@r1
; 		nop
; 		nop
; 		nop
; 		nop
; 		nop
; 		nop
; 		nop
; 		mov	#%01001,r0		; Purge OFF, Two-Way mode, Cache ON
; 		mov.b	r0,@r1
; 		ldc	r3,sr
drwtask_return:
		lds	@r15+,mach
		lds	@r15+,macl
		mov	@r15+,r14
		mov	@r15+,r13
		mov	@r15+,r12
		mov	@r15+,r11
		mov	@r15+,r10
		mov	@r15+,r9
		mov	@r15+,r8
		mov	@r15+,r7
		mov	@r15+,r6
		mov	@r15+,r5
		mov	@r15+,r4
		mov	@r15+,r3
drwtask_exit:
		mov.w   #$FE80,r1
		mov.w   #$A518,r0		; OFF
		mov.w   r0,@r1
		or      #$20,r0			; ON
		mov.w   r0,@r1
		mov.w   #$5A00,r0		; r2 - Timer
		or	r2,r0
		mov.w   r0,@r1
		mov	@r15+,r2
		rts
		nop
		align 4

; ------------------------------------------------

		ltorg
