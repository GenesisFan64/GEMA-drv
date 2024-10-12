; ===========================================================================
; -------------------------------------------------------------------
; Main sound data
; -------------------------------------------------------------------

MainGemaSeqList:
	gemaTrk 0,14,gtrk_Test0
	gemaTrk 1,6,gtrk_Test1

; ----------------------------------------------------
gtrk_Test0:
	gemaHead .blk,.pat,.ins,4
.blk:	binclude "sound/tracks/test_blk.bin"
.pat:	binclude "sound/tracks/test_patt.bin"
.ins:
	gInsPsg    0,$00,$00,$00,$00,$01,$00
	gInsPsgN +12,$00,$00,$00,$00,$01,$00,%011		; Tone3
	gInsFm   -12,FmIns_Trumpet_bus,0
	gInsFm3    0,FmIns_Sp_OpenHat,0
	gInsDac    0,DacIns_TEST,0
	gInsPcm    0,PcmIns_TEST,0
	gInsPwm    0,PwmIns_TEST,%10

; ----------------------------------------------------
gtrk_Test1:
	gemaHead .blk,.pat,.ins,4
.blk:	binclude "sound/tracks/sauron_blk.bin"
.pat:	binclude "sound/tracks/sauron_patt.bin"
.ins:
	gInsPcm -12,PcmIns_sauron_01,0
	gInsPcm -12,PcmIns_sauron_02,0
	gInsPcm -12,PcmIns_sauron_03,0
	gInsPcm -12,PcmIns_sauron_04,0
	gInsPcm -12,PcmIns_sauron_05,1
	gInsPcm -12,PcmIns_sauron_06,0
	gInsPcm -12,PcmIns_sauron_07,0
	gInsPcm -12,PcmIns_sauron_08,0
	gInsPcm -12,PcmIns_sauron_09,0
	gInsPcm -12,PcmIns_sauron_10,0
	gInsPcm -12,PcmIns_sauron_11,0
	gInsPcm -12,PcmIns_sauron_12,0
	gInsNull

; ===========================================================================
; -------------------------------------------------------------------
; GEMA/Nikona FM instruments
; -------------------------------------------------------------------

; -----------------------------------------------------------
; Normal FM Instruments
; -----------------------------------------------------------

FmIns_Bass_big_81:
		binclude "sound/instr/fm/bin/bass_big_82.bin"
FmIns_Bass_big_110:
		binclude "sound/instr/fm/bin/bass_big_110.bin"
FmIns_Bass_big_114:
		binclude "sound/instr/fm/bin/bass_big_114.bin"
FmIns_Bass_big_122:
		binclude "sound/instr/fm/bin/bass_big_122.bin"
FmIns_Bass_cave_47:
		binclude "sound/instr/fm/bin/bass_cave_47.bin"
FmIns_Bass_club_108:
		binclude "sound/instr/fm/bin/bass_club_108.bin"
FmIns_Bass_foot_75:
		binclude "sound/instr/fm/bin/bass_foot_75.bin"
FmIns_Bass_gem_26:
		binclude "sound/instr/fm/bin/bass_gem_26.bin"
FmIns_Bass_groove_119:
		binclude "sound/instr/fm/bin/bass_groove_119.bin"
FmIns_Bass_heavy_107:
		binclude "sound/instr/fm/bin/bass_heavy_107.bin"
FmIns_Bass_heavy_118:
		binclude "sound/instr/fm/bin/bass_heavy_118.bin"
FmIns_Bass_loud_117:
		binclude "sound/instr/fm/bin/bass_loud_117.bin"
FmIns_bass_low_46:
		binclude "sound/instr/fm/bin/bass_low_46.bin"
FmIns_Bass_Groove_1:
		binclude "sound/instr/fm/bin/bass_groove_1.bin"
FmIns_bass_low_81:
		binclude "sound/instr/fm/bin/bass_low_81.bin"
FmIns_bass_low_103:
		binclude "sound/instr/fm/bin/bass_low_103.bin"
FmIns_bass_low_106:
		binclude "sound/instr/fm/bin/bass_low_106.bin"
FmIns_bass_low_126:
		binclude "sound/instr/fm/bin/bass_low_126.bin"
FmIns_bass_mid_19:
		binclude "sound/instr/fm/bin/bass_mid_19.bin"
FmIns_bass_mid_80:
		binclude "sound/instr/fm/bin/bass_mid_80.bin"
FmIns_bass_mid_111:
		binclude "sound/instr/fm/bin/bass_mid_111.bin"
FmIns_bass_power_123:
		binclude "sound/instr/fm/bin/bass_power_123.bin"
FmIns_bass_silent_53:
		binclude "sound/instr/fm/bin/bass_silent_53.bin"
FmIns_bass_slap_10:
		binclude "sound/instr/fm/bin/bass_slap_10.bin"
FmIns_bass_slap_105:
		binclude "sound/instr/fm/bin/bass_slap_105.bin"
FmIns_bass_synth_60:
		binclude "sound/instr/fm/bin/bass_synth_60.bin"
FmIns_bass_synth_61:
		binclude "sound/instr/fm/bin/bass_synth_61.bin"
FmIns_bass_synth_72:
		binclude "sound/instr/fm/bin/bass_synth_72.bin"
FmIns_bass_synth_73:
		binclude "sound/instr/fm/bin/bass_synth_73.bin"
