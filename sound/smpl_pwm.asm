; ===========================================================================
; -------------------------------------------------------------------
; GEMA/Nikona PWM instruments located at SDRAM
;
; *** VERY LIMITED STORAGE ***
; If you are using CD32X consider using PCM samples instead.
;
; MACRO:
; gSmplData Label,"file_path",loop_start
; Set loop_start to 0 if not using it.
;
; BASE C-5 samplerate is 16000hz
; -------------------------------------------------------------------

		align 4
		;gSmplData Label,"file_path",loop_start
; -----------------------------------------------------------
		gSmplData PwmIns_TEST,"sound/instr/smpl/test_st.wav",0


