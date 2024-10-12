; ====================================================================
; ----------------------------------------------------------------
; CACHE code
;
; LIMIT: $600 bytes
; ----------------------------------------------------------------

; WARNING: AS can't phase $C0000000, set the labels like this
; $C0000000|label

		align 4
CACHE_SLAVE:
		phase 0		; AS can't phase $C0000000

; ====================================================================
; ----------------------------------------------------------------
; PWM Interrupt
; ----------------------------------------------------------------

; MarsPwm_Playback:
s_irq_pwm:
		mov	#_FRT,r1
		mov.b	@(7,r1),r0
		xor	#2,r0
		mov.b	r0,@(7,r1)
		mov	#_sysreg+pwmintclr,r1
		mov.w	r0,@r1
		mov.w	@r1,r0
; 		mov	#_sysreg+comm6,r1	; **** TEMPORAL COUNTER
; 		mov.w	@r1,r0			; ****
; 		add	#1,r0			; ****
; 		mov.w	r0,@r1			; ****
	; --------------------------------
		mov	#_sysreg+monowidth,r1
		mov.w	@r1,r0
		shlr8	r0
		tst	#$80,r0
		bt	.fifo_free
		bra	.pwm_full
		nop

; ------------------------------------------------

.fifo_free:
		mov	r2,@-r15
		mov	r3,@-r15
		mov	r4,@-r15
		mov	r5,@-r15
		mov	r6,@-r15
		mov	r7,@-r15
		mov	r8,@-r15
		mov	r9,@-r15
		mov	r10,@-r15
		sts	macl,@-r15
		sts	mach,@-r15
.fifo_loop:
		mov	#RAM_Mars_PwmList,r10
		mov	#MAX_PWMCHNL,r9
		mov	#0,r6			; r6 - left
		mov	#0,r7			; r7 - right
.next_chnl:
		mov	@(marspwm_enbl,r10),r0
		lds	r0,macl
		tst	#$80,r0
		bf	.enabled
.chnl_siln:	mov	#$80,r1
		bra	.chnl_off
		mov	r1,r2
.enabled:
		nop
		mov	@(marspwm_pitch,r10),r3
		tst	#%1000,r0
		bt	.st_pitch
		shll	r3
.st_pitch:
		mov	@(marspwm_cread,r10),r5
		add	r3,r5
		mov	r5,@(marspwm_cread,r10)
		mov	@(marspwm_read,r10),r5
		add	r3,r5
		mov	@(marspwm_length,r10),r0
		sub	r3,r0
		cmp/ge	r0,r5
		bf	.keep
		sts	macl,r0
		tst	#%00000100,r0
		bf	.loopit
		and	#%01000000,r0
		bra	.chnl_siln
		mov	r0,@(marspwm_enbl,r10)
.loopit:
		mov	@(marspwm_start,r10),r5
		mov	@(marspwm_loop,r10),r4
		add	r4,r5
.keep:
		mov	r5,@(marspwm_read,r10)

	; Make wave address point
	; r5 - xxxxxx.00
		mov	@(marspwm_bank,r10),r4
		sts	macl,r0
		tst	#%01000000,r0
		bt	.not_backup
		mov	@(marspwm_cread,r10),r5
		add	r3,r5
		mov	#($200-1)<<8,r0
		and	r0,r5
		mov	r5,@(marspwm_cread,r10)
		mov	@(marspwm_cbank,r10),r4
.not_backup:
		shlr8	r5
		or	r4,r5
.read_wav:
		tst	#%1000,r0		; Stereo sample?
		bt	.stand
		mov	#-2,r3			; Limit to words
		and	r3,r5
.stand:
		mov.b	@r5+,r3			; Left wave
		extu.b	r3,r3
		tst	#%1000,r0		; Stereo sample?
		bt	.do_mono		; Copy Left to Right
		mov.b	@r5+,r4			; Right wave
		bra	.go_wave
		extu.b	r4,r4
.do_mono:
		mov	r3,r4

; r3 - left byte
; r4 - right byte
.go_wave:
		add	#1,r3
		add	#1,r4
		mov.b	#$80,r1
		extu.b	r1,r1
		mov	r1,r2
.mnon_z:	tst	#%0010,r0
		bt	.ml_out
		mov	r3,r1
.ml_out:	tst	#%0001,r0
		bt	.do_vol
		mov	r4,r2
