; ====================================================================
; ----------------------------------------------------------------
; CACHE code
;
; LIMIT: $600 bytes
; ----------------------------------------------------------------

; WARNING: AS can't phase $C0000000, set the labels like this:
; $C0000000|label

		align 4
CACHE_MASTER:

; ====================================================================
; ----------------------------------------------------------------

			memory 0
RAM_Mars_SVdpSprInfo	ds.b $10*MAX_MARSSPR
RAM_Mars_ScrlRefill	ds.w (512/SET_MSCRLSIZE)*(256/SET_MSCRLSIZE)
			endmemory

			memory 0
RAM_Mars_SVdpDrwList	ds.b $40*16			; Polygon pieces
Cach_DDA_Top		ds.l 2*2			; First 2 points
Cach_DDA_Last		ds.l 2*2			; Triangle or Quad (+8)
Cach_DDA_Src		ds.l 4*2
Cach_DDA_Src_L		ds.l 4				; X/DX/Y/DX result for textures
Cach_DDA_Src_R		ds.l 4
Cach_LnDrw_L		ds.l 14				;
Cach_LnDrw_S		ds.l 0				; <-- Reads backwards
Cach_Bkup_LB		ds.l 11
Cach_Bkup_S		ds.l 0				; <-- Reads backwards
Cach_Bkup_LPZ		ds.l 7
Cach_Bkup_SPZ		ds.l 0				; <-- Reads backwards
			endmemory

; ----------------------------------------------------------------
; ====================================================================

; 		dephase
		align 4
CACHE_MASTER_E:
	erreport "SH2 SLAVE CACHE",CACHE_MASTER_E-CACHE_MASTER,$800
