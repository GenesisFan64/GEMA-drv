# GEMA Sound Driver (GEMA-drv)
A sound driver for the Genesis with support for Sega CD, Sega 32X and Sega CD32X<br>

## FEATURES

* Runs entirely on Z80, PCM and PWM playback is done through direct communication from Z80 to each add-on's specific CPU<br>
* All sound chips supported: PSG, YM2612, RF5C164 and PWM and can be used at the same time, a single track sequence can use up to 26 channels<br>
* Works on real hardware (ONLY tested Genesis and 32X, I don't have the Sega CD but it should work)<br>


### PSG
* Can use Attack, Decay, Sustain and Release<br>
* Support for NOISE channel's frequency-steal mode<br>


### YM2612
* FM3 Special mode with manual OP frequencies<br>
* DAC with Sample rate at 16000hz base, pitch controlled, can be looped, has quality protection when doing DMA<br>


### RF5C164 (Sega CD)
* Sample rate at 16000hz base, can be looped.<br>
* Support for larger samples by streaming data on Sub-CPU (from SUB-CPU's memory to PCM memory)<br>


### PWM (Sega 32X)
* Sample rate at 16000hz base, can be looped.<br>
* Supports STEREO samples<br>
* Samples are stored in either SDRAM (CD32X compatibilty) or ROM (Cartridge only)<br>
* For the samples stored at ROM: DMA protection when the RV bit is active (WIP, needs more testing)<br>


## REQUIREMENTS

* AS Macro Assembler improved by Flamewing: https://github.com/flamewing/asl-releases/releases/ ORIGINAL AS WILL NOT WORK.<br>
* Python 3, already included on most Linux distros<br>

## HOW TO USE

### Setting up the assembler

* Pick your version: linux ("ubuntu") or win32
* Go to `/src/tools`<br>
* Make the folder `AS` and extract the contents there<br>

### Building the sound tester

* Music data is located at `sound/seq`, FM instruments and samples on `sound/ins`
* The sequence list, instruments and DAC samples are located on `sound/data.asm`, PCM and PWM samples are stored separately.
* Sub-beats are loaded externally: open `src/game/code/sound_test.asm` and go to the label `exgema_beats`, the sub-beats are sorted the same order as the sequence list. (I don't have the exact formula to convert to IT tempo, but the value 214 corresponds to tempo 125)
* OPTIONAL: on the same file but at the very top, there's 2 boolean settings: `VIEW_GEMAINFO` and `VIEW_FAIRY`, VIEW_GEMAINFO toggles the note playback status but causes a small loss of DAC quality and VIEW_FAIRY toggles the status fairies (in case you don't like those)
* Run `make_tester.sh` on Linux or `make_tester.bat` on Windows
* Output ROMS will be located at /bin: the `rom_(system)` rom are for real hardware and `rom_emu_(system)` are for emulators, SegaCD/CD32X: the letters j, u, e represent the region.

The tester uses code a copy of NikonaMD which you can check here: https://github.com/GenesisFan64/NikonaMD

### Using this driver in your project

* Build the Z80 binary by running `make_driver.sh` on Linux or `make_driver.bat` on Windows, output files will be located at /drvbin: The `zdrv_(system)` files are for real hardware and `zdrv_emu_(system)` for emulation, only difference is a few NOPs with the DAC playback.<br>
**Currently the standard driver zdrv_md.bin / zdrv_emu_md.bin is the only one that can be used outside of this code, support for the PCM and PWM chips require special playback code on SCD's Sub-CPU and 32X's Slave SH2**<br>
The `gema_macros.asm` file uses the variables `MCD`, `MARS` and `MARSCD` for detecting the current target system, if you are not using PCM and PWM you can delete the macros `gInsPcm` and `gInsPwm`, also the variables at `gSmplData`, `gSmplRaw`.

* Include the Z80 binary like this:<br>
    Z80_CODE:
    		binclude "zdrv_md.bin"
    Z80_CODE_END:

* Include the files `sound/driver/gema.asm`, `sound/driver/gema_macros.asm` in your code.<br>
If your assembler doesn't support dotted labels (ASM68k...) change the dots to @

* You can check the list of sound calls (play, stop, fade) at gema.asm<br>

If you can implement PCM and PWM manually: (Requires knowdage of both Sega CD and 32X)<br>
* PCM code is located at `src/system/mcd/marscd.asm` at CdSub_PCM_Process
* PWM at: `src/system/mars/sound.asm` `src/system/mars/main.asm` (at s_irq_cmd) and `src/system/mars/cache/cache_slv.asm` (playback code loaded to SH2's Slave CACHE)

## CURRENT ISSUES

* YM2612: Changing from FM3 Special to Normal might cause a click
* w/32X: PWM sample volume is lower that the other chips

Documentation for the driver is located at /doc<br>