; r1 - left
; r2 - right
.do_vol:
		mov	@(marspwm_vol,r10),r0
		cmp/pl	r0
		bf	.chnl_off
		mov	#64,r4
		cmp/ge	r4,r0
		bt	.chnl_siln
		add	#1,r0
		shll2	r0
		mulu	r0,r1
		sts	macl,r4
		shlr8	r4
		sub	r4,r1
		mulu	r0,r2
		sts	macl,r4
		shlr8	r4
		sub	r4,r2
		cmp/pl	r1
		bt	.l_low
		mov	#0,r1
.l_low:		cmp/pl	r2
		bt	.r_low
		mov	#0,r2
.r_low:		mov	#$80,r4		; <-- This prevents a click
		mulu	r0,r4
		sts	macl,r0
		shlr8	r0
		add	r0,r1
		add	r0,r2
.chnl_off:
		add	r1,r6
		add	r2,r7
		dt	r9
		bf/s	.next_chnl
		add	#marspwm_len,r10
		mov	#$7FF,r0
		cmp/ge	r0,r6
		bf	.l_max
		mov	r0,r6
.l_max:
		cmp/ge	r0,r7
		bf	.r_max
		mov	r0,r7
.r_max:
		shll16	r6
		or	r6,r7
		mov	#_sysreg+lchwidth,r0
		mov	r7,@r0
		mov	#_sysreg+monowidth,r1
		mov.w	@r1,r0
		shlr8	r0
		tst	#$80,r0
		bt	.fifo_loop

; ------------------------------------------------
		lds	@r15+,mach
		lds	@r15+,macl
		mov	@r15+,r10
		mov	@r15+,r9
		mov	@r15+,r8
		mov	@r15+,r7
		mov	@r15+,r6
		mov	@r15+,r5
		mov	@r15+,r4
		mov	@r15+,r3
		mov	@r15+,r2
.pwm_full:
		rts
		nop
		align 4
		ltorg

; ====================================================================
; ----------------------------------------------------------------
; 3D Section
; ----------------------------------------------------------------

; --------------------------------------------------------
; MarsMdl_MdlLoop
; --------------------------------------------------------

		align 4
MarsMdl_MdlLoop:
		sts	pr,@-r15
		bsr	Mars_CachePurge_S
		nop
		mov	#0,r11
		mov 	#RAM_Mars_Polygons_0,r13
		mov	#RAM_Mars_PlgnList_0,r12
		mov	#$C0000000|CachSlv_CurrPage,r0
		mov	@r0,r0
		tst     #1,r0
		bt	.go_mdl
		mov 	#RAM_Mars_Polygons_1,r13
		mov	#RAM_Mars_PlgnList_1,r12
.go_mdl:

	; ------------------------------------------------
	; 3D Sprites
		mov	#RAM_Mars_SprPolygn,r14
		mov	#MAX_MARSMSPR,r10
.m_loop:
		mov.b	@(mspr_flags,r14),r0
		tst	#$80,r0
		bt	.m_invlid
		mov	#MAX_FACES,r0
		cmp/gt	r0,r11
		bt	.invlid
		bsr	MarsMdl_MkSpr
		mov	r10,@-r15
		mov	@r15+,r10
.m_invlid:
		dt	r10
		bf/s	.m_loop
		add	#mspr_len,r14
	; ------------------------------------------------
	; 3D Models
		mov	#RAM_Mars_Objects,r14
		mov	#MAX_MARSOBJ,r10
.loop:
		mov	@(mmdl_data,r14),r0		; Object model data == 0 or -1?
		cmp/pl	r0
		bf	.invlid
		mov	#MAX_FACES,r0
		cmp/gt	r0,r11
		bt	.invlid
		bsr	MarsMdl_ReadModel
		mov	r10,@-r15
		mov	@r15+,r10
.invlid:
		dt	r10
		bf/s	.loop
		add	#mmdl_len,r14
	; ------------------------------------------------
.skip:
		mov 	#RAM_Mars_PlgnNum_0,r12
		mov	#$C0000000|CachSlv_CurrPage,r0
		mov	@r0,r0
; 		mov.w   @(marsGbl_PlgnBuffNum,gbr),r0
		tst     #1,r0
		bt	.page_2
		mov 	#RAM_Mars_PlgnNum_1,r12
