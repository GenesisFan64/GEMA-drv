; ===========================================================================
; -------------------------------------------------------------------
; Default sound data
; -------------------------------------------------------------------

MainGemaSeqList:
	gemaTrk 0,16,gtrk_Test0
	gemaTrk 1,3,gtrk_BGM0
	gemaTrk 0,3,gtrk_BGM1
	gemaTrk 1,6,gtrk_savage
	gemaTrk 1,3,gtrk_song0

; ----------------------------------------------------
gtrk_Test0:
	gemaHead .blk,.pat,.ins,4
.blk:	binclude "sound/seq/test_blk.bin"
.pat:	binclude "sound/seq/test_patt.bin"
.ins:
	gInsPsg    0,$00,$00,$00,$00,$01,$00
	gInsPsgN +12,$00,$00,$00,$00,$01,$00,%011	; Tone3
	gInsFm   -12,FmIns_Trumpet_bus,0
	gInsFm3    0,FmIns_Sp_OpenHat,0
	gInsDac    0,DacIns_TEST,0
	gInsPcm    0,PcmIns_TEST,0
	gInsPwm    0,PwmIns_TEST,%10

; ----------------------------------------------------
gtrk_BGM0:
	gemaHead .blk,.pat,.ins,12
.blk:	binclude "sound/seq/bgm0_blk.bin"
.pat:	binclude "sound/seq/bgm0_patt.bin"
.ins:
	gInsFm -24,FmIns_Trumpet_bus
	gInsFm -12,FmIns_Organ_86;FmIns_Piano_Aqua
	gInsFm -12,FmIns_Bass_Groove_1
	gInsPsg 0,$40,$30,$30,$02,$01,$00
	gInsPsg -12,$00,$00,$00,$00,$01,$00
	gInsFm -12,FmIns_Organ_121;FmIns_Vibraphone_1
	gInsFm -12,FmIns_Brass_eur
; ----------------------------------------------------
gtrk_BGM1:
	gemaHead .blk,.pat,.ins,12
.blk:	binclude "sound/seq/bgm1_blk.bin"
.pat:	binclude "sound/seq/bgm1_patt.bin"
.ins:
	gInsFm -12,FmIns_Trumpet_1
	gInsPsg 0,$30,$10,$10,$03,$05,$00
	gInsFm 0,FmIns_Bass_club
	gInsFm -12,FmIns_Vibraphone_2
	gInsDac +24,DacIns_Kick,0
	gInsNull
	gInsFm3 0,FmIns_Sp_ClosedHat
	gInsDac +24,DacIns_Snare,0
	gInsFm3 0,FmIns_Sp_OpenHat
	gInsFm -24,FmIns_Vibraphone_1
	gInsFm -12,FmIns_Trumpet_bus
	gInsFm 0,FmIns_Xylophone
	gInsNull
	gInsNull
	gInsNull
	gInsNull
	gInsNull
	gInsNull
	gInsNull
	gInsNull

; ----------------------------------------------------
gtrk_savage:
	gemaHead .blk,.pat,.ins,4
