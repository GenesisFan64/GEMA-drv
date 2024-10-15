; ===========================================================================
; -------------------------------------------------------------------
; SEGA CD SUB-CPU MAP
; -------------------------------------------------------------------

; ----------------------------------------------------------------
; SEGA CD map
; ----------------------------------------------------------------

sysmcd_wram	equ	$200000
sysmcd_reg	equ	$A12000

; ------------------------------------------------
; Register area
;
; MAIN-CPU: $A12000 (sysmcd_reg)
; SUB-CPU:  $FF8000 (scpu_reg)
; ------------------------------------------------

; -------------
; bits
bitWRamMode	equ 2		;2M | 1M

; -------------
; Registers
mcd_memory	equ $03
mcd_hint	equ $06		; [W] HBlank RAM redirection-jump (MAIN CPU ONLY)
mcd_comm_m	equ $0E		; [B] Comm port MAIN R/W | SUB READ ONLY
mcd_comm_s	equ $0F		; [B] Comm port SUB R/W  | MAIN READ ONLY
mcd_dcomm_m	equ $10		; [S: $0E] Communication MAIN
mcd_dcomm_s	equ $20		; [S: $0E] Communication SUB
mcd_intmask	equ $32		;

; ====================================================================