.page_2:
		mov	r11,@r12			; Save faces counter
		lds	@r15+,pr
		rts
		nop
		align 4
		ltorg

; ------------------------------------------------
; Read model
;
; r14 - Current Msprite list
; r13 - Current polygon
; r12 - Z storage
; r11 - Used faces counter
; ------------------------------------------------

		align 4
MarsMdl_MkSpr:
		sts	pr,@-r15
		mov.b	@(mspr_indx,r14),r0
		extu.b	r0,r2
		mov.b	@(mspr_srcwdth,r14),r0	; Texture file width
		extu.b	r0,r3
		mov	#$8000,r0
		add	r3,r0
		mov	@(mspr_vram,r14),r1	; Texture location
		shll16	r0
		or	r2,r0
		mov	r0,@(plygn_type,r13)
		nop
		mov	r1,@(plygn_mtrl,r13)

	; r1 | -X
	; r2 | +X
	; r3 | -Y
	; r4 | +Y
		mov.b	@(mspr_src_w,r14),r0
		extu.b	r0,r2
		mov.b	@(mspr_src_h,r14),r0
		extu.b	r0,r4
		mov	#0,r1
		mov	#0,r3
		mov.b	@(mspr_frame_x,r14),r0
		extu.b	r0,r5
		mov.b	@(mspr_frame_y,r14),r0
		extu.b	r0,r6
		mulu	r4,r6
		sts	macl,r0
		add	r0,r3
		add	r0,r4
		add	r5,r1
		add	r5,r2
		mov	r13,r5
		add	#plygn_srcpnts+((4*2)*2),r5
		mov.w	r4,@-r5		;
		mov.w	r2,@-r5		; +X +Y
		mov.w	r4,@-r5		;
		mov.w	r1,@-r5		; -X +Y
		mov.w	r3,@-r5		;
		mov.w	r1,@-r5		; -X -Y
		mov.w	r3,@-r5		;
		mov.w	r2,@-r5		; +X -Y

	; r1 | -X
	; r2 | +X
	; r3 | -Y
	; r4 | +Y
		mov.b	@(mspr_size_w,r14),r0
		shll	r0
		extu.b	r0,r2
		neg	r2,r1
		mov.b	@(mspr_size_h,r14),r0
		shll	r0
		extu.b	r0,r4
		neg	r4,r3
		mov.b	@(mspr_flags,r14),r0
		tst	#%00000001,r0			; 3D flag?
		bf	.not_oldpos
		mov.w	@(mspr_x_pos,r14),r0
; 		shlr2	r0
		exts.w	r0,r5
		add	r5,r1
		add	r5,r2
		mov.w	@(mspr_y_pos,r14),r0
; 		shlr2	r0
		exts.w	r0,r6
		add	r6,r3
		add	r6,r4
		shlr2	r1
		shlr2	r2
		shlr2	r3
		shlr2	r4
		exts.w	r1,r1
		exts.w	r2,r2
		exts.w	r3,r3
		exts.w	r4,r4
.not_oldpos:
		mov	r13,r5
		add	#plygn_points+((4*2)*4),r5
		mov	r4,@-r5		;
		mov	r2,@-r5		; +X +Y
		mov	r4,@-r5		;
		mov	r1,@-r5		; -X +Y
		mov	r3,@-r5		;
		mov	r1,@-r5		; -X -Y
		mov	r3,@-r5		;
		mov	r2,@-r5		; +X -Y

	; Inside 3D
		mov.b	@(mspr_flags,r14),r0
		tst	#%00000001,r0		; 3D flag?
		bt	.not_plyfld
		mov	r13,r1
		add	#plygn_points,r1
		mov	#4,r5
		mov	#0,r8
.mk_point:
		mov	@r1,r2
		shlr2	r2
		mov	@(4,r1),r3
		shlr2	r3
		exts.w	r2,r2
		exts.w	r3,r3
		bsr	mdlrd_setsppt
		mov	#0,r4			; TEMPORAL Z
		mov	r2,@r1
		mov	r3,@(4,r1)
		cmp/ge	r4,r8
		bf	.lower_z
		mov	r4,r8
.lower_z:
		dt	r5
		bf/s	.mk_point
		add	#8,r1
		cmp/pz	r8
		bt	.bad_face
		mov	#RAM_Mars_ObjCamera,r7
		mov	@(mcam_y_pos,r7),r0
		shlr2	r0
		exts.w	r0,r0
		mov	#MAX_ZDIST>>2,r1
		shll2	r1
		cmp/pz	r0
		bf	.z_plus
		neg	r0,r0