.blk:	binclude "sound/seq/savage_blk.bin"
.pat:	binclude "sound/seq/savage_patt.bin"
.ins:
 if MARS
	gInsPwm -12,PwmIns_savage_01,0
	gInsPwm -12,PwmIns_savage_02,0
	gInsPwm -12,PwmIns_savage_03,0
	gInsPwm -12,PwmIns_savage_04,0
	gInsPwm -12,PwmIns_savage_05,0
	gInsPwm -12,PwmIns_savage_06,0
	gInsPwm -12,PwmIns_savage_07,0
	gInsPwm -12,PwmIns_savage_08,0
	gInsPwm -12,PwmIns_savage_09,0
	gInsPwm -12,PwmIns_savage_10,0
	gInsPwm -12,PwmIns_savage_11,0
	gInsPwm -12,PwmIns_savage_12,0
	gInsPwm -12,PwmIns_savage_13,0
	gInsPwm -12,PwmIns_savage_14,0
 else
	gInsPcm -12,PcmIns_savage_01,0
	gInsPcm -12,PcmIns_savage_02,0
	gInsPcm -12,PcmIns_savage_03,0
	gInsPcm -12,PcmIns_savage_04,0
	gInsPcm -12,PcmIns_savage_05,0
	gInsPcm -12,PcmIns_savage_06,0
	gInsPcm -12,PcmIns_savage_07,0
	gInsPcm -12,PcmIns_savage_08,0
	gInsPcm -12,PcmIns_savage_09,0
	gInsPcm -12,PcmIns_savage_10,0
	gInsPcm -12,PcmIns_savage_11,0
	gInsPcm -12,PcmIns_savage_12,0
	gInsPcm -12,PcmIns_savage_13,0
	gInsPcm -12,PcmIns_savage_14,0
 endif

; ----------------------------------------------------
gtrk_song0:
	gemaHead .blk,.pat,.ins,8
.blk:	binclude "sound/seq/song0_blk.bin"
.pat:	binclude "sound/seq/song0_patt.bin"
.ins:
 if MARS
	gInsPwm -12,PwmIns_song0_01,0
	gInsPwm -12,PwmIns_song0_02,0
	gInsFm    0,FmIns_Hats_1
	gInsFm3    0,FmIns_Sp_OpenHat
	gInsPwm -12,PwmIns_song0_05,1
	gInsPwm -12,PwmIns_song0_06,0
	gInsPwm -12,PwmIns_song0_07,0
	gInsPwm -12,PwmIns_song0_08,0
	gInsPwm -12,PwmIns_song0_09,0
 else
	gInsPcm -12,PcmIns_song0_01,0
	gInsPcm -12,PcmIns_song0_02,0
	gInsFm    0,FmIns_Hats_1
	gInsFm3    0,FmIns_Sp_OpenHat
	gInsPcm -12,PcmIns_song0_05,1
	gInsPcm -12,PcmIns_song0_06,0
	gInsPcm -12,PcmIns_song0_07,0
	gInsPcm -12,PcmIns_song0_08,0
	gInsPcm -12,PcmIns_song0_09,0
 endif

; ===========================================================================
; -------------------------------------------------------------------
; GEMA FM instruments
; -------------------------------------------------------------------

; -----------------------------------------------------------
; Normal FM Instruments
; -----------------------------------------------------------

FmIns_Bass_big_81:
		binclude "sound/ins/fm/bin/bass_big_82.bin"
FmIns_Bass_big_110:
		binclude "sound/ins/fm/bin/bass_big_110.bin"
FmIns_Bass_big_114:
		binclude "sound/ins/fm/bin/bass_big_114.bin"
FmIns_Bass_big_122:
		binclude "sound/ins/fm/bin/bass_big_122.bin"
FmIns_Bass_cave_47:
		binclude "sound/ins/fm/bin/bass_cave_47.bin"
FmIns_Bass_club_108:
		binclude "sound/ins/fm/bin/bass_club_108.bin"
FmIns_Bass_foot_75:
		binclude "sound/ins/fm/bin/bass_foot_75.bin"
FmIns_Bass_gem_26:
		binclude "sound/ins/fm/bin/bass_gem_26.bin"
FmIns_Bass_groove_119:
		binclude "sound/ins/fm/bin/bass_groove_119.bin"
FmIns_Bass_heavy_107:
		binclude "sound/ins/fm/bin/bass_heavy_107.bin"
FmIns_Bass_heavy_118:
		binclude "sound/ins/fm/bin/bass_heavy_118.bin"
FmIns_Bass_loud_117:
		binclude "sound/ins/fm/bin/bass_loud_117.bin"
FmIns_bass_low_46:
		binclude "sound/ins/fm/bin/bass_low_46.bin"
