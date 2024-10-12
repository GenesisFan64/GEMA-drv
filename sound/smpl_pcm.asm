; ===========================================================================
; -------------------------------------------------------------------
; GEMA/Nikona PCM instruments for SCD's PCM soundchip
;
; Stored on DISC and loaded to Sub-CPU on boot
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
		gSmplData PcmIns_TEST,"sound/instr/smpl/test.wav",0

		gSmplData PcmIns_sauron_01,"sound/instr/smpl/sauron/01.wav",0
		gSmplData PcmIns_sauron_02,"sound/instr/smpl/sauron/02.wav",0
		gSmplData PcmIns_sauron_03,"sound/instr/smpl/sauron/03.wav",0
		gSmplData PcmIns_sauron_04,"sound/instr/smpl/sauron/04.wav",0
		gSmplData PcmIns_sauron_05,"sound/instr/smpl/sauron/05.wav",13988
		gSmplData PcmIns_sauron_06,"sound/instr/smpl/sauron/06.wav",0
		gSmplData PcmIns_sauron_07,"sound/instr/smpl/sauron/07.wav",0
		gSmplData PcmIns_sauron_08,"sound/instr/smpl/sauron/08.wav",0
		gSmplData PcmIns_sauron_09,"sound/instr/smpl/sauron/09.wav",0
		gSmplData PcmIns_sauron_10,"sound/instr/smpl/sauron/10.wav",0
		gSmplData PcmIns_sauron_11,"sound/instr/smpl/sauron/11.wav",0
		gSmplData PcmIns_sauron_12,"sound/instr/smpl/sauron/12.wav",0