.z_plus:
		add	r0,r1
		cmp/ge	r1,r8
		bf	.bad_face
	; X/Y checks
		mov	r13,r10
		add	#plygn_points,r10
		mov	r10,r1
		mov	#-(SET_MSCRLWDTH/2)>>2,r4
		shll2	r4
		bsr	mdl_get_hilow
		neg	r4,r5
		cmp/gt	r4,r2
		bf	.bad_face
		cmp/ge	r5,r3
		bt	.bad_face
		mov	r10,r1
		add	#4,r1
		mov	#-(224/2)>>2,r4
		shll2	r4
		bsr	mdl_get_hilow
		neg	r4,r5
		cmp/gt	r4,r2
		bf	.bad_face
		cmp/ge	r5,r3
		bt	.bad_face
		bra	.mk_face
		nop
.not_plyfld:
		mov	#0,r8			; TODO
.mk_face:
		mov	r8,@r12			; Z position
		mov	r13,@(4,r12)		; Polygon pointer
		add	#plygn_len,r13	; Next X/Y polygon
		add	#8,r12			; Next Z storage
		add	#1,r11			; Mark as a valid face

.bad_face:
		lds	@r15+,pr
		rts
		nop
		align 4

; ----------------------------------------

		ltorg

; ----------------------------------------
; Modify position to current point
; ----------------------------------------

; r2 - X
; r3 - Y
; r4 - Z
		align 4
mdlrd_setsppt:
		sts	pr,@-r15
		mov 	r5,@-r15
		mov 	r6,@-r15
		mov 	r7,@-r15
		mov 	r8,@-r15
		mov 	r9,@-r15
		mov 	r10,@-r15
		mov 	r11,@-r15

	; Object rotation
		mov	r2,r5			; r5 - X
		mov	r4,r6			; r6 - Z
  		mov.w 	@(mspr_y_rot,r14),r0
		bsr	mdlrd_rotate
  		shll2	r0
   		mov	r7,r2
   		mov	r3,r5			; r5 - Y
  		mov	r8,r6
  		mov.w 	@(mspr_x_rot,r14),r0
		bsr	mdlrd_rotate
  		shll2	r0
   		mov	r8,r4			; UPDATE Z
		mov	r2,r5			; r5 - X
   		mov	r7,r6
  		mov.w 	@(mspr_z_rot,r14),r0
		bsr	mdlrd_rotate
   		shll2	r0
   		mov	r7,r2			; UPDATE X
   		mov	r8,r3			; UPDATE Y

   		nop
		mov.b	@(mspr_flags,r14),r0
		tst	#%00000010,r0
		bt	.no_facecam
		mov	#RAM_Mars_ObjCamera,r11
		mov	r2,r5			; r5 - X
		mov	r4,r6			; r6 - Z
  		mov	@(mcam_y_rot,r11),r0
  		neg	r0,r0
		bsr	mdlrd_rotate
  		shlr	r0
   		mov	r7,r2
   		mov	r3,r5			; r5 - Y
  		mov	r8,r6
  		mov	@(mcam_x_rot,r11),r0
  		neg	r0,r0
		bsr	mdlrd_rotate
  		shlr	r0
   		mov	r8,r4			; UPDATE Z
		mov	r2,r5			; r5 - X
   		mov	r7,r6
  		mov	@(mcam_z_rot,r11),r0
  		neg	r0,r0
		bsr	mdlrd_rotate
   		shlr	r0
.no_facecam:
		mov.w	@(mspr_x_pos,r14),r0
		exts.w	r0,r5
		mov.w	@(mspr_y_pos,r14),r0
		exts.w	r0,r6
		mov.w	@(mspr_z_pos,r14),r0
		exts.w	r0,r7
		add 	r5,r2
		add 	r6,r3
   		bra	mdlrd_persp
		add 	r7,r4
   		align 4
   		ltorg

; ------------------------------------------------
; Read model
;
; r14 - Current model data
; r13 - Current polygon
; r12 - Z storage
; r11 - Used faces counter
; ------------------------------------------------

