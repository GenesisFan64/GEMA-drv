; ===========================================================================
; ----------------------------------------------------------------
; 68K DATA BANKS
;
; Size limits:
;  $40000 for SegaCD's Word-RAM **compatible to all**
;  $80000 for Sega-Mapper(SSF2) bank
; $100000 for 32X Cartridge
; All 4MB for Genesis/Pico
;
; SCD/CD32:
; Add your BANK entries and filenames on iso_files.asm
;
; MACRO Usage:
;	data_dset LABEL_START
;	; your data
;	data_dend LABEL_END
; ----------------------------------------------------------------

; ============================================================
; --------------------------------------------------------
; MAIN bank
; --------------------------------------------------------

	data_dset DATA_BANK0
	; ------------------------------------------------
		include "sound/data.asm"		; GEMA user sound data
		include "game/data/bank_main.asm"
	; ------------------------------------------------
	data_dend DATA_BANK0_e
