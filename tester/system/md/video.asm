; ===========================================================================
; ----------------------------------------------------------------
; Genesis VDP section
; ----------------------------------------------------------------

; ====================================================================
; --------------------------------------------------------
; Settings
; --------------------------------------------------------

MAX_MDDMATSK		equ 24		; DMA BLAST entries
MAX_MDMAPSPR		equ 24		; VDP Sprites with map data
MAX_PALFDREQ		equ 8		; Maximum Pal-fading requests both VDP/SVDP, includes full fade

SET_NullVram		equ $07FE	; Default Blank cell
SET_DefAutoDma		equ $0480	; Default VRAM location for automatic-DMA output
DEF_PrintVram		equ $05A0	; Default VRAM location of the PRINT text graphics
DEF_PrintVramW		equ $04E0
DEF_PrintPal		equ $6000

DEF_MaxStampCOut	equ $60		; Maximum backup cells for the SCD Stamps

; ===================================================================
; --------------------------------------------------------
; Variables
; --------------------------------------------------------

; VDPATT_PL0		equ $0000
VDPATTR_PL1		equ $2000
VDPATTR_PL2		equ $4000
VDPATTR_PL3		equ $6000
VDPATTR_HI		equ $8000

; ------------------------------------------------
; Use these if you are not planning changing
; the VRAM locations of the scrolling area(s)
; ------------------------------------------------
DEF_VRAM_FG		equ $C000
DEF_VRAM_BG		equ $E000
DEF_VRAM_WD		equ $D000
DEF_VRAM_SPR		equ $F800
DEF_VRAM_HSCRL		equ $FC00

; ------------------------------------------------
; H sizes for the current layer
;
; Note:
; WINDOW's width changes between H32 and H40
; resolution modes.
; ------------------------------------------------
DEF_HSIZE_32		equ $040
DEF_HSIZE_64		equ $080	; Default
DEF_HSIZE_128		equ $100

; ------------------------------------------------
; VDP registers
; ------------------------------------------------
; $80
HVStop			equ $02
HintEnbl		equ $10
bitHVStop		equ 1
bitHintEnbl		equ 4
; $81
DispEnbl 		equ $40
VintEnbl 		equ $20
DmaEnbl			equ $10
bitDispEnbl		equ 6
bitVintEnbl		equ 5
bitDmaEnbl		equ 4
bitV30			equ 3

; ------------------------------------------------
; VDP VRAM bits
; ------------------------------------------------
; BYTE read:
bitAttrPrio		equ 7
bitAttrV		equ 4
bitAttrH		equ 3
; WORD read:
AttrPrio		equ $8000
AttrV			equ $1000
AttrH			equ $0800

; ------------------------------------------------
; vdp_ctrl READ bits
; Read as WORD
; ------------------------------------------------
bitFifoE		equ 9		; VDP DMA FIFO empty
bitFifoF		equ 8		; VDP DMA FIFO full
bitVInt			equ 7		; Vertical interrupt (NOT confused with bitVBlk)
bitSprOvr		equ 6		; Sprite overflow
bitSprCol		equ 5		; Sprite collision (leftover feature)
bitOdd			equ 4		; EVEN or ODD frame displayed on interlace mode
bitVBlk			equ 3		; Inside VBlank
bitHBlk			equ 2		; Inside HBlank
bitDma			equ 1		; DMA active bit, only works on FILL and COPY
bitPal			equ 0		; VDP PAL-speed mode flag

; ====================================================================
; ----------------------------------------------------------------
; Structs
; ----------------------------------------------------------------

; ------------------------------------------------
; RAM_PalFadeList
palfd			struct
req			ds.b 1
delay			ds.b 1
start			ds.b 1
incr			ds.b 1
target			ds.b 1
timer			ds.b 1
num			ds.w 1
; len		ds.l 0
			endstruct

; ------------------------------------------------
; RAM_MdMcd_Stamps

mdstmp		struct
flags		ds.w 1		; Flags settings/status
vramMain	ds.w 1		; Main VRAM output *full*
vramSec		ds.w 1		; Secondary VRAM output *full*
vramSize	ds.w 1
vramLen		ds.w 1		; temporals
vramIncr	ds.w 1		; ''
stmpoutb	ds.w 1
currOutFlip	ds.w 1
fdrop		ds.w 1
cellstorage	ds.l 1
dotIncr		ds.l 1
buffIncr	ds.l 1
; len		ds.l 0
		endstruct

; ====================================================================
; ----------------------------------------------------------------
; RAM section
; ----------------------------------------------------------------

			memory RAM_MdVideo
	; Some 32X labels are in system/shared.asm
RAM_PalFadeList		ds.b palfd_len*MAX_PALFDREQ	; Pal-fade request and buffers
RAM_SprMapList		ds.b $10*MAX_MDMAPSPR		; List of mapped-sprite data
RAM_SprPzList		ds.b $08*80			; List of sprite pieces to build
RAM_HorScroll		ds.l 240			; DMA Horizontal scroll data
RAM_VerScroll		ds.l 320/16			; DMA Vertical scroll data
RAM_Sprites		ds.w 8*80			; DMA Sprites
RAM_Palette		ds.w 64				; DMA Palette
RAM_PaletteFade		ds.w 64				; Target MD palette for FadeIn/Out
; RAM_VidPrntList		ds.w 3*24			; Video_Print list: Address, Type
RAM_VdpDmaIndx		ds.w 1				; Current index in DMA BLAST list
RAM_VdpDmaMod		ds.w 1				; Mid-write flag
RAM_SprOffsetX		ds.w 1				; X spriteset position
RAM_SprOffsetY		ds.w 1				; Y spriteset position
RAM_MdVidClr_e		ds.l 0				; <-- END POINT for Video_Clear

	; *** Variables NOT cleared DURING SCREEN CHANGES:
RAM_VdpDmaList		ds.b $10*MAX_MDDMATSK		; DMA BLAST list for VBlank
RAM_FrameCount		ds.l 1				; Frame-counter
RAM_IndxPalFade		ds.w 1				; Current index in the pal-fade request list
RAM_SprLinkNum		ds.w 1				; Current link number for the sprite-building routines
RAM_VdpVramFG		ds.w 1				; Full VRAM location for FG
RAM_VdpVramBG		ds.w 1				; '' BG
RAM_VdpVramWD		ds.w 1				; '' Window
RAM_VdpVramSpr		ds.w 1				; '' Sprites
RAM_VdpVramHScrl	ds.w 1				; '' Horizontal scroll
RAM_VdpMapSize		ds.w 1				; BG/FG Size
RAM_VdpRegSet0		ds.w 1				; * VDP Register $80
RAM_VdpRegSet1		ds.w 1				; * VDP Register $81
RAM_VdpRegSetB		ds.w 1				; * VDP Register $8B
RAM_VdpRegSetC		ds.w 1				; * VDP Register $8C
sizeof_mdvid		ds.l 0
			endmemory

; ====================================================================
; ----------------------------------------------------------------
; Initialize Genesis video
;
; Uses:
; d5-d7/a5-a6
; ----------------------------------------------------------------

Video_Init:
		lea	(RAM_MdVideo).w,a6			; Clear ALL Video RAM section
		moveq	#0,d6
		move.w	#(sizeof_mdvid-RAM_MdVideo)-1,d7
.clr_ram:
		move.b	d6,(a6)+
		dbf	d7,.clr_ram
		lea	(RAM_VdpDmaList).w,a6			; Reset the DMA blast list
		lea	.dma_entry(pc),a5
		move.w	#MAX_MDDMATSK-1,d7
.copy_dma:
		move.l	(a5),(a6)+
		move.l	4(a5),(a6)+
		move.l	8(a5),(a6)+
		move.l	$C(a5),(a6)+
		dbf	d7,.copy_dma
		lea	(RAM_SprMapList).w,a6
		move.w	#MAX_MDMAPSPR-1,d7
.clr_d:
		clr.l	(a6)+
		clr.l	(a6)+
		clr.l	(a6)+
		clr.l	(a6)+
		dbf	d7,.clr_d

		clr.w	(RAM_IndxPalFade).w			; Reset all these indexes
		lea	(RAM_PalFadeList).w,a6
		move.w	#MAX_PALFDREQ-1,d7
.clr_preq:
		clr.l	(a6)+
		clr.l	(a6)+
		dbf	d7,.clr_preq
	if MARS|MARSCD
		clr.w	(RAM_MdMars_IndxPalFd).w
		lea	(RAM_MdMars_MPalFdList).w,a6
		move.w	#MAX_PALFDREQ-1,d7
.clr_mreq:
		clr.l	(a6)+
		clr.l	(a6)+
		dbf	d7,.clr_mreq
	endif
		movem.w	.def_regset(pc),d0-d3
		movem.w	d0-d3,(RAM_VdpRegSet0).w
		move.l	(RAM_VdpRegSet0).w,(vdp_ctrl).l
		move.l	(RAM_VdpRegSetB).w,(vdp_ctrl).l
		bra	Video_Default

; --------------------------------------------------------
; DMA blast base entry
.dma_entry:
		dc.w $9400,$9300		; Size
		dc.w $9600,$9500,$9700		; Source
		dc.l $40000080 			; VDP write with DMA
		dc.w $0000			; Patch for the first 4 pixels (SCD/CD32X only)
		align 2
.def_regset:
		dc.w $8004,$8104,$8B00,$8C00
		align 2

; --------------------------------------------------------
; Video_Default
; --------------------------------------------------------

Video_Default:
	if MCD|MARSCD
		lea	(RAM_MdMcd_Stamps).w,a6
		move.w	#MAX_MCDSTAMPS-1,d7
.clr_stamps:
	rept $20/4
		clr.l	(a6)+
	endm
		dbf	d7,.clr_stamps
	endif
		move.l	#$91009200,(vdp_ctrl).l
		move.w	#$8F00|$02,(vdp_ctrl).l			; VDP increment $02 (failsafe)
		move.w	#DEF_VRAM_FG,(RAM_VdpVramFG).w
		move.w	#DEF_VRAM_BG,(RAM_VdpVramBG).w
		move.w	#DEF_VRAM_WD,(RAM_VdpVramWD).w
		move.w	#DEF_VRAM_SPR,(RAM_VdpVramSpr).w
		move.w	#DEF_VRAM_HSCRL,(RAM_VdpVramHScrl).w
		move.w	#$1000,(RAM_VdpMapSize).w		; Map size for FG/BG
		bsr	Video_UpdMapVram
		bsr	Video_UpdSprHVram
		moveq	#1,d0					; Size H64 V32
		moveq	#0,d1
		bsr	Video_SetMapSize
		moveq	#1,d0					; Resolution 320x224
		moveq	#0,d1
		bra	Video_Resolution

; ====================================================================
; --------------------------------------------------------
; Video_Render
;
; Call this during VBlank to update the VDP visuals
; and process the DMA BLAST list, also resets a
; few variables.
; (This is already called on System_Render)
;
; Uses:
; ALL
; --------------------------------------------------------

Video_Render:
		bsr	Video_DmaOn
		bsr	System_DmaEnter_RAM
		lea	(vdp_ctrl).l,a6
		move.w	(RAM_VdpVramSpr).w,d7
		move.w	(RAM_VdpVramHScrl).w,d5
		move.w	d7,d6
		andi.w	#$3FFF,d7
		ori.w	#$4000,d7
		rol.w	#2,d6
		andi.w	#%11,d6
		or.w	#$80,d6
		move.w	d5,d4
		andi.w	#$3FFF,d5
		ori.w	#$4000,d5
		rol.w	#2,d4
		andi.w	#%11,d4
		or.w	#$80,d4
		move.l	#$94019340,(a6)			; Size $280/2
		move.l	#$96009500|(RAM_Sprites<<7&$FF0000)|(RAM_Sprites>>1&$FF),(a6)
		move.w	#$9700|(RAM_Sprites>>17&$7F),(a6)
		move.w	d7,(a6)
		move.w	d6,-(sp)
		move.w	(sp)+,(a6)
		move.l	#$940193E0,(a6)			; Size $3C0/2
		move.l	#$96009500|(RAM_HorScroll<<7&$FF0000)|(RAM_HorScroll>>1&$FF),(a6)
		move.w	#$9700|(RAM_HorScroll>>17&$7F),(a6)
		move.w	d5,(a6)
		move.w	d4,-(sp)
		move.w	(sp)+,(a6)
		move.l	#$94009328,(a6)
		move.l	#$96009500|(RAM_VerScroll<<7&$FF0000)|(RAM_VerScroll>>1&$FF),(a6)
		move.w	#$9700|(RAM_VerScroll>>17&$7F),(a6)
		move.w	#$4000,(a6)
		move.w	#$0010|$80,-(sp)
		move.w	(sp)+,(a6)
		move.l	#$94009340,(a6)
		move.l	#$96009500|(RAM_Palette<<7&$FF0000)|(RAM_Palette>>1&$FF),(a6)
		move.w	#$9700|(RAM_Palette>>17&$7F),(a6)
		move.w	#$C000,(a6)
		move.w	#$0000|$80,-(sp)
		move.w	(sp)+,(a6)
		bsr	System_DmaExit_RAM
		bsr	Video_DmaOff

; --------------------------------------------------------
; Struct:
; dc.w $94xx,$93xx		; Size
; dc.w $96xx,$95xx,$97xx	; Source
; dc.l $4xxx008x 		; VDP destination with DMA bit
; dc.w $xxxx			; SegaCD/CD32X only: Patch for the first 4 pixels
		tst.w	(RAM_VdpDmaMod).w		; Got mid-write?
		bne.s	.exit
		tst.w	(RAM_VdpDmaIndx).w		; Any requests?
		beq.s	.exit
		lea	(vdp_ctrl).l,a4			; a4 - vdp_ctrl
		lea	(RAM_VdpDmaList).w,a3		; a3 - Blast list
		move.w	(RAM_VdpRegSet1).w,d7		; DMA Enable + VDP Display OFF
		bset	#bitDmaEnbl,d7
		move.w	d7,(a4)
		bsr	System_DmaEnter_ROM
.next:		tst.w	(RAM_VdpDmaIndx).w
		beq.s	.end
		move.l	(a3)+,(a4)			; Size
		move.l	(a3)+,(a4)			; Source
		move.w	(a3)+,(a4)
	; CD/CD32X
	if MCD|MARSCD
		move.w	(a3)+,d3			; Destination
		move.w	(a3)+,d2
		move.w	d2,-(sp)			; Use stack for this write
		move.w	d3,(a4)
		move.w	(sp)+,(a4)			; *** CPU freezes ***
		andi.w	#$FF7F,d2			; Remove DMA bit
		move.w	d3,(a4)				; Set VDP control normally
		move.w	d2,(a4)
		move.w	(a3)+,-4(a4)			; Write the patch data
	; Cartridge
	else
		move.w	(a3)+,(a4)			; Normal VDP control write
		move.w	(a3)+,(a4)			; *** CPU freezes ***
		adda	#2,a3
	endif
		subq.w	#1,(RAM_VdpDmaIndx).w
		bra.s	.next