; Mdl_Object:
; 		dc.w num_faces,num_vertex_old
; 		dc.l .vert,.face,.vrtx,.mtrl
; .vert:	binclude "data/mars/objects/mdl/test/vert.bin"
; .face:	binclude "data/mars/objects/mdl/test/face.bin"
; .vrtx:	binclude "data/mars/objects/mdl/test/vrtx.bin"
; .mtrl:	include "data/mars/objects/mdl/test/mtrl.asm"
;
		align 4
MarsMdl_ReadModel:
		sts	pr,@-r15
		nop
		mov	@(mmdl_data,r14),r10	; r10 - Model header
		nop
		mov.w	@r10,r9			;  r9 - Number of polygons of this model
		extu.w	r9,r9
		mov 	@(8,r10),r8		;  r8 - face data
		add	r10,r8
		mov	@(4,r10),r7		;  r7 - Vertex data
		add	r10,r7
.next_face:
		mov	#MAX_FACES,r0
		cmp/ge	r0,r11
		bf	.valid
		bra	.exit
		mov	r0,r11
.valid:
		mov.w	@r8+,r0
		mov	r0,r5			; r5 - Face type
		mov	#4,r6			; r6 - number of vertex (quad or tri)
		shlr8	r0			;
		tst	#PLGN_TRI,r0
		bt	.quad			; bit 0 = quad
		dt	r6
.quad:
		mov	r13,r4
		cmp/pl	r5			; Solid or texture? ($8xxx)
		bf	.has_uv

; --------------------------------
; Face is solid color
		mov	r5,r0
		extu.b	r0,r0
		mov	#%01100000,r3
		shll	r3
		shll8	r3
		and	r3,r5
		shll16	r5
		mov	r0,@(plygn_mtrl,r4)
		bra	.mk_face
		mov	r5,@(plygn_type,r4)
		align 4

; --------------------------------
; Face has UV settings

.has_uv:
		mov	@($C,r10),r1		; r1 - Grab UV points
		add	r10,r1
		mov	r6,r0
		mov	r13,r2			; r2 - Output to polygon
		add	#plygn_srcpnts,r2
		cmp/eq	#3,r0			; Polygon is tri?
		bt	.uv_tri
		nop
		mov.w	@r8+,r0			; Do quad point
		extu.w	r0,r0
		shll2	r0
		mov	@(r1,r0),r0
		mov	r0,@r2
		add	#4,r2
.uv_tri:
	rept 3					; Grab UV points 3 times
		mov.w	@r8+,r0
		extu.w	r0,r0
		shll2	r0
		mov	@(r1,r0),r0
		mov	r0,@r2
		add	#4,r2
	endm
		mov	@($10,r10),r1		; r1 - Read material list
		add	r10,r1
		mov	r5,r0			; r0 - Material slot
		and	#$FF,r0
		shll2	r0			; *8
		shll	r0
		add	r0,r1			; Increment r1 into mtrl slot
		mov	#%01100000,r3
		shll	r3
		shll8	r3			; r3 - $C0
		and	r3,r5			; Filter settings bits

	; dc.l pointer
	; dc.w tex_wdth
	; dc.w indx
		mov	@(4,r1),r0		; r0 - Texture width
		mov	r0,r2
		extu.w	r0,r0

		shlr16	r2
		or	r2,r5
; 		or	r0,r5
		mov	@r1,r3			; r3 - Texture ROM pointer
		shll16	r5
		or	r0,r5
; 		mov	@(mmdl_option,r14),r0
; 		extu.b	r0,r0
		mov	r3,@(plygn_mtrl,r4)
; 		or	r0,r5
		mov	r5,@(plygn_type,r4)
		nop

.mk_face:
		mov	#0,r5			; Z last pos

		mov	r4,r1			; r1 - OUTPUT face (X/Y) points
		add 	#plygn_points,r1
		mov	r6,r0
		cmp/eq	#3,r0			; Polygon is tri?
		bt	.fc_tri
		mov.w 	@r8+,r0			; Do quad point
		extu.w	r0,r0
		mov	r7,r4
		add 	r0,r4
		mov	@r4,r2
		mov	@(4,r4),r3
		bsr	mdlrd_setpoint
		mov	@(8,r4),r4
		mov	r2,@r1
		mov	r3,@(4,r1)
		add	#8,r1
		cmp/ge	r5,r4			; Save LOWEST Z point
		bt	.fc_tri
		mov	r4,r5