FmIns_Bass_Groove_1:
		binclude "sound/ins/fm/bin/bass_groove_1.bin"
FmIns_bass_low_81:
		binclude "sound/ins/fm/bin/bass_low_81.bin"
FmIns_bass_low_103:
		binclude "sound/ins/fm/bin/bass_low_103.bin"
FmIns_bass_low_106:
		binclude "sound/ins/fm/bin/bass_low_106.bin"
FmIns_bass_low_126:
		binclude "sound/ins/fm/bin/bass_low_126.bin"
FmIns_bass_mid_19:
		binclude "sound/ins/fm/bin/bass_mid_19.bin"
FmIns_bass_mid_80:
		binclude "sound/ins/fm/bin/bass_mid_80.bin"
FmIns_bass_mid_111:
		binclude "sound/ins/fm/bin/bass_mid_111.bin"
FmIns_bass_power_123:
		binclude "sound/ins/fm/bin/bass_power_123.bin"
FmIns_bass_silent_53:
		binclude "sound/ins/fm/bin/bass_silent_53.bin"
FmIns_bass_slap_10:
		binclude "sound/ins/fm/bin/bass_slap_10.bin"
FmIns_bass_slap_105:
		binclude "sound/ins/fm/bin/bass_slap_105.bin"
FmIns_bass_synth_60:
		binclude "sound/ins/fm/bin/bass_synth_60.bin"
FmIns_bass_synth_61:
		binclude "sound/ins/fm/bin/bass_synth_61.bin"
FmIns_bass_synth_72:
		binclude "sound/ins/fm/bin/bass_synth_72.bin"
FmIns_bass_synth_73:
		binclude "sound/ins/fm/bin/bass_synth_73.bin"
FmIns_bass_vlow_74:
		binclude "sound/ins/fm/bin/bass_vlow_74.bin"
FmIns_Organ_70:
		binclude "sound/ins/fm/bin/organ_70.bin"
FmIns_Organ_86:
		binclude "sound/ins/fm/bin/organ_86.bin"
FmIns_Organ_115:
		binclude "sound/ins/fm/bin/organ_115.bin"
FmIns_Organ_121:
		binclude "sound/ins/fm/bin/organ_121.bin"

FmIns_Flaute_1:
		binclude "sound/ins/fm/bin/flaute_1.bin"
FmIns_Flaute_2:
		binclude "sound/ins/fm/bin/flaute_2.bin"
FmIns_Vibraphone_1:
		binclude "sound/ins/fm/bin/vibraphone_1.bin"
FmIns_Vibraphone_2:
		binclude "sound/ins/fm/bin/vibraphone_2.bin"
FmIns_Xylophone:
		binclude "sound/ins/fm/bin/xylophone2_43.bin"
FmIns_Bass_low81:
		binclude "sound/ins/fm/bin/bass_low_46.bin"
FmIns_Trumpet_low:
		binclude "sound/ins/fm/bin/trumpet_low.bin"
FmIns_Trumpet_genie:
		binclude "sound/ins/fm/bin/trumpet_genie.bin"
FmIns_Trumpet_bus:
		binclude "sound/ins/fm/bin/trumpet_bus.bin"
FmIns_Hats_1:
		binclude "sound/ins/fm/bin/hats_96.bin"
FmIns_Bell_mid36:
		binclude "sound/ins/fm/bin/bell_mid_36.bin"
FmIns_Drum_Kick:
		binclude "sound/ins/fm/bin/kick_low.bin"
FmIns_Tick:
		binclude "sound/ins/fm/bin/tick_44.bin"

; -----------------------------------------------------------
; Special FM3 Instruments
; -----------------------------------------------------------

FmSpIns_clack_1:
		binclude "sound/ins/fm/bin/fm3_clack_1.bin"
FmSpIns_cowbell_h:
		binclude "sound/ins/fm/bin/fm3_cowbell_h.bin"