.end:
		bsr	System_DmaExit_ROM
		move.w	(RAM_VdpRegSet1).w,d7		; Restore reg $81 setting
		move.w	d7,(a4)
.exit:
		rts

; ====================================================================
; --------------------------------------------------------
; Video_BuildSprites
;
; Build VDP Sprite pieces and maps
; --------------------------------------------------------

Video_BuildSprites:
		move.w	#1,(RAM_SprLinkNum).w		; Reset SPRITE LINK number
		lea	(RAM_Sprites).w,a6		; a6 - Genesis sprites
		move.w	(RAM_SprLinkNum).w,d6		; d6 - Starting sprite link
		cmp.w	#80,d6
		bge	.stop_all
		move.w	d6,d5
		subq.w	#1,d5
		bmi	.first_spr
		lsl.w	#3,d5
		adda	d5,a6
.first_spr:
		lea	(RAM_SprPzList).w,a5
		move.w	#80-1,d7			; Loop all pieces
.next_pz:
		cmpi.w	#80,d6
		bgt	.stop_all
		btst	#7,(a5)
		beq	.no_slot_s
		move.w	(a5),d0				; This slot is used?
		move.w	d0,d1
		andi.w	#$3C00,d1
		lsr.w	#2,d1
		add.w	d6,d1
		move.w	4(a5),d2
		move.w	2(a5),d3
		andi.w	#$03FF,d0
		move.w	d0,(a6)+
		move.w	d1,(a6)+
		move.w	d2,(a6)+
		move.w	d3,(a6)+
		addq.w	#1,d6
.no_slot_s:
		adda	#$08,a5
		dbf	d7,.next_pz
		lea	(RAM_SprMapList).w,a5	; Sprite with map data
		move.w	#MAX_MDMAPSPR-1,d7
.next:
		btst	#7,(a5)
		beq	.no_map
		move.l	(a5),a0
		swap	d7
		moveq	#0,d0
		move.w	$04(a5),d0		; Read frame number
		add.w	d0,d0
		move.w	(a0,d0.w),d0
		lea	(a0,d0.w),a0
		move.w	(a0)+,d5
		beq	.no_map
		subq.w	#1,d5
.mk_pz:
		cmpi.w	#80,d6
		bgt	.stop_all
		swap	d5
		swap	d6
		move.b	(a0)+,d0		; d0 - Y pos
		move.b	(a0)+,d1		; d1 - Size
		move.w	(a0),d2			; d2 - VRAM main
		btst	#2,(RAM_VdpRegSetC+1).w
		beq.s	.ex_vram
		move.w	d1,d4
		andi.w	#%1100,d1
		andi.w	#%0011,d4
		lsr.w	#1,d4
		or.w	d4,d1
		lsr.w	#1,d2
.ex_vram:
		adda	#4,a0			; <-- Reserved for VRAM double-interlace
		move.w	(a0)+,d3		; d3 - X pos
		ext.w	d0
		move.w	$06(a5),d5		; Read VRAM
		move.w	d5,d4
		btst	#2,(RAM_VdpRegSetC+1).w
		beq.s	.ex_vrams
		move.w	d5,d4
		andi.w	#$F800,d4
		andi.w	#$07FF,d5
		lsr.w	#1,d5
		or.w	d4,d5
.ex_vrams:
		move.w	d5,d4
		andi.w	#$1000,d4
		beq.s	.vram_v
		neg.w	d0
		subi.w	#8,d0
		move.w	d1,d6
		andi.w	#%0011,d6
		lsl.w	#3,d6
		sub.w	d6,d0
.vram_v:
		move.w	d5,d4
		andi.w	#$0800,d4
		beq.s	.vram_h
		neg.w	d3
		subi.w	#8,d3
		move.w	d1,d6
		andi.w	#%1100,d6
		add.w	d6,d6
		sub.w	d6,d3
.vram_h:
		add.w	d5,d2
		swap	d5
		swap	d6
		add.w	$0A(a5),d0		; Add Y pos
		add.w	$08(a5),d3		; Add X pos
		add.w	(RAM_SprOffsetY).w,d0
		sub.w	(RAM_SprOffsetX).w,d3
		cmp.w	#320,d3			; X/Y wrap
		bge.s	.no_pz
		move.w	d1,d4
		andi.w	#%1100,d4
		add.w	d4,d4
		add.w	#8,d4
		move.w	d3,d7
		add.w	d4,d7
		bmi.s	.no_pz
		move.w	#240,d4
		btst	#2,(RAM_VdpRegSetC+1).w
		beq.s	.ex_yext
		add.w	d4,d4
.ex_yext:
		cmp.w	d4,d0
		bge.s	.no_pz
		move.w	d1,d4
		andi.w	#%0011,d4
		lsl.w	#3,d4
		add.w	#8,d4
		move.w	d0,d7
		add.w	d4,d7
		bmi.s	.no_pz
		lsl.w	#8,d1			; Size + Link
		or.w	d6,d1
		addi.w	#$80,d0
		move.w	(RAM_VdpRegSetC).w,d4
		btst	#2,d4
		beq.s	.dont_add
		addi.w	#$80,d0
.dont_add:
		addi.w	#$80,d3
		move.w	d0,(a6)+
		move.w	d1,(a6)+
		move.w	d2,(a6)+
		move.w	d3,(a6)+
		add.w	#1,d6
.no_pz:
		dbf	d5,.mk_pz
.no_map:
		adda	#$10,a5
		swap	d7
.no_slot:
		dbf	d7,.next
.stop_all:
		bsr	vid_CheckLastSpr
		move.w	d6,(RAM_SprLinkNum).w

; --------------------------------------------------------
; Reset slots
; --------------------------------------------------------

.freeze:
		lea	(RAM_SprPzList).w,a6
		moveq	#80-1,d7
		moveq	#$08,d6
.chk_spr_r:
		move.b	(a6),d5
		btst	#7,d5
		beq.s	.no_slot_r
		btst	#6,d5
		beq.s	.no_slot_r
		clr.l	(a6)
		clr.l	4(a6)
.no_slot_r:
		adda	d6,a6
		dbf	d7,.chk_spr_r
		lea	(RAM_SprMapList).w,a6
		moveq	#MAX_MDMAPSPR-1,d7
		moveq	#$10,d6
.chk_spr_mr:
		move.b	(a6),d5
		btst	#7,d5
		beq.s	.no_slot_mr
		btst	#6,d5
		beq.s	.no_slot_mr
		clr.l	(a6)
		clr.l	4(a6)
.no_slot_mr:
		adda	d6,a6
		dbf	d7,.chk_spr_mr
		rts

; --------------------------------------------------------
; d6 - Current link

vid_CheckLastSpr:
		lea	(RAM_Sprites).w,a6	; Check last sprite piece
		cmpi.w	#1,d6
		beq.s	.blnk_first
		cmpi.w	#80,d6
		bgt.s	.last_one
		move.w	d6,d7
		subi.w	#1,d7
		lsl.w	#3,d7
		adda	d7,a6
.blnk_first:
		clr.l	(a6)+
		clr.l	(a6)+
		bra.s	.spr_exit
.last_one:
		adda	#79*8,a6		; Go to last sprite
		move.w	2(a6),d7		; Set last link to 0
		andi.w	#$0F00,d7
		move.w	d7,2(a6)
.spr_exit:
		rts

; ====================================================================
; --------------------------------------------------------
; Subroutines
; --------------------------------------------------------

; --------------------------------------------------------
; Video_Clear
;
; Clears VDP VRAM and other RAM sections
;
; Breaks:
; ALL
; --------------------------------------------------------

Video_Clear:
	if MARS|MARSCD
		lea	(RAM_MdMars_CommBuff).w,a6		; ****
		move.w	#(Dreq_len/2)-1,d7
		moveq	#0,d6
.pmnext:
		move.w	d6,(a6)+
		dbf	d7,.pmnext
	endif
		moveq	#0,d6
		lea	(RAM_MdVideo).w,a6			; Clear half of Video RAM section
		move.w	#(RAM_MdVidClr_e-RAM_MdVideo)-1,d7
.clr_me:
		move.b	d6,(a6)+
		dbf	d7,.clr_me
		move.w	#0,d0
		move.w	#0,d1
		move.w	#cell_vram($7FE),d2
		bsr	Video_Fill

; --------------------------------------------------------
; Video_ClearScreen
;
; Clears ALL 3 map layers.
; --------------------------------------------------------

Video_ClearScreen:
		moveq	#0,d0
		move.w	(RAM_VdpVramFG).w,d1
		move.w	(RAM_VdpMapSize).w,d2	; FG/BG size
		bsr	Video_Fill
		move.w	(RAM_VdpVramBG).w,d1
		bsr	Video_Fill
		move.w	#$800,d2		; WD Size
		move.w	(RAM_VdpRegSetC).w,d7	; Current $8Cxx
		andi.w	#%10000001,d7		; Check if we are in H40
		beq.s	.not_small
		add.w	d2,d2			; Size $1000
.not_small:
		move.w	(RAM_VdpVramWD).w,d1
		bra	Video_Fill

; --------------------------------------------------------
; Video_DisplayOn, Video_DisplayOff
;
; Enable/Disable VDP Display
; --------------------------------------------------------

Video_DisplayOn:
		move.w	d7,-(sp)
		move.w	(RAM_VdpRegSet1).w,d7
		bset	#bitDispEnbl,d7
		bra.s	vid_WrtReg01
Video_DisplayOff:
		move.w	d7,-(sp)
		move.w	(RAM_VdpRegSet1).w,d7
		bclr	#bitDispEnbl,d7
		bra.s	vid_WrtReg01

; --------------------------------------------------------
; Video_DmaOn, Video_DmaOff
;
; Enable/Disable DMA
; --------------------------------------------------------

Video_DmaOn:
		move.w	d7,-(sp)
		move.w	(RAM_VdpRegSet1).w,d7
		bset	#bitDmaEnbl,d7
		bra.s	vid_WrtReg01
Video_DmaOff:
		move.w	d7,-(sp)
		move.w	(RAM_VdpRegSet1).w,d7
		bclr	#bitDmaEnbl,d7

; ------------------------------------------------

vid_WrtReg01:
		move.w	d7,(vdp_ctrl).l
		move.w	d7,(RAM_VdpRegSet1).w
		move.w	(sp)+,d7
		rts

; --------------------------------------------------------
; Video_IntEnable
;
; Enable or Disable VBlank, HBlank and External
; interrupts
;
; Input:
; d0.b | Enable these interrupts generated by VDP:
;      | %00000EHV
;      | E - External
;      | H - HBlank
;      | V - VBlank
;
; Notes:
; Set your interrupt locations with System_SetIntJumps
; --------------------------------------------------------

Video_IntEnable:
		movem.w	d6-d7,-(sp)
		move.w	(RAM_VdpRegSet1).w,d7
		move.w	d0,d6
		andi.w	#1,d6			; %--V
		lsl.w	#5,d6
		or.w	d6,d7
		move.w	d7,(RAM_VdpRegSet1).w
		move.w	d7,(vdp_ctrl).l
		move.w	(RAM_VdpRegSet0).w,d7
		move.w	d0,d6
		andi.w	#%10,d6			; %-H-
		lsl.w	#3,d6
		or.w	d6,d7
		move.w	d7,(RAM_VdpRegSet0).w
		move.w	d7,(vdp_ctrl).l
		move.w	(RAM_VdpRegSetB).w,d7
		move.w	d0,d6			; %E--
		andi.w	#%100,d6
		add.w	d6,d6
		or.w	d6,d7
		move.w	d7,(RAM_VdpRegSetB).w
		move.w	d7,(vdp_ctrl).l
		movem.w	(sp)+,d6-d7
		rts

; --------------------------------------------------------
; Video_Resolution
;
; Set video resolution
;
; Input:
; d0.w | $00 - Horizontal 256
;      | $01 - Horizontal 320
;
; d1.w | $00 - Vertical 224
;      | $01 - Vertical 240 (PAL ONLY)
;      | $02 - Double resolution mode
;      | $03 - INVALID
; --------------------------------------------------------

Video_Resolution:
		movem.w	d6-d7,-(sp)
		move.w	(RAM_VdpRegSet1).w,d7
		andi.b	#%11110111,d7
		move.w	d1,d6
		and.w	#1,d6
		lsl.w	#3,d6
		or.w	d6,d7
		move.w	d7,(vdp_ctrl).l
		move.w	d7,(RAM_VdpRegSet1).w
		move.w	(RAM_VdpRegSetC).w,d7
		andi.b	#%01111000,d7
		move.w	d0,d6
		and.w	#$01,d6
		beq.s	.ex_bit
		or.w	#$81,d6
.ex_bit:
		or.w	d6,d7
		move.w	d1,d6
		and.w	#%010,d6
		beq.s	.double
		or.w	#%100,d6
.double:
		or.w	d6,d7
		move.w	d7,(vdp_ctrl).l
		move.w	d7,(RAM_VdpRegSetC).w
		movem.w	(sp)+,d6-d7
		rts

; --------------------------------------------------------
; Video_UpdMapVram, Video_UpdSprHVram
;
; Update VRAM locations for FG, BG, Window and
; the Horizontal scroll
; --------------------------------------------------------

Video_UpdMapVram:
		movem.w	d6-d7,-(sp)
		move.w	#$8200,d7
		move.w	(RAM_VdpVramFG).w,d6
		lsr.w	#8,d6
		lsr.w	#2,d6
		andi.w	#%00111000,d6
		or.w	d6,d7
		move.w	d7,(vdp_ctrl).l
		move.w	#$8300,d7
		move.w	(RAM_VdpVramWD).w,d6
		lsr.w	#8,d6
		lsr.w	#2,d6
		andi.w	#%00111110,d6
		or.w	d6,d7
		move.w	d7,(vdp_ctrl).l
		move.w	#$8400,d7
		move.w	(RAM_VdpVramBG).w,d6
		lsr.w	#8,d6
		lsr.w	#5,d6
		andi.w	#%00000111,d6
		or.w	d6,d7
		move.w	d7,(vdp_ctrl).l
		movem.w	(sp)+,d6-d7
		rts

Video_UpdSprHVram:
		movem.l	d6-d7,-(sp)
		move.w	#$8500,d7
		move.w	(RAM_VdpVramSpr).w,d6
		lsr.w	#8,d6
		lsr.w	#1,d6
		andi.w	#%01111111,d6
		or.w	d6,d7
		move.w	d7,(vdp_ctrl).l
		move.w	#$8D00,d7
		move.w	(RAM_VdpVramHScrl).w,d6
		lsr.w	#8,d6
		lsr.w	#2,d6
		andi.w	#%00111111,d6
		or.w	d6,d7
		move.w	d7,(vdp_ctrl).l
		movem.l	(sp)+,d6-d7
		rts

; --------------------------------------------------------
; Video_SetMapSize
;
; Set MAP size(s) to FG and BG
;
; Input:
; d0.w | Width: %00 - H32
;      |        %01 - H40
;      |        %11 - H128
;
; d1.w | Height: %00 - V32
;      |         %01 - V40
;      |         %11 - V128
;
; Notes:
; Maximum size for a single layer size
; is $1000
; --------------------------------------------------------

