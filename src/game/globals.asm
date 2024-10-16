; ====================================================================
; ----------------------------------------------------------------
; GLOBAL settings and variables
; ----------------------------------------------------------------

; ====================================================================
; ----------------------------------------------------------------
; USER SETTINGS
;
; Example:
; setting_tagname	equ value
; SET_DEBUGMODE		equ True
; SET_PLAYERNAME	equ "NIKONA"
;
; setting_tagname:
; Any name you want but careful with any conflicting names
; within the Nikona-internal code
;
; Notes:
; "equ" es permanent, "set" is temporal can get rewritten
; during build
; ----------------------------------------------------------------

SET_DEBUGMODE		equ False

; ====================================================================
; ----------------------------------------------------------------
; RAM memory (RAM_Global)
;
; Your Score, Lives, Level number, etc. go here, for
; storing temporals on your current screen use RAM_ScrnBuff
;
; Examples:
;
; RAM_Glbl_ExmpL ds.l 8 ; Reserve 8 LONGS ($20 bytes)
; RAM_Glbl_ExmpW ds.w 5 ; Reserve 5 WORDS ($0A bytes)
; RAM_Glbl_ExmpB ds.b 6 ; Reserve 6 BYTES
;
; Careful with BYTES, everything needs to be even-aligned
; or your will get an ADDRESS ERROR.
; ----------------------------------------------------------------

RAM_Glbl_Example_L	ds.l 1		; 1 long (4 bytes)
RAM_Glbl_Example_W	ds.w 1		; 1 word (2 bytes)
RAM_Glbl_Example_B	ds.b 1		; 1 byte

; --------------------------------------------------------
			align 2