.fc_tri:
	rept 3
		mov.w 	@r8+,r0			; Grab face index 3 times
		extu.w	r0,r0
		mov	r7,r4			; r2 - vertex data + index
		add 	r0,r4
		mov	@r4,r2
		mov	@(4,r4),r3
		bsr	mdlrd_setpoint
		mov	@(8,r4),r4
		mov	r2,@r1
		mov	r3,@(4,r1)
		add	#8,r1
		cmp/ge	r5,r4
		bt	.higher
		mov	r4,r5
.higher:
	endm
	; *** Z-offscreen check***
		lds	r7,mach
		cmp/pz	r5
		bt	.bad_face
		mov	#RAM_Mars_ObjCamera,r7
		mov	@(mcam_y_pos,r7),r0
		shlr2	r0
		exts.w	r0,r0
		mov	#MAX_ZDIST>>2,r1
		shll2	r1
		cmp/pz	r0
		bf	.z_plus
		neg	r0,r0
.z_plus:
		add	r0,r1
		cmp/ge	r1,r5
		bf	.bad_face
		lds	r5,macl
	; X/Y checks
		mov	r13,r7
		add	#plygn_points,r7
		mov	r7,r1
		mov	#(SET_MSCRLWDTH/2)>>2,r5
		shll2	r5
		bsr	mdl_get_hilow
		neg	r5,r4
		cmp/ge	r4,r2
		bf	.bad_face
		cmp/gt	r5,r3
		bt	.bad_face
		mov	r7,r1
		add	#4,r1
		mov	#(SET_MSCRLHGHT/2)>>2,r5
		shll2	r5
		bsr	mdl_get_hilow
		neg	r5,r4
		cmp/ge	r4,r2
		bf	.bad_face
		cmp/ge	r5,r3
		bt	.bad_face
	; *** Valid face:
		sts	macl,r0
		mov	r0,@r12
		mov	r13,@(4,r12)
		add	#plygn_len,r13	; Next X/Y polygon
		add	#8,r12			; Next Z storage
		add	#1,r11			; Mark as a valid face
		nop
.bad_face:
		sts	mach,r7
		dt	r9
		bt	.exit
		bra	.next_face
		nop
		align 4
.exit:
		lds	@r15+,pr
		rts
		nop
		align 4
		ltorg

; ----------------------------------------
; X/Y off check
; ----------------------------------------

; r1 - points
; r4 - left maximum
; r5 - right maximum
mdl_get_hilow:
		mov	#4,r6
		mov	@r1,r2
		mov	r2,r3
.pick_next:
		mov	@r1,r0
		cmp/gt	r4,r0
		bf	.x_l
		mov	r0,r2
.x_l:
		cmp/ge	r5,r0
		bt	.x_r
		mov	r0,r3
.x_r:
		dt	r6
		bf/s	.pick_next
		add	#8,r1
		rts
		nop
		align 4

; ----------------------------------------
; Modify position to current point
; ----------------------------------------

; r2 - X
; r3 - Y
; r4 - Z
		align 4
mdlrd_setpoint:
		sts	pr,@-r15
		mov 	r5,@-r15
		mov 	r6,@-r15
		mov 	r7,@-r15
		mov 	r8,@-r15
		mov 	r9,@-r15
		mov 	r10,@-r15
		mov 	r11,@-r15
	; Object rotation
		mov	r2,r5			; r5 - X
		mov	r4,r6			; r6 - Z
  		mov	@(mmdl_y_rot,r14),r0
  		bsr	mdlrd_rotate
  		shar	r0
   		mov	r7,r2
   		mov	r3,r5			; r5 - Y
  		mov	r8,r6
  		mov	@(mmdl_x_rot,r14),r0
  		bsr	mdlrd_rotate
  		shar	r0
   		mov	r8,r4			; UPDATE Z
		mov	r2,r5			; r5 - X
   		mov	r7,r6
   		mov	@(mmdl_z_rot,r14),r0
  		bsr	mdlrd_rotate
  		shar	r0
   		mov	r7,r2			; UPDATE X
   		mov	r8,r3			; UPDATE Y
   		nop
		mov	@(mmdl_x_pos,r14),r5
		add 	r5,r2
		mov	@(mmdl_y_pos,r14),r6
		add 	r6,r3
		mov	@(mmdl_z_pos,r14),r7
		add 	r7,r4