Video_SetMapSize:
		movem.w	d5-d7,-(sp)
		move.w	#$9000,d7
		move.w	d0,d6
		move.w	d1,d5
		andi.w	#%11,d6
		andi.w	#%11,d5
		lsl.w	#4,d5
		or.w	d5,d6
		or.w	d6,d7
		move.w	d7,(vdp_ctrl).l
		movem.w	(sp)+,d5-d7
		rts

; --------------------------------------------------------
; Video_LoadArt
;
; Loads VDP graphics using DMA
;
; Input:
; d0.l | Graphics data (NOT a0)
; d1.w | VRAM location: cell_vram(vram_pos)
; d2.w | Size:          cell_vram(size)
;
; Notes:
; - For a faster load: call this during VBlank or
;   disable VDP Display temporally.
;
; * 32X Cartridge ONLY:
; - This sets RV bit, make sure your code is
;   running on RAM (already doing here) and the
;   SH2 is not reading from it's ROM area CS1
; --------------------------------------------------------

Video_LoadArt:
		movem.l	d4-d7/a6,-(sp)
		move.l	d0,d7
		andi.l	#$FF0000,d7
		cmp.l	#$FF0000,d7
		beq.s	.normal
		move.l	d0,d5
		add.w	d2,d5
		bcc.s	.normal
		move.l	d0,d5		; <-- DOUBLE TRANSFER
		move.w	d1,d6
		move.l	d5,d7		; Top
		addi.l	#$010000,d7
		andi.l	#$FF0000,d7
		sub.l	d0,d7
		bsr.s	.mk_set
		move.l	d0,d5		; Bottom
		addi.l	#$010000,d5
		andi.l	#$FF0000,d5
		move.l	d5,d6
		sub.l	d0,d6
		move.w	d2,d7
		sub.w	d6,d7
		add.w	d1,d6
		bra.s	.last_set
.normal:
		move.l	d0,d5
		move.w	d1,d6
		move.w	d2,d7
.last_set:
		bsr.s	.mk_set
		movem.l	(sp)+,d4-d7/a6
		rts

; d7 - size
; d6 - vram
; d5 - data
.mk_set:
  		andi.l	#$FFFFFF,d5
		andi.l	#$0000FFFE,d7
		beq.s	.bad_size
		swap	d6
		swap	d5
		move.w	d5,d6
		swap	d5
	if MCD|MARSCD
		andi.w	#$F0,d6
		cmpi.b	#$20,d6
		bne.s	.non_wram
		movem.l	d5-d6,-(sp)		; Copy data and vram to stack
		addi.l	#2,d5
.non_wram:
	endif
		lea	(vdp_ctrl).l,a6
		move.l	d7,-(sp)		; <--
		bsr	Video_DmaOn
		move.l	(sp)+,d7
		andi.w	#$FF,d6
		cmp.b	#$FF,d6
		beq.s	.ram_write
		swap	d6
		bsr.s	.shared_setup
		bsr	System_DmaEnter_ROM
		move.w	d6,(a6)			; First write
		move.w	d7,(a6)			; Second write
		bsr	System_DmaExit_ROM
		bsr	Video_DmaOff
	; Word-RAM patch
	if MCD|MARSCD
		movem.l	(sp)+,d5-d6		; --> Get data as d7
		cmpi.b	#$20,d6			; Word-RAM?
		bne.s	.non_wram_l
		swap	d6
		move.w	d6,d7			; Destination
		andi.l	#$3FFF,d6
		ori.w	#$4000,d6
		lsr.w	#8,d7
		lsr.w	#6,d7
		andi.w	#%11,d7
		move.w	d6,(a6)			; VDP destination
		move.w	d7,(a6)			;
		move.l	a6,d7
		move.l	d5,a6
		move.w	(a6),d6
		move.l	d7,a6
		move.w	d6,-4(a6)		; DATA port -4
.non_wram_l:
	endif
.bad_size:
		rts

; --------------------------------------------------------

.ram_write:
		swap	d6
		bsr.s	.shared_setup
		bsr	System_DmaEnter_RAM
		move.w	d6,(a6)			; First write
		move.w	d7,(a6)			; Second write
		bsr	System_DmaExit_RAM
		bra	Video_DmaOff

; --------------------------------------------------------

.shared_setup:
		lsl.l	#7,d7
		lsr.w	#8,d7
		ori.l	#$94009300,d7
		move.l	d7,(a6)
  		lsr.l	#1,d5			; d5 - Source
 		move.l	#$96009500,d7
 		move.b	d5,d7
 		lsr.l	#8,d5
 		swap	d7
 		move.b	d5,d7
 		move.l	d7,(a6)
 		move.w	#$9700,d7
 		lsr.l	#8,d5
 		move.b	d5,d7
 		move.w	d7,(a6)
		move.w	d6,d7			; Destination
		andi.l	#$3FFF,d6
		ori.w	#$4000,d6
		lsr.w	#8,d7
		lsr.w	#6,d7
		andi.w	#%11,d7
		ori.w	#$80,d7
		rts

; --------------------------------------------------------
; Video_LoadArt_List
;
; Loads VDP graphics on bulk
;
; Input:
; a0 | List of graphics to load:
;        dc.w numof_entries
;        dc.l ART_DATA
;        dc.w cell_vram(vram_pos)
;        dc.w ART_DATA_end-ART_DATA OR cell_vram(size)
;        ; ...more entries
;
; Note:
; CPU heavy.
; --------------------------------------------------------

Video_LoadArt_List:
		movem.l	d0-d2/d7,-(sp)
		move.w	(a0)+,d7
		beq.s	.invalid
		bmi.s	.invalid
		subq.w	#1,d7
.next_one:
		move.l	(a0)+,d0
		move.w	(a0)+,d1
		move.w	(a0)+,d2
		bsr	Video_LoadArt
		dbf	d7,.next_one
.invalid:
		movem.l	(sp)+,d0-d2/d7
		rts

; --------------------------------------------------------
; Video_Fill
;
; Fill data to VRAM
;
; Input:
; d0.b | BYTE to fill
; d1.w | VRAM destination: cell_vram(dest)
; d2.w | Size:             cell_vram(size)
;
; Notes:
; - FILL writes in this order: $56781234, Size $0001 is
;   invalid.
; --------------------------------------------------------

; Video_Fill_Incr:
; 		movem.l	d6-d7/a6,-(sp)
; 		move.w	d3,d6
; 		bra.s	vid_FillGo
Video_Fill:
		movem.l	d6-d7/a6,-(sp)
		move.w	#1,d6
vid_FillGo:
		lea	(vdp_ctrl).l,a6
.dmaw:		move.w	(a6),d7
		btst	#bitDma,d7
		bne.s	.dmaw
		bsr	Video_DmaOn
		andi.w	#$FF,d6
		or.w	#$8F00,d6
		move.w	d6,(a6)		; Set increment to $01
		move.w	d2,d7		; d2 - Size
		subi.w	#1,d7
		move.l	#$94009300,d6
		move.b	d7,d6
		swap	d6
		lsr.w	#8,d7
		move.b	d7,d6
		swap	d6
		move.l	d6,(a6)
		move.w	#$9780,(a6)	; DMA Fill mode
		move.w	d1,d7		; d1 - Destination
		move.w	d1,d6
		andi.w	#$3FFF,d6
		ori.w	#$4000,d6
		swap	d6
		move.w	d7,d6
		lsr.w	#8,d6
		lsr.w	#6,d6
		andi.w	#%11,d6
		ori.w	#$80,d6
		move.l	d6,(a6)
		move.w	d0,-4(a6)
.dma_w:		move.w	(a6),d7
		btst	#bitDma,d7
		bne.s	.dma_w
		move.w	#$8F02,(a6)
		bsr	Video_DmaOff
		movem.l	(sp)+,d6-d7/a6
		rts

; --------------------------------------------------------
; Video_Copy
;
; Copy VRAM data to another location inside VRAM
;
; Input:
; d0.w | VRAM Source: cell_vram(src)
; d1.w | VRAM Destination: cell_vram(dest)
; d2.w | Size
; --------------------------------------------------------

Video_Copy:
		movem.l	d6-d7/a6,-(sp)
		lea	(vdp_ctrl).l,a6
.dmaw:		move.w	(a6),d7
		btst	#bitDma,d7
		bne.s	.dmaw
		bsr	Video_DmaOn
		move.w	#$8F01,(a6)		; Increment $01
		move.w	d2,d7			; SIZE
		move.l	#$94009300,d6
		move.b	d7,d6
		swap	d6
		lsr.w	#8,d7
		move.b	d7,d6
		swap	d6
		move.l	d6,(a6)
		move.l	#$96009500,d6		; SOURCE
		move.w	d0,d7
		move.b	d7,d6
		swap	d6
		lsr.w	#8,d7
		move.b	d7,d6
		move.l	d6,(a6)
		move.w	#$97C0,(a6)		; DMA Copy mode
		move.l	d1,d7			; DESTINATION
		move.w	d7,d6
		andi.w	#$3FFF,d6
		ori.w	#$4000,d6
		swap	d6
		move.w	d7,d6
		lsr.w	#8,d6
		lsr.w	#6,d6
		andi.w	#%11,d6
		ori.w	#$C0,d6
		move.l	d6,(a6)
		move.w	d1,-4(a6)
.dma_w:		move.w	(a6),d7
		btst	#bitDma,d7
		bne.s	.dma_w
		move.w	#$8F02,(a6)		; Increment $02
		bsr	Video_DmaOff
		movem.l	(sp)+,d6-d7/a6
		rts

; --------------------------------------------------------
; Video_MakeDmaEntry
;
; Makes a new entry to the DMA BLAST list
; to be processed on the next VBlank
;
; Input:
; d0.l | Graphics data location
; d1.w | VRAM location: cell_vram(vram_pos)
; d2.w | Size
;
; Notes:
; - Call this during DISPLAY only
; - For loading graphics quickly use Video_LoadArt
;
; * SCD/CD32X ONLY:
; - The 4-pixel patch is ALWAYS applied even
;   if not reading from WORD-RAM
; --------------------------------------------------------

Video_MakeDmaEntry:
		movem.l	d5-d7/a6,-(sp)
		move.l	d0,d7
		andi.l	#$FF0000,d7
		cmp.l	#$FF0000,d7
		beq.s	.normal
		move.l	d0,d5
		add.w	d2,d5
		bcc.s	.normal
		move.l	d0,d5		; d5 - TOP point
		move.w	d1,d6		; d6 - VRAM position
		move.l	d5,d7
		andi.l	#$FF0000,d7
		addi.l	#$010000,d7
		sub.l	d0,d7		; d7 - TOP Size
		bsr.s	.mk_set
		move.l	d0,d5		; d5 - BOTTOM point
		addi.l	#$010000,d5
		andi.l	#$FF0000,d5
		move.l	d5,d6
		sub.l	d0,d6
		move.w	d2,d7
		sub.w	d6,d7
		add.w	d1,d6
		bra.s	.last_set
.normal:
		move.l	d0,d5
		move.w	d1,d6
		move.w	d2,d7
.last_set:
		bsr.s	.mk_set
		movem.l	(sp)+,d5-d7/a6
		rts

; d7 - size
; d6 - vram
; d5 - data
.mk_set:
  		andi.l	#$FFFFFF,d5
		swap	d7
		move.w	(RAM_VdpDmaIndx).w,d7
		cmpi.w	#MAX_MDDMATSK,d7
		bge	.ran_out
		lsl.w	#4,d7			; Size $10
		lea	(RAM_VdpDmaList).w,a6
		adda	d7,a6
		swap	d7
		andi.l	#$0000FFFE,d7		; d7 - Size
		beq.s	.ran_out		; If == 0, bad
		tst.w	d7
		bmi.s	.ran_out		; If negative, bad
		move.w	#1,(RAM_VdpDmaMod).w
		addq.w	#1,(RAM_VdpDmaIndx).w
		lsr.w	#1,d7
		movep.w	d7,1(a6)
	if MCD|MARSCD
  		move.l	d5,-(sp)		; Save TOP point
  		move.l	d5,d7
  		andi.l	#$F00000,d7
  		cmpi.l	#$200000,d7
  		bne.s	.not_wram
  		addq.l	#2,d5			; WORD-RAM patch
.not_wram:
	endif
  		lsr.l	#1,d5			; d5 - Source
  		move.l	d5,d7
  		swap	d7
 		movep.w	d5,5(a6)
 		move.b	d7,9(a6)
		move.w	d6,d7			; Destination
		andi.l	#$3FFF,d6
		ori.w	#$4000,d6
		lsr.w	#8,d7
		lsr.w	#6,d7
		andi.w	#%11,d7
		ori.w	#$80,d7
		move.w	d6,$A(a6)
		move.w	d7,$C(a6)
	if MCD|MARSCD
		move.l	a6,d7			; Save a6
		move.l	(sp)+,a6		; Restore TOP point
		move.w	(a6),d6			; Read the first 4 pixels to d6
		move.l	d7,a6			; Restore a6
		move.w	d6,$E(a6)		; Write pixels copy
	endif
		move.w	#0,(RAM_VdpDmaMod).w
.ran_out:
		rts

; ====================================================================
; --------------------------------------------------------
; Video_LoadMap, Video_LoadMapV
;
; Write map data to VDP
;
; _LoadMap:  Left to Right / Top to Bottom
; _LoadMapV: Top to Bottom / Left to Right
;
; Input:
; a0   | Map data
; d0.l | X/Y Position: splitw(x_pos,y_pos)
; d1.l | Width/Height: splitw(width/8,height/8)
; d2.l | Screen Width/VRAM location:
;        splitw(sw_size,vram_loc)
; d3.w | VRAM-cell increment
;
; Notes:
; - Data starts from 0, Map data $FFFF(-1) is
;   used to place the BLANK tile, see SET_NullVram.
; * SCD/CD32X ONLY:
; - For making the dot-screen map see
;   Video_MdMcd_StampDotMap
; --------------------------------------------------------

Video_LoadMap:
		movem.l	d4-d7/a4-a6,-(sp)
		lea	(vdp_data).l,a6

		move.l	d2,d6
		swap	d6
		move.w	d0,d5
		mulu.w	d6,d5
		move.l	d0,d4
		swap	d4
		add.w	d4,d4
		add.w	d4,d5
		move.w	d2,d7
		add.w	d5,d7
		moveq	#0,d5
		move.w	d7,d5
		andi.w	#$3FFF,d7
		or.w	#$4000,d7
		rol.w	#2,d5
		andi.w	#%11,d5
		swap	d5
		move.l	a0,a5
		move.w	d1,d4
		subq.w	#1,d4
		bmi.s	.bad_size
.y_loop:
		move.l	d4,a4
		swap	d5
		move.w	d7,4(a6)
		move.w	d5,4(a6)
		swap	d5
		move.l	d1,d4
		swap	d4
		subq.w	#1,d4
.x_loop:
		swap	d4
		move.w	(a5)+,d4
		cmp.w	#-1,d4
		bne.s	.non_blank
		move.w	#SET_NullVram,d4
		bra.s	.mk_cell
.non_blank:
		add.w	d3,d4