FmSpIns_cowbell_l:
		binclude "sound/ins/fm/bin/fm3_cowbell_l.bin"
FmSpIns_hats_hq:
		binclude "sound/ins/fm/bin/fm3_hats_hq.bin"
FmSpIns_sfx_alien:
		binclude "sound/ins/fm/bin/fm3_sfx_alien.bin"
FmSpIns_sfx_knckbuzz:
		binclude "sound/ins/fm/bin/fm3_sfx_knckbuzz.bin"
FmSpIns_sfx_knock_h:
		binclude "sound/ins/fm/bin/fm3_sfx_knock_h.bin"
FmSpIns_sfx_knock_l:
		binclude "sound/ins/fm/bin/fm3_sfx_knock_l.bin"
FmSpIns_sfx_laser:
		binclude "sound/ins/fm/bin/fm3_sfx_laser.bin"

; -----------------------------------------------------------
; FM sound effects
; -----------------------------------------------------------

FmIns_sfx_punch:
		binclude "sound/ins/fm/bin/sfx_punch.bin"
FmIns_sfx_slash:
		binclude "sound/ins/fm/bin/sfx_slash.bin"
FmIns_sfx_alien1:
		binclude "sound/ins/fm/bin/sfx_alien_83.bin"
FmIns_sfx_alien2:
		binclude "sound/ins/fm/bin/sfx_alien_84.bin"

; ====================================================================
; OLD gsx patches:

FmIns_Sp_OpenHat:
		binclude "sound/ins/fm/gsx/fm3_openhat.gsx",$2478,$28
FmIns_Sp_ClosedHat:
		binclude "sound/ins/fm/gsx/fm3_closedhat.gsx",$2478,$28
FmIns_Sp_Cowbell:
		binclude "sound/ins/fm/gsx/fm3_cowbell.gsx",$2478,$28
FmIns_Drums_Kick1:
		binclude "sound/ins/fm/gsx/drum_kick_gem.gsx",$2478,$20
FmIns_Piano_Aqua:
		binclude "sound/ins/fm/gsx/piano_aqua.gsx",$2478,$20
FmIns_HBeat_tom:
		binclude "sound/ins/fm/gsx/nadia_tom.gsx",$2478,$20
FmIns_Trumpet_1:
		binclude "sound/ins/fm/gsx/trumpet_1.gsx",$2478,$20
FmIns_Bass_duck:
		binclude "sound/ins/fm/gsx/bass_duck.gsx",$2478,$20
FmIns_ClosedHat:
		binclude "sound/ins/fm/gsx/hats_closed.gsx",$2478,$20
FmIns_Trumpet_carnival:
		binclude "sound/ins/fm/gsx/OLD_trumpet_carnivl.gsx",$2478,$20
FmIns_Bass_club:
		binclude "sound/ins/fm/gsx/OLD_bass_club.gsx",$2478,$20
FmIns_Bass_groove_2:
		binclude "sound/ins/fm/gsx/bass_groove_2.gsx",$2478,$20
FmIns_PSynth_plus:
		binclude "sound/ins/fm/gsx/psynth_plus.gsx",$2478,$20
FmIns_Brass_7:
		binclude "sound/ins/fm/gsx/brass_7.gsx",$2478,$20
FmIns_Brass_eur:
		binclude "sound/ins/fm/gsx/brass_eur.gsx",$2478,$20

; ===========================================================================
; -------------------------------------------------------------------
; GEMA/Nikona DAC samples
;
; 16000hz base
; -------------------------------------------------------------------

		align $800
		;gSmplData Label,"file_path",loop_start
; -----------------------------------------------------------
		gSmplData DacIns_TEST,"sound/ins/smpl/test.wav",0
		gSmplData DacIns_Kick,"sound/ins/smpl/kick.wav",0
		gSmplData DacIns_Snare,"sound/ins/smpl/snare.wav",0
