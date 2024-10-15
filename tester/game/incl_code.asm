; ============================================================
; --------------------------------------------------------
; CODE BANKS section
;
; Usage:
; screen_code START_LABEL,END_LABEL,CODE_PATH
;
; NOTES:
; - Screen order is at game/screens.asm
; - DATA banks are loaded separately inside the
;   screen's code
; --------------------------------------------------------

	;screen_code Md_Screen00,Md_Screen00_e,"game/code/main.asm"
	screen_code Md_Screen00,Md_Screen00_e,"game/code/sound_test.asm"