.mk_cell:
		move.w	d4,(a6)
		swap	d4
		dbf	d4,.x_loop
		add.w	d6,d7
		move.l	a4,d4
		dbf	d4,.y_loop
.bad_size:
		movem.l	(sp)+,d4-d7/a4-a6
		rts
; ------------------------------------------------
; d1.l | Width/Height: splitw(width/8,height/8)
; d2.l | Screen Width/VRAM location:
; d3.w | VRAM-cell increment

Video_LoadMapV:
		movem.l	d4-d7/a4-a6,-(sp)
		lea	(vdp_data).l,a6
		move.l	d2,d6
		swap	d6
		move.w	d0,d5
		mulu.w	d6,d5
		move.l	d0,d4
		swap	d4
		add.w	d4,d4
		add.w	d4,d5
		move.w	d2,d7
		add.w	d5,d7
		moveq	#0,d5
		move.w	d7,d5
		andi.w	#$3FFF,d7
		or.w	#$4000,d7
		rol.w	#2,d5
		andi.w	#%11,d5
		swap	d5
		move.l	a0,a5
		btst	#2,(RAM_VdpRegSetC+1).w
		bne.s	.dble_mode
		move.l	d1,d4
		swap	d4
		subq.w	#1,d4
		bmi.s	.bad_size
.x_loop:
		move.l	d4,a4
		move.w	d1,d4
		subq.w	#1,d4
.y_loop:
		swap	d4
		move.w	d7,d4
		add.w	d5,d4
		swap	d5
		move.w	d4,4(a6)
		move.w	d5,4(a6)
		swap	d5
		move.w	(a5)+,d4
		cmp.w	#-1,d4
		bne.s	.non_blank
		move.w	#SET_NullVram,d4
		bra.s	.mk_cell
.non_blank:
		add.w	d3,d4
.mk_cell:
		move.w	d4,(a6)
		add.w	d6,d5
		swap	d4
		dbf	d4,.y_loop
		add.w	#2,d7
		clr.w	d5
		move.l	a4,d4
		dbf	d4,.x_loop
.bad_size:
		movem.l	(sp)+,d4-d7/a4-a6
		rts

; ------------------------------------------------

.dble_mode:
		move.l	d1,-(sp)

		lsr.w	#1,d1			; <-- lazy patch
		move.w	d3,d4
		andi.w	#$F800,d4
		andi.w	#$7FF,d3
		lsr.w	#1,d3
		or.w	d4,d3

		move.l	d1,d4
		swap	d4
		subq.w	#1,d4
		bmi.s	.bad_size_d
.x_loop_d:
		move.l	d4,a4
		move.w	d1,d4
		subq.w	#1,d4
.y_loop_d:
		swap	d4
		move.w	d7,d4
		add.w	d5,d4
		swap	d5
		move.w	d4,4(a6)
		move.w	d5,4(a6)
		swap	d5
		move.w	(a5)+,d4
		adda	#2,a5
		cmp.w	#-1,d4
		bne.s	.non_blank_d
		move.w	#SET_NullVram/2,d4
		bra.s	.mk_cell_d
.non_blank_d:
		andi.w	#$7FF,d4
		lsr.w	#1,d4
		add.w	d3,d4
.mk_cell_d:
		move.w	d4,(a6)
		add.w	d6,d5
		swap	d4
		dbf	d4,.y_loop_d
		add.w	#2,d7
		clr.w	d5
		move.l	a4,d4
		dbf	d4,.x_loop_d
.bad_size_d:
		move.l	(sp)+,d1
		bra	.bad_size

; ====================================================================
; ----------------------------------------------------------------
; Palette fading section
; ----------------------------------------------------------------

; --------------------------------------------------------
; Video_RunFade
;
; Process Palette changes (fade and effects)
; --------------------------------------------------------

Video_RunFade:
		lea	(RAM_PalFadeList).w,a6
.next_req:
		move.b	palfd_req(a6),d0
		beq.s	.no_req
		subq.b	#1,palfd_timer(a6)
		bpl.s	.busy_timer
		move.b	palfd_delay(a6),palfd_timer(a6)
		lea	(RAM_Palette).w,a5
		lea	(RAM_PaletteFade).w,a4
		moveq	#0,d7
		move.b	palfd_start(a6),d7
		add.w	d7,d7
		adda	d7,a5
		adda	d7,a4
		moveq	#0,d6
		move.w	palfd_num(a6),d7
		beq.s	.busy_timer
		move.b	palfd_incr(a6),d6
		add.w	d6,d6		; * 2
		subq.w	#1,d7
		andi.w	#$FF,d0
		add.w	d0,d0
		move.w	.fade_list(pc,d0.w),d0
		jsr	.fade_list(pc,d0.w)
.busy_timer:
		adda	#palfd_len,a6
		bra.s	.next_req
.no_req:
		clr.w	(RAM_IndxPalFade).w
		rts

; ------------------------------------------------

.fade_list:
		dc.w .nothing-.fade_list	; $00
		dc.w .fade_out-.fade_list
		dc.w .fade_in-.fade_list
		dc.w .nothing-.fade_list
		dc.w .nothing-.fade_list	; $04
		dc.w .nothing-.fade_list
		dc.w .nothing-.fade_list
		dc.w .nothing-.fade_list

; ----------------------------------------------------
; Fade request $00: Null/exit.
; ----------------------------------------------------

.nothing:
.pfade_del:
		clr.b	palfd_req(a6)
		clr.b	palfd_timer(a6)
		rts

; ----------------------------------------------------
; Fade request $01: fade-out to black
; Quick.
;
; d7 - Num colors
; d6 - Increment*2
; ----------------------------------------------------

.fade_out:
		andi.w	#%0000000000001110,d6	; d6 - Max increment
		move.w	#%0000000000001110,d5	; d5 - Target filter
		move.w	#%1110111011100000,d4	; d4 - Others filter + extra
		moveq	#0,d3			; d3 - Exit counter
.next_color:
		move.w	(a5),d0
		beq.s	.all_black		; Skip if all black
	rept 3
		move.w	d0,d1
		and.w	d5,d1			; Filter TARGET
		beq.s	.no_chng
		and.w	d4,d0			; Filter OTHERS
		sub.w	d6,d1
		bpl.s	.blck_alrdy
		clr.w	d1
.blck_alrdy:
		addq.w	#1,d3			; Color changed
.no_chng:
		or.w	d1,d0
		rol.w	#4,d6			; next << color
		rol.w	#4,d5
		rol.w	#4,d4
	endm
	; we got $Exxx, rotate back to $xxxE:
		rol.w	#4,d6
		rol.w	#4,d5
		rol.w	#4,d4
		move.w	d0,(a5)
.all_black:
		adda	#2,a5
		dbf	d7,.next_color
		tst.w	d3
		beq	.pfade_del
.fdout_nend:
		rts

; ----------------------------------------------------
; Fade request $02
; Fade-in
; ----------------------------------------------------

.fade_in:
		andi.w	#%0000000000001110,d6	; d6 - Max increment
		move.w	#%0000000000001110,d5	; d5 - Target filter
		move.w	#$0EEE,d4		; d4 - Filter bits
.next_in:
		swap	d7
		move.w	(a5),d0			; d0 - Current
		move.w	(a4),d2			; d2 - Target
		and.w	d4,d0
		and.w	d4,d2
		cmp.w	d2,d0
		beq.s	.same_in
	rept 3
		move.w	d0,d1
		move.w	d4,d3
		eor.w	d5,d3
		and.w	d3,d0
		move.w	d2,d3
		and.w	d5,d1		; filter CURRENT color
		and.w	d5,d3		; filter TARGET color

		add.w	d6,d1		; ADD to current
		cmp.w	d3,d1
		bcs.s	.max_out
		move.w	d2,d1
		and.w	d5,d1
.max_out:
		addq.w	#1,d7
		or.w	d1,d0
		rol.w	#4,d6		; next << color
		rol.w	#4,d5
	endm
		rol.w	#4,d6
		rol.w	#4,d5
		move.w	d0,(a5)
.same_in:
		adda	#2,a5		; Next index
		adda	#2,a4
		swap	d7
		dbf	d7,.next_in
		swap	d7
		tst.w	d7
		beq	.pfade_del
.fdin_nend:
		rts

; --------------------------------------------------------
; Video_WaitFade
;
; CPU-saving version of System_Render when
; waiting for a fade-in/fade-out
;
; THIS IS REQUIRED FOR 32X as
; fading all 32X's 256 colors is too heavy for the 68000.
; --------------------------------------------------------

Video_WaitFade:
.loop:
		bsr	System_Render
		lea	(RAM_PalFadeList).w,a6
	if MARS|MARSCD
		lea	(RAM_MdMars_MPalFdList).w,a5
	endif
		move.w	#MAX_PALFDREQ-1,d7
		moveq	#0,d6
.next_one:
		or.b	palfd_req(a6),d6
		adda	#palfd_len,a6
	if MARS|MARSCD
		or.b	palfd_req(a5),d6
		adda	#palfd_len,a5
	endif
		dbf	d7,.next_one
		tst.b	d6
		bne.s	.loop
		rts

; --------------------------------------------------------
; Video_FadeIn_Full
;
; Overwrites first entry on each's PalFadeList
; --------------------------------------------------------

Video_FadeIn_Full:
	if MARS|MARSCD
		moveq	#2,d0
		move.l	#splitw(0,256),d1
		move.l	#splitw(0,2),d2
		bsr	Video_MdMars_MakeFade
	endif
		moveq	#2,d0
		move.l	#splitw(0,64),d1
		move.l	#splitw(0,1),d2
		bsr	Video_MakeFade
		bra	Video_WaitFade

; --------------------------------------------------------
; Video_FadeIn_Full
;
; Overwrites first entry on each's PalFadeList
; --------------------------------------------------------

Video_FadeOut_Full:
	if MARS|MARSCD
		moveq	#1,d0
		move.l	#splitw(0,256),d1
		move.l	#splitw(0,2),d2
		bsr	Video_MdMars_MakeFade
	endif
		moveq	#1,d0
		move.l	#splitw(0,64),d1
		move.l	#splitw(0,1),d2
		bsr	Video_MakeFade
		bra	Video_WaitFade

; ============================================================
; --------------------------------------------------------
; Subroutines
; --------------------------------------------------------

; --------------------------------------------------------
; Video_MakeFade, Video_MdMars_MakeFade
;
; Make palette Fading (or other) request, for
; both VDP and SVDP
;
; Input:
; d0.w | Task number:
;        0 - Fade-out
;        1 - Fade-in
; d1.l | Start at/Number of colors: splitw(start,num)
; d2.l | Delay/Increment: splitw(delay,incr)
; --------------------------------------------------------

Video_MdMars_MakeFade:
	if MARS|MARSCD
		movem.l	d6-d7/a6,-(sp)
		lea	(RAM_MdMars_MPalFdList).w,a6
		move.w	(RAM_MdMars_IndxPalFd).w,d7
		addq.w	#1,(RAM_MdMars_IndxPalFd).w
		bsr	vidMkFade_Go
		movem.l	(sp)+,d6-d7/a6
	endif
		rts
Video_MakeFade:
		movem.l	d6-d7/a6,-(sp)
		lea	(RAM_PalFadeList).w,a6
		move.w	(RAM_IndxPalFade).w,d7
		addq.w	#1,(RAM_IndxPalFade).w
		bsr	vidMkFade_Go
		movem.l	(sp)+,d6-d7/a6
		rts
vidMkFade_Go:
		andi.l	#$FF,d7
		lsl.w	#3,d7			; index * 8
		adda	d7,a6
		move.l	d1,d7
		move.l	d2,d6
		move.b	d0,palfd_req(a6)
		move.w	d7,palfd_num(a6)
		move.b	d6,palfd_incr(a6)
		swap	d6
		swap	d7
		move.b	d7,palfd_start(a6)
		move.b	d6,palfd_delay(a6)
		rts

; --------------------------------------------------------
; Video_LoadPal, Video_FadePal
;
; Load VDP palette data, either current or for fading.
;
; Input:
; a0   | Palette data
; d0.w | Starting color index
; d1.w | Number of colors
; --------------------------------------------------------

Video_FadePal:
		movem.l	d6-d7/a5-a6,-(sp)
		lea	(RAM_PaletteFade).w,a6
		bra.s	vidMd_Pal
; 		movem.l	(sp)+,d6-d7/a5-a6
; 		rts
Video_LoadPal:
		movem.l	d6-d7/a5-a6,-(sp)
		lea	(RAM_Palette).w,a6
; 		bsr.s	vidMd_Pal
; 		movem.l	(sp)+,d6-d7/a5-a6
; 		rts

; --------------------------------------------------------
vidMd_Pal:
		move.l	a0,a5
		moveq	#0,d7
		move.w	d0,d7
		add.w	d7,d7
		adda	d7,a6
		move.w	d1,d7
		subq.w	#1,d7
		bmi.s	.bad
		move.w	d2,d6
		andi.w	#1,d6
		ror.w	#1,d6
.loop:
		move.w	(a5)+,(a6)+
		dbf	d7,.loop
.bad:
		movem.l	(sp)+,d6-d7/a5-a6
		rts

; --------------------------------------------------------
; Video_LoadPal_List, Video_FadePal_List
;
; Loads palettes on bulk with a list
;
; Input:
; a0 | List of graphics to load:
;        dc.w numof_entries
;        dc.l palette_data
;        dc.w start_at
;        dc.w numof_colors
;        ; ...more entries
; --------------------------------------------------------

Video_LoadPal_List:
		movem.l	d7/a5,-(sp)
		move.l	a0,a5
		move.w	(a5)+,d7
		beq.s	.invalid
		bmi.s	.invalid
		subq.w	#1,d7
.next_one:
		move.l	(a5)+,a0
		move.w	(a5)+,d0
		move.w	(a5)+,d1
		bsr	Video_LoadPal
		dbf	d7,.next_one
.invalid:
		movem.l	(sp)+,d7/a5
		rts

Video_FadePal_List:
		movem.l	d7/a5,-(sp)
		move.l	a0,a5
		move.w	(a5)+,d7
		beq.s	.invalid
		bmi.s	.invalid
		subq.w	#1,d7
.next_one:
		move.l	(a5)+,a0
		move.w	(a5)+,d0
		move.w	(a5)+,d1
		bsr	Video_FadePal
		dbf	d7,.next_one
.invalid:
		movem.l	(sp)+,d7/a5
		rts

; ====================================================================
; ----------------------------------------------------------------
; Text PRINT system.
; ----------------------------------------------------------------

; --------------------------------------------------------
; Video_PrintInit, Video_PrintInitW
;
; Initializes the default Graphics and Palette
; for the font.
;
; Input:
; d0.l | Graphics data
;        $20 (" ") to $7F ("[DEL]")
; d1.w | VRAM output location to load and use
;        the ASCII text including attribute
;        settings (Palette and Priority)
;        Defualt values are:
;        DEF_PrintVram for 8x8 and
;        DEF_PrintVramW for 8x16
;
; Breaks:
; d0-d3
;
; Notes:
; - Only call this when the VDP DISPLAY is OFF
; - Write your palette manually after this
; --------------------------------------------------------

