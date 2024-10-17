; ===========================================================================
; -------------------------------------------------------------------
; GEMA/Nikona PWM instruments on Cartridge ONLY
;
; - Samples located here CANNOT be used on CD32X
; - If the Genesis does DMA that requires the RV bit this
;   section will get protected before the DMA starts
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
	gSmplData PwmIns_song0_01,"sound/instr/smpl/song0/1.wav",0
	gSmplData PwmIns_song0_02,"sound/instr/smpl/song0/2.wav",0
	gSmplData PwmIns_song0_03,"sound/instr/smpl/song0/3.wav",0
	gSmplData PwmIns_song0_04,"sound/instr/smpl/song0/4.wav",0
	gSmplData PwmIns_song0_05,"sound/instr/smpl/song0/5.wav",0
	gSmplData PwmIns_song0_06,"sound/instr/smpl/song0/6.wav",0
	gSmplData PwmIns_song0_07,"sound/instr/smpl/song0/7.wav",0
	gSmplData PwmIns_song0_08,"sound/instr/smpl/song0/8.wav",0
	gSmplData PwmIns_song0_09,"sound/instr/smpl/song0/9.wav",0