; 		mov	@(mmdl_x_pos,r14),r0
; 		exts.w	r0,r5
; 		mov	@(mmdl_y_pos,r14),r0
; 		exts.w	r0,r6
; 		mov	@(mmdl_z_pos,r14),r0
; 		exts.w	r0,r7
; 		add 	r5,r2
; 		add 	r6,r3
; 		add 	r7,r4
mdlrd_persp:
	; Include camera changes
		mov	#RAM_Mars_ObjCamera,r11
		mov	@(mcam_x_pos,r11),r5
		mov	@(mcam_y_pos,r11),r6
		mov	@(mcam_z_pos,r11),r7
		sub 	r5,r2
		sub 	r6,r3
		sub 	r7,r4
		mov	r2,r5
		mov	r4,r6
  		mov 	@(mcam_y_rot,r11),r0
  		bsr	mdlrd_rotate
  		shlr	r0
   		mov	r7,r2
   		mov	r8,r4
   		mov	r3,r5
  		mov	r8,r6
  		mov 	@(mcam_x_rot,r11),r0
  		bsr	mdlrd_rotate
  		shlr	r0
   		mov	r8,r4
   		mov	r2,r5
   		mov	r7,r6
   		mov 	@(mcam_z_rot,r11),r0
  		bsr	mdlrd_rotate
  		shlr	r0
   		mov	r7,r2
   		mov	r8,r3
	; Do perspective
		mov	#320<<15,r7
		neg	r4,r8		; reverse Z
		cmp/pl	r8
		bt	.inside
		mov	r4,r0
.patchme:
		shll16	r0
		shll	r0
		add	r0,r7
		shlr2	r7
		bra	.zmulti
		shlr2	r7
.inside:
		mov	#24,r9
		cmp/ge	r9,r8
		bt	.center
		bra	.patchme
		mov	r4,r0

.center:
		mov 	#_JR,r9
		mov 	r8,@r9
		mov 	r7,@(4,r9)
		nop
		mov 	@($14,r9),r7
.zmulti:
		dmuls	r7,r2
		sts	mach,r0
		sts	macl,r2
		xtrct	r0,r2
		dmuls	r7,r3
		sts	mach,r0
		sts	macl,r3
		xtrct	r0,r3
		mov	@r15+,r11
		mov	@r15+,r10
		mov	@r15+,r9
		mov	@r15+,r8
		mov	@r15+,r7
		mov	@r15+,r6
		mov	@r15+,r5
		lds	@r15+,pr
		rts
		nop
		align 4

; ------------------------------
; Rotate point
;
; Entry:
; r5: x
; r6: y
; r0: theta
;
; Returns:
; r7: (x  cos @) + (y sin @)
; r8: (x -sin @) + (y cos @)
; ------------------------------

		align 4
mdlrd_rotate:
    		mov	#$7FF,r7
    		and	r7,r0
   		shll2	r0
		mov	#sin_table,r7
		mov	#sin_table+$800,r8
		mov	@(r0,r7),r9
		mov	@(r0,r8),r10
		dmuls	r5,r10		; x cos @
		sts	macl,r7
		sts	mach,r0
		xtrct	r0,r7
		dmuls	r6,r9		; y sin @
		sts	macl,r8
		sts	mach,r0
		xtrct	r0,r8
		add	r8,r7
		neg	r9,r9
		dmuls	r5,r9		; x -sin @
		sts	macl,r8
		sts	mach,r0
		xtrct	r0,r8
		dmuls	r6,r10		; y cos @
		sts	macl,r9
		sts	mach,r0
		xtrct	r0,r9
		add	r9,r8
 		rts
		nop
		align 4

; ====================================================================

		align 4
Mars_CachePurge_S:
		mov.w	#_CCR&$FFFF,r1		; Purge ON, Cache OFF
		mov	#%10000,r0
		mov.b	r0,@r1
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		mov	#%01001,r0		; Purge OFF, Two-Way mode, Cache ON
		rts
		mov.b	r0,@r1
		align 4

; ====================================================================

		ltorg

; ====================================================================

			align $10
CachSlv_CurrPage	ds.l 1

; ------------------------------------------------
		dephase
; .end:		phase CACHE_SLAVE+.end&$1FFF

		align 4
CACHE_SLAVE_E:
	erreport "SH2 SLAVE CACHE",CACHE_SLAVE_E-CACHE_SLAVE,$800