Video_PrintInitW:
		move.w	#($60*$20)*2,d2			; Graphics data from " " to "[DEL]"
		bra.s	vidPrint_Init
Video_PrintInit:
		move.w	#($60*$20),d2			; Graphics data from " " to "[DEL]"
vidPrint_Init:
		lsl.w	#5,d1				; VRAM location to real position
		bra	Video_LoadArt

; --------------------------------------------------------
; Video_PrintDefPal, Video_PrintDefPal_Fade
;
; Loads default palette for the font
; --------------------------------------------------------

Video_PrintDefPal_Fade:
		move.l	a6,-(sp)
		lea	(RAM_PaletteFade+$60).w,a6		; Palette line 4:
		bra.s	vid_FontDefPal
Video_PrintDefPal:
		move.l	a6,-(sp)
		lea	(RAM_Palette+$60).w,a6			; Palette line 4
vid_FontDefPal:
		move.w	#$0000,(a6)+				; black (background)
		move.w	#$0EEE,(a6)+				; white
		move.w	#$0888,(a6)+				; gray
		move.l	(sp)+,a6
		rts

; --------------------------------------------------------
; Video_Print, Video_PrintW
;
; Prints a text string, VDP side.
;
; Input:
; a0   | String data
; d0.w | X position
; d1.w | Y position
; d2.w | Font VRAM location
; d3.l | Screen width / Screen VRAM location:
;        splitw(width,vram_out)
;
; * Font VRAM location
; Default 8x8:  DEF_PrintVram
; Default 8x16: DEF_PrintVramW
;
; * Screen VRAM
; Foreground: DEF_VRAM_FG
; Background: DEF_VRAM_BG
; Window:     DEF_VRAM_WD
;
; * Screen Width
; $040 (DEF_HSIZE_32)
; $080 (DEF_HSIZE_64)
; $100 (DEF_HSIZE_128)
;
; Notes:
; - Initialize your graphics and VRAM location
;   with Video_PrintInit
; - Only Video_PrintW can be used in double-interlace
;   mode.
; --------------------------------------------------------

; dc.l pstr(type,ram_location)
;
; type:
; 0 - Byte
; 1 - Word
; 2 - 24-bit
; 3 - Long

Video_Print:
		movem.l	d4-d7/a4-a6,-(sp)
		lea	(vdp_data).l,a6
		move.w	d3,d7
		move.w	d0,d5
		add.w	d5,d5
		move.w	d1,d4
		swap	d3
		mulu.w	d3,d4
		add.w	d4,d5
		add.w	d5,d7
		move.w	d3,d6
		swap	d3
		moveq	#0,d5
		move.w	d7,d5
		andi.w	#$3FFF,d7
		or.w	#$4000,d7
		rol.w	#2,d5
		andi.w	#%11,d5
		swap	d5
		move.l	a0,a5
.loop:
		move.w	d6,d4
		subq.w	#1,d4
		and.w	d4,d5

		move.w	d7,d4
		add.w	d5,d4
		swap	d5
		move.w	d4,4(a6)
		move.w	d5,4(a6)
		swap	d5
.q_loop:
		move.b	(a5)+,d4
		beq.s	.exit
		bmi.s	.special
		cmpi.b	#$0A,d4
		beq.s	.next
; ------------------------------------------------
; Normal text
		andi.w	#$FF,d4
; 		add.w	(RAM_SetPrntVram).w,d4
		add.w	d2,d4
		subi.w	#$20,d4
		move.w	d4,(a6)
		addq.w	#2,d5
		bra.s	.q_loop
.next:
		clr.w	d5
		add.w	d6,d7			; Next line
		bra.s	.loop
.exit:
		movem.l	(sp)+,d4-d7/a4-a6
		rts
; ------------------------------------------------
; Show value
; d4 - $80|flags
.special:
		swap	d6
		move.b	d4,d6
		rol.l	#8,d4
		move.b	(a5)+,d4	; $00xx0000
		rol.l	#8,d4
		move.b	(a5)+,d4	; $0000xx00
		rol.l	#8,d4
		move.b	(a5)+,d4	; $000000xx
		move.l	d4,a4
		andi.w	#%11,d6
		swap	d7
		move.w	#1-1,d7
		cmp.b	#$03,d6
		beq.s	.show_long
		cmp.b	#$02,d6
		beq.s	.show_24
		cmp.b	#$01,d6
		beq.s	.show_word
.show_byte:
		move.b	(a4),d4
		swap	d4
		rol.l	#8,d4
		bra.s	.mk_value
.show_word:
		move.w	(a4),d4
		swap	d4
		addq.w	#1,d7
		bra.s	.mk_value
.show_24:
		move.l	(a4),d4
		rol.l	#8,d4
		addq.w	#2,d7
		bra.s	.mk_value
.show_long:
		move.l	(a4),d4
		addq.w	#3,d7
.mk_value:
		rol.l	#4,d4
		bsr.s	.show_nibbl
		rol.l	#4,d4
		bsr.s	.show_nibbl
		dbf	d7,.mk_value
		swap	d6
		swap	d7
		bra	.loop
.show_nibbl:
		move.l	d6,a4
		move.b	d4,d6
		andi.w	#$0F,d6
		cmpi.w	#$0A,d6
		bcs.s	.hex_incr
		addq.w	#7,d6
.hex_incr:	add.w	#"0",d6
; 		add.w	(RAM_SetPrntVram).w,d6
		add.w	d2,d6
		subi.w	#$20,d6
		move.w	d6,(a6)
		addq.w	#2,d5
		move.l	a4,d6
		rts

; --------------------------------------------------------
; 8x16 version
; --------------------------------------------------------

Video_PrintW:
		movem.l	d4-d7/a3-a6,-(sp)
		lea	(vdp_data).l,a6
; 		move.w	(RAM_SetPrntVramW).w,d6
		move.w	d2,d6
		subi.w	#$20*2,d6
		move.w	(RAM_VdpRegSetC).w,d5
		btst	#2,d5
		beq.s	.no_dble_y
		move.w	d6,d7
		andi.w	#$F800,d7
		andi.w	#$7FF,d6
		lsr.w	#1,d6
		or.w	d7,d6
.no_dble_y:
		swap	d6
		move.w	d3,d7
		move.w	d0,d5
		add.w	d5,d5
		move.w	d1,d4
		swap	d3
		mulu.w	d3,d4
		add.w	d4,d5
		add.w	d5,d7
		move.w	d3,d6
		swap	d3

		moveq	#0,d5
		move.w	d7,d5
		andi.w	#$3FFF,d7
		or.w	#$4000,d7
		rol.w	#2,d5
		andi.w	#%11,d5
		swap	d5
		move.l	a0,a5
	; d7 -      TEMP       | VDP write left
	; d6 -      TEMP       | Y next-line size
	; d5 - VDP write right | X current pos
	; d4 -                 | TEMP
.loop:
		move.w	d6,d4
		subq.w	#1,d4
		and.w	d4,d5
		move.b	(a5)+,d4
		beq.s	.exit
		bmi.s	.special
		cmpi.b	#$0A,d4
		beq.s	.next
; ------------------------------------------------
; Normal text
		andi.w	#$FF,d4
		swap	d7
		move.w	(RAM_VdpRegSetC).w,d7
		btst	#2,d7
		beq.s	.ver_normal
		swap	d6
		add.w	d6,d4
		swap	d6
		swap	d4
		swap	d7
		move.w	d7,d4
		add.w	d5,d4
		swap	d5
		move.w	d4,4(a6)
		move.w	d5,4(a6)
		swap	d4
		move.w	d4,(a6)
		bra.s	.ver_cont
.ver_normal:
		add.w	d4,d4
		swap	d6
		add.w	d6,d4
		swap	d6
		swap	d4
		swap	d7
		move.w	d7,d4
		add.w	d5,d4
		swap	d5
		move.w	d4,4(a6)
		move.w	d5,4(a6)
		swap	d4
		move.w	d4,(a6)
		addq.w	#1,d4
		swap	d4
		add.w	d6,d4
		move.w	d4,4(a6)
		move.w	d5,4(a6)
		swap	d4
		move.w	d4,(a6)
		swap	d4

.ver_cont:
		swap	d5
		addq.w	#2,d5		; Next VDP X pos
		bra.s	.loop
.next:
		clr.w	d5		; Clear X pos
		add.w	d6,d7		; Next Y line
		add.w	d6,d7		; twice
		bra	.loop
.exit:
		movem.l	(sp)+,d4-d7/a3-a6
		rts
; ------------------------------------------------
; Show value
; d4 - $80|flags
.special:
		move.l	d6,a3
		move.b	d4,d6
		rol.l	#8,d4
		move.b	(a5)+,d4	; $00xx0000
		rol.l	#8,d4
		move.b	(a5)+,d4	; $0000xx00
		rol.l	#8,d4
		move.b	(a5)+,d4	; $000000xx
		move.l	d4,a4
		andi.w	#%11,d6
		swap	d7
		move.w	#1-1,d7
		cmp.b	#$03,d6
		beq.s	.show_long
		cmp.b	#$02,d6
		beq.s	.show_24
		cmp.b	#$01,d6
		beq.s	.show_word
.show_byte:
		move.b	(a4),d4
		swap	d4
		rol.l	#8,d4
		bra.s	.mk_value_in
.show_word:
		move.w	(a4),d4
		swap	d4
		addq.w	#1,d7
		bra.s	.mk_value_in
.show_24:
		move.l	(a4),d4
		rol.l	#8,d4
		addq.w	#2,d7
		bra.s	.mk_value_in
.show_long:
		move.l	(a4),d4
		addq.w	#3,d7
.mk_value_in:
		move.l	a3,d6


	; d4 - value
		swap	d6
.mk_value:
		rol.l	#4,d4
		bsr.s	.show_nibbl
		rol.l	#4,d4
		bsr.s	.show_nibbl
		dbf	d7,.mk_value
		swap	d6
		swap	d7
		bra	.loop

	; d6 - Y next-line size | TEMP
.show_nibbl:
		move.l	d6,a4
		move.l	d4,a3
		move.w	(RAM_VdpRegSetC).w,d6
		btst	#2,d6
		beq.s	.nibbl_norm

	; TODO CHECAR ESTO
		bsr.s	.get_preval
		subi.w	#$20,d6
		swap	d7
; 		move.w	(RAM_SetPrntVramW).w,d4
		move.w	d2,d4
		andi.w	#$7FF,d4
		lsr.w	#1,d4
		add.w	d4,d6
; 		move.w	(RAM_SetPrntVramW).w,d4
		move.w	d2,d4
		andi.w	#$F800,d4
		or.w	d4,d6
		move.w	d7,d4
		swap	d7
		add.w	d5,d4
		swap	d5
		move.w	d4,4(a6)
		move.w	d5,4(a6)
		swap	d5
		move.w	d6,(a6)
		bra.s	.nibbl_cont

.nibbl_norm:
		bsr.s	.get_preval
		subi.w	#$20,d6
		add.w	d6,d6
		add.w	d2,d6
		swap	d7
		move.w	d7,d4
		swap	d7
		add.w	d5,d4
		swap	d5
		move.w	d4,4(a6)
		move.w	d5,4(a6)
		swap	d5
		move.w	d6,(a6)
		addq.w	#1,d6
		swap	d6
		add.w	d6,d4
		swap	d6
		swap	d5
		move.w	d4,4(a6)
		move.w	d5,4(a6)
		swap	d5
		move.w	d6,(a6)
.nibbl_cont:
		addq.w	#2,d5
		move.l	a4,d6
		move.l	a3,d4
		rts

.get_preval:
		move.b	d4,d6
		andi.w	#$0F,d6
		cmpi.w	#$0A,d6
		bcs.s	.hex_incr
		addq.w	#7,d6
.hex_incr:
		add.w	#"0",d6
		rts

; ------------------------------------------------
; Input:
; d2.w | Layer:
;        0 - Foreground
;        1 - Background
;        2 - WINDOW
;
; Returns:
; d7 - VRAM location
; d6 - Y jump size
; ------------------------------------------------

; vidSub_PickLayer:
; 		move.w	d2,d7
; 		lsl.w	#2,d7
; 		lea	(RAM_VdpRegs+$02).w,a5
; 		lea	.filter_data(pc),a4
; 		adda	d7,a4
; 		moveq	#0,d7
; 		moveq	#0,d5
; 		move.b	(a4),d7
; 		adda	d7,a5
; 		move.b	1(a4),d6
; 		move.b	2(a4),d5
; 		move.b	(a5),d7		; d7 - Reg
; 		and.b	d6,d7		; filter
; 		lsl.w	d5,d7		; shift left
; 		move.w	#$40,d6
; 		move.b	(RAM_VdpRegs+$10).w,d6
; 		andi.w	#%00000011,d6
; 		add.w	d6,d6
; 		move.w	.jump_sizes(pc,d6.w),d6
; 		rts
; .filter_data:
; 		dc.b $00		; Reg slot
; 		dc.b %00111000		; Filter bits
; 		dc.b 10,0		; shift left, 0
; 		dc.b $02
; 		dc.b %00000111
; 		dc.b 13,0
; 		dc.b $01
; 		dc.b %00111110
; 		dc.b 10,0
; .jump_sizes:	dc.w $040
; 		dc.w $080
; 		dc.w $080
; 		dc.w $100

; ====================================================================
; ----------------------------------------------------------------
; VDP Sprites
; ----------------------------------------------------------------

; --------------------------------------------------------
; Video_SetSpr, Video_MakeSpr
;
; Sets or Makes a VDP Sprite piece
;
; Input:
; a0   | Slot (0-80)
; d0.w | X pos
; d1.w | Y pos
; d2.w | VRAM
; d3.w | Size
;
; Returns:
; bcc | OK
; bcs | Ran out of slots (not sprites)
; --------------------------------------------------------

Video_SetSpr:
		movem.l	d6-d7/a6,-(sp)
		move.l	a0,d7
		moveq	#0,d6
		bra	vidMdSpr_MkSpr
Video_MakeSpr:
		movem.l	d6-d7/a6,-(sp)
		moveq	#0,d7
		lea	(RAM_SprPzList).w,a6
		moveq	#80-1,d6
.chk_free:
		btst	#7,(a6)
		beq.s	.mk_spr
		addq.w	#1,d7
		adda	#8,a6
		dbf	d6,.chk_free
		bra.s	vidMd_CError
.mk_spr:
		moveq	#$40,d6
vidMdSpr_MkSpr:
		andi.l	#$FF,d7
		cmp.w	#80,d7
		bge.s	vidMd_CError
		lsl.w	#3,d7
		addi.l	#RAM_SprPzList,d7
		move.l	d7,a6
		swap	d6
		move.w	d1,d7			; Y pos
		addi.w	#$80,d7			; +$80
		btst	#2,(RAM_VdpRegSetC+1).w
		beq.s	.dont_add
		addi.w	#$80,d7