FmIns_bass_vlow_74:
		binclude "sound/instr/fm/bin/bass_vlow_74.bin"
FmIns_Organ_drawbar:
		binclude "sound/instr/fm/bin/organ_drawbar.bin"
FmIns_Flaute_1:
		binclude "sound/instr/fm/bin/flaute_1.bin"
FmIns_Flaute_2:
		binclude "sound/instr/fm/bin/flaute_2.bin"
FmIns_Vibraphone_1:
		binclude "sound/instr/fm/bin/vibraphone_1.bin"
FmIns_Vibraphone_2:
		binclude "sound/instr/fm/bin/vibraphone_2.bin"
FmIns_Xylophone:
		binclude "sound/instr/fm/bin/xylophone2_43.bin"
FmIns_Bass_low81:
		binclude "sound/instr/fm/bin/bass_low_46.bin"
FmIns_Trumpet_low:
		binclude "sound/instr/fm/bin/trumpet_low.bin"
FmIns_Trumpet_genie:
		binclude "sound/instr/fm/bin/trumpet_genie.bin"
FmIns_Trumpet_bus:
		binclude "sound/instr/fm/bin/trumpet_bus.bin"
FmIns_Hats_1:
		binclude "sound/instr/fm/bin/hats_96.bin"
FmIns_Bell_mid36:
		binclude "sound/instr/fm/bin/bell_mid_36.bin"
FmIns_Drum_Kick:
		binclude "sound/instr/fm/bin/kick_low.bin"
FmIns_Tick:
		binclude "sound/instr/fm/bin/tick_44.bin"

; -----------------------------------------------------------
; Special FM3 Instruments
; -----------------------------------------------------------

FmSpIns_clack_1:
		binclude "sound/instr/fm/bin/fm3_clack_1.bin"
FmSpIns_cowbell_h:
		binclude "sound/instr/fm/bin/fm3_cowbell_h.bin"
FmSpIns_cowbell_l:
		binclude "sound/instr/fm/bin/fm3_cowbell_l.bin"
FmSpIns_hats_hq:
		binclude "sound/instr/fm/bin/fm3_hats_hq.bin"
FmSpIns_sfx_alien:
		binclude "sound/instr/fm/bin/fm3_sfx_alien.bin"
FmSpIns_sfx_knckbuzz:
		binclude "sound/instr/fm/bin/fm3_sfx_knckbuzz.bin"
FmSpIns_sfx_knock_h:
		binclude "sound/instr/fm/bin/fm3_sfx_knock_h.bin"
FmSpIns_sfx_knock_l:
		binclude "sound/instr/fm/bin/fm3_sfx_knock_l.bin"
FmSpIns_sfx_laser:
		binclude "sound/instr/fm/bin/fm3_sfx_laser.bin"

; -----------------------------------------------------------
; FM sound effects
; -----------------------------------------------------------

FmIns_sfx_punch:
		binclude "sound/instr/fm/bin/sfx_punch.bin"
FmIns_sfx_slash:
		binclude "sound/instr/fm/bin/sfx_slash.bin"
FmIns_sfx_alien1:
		binclude "sound/instr/fm/bin/sfx_alien_83.bin"
FmIns_sfx_alien2:
		binclude "sound/instr/fm/bin/sfx_alien_84.bin"

; ====================================================================

; FM3 Special
FmIns_Sp_OpenHat:
		binclude "sound/instr/fm/gsx/fm3_openhat.gsx",$2478,$28
FmIns_Sp_ClosedHat:
		binclude "sound/instr/fm/gsx/fm3_closedhat.gsx",$2478,$28
FmIns_Sp_Cowbell:
		binclude "sound/instr/fm/gsx/fm3_cowbell.gsx",$2478,$28
FmIns_Drums_Kick1:
		binclude "sound/instr/fm/gsx/drum_kick_gem.gsx",$2478,$20
FmIns_Piano_Aqua:
		binclude "sound/instr/fm/gsx/piano_aqua.gsx",$2478,$20
FmIns_HBeat_tom:
		binclude "sound/instr/fm/gsx/nadia_tom.gsx",$2478,$20
FmIns_Trumpet_1:
		binclude "sound/instr/fm/gsx/trumpet_1.gsx",$2478,$20
FmIns_Bass_duck:
		binclude "sound/instr/fm/gsx/bass_duck.gsx",$2478,$20
FmIns_ClosedHat:
		binclude "sound/instr/fm/gsx/hats_closed.gsx",$2478,$20
FmIns_Trumpet_carnival:
		binclude "sound/instr/fm/gsx/OLD_trumpet_carnivl.gsx",$2478,$20
FmIns_Bass_club:
		binclude "sound/instr/fm/gsx/OLD_bass_club.gsx",$2478,$20
FmIns_Bass_groove_2:
		binclude "sound/instr/fm/gsx/bass_groove_2.gsx",$2478,$20
FmIns_PSynth_plus:
		binclude "sound/instr/fm/gsx/psynth_plus.gsx",$2478,$20
FmIns_Brass_7:
		binclude "sound/instr/fm/gsx/brass_7.gsx",$2478,$20

; ===========================================================================
; -------------------------------------------------------------------
; GEMA/Nikona DAC samples
;
; 16000hz base
; -------------------------------------------------------------------

		align $800
		;gSmplData Label,"file_path",loop_start
; -----------------------------------------------------------
		gSmplData DacIns_TEST,"sound/instr/smpl/test.wav",0