.dont_add:
		andi.w	#$3FF,d7
		move.w	d3,d6
		andi.w	#%1111,d6
		lsl.w	#8,d6
		lsl.w	#2,d6
		or.w	d6,d7			; %00ssssyyyyyyyyyy
		swap	d6
		lsl.w	#8,d6
		or.w	#$8000,d7
		or.w	d6,d7
		move.w	d7,(a6)+
		move.w	d0,d7
		addi.w	#$80,d7
		move.w	d7,(a6)+
		move.w	d2,(a6)+
		movem.l	(sp)+,d6-d7/a6
		and	#%11110,ccr		; Return OK
		rts
; Carry error
vidMd_CError:
		movem.l	(sp)+,d6-d7/a6
		or	#1,ccr			; Return Error
vidMd_CFreeze:
		rts

; --------------------------------------------------------
; Video_SetSprMap, Video_MakeSprMap
; Video_SetSprMap_DMA, Video_MakeSprMap_DMA
;
; Sets or Makes a VDP Sprite with map data
;
; Input:
; a0   | Slot (0-80)
; a1   | Map data
; a2   | PLC data (_DMA/_DMA_Auto ONLY)
; a3   | Graphics data (_DMA/_DMA_Auto ONLY)
; d0.w | X position
; d1.w | Y position
; d2.w | VRAM output location
;        For _DMA_Auto: VRAM's attribute bits,
;        cell vram is ignored.
; d3.w | Frame number
;
; Returns:
; bcc | OK
; bcs | Ran out of slots (not sprites)
; --------------------------------------------------------

Video_SetSprMap_DMA:
		movem.l	d0-d3/a0-a2,-(sp)
		bsr	Video_SetSprMap
		bcs.s	vid_MkDmaCarry
		bra	vid_MkDmaNext
Video_SetSprMap:
		movem.l	d6-d7/a6,-(sp)
		move.l	a0,d7
		moveq	#0,d6
		bra	vidMdSpr_MkSprMap
Video_MakeSprMap_DMA:
		movem.l	d0-d3/a0-a2,-(sp)
		bsr	Video_MakeSprMap
		bcs.s	vid_MkDmaCarry
vid_MkDmaNext:
		move.l	a2,a0			; Redirect these regs
		move.l	a3,a1
		move.w	d3,d0
		move.w	d2,d1
		bsr	vid_MkMapDma
vid_MkDmaCarry:
		movem.l	(sp)+,d0-d3/a0-a2
		rts

Video_MakeSprMap:
		movem.l	d6-d7/a6,-(sp)
		moveq	#0,d7
		lea	(RAM_SprMapList).w,a6
		moveq	#MAX_MDMAPSPR-1,d6
.chk_free:
		tst.b	(a6)
		beq.s	.mk_spr
		addq.w	#1,d7
		adda	#$10,a6
		dbf	d6,.chk_free
		bra	vidMd_CError
.mk_spr:
		moveq	#$40,d6
vidMdSpr_MkSprMap:
		andi.l	#$FF,d7
		cmp.w	#MAX_MDMAPSPR,d7
		bge	vidMd_CError
		lsl.l	#4,d7
		addi.l	#RAM_SprMapList,d7
		move.l	d7,a6
		move.l	a1,d7
		or.w	#$80,d6
		swap	d6
		lsl.l	#8,d6
		and.l	#$FFFFFF,d7
		or.l	d6,d7
		move.l	d7,(a6)+		; $00 - Map data
		move.w	d3,(a6)+		; $04 - Frame
		move.w	d2,(a6)+		; $06 - VRAM
		move.w	d0,(a6)+		; $08 - X pos
		move.w	d1,(a6)+		; $0A - Y pos
		movem.l	(sp)+,d6-d7/a6
		and	#%11110,ccr		; Return OK
		rts

; --------------------------------------------------------
; Input:
; a0   | DMA map data
; a1   | Graphics data
; d0.w | Current frame in DMA list
; d1.w | VRAM position
;
; USES:
; a6
vid_MkMapDma:
		movem.l	d4-d7/a6,-(sp)		; SAVE a6
		moveq	#0,d4
		andi.w	#$FF,d0
 		add.w	d0,d0
		move.w	(a0,d0.w),d4
 		adda	d4,a0
 		move.w	(a0)+,d4
 		beq.s	.no_dma			; If no valid entries, exit.
 		bmi.s	.no_dma
 		subq.w	#1,d4
		andi.w	#$07FF,d1
		lsl.w	#5,d1
.next_pz:
		swap	d4
		move.w	(a0)+,d4
		move.w	d4,d2
		lsr.w	#7,d2
		andi.w	#$1E0,d2
		add.w	#$20,d2
		moveq	#0,d0
		move.w	d4,d0
		andi.w	#$FFF,d0
		lsl.w	#5,d0
		add.l	a1,d0
		bsr	Video_MakeDmaEntry
		add.w	d2,d1
		swap	d4
		dbf	d4,.next_pz
		lsr.w	#5,d1			; Get d1 back
.no_dma:
		movem.l	(sp)+,d4-d7/a6		; Restore a6
		rts

; ====================================================================
; ----------------------------------------------------------------
; Video routines for SEGA CD
; ----------------------------------------------------------------

	if MCD|MARSCD

; --------------------------------------------------------
; EXAMPLE CODE to use stamps
;
; Single-buffer:
; 		move.l	#splitw(128,128),d0				; Dot-screen Width/Height 128x128
; 		move.w	#vramLoc_Backgrnd,d1				; VRAM location
; 		moveq	#0,d2						; Single buffer mode
; 		move.w	#DEF_MaxStampCOut,d3				; Size of temporal cells
; 		lea	(SC2_OutCells),a0				; Location for the temporal cells
; 		bsr	Video_MdMcd_StampEnable
; 		move.l	#splitw($0000,$0002),d0				; Map position 0,2
; 		move.l	#splitw(128/8,128/8),d1				; Size 128x128 in cells
; 		move.l	#splitw(DEF_HSIZE_64,DEF_VRAM_BG),d2		; Map scroll width / Foreground
; 		move.w	(RAM_MdMcd_StampSett+mdstmp_vramMain).w,d3	; Get Auto-VRAM set by _StampEnable
; 		bsr	Video_MdMcd_StampDotMap

; Double-buffer:
; V32 H64
; 		move.l	#splitw(128,128),d0				; Dot-screen Width/Height 128x128
; 		move.w	#vramLoc_Backgrnd,d1				; VRAM location
; 		moveq	#1,d2						; Double buffer mode
; 		move.w	#DEF_MaxStampCOut,d3				; Size of temporal cells
; 		lea	(SC2_OutCells),a0				; Location for the temporal cells
; 		bsr	Video_MdMcd_StampEnable
; 		move.l	#splitw($0000,$0002),d0				; Map position 0,2
; 		move.l	#splitw(128/8,128/8),d1				; Size 128x128 in cells
; 		move.l	#splitw(DEF_HSIZE_64,DEF_VRAM_BG),d2		; Map scroll width / Foreground
; 		move.w	(RAM_MdMcd_StampSett+mdstmp_vramMain).w,d3	; Get Auto-VRAM set by _StampEnable
; 		bsr	Video_MdMcd_StampDotMap
; 		move.l	#splitw($0000+$20,$0002),d0			; X+$20
; 		move.w	(RAM_MdMcd_StampSett+mdstmp_vramSec).w,d3	; Get Second Auto-VRAM set by _StampEnable
; 		bsr	Video_MdMcd_StampDotMap

; --------------------------------------------------------
; Video_MdMcd_StampInit
;
; Make the first Stamp screens, Call this BEFORE entering
; your main loop.
; ** VDP DISPLAY MUST BE ENABLED **
;
; Breaks:
; ALL
; --------------------------------------------------------

Video_MdMcd_StampInit:
	if MCD|MARSCD
		lea	(RAM_MdMcd_StampSett).w,a6
		btst	#7,mdstmp_flags(a6)
		beq.s	.exit_now
		clr.w	mdstmp_currOutFlip(a6)
		bsr	System_MdMcd_WaitWRAM
		bsr	vidMdMcd_SendStampInfo
		bsr	System_MdMcd_GiveWRAM
		bsr	.mk_initbuff
		bsr	.mk_initbuff
		bsr	.mk_initbuff
.mk_initbuff:
		bsr	System_Render
		bsr	Video_MdMcd_StampRender
.wait_finish:
		bsr	System_Render
		bsr	Video_MdMcd_StampRender
		tst.w	(RAM_MdMcd_StampSett+mdstmp_vramLen).w
		bne.s	.wait_finish
.exit_now:
	endif
		bra	Sound_Update

; --------------------------------------------------------
; Video_MdMcd_StampRender
;
; Update new Stamp output, drops frames if not ready.
; ** Call this during VBlank ONLY.
;
; Returns:
; bcc | No changes
; bcs | Output buffer changed (DOUBLE-buffer ONLY)
;
; Breaks:
; ALL
; --------------------------------------------------------

Video_MdMcd_StampRender:
	if MCD|MARSCD
		lea	(RAM_MdMcd_StampSett).w,a6
		btst	#7,mdstmp_flags(a6)
		beq	.not_yet
		tst.w	mdstmp_vramLen(a6)
		bne	.draw_cells
; 		bsr	System_MdMcd_WaitWRAM
; 		move.b	(sysmcd_reg+mcd_comm_s).l,d7
; 		btst	#3,d7
; 		bne.s	.not_yet
		bsr	System_MdMcd_CheckWRAM
		bne	.not_yet
		bsr	System_MdMcd_SubWait
		move.w	mdstmp_currOutFlip(a6),d7
		andi.w	#%01,d7
		move.w	d7,(sysmcd_wram+WRAM_StampCurrFlip).l
		move.w	#0,(sysmcd_wram+WRAM_StampsDone).l
		eor.w	#1,mdstmp_currOutFlip(a6)
		bchg	#6,mdstmp_flags(a6)		; Change buffer
		bsr	Sound_Update
		clr.l	mdstmp_buffIncr(a6)
		clr.w	mdstmp_vramIncr(a6)
		move.w	mdstmp_vramSize(a6),mdstmp_vramLen(a6)
		bsr	vidMdMcd_SendStampInfo
		bsr	.make_cellbuff
		bra	.first_step

; --------------------------------------------------------
; Next cell slice
; --------------------------------------------------------

.draw_cells:
		bsr	System_MdMcd_Interrupt
.wait_wram:
		bsr	Sound_Update
		bsr	System_MdMcd_CheckWRAM
		bne	.wait_wram
		bsr	.make_cellbuff
.first_step:
		bsr	System_MdMcd_GiveWRAM
		bsr	.mkdma_buff
		tst.w	mdstmp_vramLen(a6)
		bne.s	.not_yet
		bchg	#6,mdstmp_flags(a6)		; Change buffer
		bsr	Sound_Update
		btst	#0,mdstmp_flags(a6)
		beq.s	.not_yet
		bsr	Sound_Update
		or	#1,ccr
		rts
.not_yet:
		bsr	Sound_Update
		and	#%11110,ccr
		rts

; --------------------------------------------------------

.mkdma_buff:
		move.l	mdstmp_cellstorage(a6),d0
		moveq	#0,d1
		move.w	mdstmp_vramMain(a6),d1
		btst	#0,mdstmp_flags(a6)
		beq.s	.first_one
		btst	#6,mdstmp_flags(a6)
		beq.s	.first_one
		move.w	mdstmp_vramSec(a6),d1
.first_one:
		add.w	mdstmp_vramIncr(a6),d1
		move.w	mdstmp_vramLen(a6),d3
		move.w	mdstmp_stmpoutb(a6),d2
		cmp.w	mdstmp_vramSize(a6),d2
		beq.s	.exact_size
		cmp.w	d2,d3
		bgt.s	.maximum
.exact_size:
		move.w	d3,d2
		clr.w	mdstmp_vramLen(a6)
		bra.s	.not_done
.maximum:
		move.w	d2,d3
		addi.w	d3,mdstmp_vramIncr(a6)
		subi.w	d3,mdstmp_vramLen(a6)
		tst.w	mdstmp_vramLen(a6)	; Failsafe
		bpl.s	.not_done
		clr.w	mdstmp_vramLen(a6)
.not_done:
		lsl.l	#5,d1
		lsl.l	#5,d2
		bsr	Video_MakeDmaEntry
	endif
		bra	Sound_Update

; --------------------------------------------------------
; Get a slice of the dot-screen
; --------------------------------------------------------

.out_locs:
		dc.l sysmcd_wram+WRAM_DotOutput_0
		dc.l sysmcd_wram+WRAM_DotOutput_1
.make_cellbuff:
		bsr	Sound_Update
		moveq	#0,d7
		move.w	mdstmp_currOutFlip(a6),d7
		andi.w	#%01,d7
		lsl.l	#2,d7
		move.l	.out_locs(pc,d7.w),d7
		add.l	mdstmp_buffIncr(a6),d7
		move.l	d7,a5
		moveq	#0,d7
		move.w	mdstmp_stmpoutb(a6),d7
		move.l	d7,d6
		lsl.l	#5,d6
		add.l	d6,mdstmp_buffIncr(a6)
		movea.l	mdstmp_cellstorage(a6),a4
		move.w	d7,d6
		lsr.w	#4,d6
		subq.w	#1,d6
.copy_mid:
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,(a4)
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,$20(a4)
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,$40(a4)
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,$60(a4)
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,$80(a4)
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,$A0(a4)
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,$C0(a4)
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,$E0(a4)
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,$100(a4)
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,$120(a4)
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,$140(a4)
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,$160(a4)
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,$180(a4)
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,$1A0(a4)
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,$1C0(a4)
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,$1E0(a4)
		lea	$200(a4),a4
		dbf	d6,.copy_mid
		bsr	Sound_Update
		andi.w	#%1111,d7
		beq.s	.no_lsb
		subq.w	#1,d7
.copy_lsb:
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,(a4)
		lea	$20(a4),a4
		dbf	d7,.copy_lsb
.no_lsb:
		bra	Sound_Update

; --------------------------------------------------------

vidMdMcd_SendStampInfo:
		lea	(RAM_MdMcd_Stamps).w,a5
		lea	(sysmcd_wram+WRAM_MdStampList).l,a4
		move.w	#MAX_MCDSTAMPS-1,d7
.copy_towram:
		movem.l	(a5)+,d0-d3/a0-a3
		movem.l	d0-d3/a0-a3,(a4)
		adda	#$20,a4
		dbf	d7,.copy_towram
		lea	(RAM_MdMcd_Stamps).w,a5
		moveq	#MAX_MCDSTAMPS-1,d7
		move.w	#cdstamp_len,d6
.chk_spr:
		btst	#6,cdstamp_flags(a5)
		beq.s	.not_sprtemp
		clr.b	cdstamp_flags(a5)
.not_sprtemp:
		adda	d6,a5
		dbf	d7,.chk_spr
		bra	Sound_Update

; --------------------------------------------------------
; Video_MdMcd_StampEnable
;
; Init/Enable SCD Stamp rendering
;
; Input:
; a0   | RAM location to store cells
; d0.l | Dot-Screen Width and Height: splitw(width,height)
; d1.w | VRAM Main output
; d2.w | Use double-buffering: No(0) or Yes(1)
; d3.w | Size of out cells storage
;        Default tag: DEF_MaxStampCOut
;
; Notes:
; - Use only Width and Height aligned by 8
; - Width and Height will also be used to get the
;   the CENTER point in ALL Stamps.
; --------------------------------------------------------

Video_MdMcd_StampEnable:
		movem.l	d0/d6-d7/a5-a6,-(sp)
		lea	(RAM_MdMcd_StampSett).w,a6
		move.l	a6,a5
		move.w	#mdstmp_len-1,d7
		moveq	#0,d6
.clr_sett:
		move.w	d6,(a5)+
		dbf	d7,.clr_sett
		move.w	d3,mdstmp_stmpoutb(a6)
		move.l	a0,mdstmp_cellstorage(a6)
		move.w	d1,mdstmp_vramMain(a6)
		moveq	#0,d7
		move.l	d0,d6
		swap	d6
		move.w	d0,d7
		mulu.w	d6,d7
		lsr.l	#5+1,d7
		move.w	d7,mdstmp_vramSize(a6)
		bclr	#0,mdstmp_flags(a6)
		tst.w	d2
		beq.s	.dont_use
		move.w	mdstmp_vramMain(a6),d6
		add.w	d7,d6
		move.w	d6,mdstmp_vramSec(a6)
		bset	#0,mdstmp_flags(a6)
.dont_use:
		bset	#7,mdstmp_flags(a6)
		move.l	d0,d7
		swap	d7
		move.w	d7,(sysmcd_reg+mcd_dcomm_m).l
		move.w	d0,(sysmcd_reg+mcd_dcomm_m+2).l
		bsr	System_MdMcd_GiveWRAM
		move.w	#$18,d0
		bsr	System_MdMcd_SubTask
		bsr	System_MdMcd_WaitWRAM
		movem.l	(sp)+,d0/d6-d7/a5-a6
		rts

; --------------------------------------------------------
; Video_MdMcd_StampDisable
;
; Disable SCD Stamp rendering
; --------------------------------------------------------

Video_MdMcd_StampDisable:
		movem.l	d0/a6,-(sp)
		lea	(RAM_MdMcd_StampSett).w,a6
		bclr	#7,mdstmp_flags(a6)
		clr.w	mdstmp_vramLen(a6)
		bsr	System_MdMcd_GiveWRAM
		moveq	#$19,d0
		bsr	System_MdMcd_SubTask
		movem.l	(sp)+,d0/a6
		rts

; --------------------------------------------------------
; Video_MdMcd_StampDotMap
;
; Show the stamp screen
;
; Input:
; d0.l | X/Y Position: splitw(x_pos,y_pos)
; d1.l | Width/Height: splitw(width/8,height/8)
; d2.l | Screen Width/VRAM location:
;        splitw(sw_size,vram_loc)
; d3.w | VRAM start
; --------------------------------------------------------

Video_MdMcd_StampDotMap:
		movem.l	d3-d7/a4-a6,-(sp)
		lea	(vdp_data).l,a6
		move.w	d2,d7
		move.l	d2,d6
		swap	d6
		move.w	d0,d5
		mulu.w	d6,d5
		move.l	d0,d4
		swap	d4
		add.w	d4,d4
		add.w	d4,d5
		add.w	d5,d7
		moveq	#0,d5
		move.w	d7,d5
		andi.w	#$3FFF,d7
		or.w	#$4000,d7
		rol.w	#2,d5
		andi.w	#%11,d5
		swap	d5
		move.l	a0,a5
		move.l	d1,d4
		swap	d4
		subq.w	#1,d4
		bmi.s	.bad_size
.x_loop:
		move.l	d4,a4
		move.w	d1,d4
		subq.w	#1,d4
.y_loop:
		swap	d4
		move.w	d7,d4
		add.w	d5,d4
		swap	d5
		move.w	d4,4(a6)
		move.w	d5,4(a6)
		swap	d5
		move.w	d3,(a6)
		addq.w	#1,d3
		add.w	d6,d5
		swap	d4
		dbf	d4,.y_loop
		add.w	#2,d7
		clr.w	d5
		move.l	a4,d4
		dbf	d4,.x_loop
.bad_size:
		movem.l	(sp)+,d3-d7/a4-a6
		rts

; --------------------------------------------------------
; Video_MdMcd_StampSet
;
; Set or Make a Sega CD Stamp
;
; Input:
; a0   | Index slot (_SetStamp ONLY)
; a1   | Map slot to use
; d0.l | X/Y position:       splitw(x_pos,y_pos)
; d1.l | Rotation and Scale: splitw(rot,scale)
; d2.l | Width/Height:       split(width,height)
; d3.l | Center X/Y:         splitw(cx,cy)
;
; Returns:
; bcc | Wrote sucessfully
; bcs | Ran out of stamps
;
; Notes:
; - This resets the X/Y/Z position and rotations
; --------------------------------------------------------

Video_MdMcd_SetStamp:
		movem.l	d6-d7/a6,-(sp)
		lea	(RAM_MdMcd_Stamps).w,a6
		move.l	a0,d7
		moveq	#0,d6			; Disposable bit
		bra	vidMdMcd_MkStamp

Video_MdMcd_MakeStamp:
		movem.l	d6-d7/a6,-(sp)
		moveq	#0,d7
		lea	(RAM_MdMcd_Stamps).w,a6
		moveq	#MAX_MCDSTAMPS-1,d6
.chk_free:
		tst.b	cdstamp_flags(a6)
		beq.s	.mk_spr
		addq.w	#1,d7
		adda	#cdstamp_len,a6
		dbf	d6,.chk_free
		bra.s	vidMdMcd_CError
.mk_spr:
		moveq	#$40,d6			; Disposable bit

vidMdMcd_MkStamp:
		andi.w	#$FF,d7
		cmpi.w	#MAX_MCDSTAMPS,d7
		bge.s	vidMdMcd_CError
		lsl.w	#5,d7
		adda	d7,a6
		move.w	a1,d7
		andi.w	#$FF,d7
		move.b	d7,cdstamp_map(a6)
		move.l	d0,d7
		swap	d7
		move.w  d0,cdstamp_y(a6)
		move.w  d7,cdstamp_x(a6)
		move.l	d2,d7
		swap	d7
		move.w  d2,cdstamp_hght(a6)
		move.w  d7,cdstamp_wdth(a6)
		move.l	d3,d7
		swap	d7
		move.w  d3,cdstamp_cy(a6)
		move.w  d7,cdstamp_cx(a6)

		move.l	d1,d7
		swap	d7
		move.w	d1,cdstamp_scale(a6)
		move.w	d7,cdstamp_rot(a6)

		move.w	#$80,d7
		or.w	d6,d7
		move.b	d7,cdstamp_flags(a6)	; TODO: add the RPT bit ($01)
		movem.l	(sp)+,d6-d7/a6
		andi	#%11110,ccr
		rts
; Carry error
vidMdMcd_CError:
		movem.l	(sp)+,d6-d7/a6
		or	#1,ccr			; Return Error
		rts

; --------------------------------------------------------

vidMdMcd_RdStmpSlot:
		lea	(RAM_MdMcd_Stamps).w,a6
		moveq	#0,d7
		move.w	d0,d7
; 		cmpi.w	#MAX_MCDSTAMPS,d0
; 		bge.s	.got_full
		lsl.w	#5,d7			; FIXED SIZE $20
		adda	d7,a6
; .got_full:
		rts

; --------------------------------------------------------
; Video_MdMcd_StampMap
; --------------------------------------------------------

Video_MdMcd_StampMap:
		rts

; ====================================================================

	endif	; End SCD section

; ====================================================================
; ----------------------------------------------------------------
; Video routines for 32X
; ----------------------------------------------------------------

	if MARS|MARSCD

; --------------------------------------------------------
; Video_MdMars_SetSync
;
; Set a bit to wait for DREQ-RAM swap
; --------------------------------------------------------

Video_MdMars_SetSync:
		bset	#4,(sysmars_reg+comm12+1).l
		rts

; --------------------------------------------------------
; Video_MdMars_WaitSync
;
; Wait if the DREQ-RAM buffer is ready to be
; rewritten.
; --------------------------------------------------------

Video_MdMars_WaitSync:
		btst	#4,(sysmars_reg+comm12+1).l
		bne.s	Video_MdMars_WaitSync
		rts

; --------------------------------------------------------
; Video_MdMars_WaitFrame
; --------------------------------------------------------

Video_MdMars_WaitFrame:
		bsr	Video_MdMars_WaitSync
		bra	Video_MdMars_SetSync

; --------------------------------------------------------
; Video_MdMars_Cleanup
;
; Manual cleanup after sending current data to 32X
; --------------------------------------------------------

Video_MdMars_Cleanup:
	if MARS|MARSCD
		move.w	(sysmars_reg+comm12).l,d7	; Check current 32X video mode
		andi.w	#%00000111,d7
		add.w	d7,d7
		move.w	.cleanlist(pc,d7.w),d7
		jmp	.cleanlist(pc,d7.w)
; --------------------------------------------------------
.cleanlist:
		dc.w .none-.cleanlist
		dc.w .mode_2D-.cleanlist
		dc.w .mode_3D-.cleanlist
		dc.w .none-.cleanlist
		dc.w .none-.cleanlist
		dc.w .none-.cleanlist
		dc.w .none-.cleanlist
		dc.w .none-.cleanlist
; --------------------------------------------------------
.none:
		rts
; --------------------------------------------------------
.mode_2D:
		lea	(RAM_MdMars_ScrlData).w,a6	; Clear the redraw bit here
		move.w	#((512/16)*(256/16))-1,d7
.check_bit:
		move.w	(a6),d6
		bpl.s	.no_redraw
		andi.w	#$7FFF,d6
		move.w	d6,(a6)
.no_redraw:
		adda	#2,a6
		dbf	d7,.check_bit
		lea	(RAM_MdMars_SuperSpr).w,a6
		moveq	#MAX_MARSSPR-1,d7
		move.w	#sspr_len,d6
.chk_spr:
		btst	#6,sspr_flags(a6)
		beq.s	.not_sprtemp
		clr.b	sspr_flags(a6)
.not_sprtemp:
		adda	d6,a6
		dbf	d7,.chk_spr
.no_freeze:
		rts

; --------------------------------------------------------

.mode_3D:
		lea	(RAM_MdMars_MSprites).w,a6
		moveq	#MAX_MARSMSPR-1,d7
		move.w	#mspr_len,d6
.chk_temp:
		btst	#6,mspr_flags(a6)
		beq.s	.not_temp
		clr.b	mspr_flags(a6)
.not_temp:
		adda	d6,a6
		dbf	d7,.chk_temp
.no_mfreeze:
	endif
		rts

; --------------------------------------------------------
; Video_MdMars_PalBackup
;
; Backup routine to load 256-color palette to SVDP
; when the SVDP permission is set to Genesis.
;
; Call this during VBlank ONLY.
; --------------------------------------------------------

Video_MdMars_PalBackup:
	if MARS|MARSCD
		move.b	(sysmars_reg).l,d7
		btst	#7,d7
		bne.s	.svdp_locked
		lea	(RAM_MdMars_CommBuff+Dreq_Palette).l,a6
		lea	(sysmars_reg+$100).l,a5
		move.w	#((256/2)/4)-1,d7
.copy_it:
	rept 4
		move.l	(a6)+,d6
		move.l	d6,(a5)+
	endm
		dbf	d7,.copy_it
.svdp_locked:
	endif
		rts

; ====================================================================
; --------------------------------------------------------
; Subroutines
; --------------------------------------------------------

; --------------------------------------------------------
; Video_MdMars_VideoMode
;
; Set the graphics mode on the 32X.
;
; Input:
; d0.w | Mode number $00-$02
;        - Write $00 to disable 32X visuals and
;          get SVDP control.
;
; Notes:
; - Setting mode to 0 (blank) does not clear the
;   FRAMEBUFFER(s)
;
; Uses:
; d0
; --------------------------------------------------------

Video_MdMars_VideoOff:
		moveq	#0,d0

Video_MdMars_VideoMode:
		move.w	d7,-(sp)
	if EMU=0
		bsr	Video_MdMars_SetSync
; 		bsr	Video_MdMars_WaitSync
; 		bsr	System_MdMars_Update
; 		bsr	Video_MdMars_SetSync
	endif
	rept 2
		bsr	Video_MdMars_WaitSync
		bsr	System_MdMars_Update
		bsr	Video_MdMars_SetSync
	endm
		move.w	d0,d7
		andi.w	#%00000111,d7			; Bits allowed
		ori.w	#%11000000,d7			; Mode + Init bits
		move.b	d7,(sysmars_reg+(comm12+1)).l
.wait_finish:	move.b	(sysmars_reg+(comm12+1)).l,d7
		andi.w	#%11000000,d7
		bne.s	.wait_finish
	rept 2
		bsr	Video_MdMars_WaitSync
		bsr	Video_MdMars_SetSync
	endm
		move.w	(sp)+,d7
		rts

; --------------------------------------------------------
; Video_MdMars_LoadVram
;
; Loads graphics data into a special section
; on the SDRAM area for the 2D and 3D modes.
;
; Input:
; a0   | Graphics data
; a1   | Output position
; d0.l | Size, 8-byte aligned
;
; Uses:
; ALL
;
; Notes:
; - Careful using this if the SH2 side is in the
;   middle of reading the graphics data.
; --------------------------------------------------------

Video_MdMars_LoadVram:
		movem.l	d0/d7/a0-a1,-(sp)
		move.l	a1,d7
		add.l	d0,d7
		cmp.l	#MAX_MarsVram,d7
		ble.s	.good_sz
		sub.l	#MAX_MarsVram,d7
		bmi.s	.got_zero
		move.l	d7,d0
.good_sz:
		addi.l	#RAM_Mars_VramData,a1	; *** EXTERNAL LABEL ***
		bsr	System_MdMars_SendData
.got_zero:
		movem.l	(sp)+,d0/d7/a0-a1
		rts

; --------------------------------------------------------
; Video_MdMars_LoadMap
;
; Loads map data for 32X's 2D-mode
;
; Input:
; a0   | Map data
; a1   | Graphics start location
; d0.w | X start position
; d1.w | Y start position
; d2.w | Map width in blocks (width/16)
; d3.w | Map height in blocks (height/16)
; d4.w | Starting color index *LIMITED*
;
; Notes:
; - To load the Graphics use Video_MdMars_LoadVram
;   a1 only sets the location in SDRAM
; --------------------------------------------------------

; CURRENT TILE FORMAT:
; %Rppp pppt tttt tttt
;
; R - Reload block, cleared here later.
; p - Palette index, limited by 4 color-sizes
; t - 16x16 block number, 0 is blank

Video_MdMars_LoadMap:
		movem.l	d4-d7/a3-a6,-(sp)
		lea	(RAM_MdMars_ScrlSett).w,a6
		lea	(RAM_MdMars_ScrlData).w,a5
		move.l	a1,sscrl_vram(a6)
		moveq	#0,d5

	; d4 - $7Exx
	; d5 - USED
	; d6 - free | Y pos copy
	; d7 - Y loop
		andi.w	#$FC,d4		; <-- d4
		lsl.w	#7,d4
		move.l	a0,a3
		move.w	d1,d6
		move.w	d3,d7
		subq.w	#1,d7
.copy_y:
		move.l	a5,a4
		moveq	#0,d5
		move.w	d6,d5
		lsl.w	#6,d5
		add.l	d5,a4
		move.w	d0,d5
		add.w	d5,d5
		swap	d7
		swap	d6
		move.w	d2,d7
		subq.w	#1,d7
.copy_x:
		move.w	(a3)+,d6
		add.w	d4,d6
		or.w	#$8000,d6
		move.w	d6,(a4,d5.w)
		addq.w	#1*2,d5
		andi.w	#((512/16)-1)*2,d5
		dbf	d7,.copy_x
		swap	d6
		swap	d7
		addq.w	#1,d6
		andi.w	#((256/16)-1),d6
		dbf	d7,.copy_y
		movem.l	(sp)+,d4-d7/a3-a6
		rts

; ====================================================================
; --------------------------------------------------------
; Video_MdMars_SetSpr2D, Video_MdMars_MakeSpr2D
;
; Set or Make a Super Sprite
;
; Input:
; a0   | Index slot (_SetSpr2D ONLY)
; a1   | Texture pointer (0-MAX_MarsVram or CS1-ROM location)
; d0.l | X/Y position: splitw(x_pos,y_pos)
; d1.l | Flags and Z position: splitw(flags,z_pos)
; d2.l | Width/Height: splitw(width,height)
; d3.l | Texture full_width+index: splitw(width,index)
; d4.l | Frame X/Y: splitw(x_frame,y_frame)
;
; Returns:
; bcc | OK
; bcs | Ran out of Super Sprites
; --------------------------------------------------------

Video_MdMars_SetSpr2D:
		movem.l	d6-d7/a6,-(sp)
		move.l	a0,d7
		moveq	#0,d6			; Disposable bit
		bra	vidMdMars_MkSpr2D

Video_MdMars_MakeSpr2D:
		movem.l	d6-d7/a6,-(sp)
		moveq	#0,d7
		lea	(RAM_MdMars_SuperSpr).w,a6
		moveq	#MAX_MARSSPR-1,d6
.chk_free:
		tst.b	sspr_flags(a6)
		beq.s	.mk_spr
		addq.w	#1,d7
		adda	#sspr_len,a6
		dbf	d6,.chk_free
		bra.s	vidMdMars_CError
.mk_spr:
		moveq	#$40,d6			; Disposable bit

vidMdMars_MkSpr2D:
		andi.l	#$FF,d7
		cmp.w	#MAX_MARSSPR,d7
		bge.s	vidMdMars_CError
; 		mulu.w	#sspr_len,d7
		lsl.l	#4,d7			; FIXED SIZE
		addi.l	#RAM_MdMars_SuperSpr,d7
		move.l	d7,a6
		move.l	a1,sspr_vram(a6)
		move.l	d0,d7
		swap	d7
		move.w	d7,sspr_x_pos(a6)
		move.w	d0,sspr_y_pos(a6)
		move.l	d2,d7
		lsr.w	#3,d7
		subq.w	#1,d7
		move.b	d7,sspr_size+1(a6)
		swap	d7
		lsr.w	#3,d7
		subq.w	#1,d7
		move.b	d7,sspr_size(a6)
		move.w	d3,d7
		andi.w	#$FF,d7
		move.w	d7,sspr_indx(a6)
		move.l	d1,d7
		swap	d7
		tst.w	d7
		andi.w	#%00000011,d7
		or.b	#$80,d7
		or.b	d6,d7
		move.b	d7,sspr_flags(a6)
		move.w	d4,d7
		andi.w	#$FF,d7
		move.w	d7,sspr_frame(a6)
.on_freeze:
		movem.l	(sp)+,d6-d7/a6
		and	#%11110,ccr		; Return OK
		rts
; Carry error
vidMdMars_CError:
		movem.l	(sp)+,d6-d7/a6
		or	#1,ccr			; Return Error
		rts

; --------------------------------------------------------
; Video_MdMars_SetSpr3D, Video_MdMars_MakeSpr3D
;
; Set or Make a 3D Sprite
;
; Input:
; a0   | Index slot (_SetSpr3D ONLY)
; a1   | Texture pointer (0-MAX_MarsVram or CS1-ROM location)
; d0.l | X/Y position: splitw(x_pos,y_pos)
; d1.l | Flags and Z position: splitw(flags,z_pos)
; d2.l | Width/Height: splitw(width,height)
; d3.l | Texture full_width+index: splitw(width,index)
; d4.l | Frame X/Y: splitw(x_frame,y_frame)
;
;        flags: %000000ff
;        %00 - Normal 3D screen sprite
;        %01 - Sprite is inside the 3D Field
;        %11 - Same as %01, always face to the front
;              of the camera
;
; Returns:
; bcc | OK
; bcs | Ran out of slots
; --------------------------------------------------------

Video_MdMars_SetSpr3D:
		movem.l	d6-d7/a6,-(sp)
		move.l	a0,d7
		moveq	#0,d6			; Disposable bit
		bra	vidMdMars_MkSpr3D

Video_MdMars_MakeSpr3D:
		movem.l	d6-d7/a6,-(sp)

		moveq	#0,d7
		lea	(RAM_MdMars_MSprites).w,a6
		moveq	#MAX_MARSMSPR-1,d6
.chk_free:
		tst.b	mspr_flags(a6)
		beq.s	.mk_spr
		addq.w	#1,d7
		adda	#mspr_len,a6
		dbf	d6,.chk_free
		bra.s	vidMdMars_CError
.mk_spr:
		moveq	#$40,d6			; Disposable bit

vidMdMars_MkSpr3D:
		andi.l	#$FF,d7
		cmp.w	#MAX_MARSMSPR,d7
		bge.s	vidMdMars_CError
; 		mulu.w	#mspr_len,d7
		lsl.l	#5,d7			; FIXED SIZE
		addi.l	#RAM_MdMars_MSprites,d7
		move.l	d7,a6
		move.l	a1,mspr_vram(a6)	; a1
		move.l	d0,d7
		swap	d7
		move.w	d7,mspr_x_pos(a6)
		move.w	d0,mspr_y_pos(a6)
		move.l	d1,d7
		swap	d7
		andi.w	#%11,d7
		or.w	#$80,d7
		or.w	d6,d7
		move.b	d7,mspr_flags(a6)
		move.w	d1,mspr_z_pos(a6)
		move.l	d2,d7
		swap	d7
		move.b	d7,mspr_size_w(a6)
		move.b	d2,mspr_size_h(a6)
		move.b	d7,mspr_src_w(a6)
		move.b	d2,mspr_src_h(a6)
		move.l	d3,d7
		swap	d7
		move.b	d7,mspr_srcwdth(a6)
		move.b	d3,mspr_indx(a6)
		move.l	d4,d7
		swap	d7
		move.b	d7,mspr_frame_x(a6)
		move.b	d4,mspr_frame_y(a6)
		movem.l	(sp)+,d6-d7/a6
		and	#%11110,ccr		; Return OK
		rts

; ====================================================================
; ----------------------------------------------------------------
; SVDP Palette
; ----------------------------------------------------------------

; --------------------------------------------------------
; Video_MdMars_RunFade
;
; Process 1 step of palette fading, SVDP Palette.
;
; Use Video_WaitFade to wait for changes.
; --------------------------------------------------------

Video_MdMars_RunFade:
	if MARS|MARSCD
		lea	(RAM_MdMars_MPalFdList).w,a6
.next_req:
		move.b	palfd_req(a6),d0
		beq.s	.no_req
		subq.b	#1,palfd_timer(a6)
		bpl.s	.busy_timer
		move.b	palfd_delay(a6),palfd_timer(a6)
		lea	(RAM_MdMars_CommBuff+Dreq_Palette).w,a5
		lea	(RAM_MdMars_PalFd).w,a4
		moveq	#0,d7
		move.b	palfd_start(a6),d7
		add.w	d7,d7
		adda	d7,a5
		adda	d7,a4
		moveq	#0,d7
		moveq	#0,d6
		move.w	palfd_num(a6),d7
		beq.s	.busy_timer
		move.b	palfd_incr(a6),d6
		subq.w	#1,d7
		andi.w	#$FF,d0
		add.w	d0,d0
		move.w	.fade_list(pc,d0.w),d0
		jsr	.fade_list(pc,d0.w)
.busy_timer:
		adda	#palfd_len,a6
		bra.s	.next_req
.no_req:
		clr.w	(RAM_MdMars_IndxPalFd).w
	endif
		rts

; ------------------------------------------------

.fade_list:
		dc.w .nothing-.fade_list	; $00
		dc.w .fade_out-.fade_list
		dc.w .fade_in-.fade_list
		dc.w .nothing-.fade_list
		dc.w .nothing-.fade_list	; $04
		dc.w .nothing-.fade_list
		dc.w .nothing-.fade_list
		dc.w .nothing-.fade_list

; ----------------------------------------------------
; Fade request $00: Null/exit.
; ----------------------------------------------------

.nothing:
		clr.b	palfd_req(a6)
		rts

; ----------------------------------------------------
; Fade request $01: fade-out to black
; Quick.
;
; d7 - Num colors
; d6 - Increment*2
; ----------------------------------------------------

.fade_out:
		andi.w	#%0000000000011111,d6	; d6 - Max increment
		move.w	#%0000000000011111,d5	; d5 - Target filter
		move.w	#%1111111111100000,d4	; d4 - Others filter + extra
		moveq	#0,d3			; d3 - Exit counter
.next_color:
		move.w	(a5),d0
	rept 3
		move.w	d0,d1
		and.w	d5,d1		; Filter TARGET
		beq.s	.no_chng
		and.w	d4,d0		; Filter OTHERS
		sub.w	d6,d1
		bpl.s	.too_blck
		clr.w	d1
.too_blck:
		addq.w	#1,d3		; Color changed
.no_chng:
		or.w	d1,d0
		rol.w	#5,d6		; next << color
		rol.w	#5,d5
		rol.w	#5,d4
	endm
	; returns to $Exxx, rotate to $xxxE:
		rol.w	#1,d6
		rol.w	#1,d5
		rol.w	#1,d4
		move.w	d0,(a5)+
.all_black:
		dbf	d7,.next_color
		tst.w	d3
		bne.s	.fdout_nend
		clr.b	palfd_req(a6)
.fdout_nend:
		rts

; ----------------------------------------------------
; Fade request $02
; Fade-in
; ----------------------------------------------------

.fade_in:
		andi.w	#%0000000000011111,d6	; d6 - Max increment
		move.w	#%0000000000011111,d5	; d5 - Target filter
		move.w	#$7FFF,d4		; d4 - Filter bits
.next_in:
		swap	d7
		move.w	(a5),d0			; d0 - Current
		move.w	(a4),d2			; d2 - Target
		move.w	d2,d3
		andi.w	#$8000,d3
		swap	d3
		and.w	d4,d0
		and.w	d4,d2
		cmp.w	d2,d0
		beq.s	.set_prio
	rept 3
		move.w	d0,d1
		move.w	d4,d3
		eor.w	d5,d3
		and.w	d3,d0
		move.w	d2,d3
		and.w	d5,d1		; filter CURRENT color
		and.w	d5,d3		; filter TARGET color

		add.w	d6,d1		; ADD to current
		cmp.w	d3,d1
		bcs.s	.max_out
		move.w	d2,d1
		andi.w	#$7FFF,d1
		and.w	d5,d1
.max_out:
		addq.w	#1,d7
		or.w	d1,d0
		rol.w	#5,d6		; next << color
		rol.w	#5,d5
	endm
		rol.w	#1,d6
		rol.w	#1,d5
.set_prio:
		swap	d3
		or.w	d3,d0
		move.w	d0,(a5)
.same_in:
		adda	#2,a5		; Next color
		adda	#2,a4
		swap	d7
		dbf	d7,.next_in
		swap	d7
		tst.w	d7
		bne.s	.fdin_nend
		clr.b	palfd_req(a6)
.fdin_nend:
		rts

; --------------------------------------------------------
; Video_MdMars_LoadPal, Video_MdMars_FadePal
;
; Loads SVDP 256-color palette data,
; either current or for fading.
;
; Input:
; a0   | 256-color Palette data
; d0.w | Starting index
; d1.w | Number of colors
; d2.w | Priority bit 0 or 1
;
; Notes:
; - Priority bit is skipped on the first color index
; --------------------------------------------------------

Video_MdMars_FadePal:
		movem.l	d5-d7/a5-a6,-(sp)
		lea	(RAM_MdMars_PalFd).w,a6
		bra.s	vidMars_Pal
Video_MdMars_LoadPal:
		movem.l	d5-d7/a5-a6,-(sp)
		lea	(RAM_MdMars_CommBuff+Dreq_Palette).w,a6
; 		bra.s	vidMars_Pal
vidMars_Pal:
		move.l	a0,a5
		moveq	#0,d7
		move.w	d0,d7
		move.w	d0,d5
		add.w	d7,d7
		adda	d7,a6
		move.w	d1,d7
		subi.w	#1,d7
		move.w	d2,d6
		andi.w	#1,d6
		ror.w	#1,d6
.loop:
		swap	d7
		move.w	(a5)+,d7
		tst.w	d5
		beq.s	.trnspr
		cmpa.l	#RAM_MdMars_CommBuff+Dreq_Palette,a5	; Skip first index
		beq.s	.trnspr
		or.w	d6,d7
.trnspr:
		move.w	d7,(a6)+
		swap	d7
		addq.w	#1,d5
		dbf	d7,.loop
		movem.l	(sp)+,d5-d7/a5-a6
		rts

; --------------------------------------------------------
; Video_LoadPal_List, Video_FadePal_List
;
; Loads palettes on bulk with a list
;
; Input:
; a0 | List of graphics to load:
;        dc.w numof_entries
;        dc.l palette_data
;        dc.w start_at
;        dc.w numof_colors
;        dc.w priority (0 or 1)
;        ; ...more entries
; --------------------------------------------------------

Video_MdMars_LoadPal_List:
		movem.l	d7/a5,-(sp)
		move.l	a0,a5
		move.w	(a5)+,d7
		beq.s	.invalid
		bmi.s	.invalid
		subq.w	#1,d7
.next_one:
		move.l	(a5)+,a0
		move.w	(a5)+,d0
		move.w	(a5)+,d1
		move.w	(a5)+,d2
		bsr	Video_MdMars_LoadPal
		dbf	d7,.next_one
.invalid:
		movem.l	(sp)+,d7/a5
		rts

Video_MdMars_FadePal_List:
		movem.l	d7/a5,-(sp)
		move.l	a0,a5
		move.w	(a5)+,d7
		beq.s	.invalid
		bmi.s	.invalid
		subq.w	#1,d7
.next_one:
		move.l	(a5)+,a0
		move.w	(a5)+,d0
		move.w	(a5)+,d1
		move.w	(a5)+,d2
		bsr	Video_MdMars_FadePal
		dbf	d7,.next_one
.invalid:
		movem.l	(sp)+,d7/a5
		rts

; ====================================================================

	endif	; end 32X section
