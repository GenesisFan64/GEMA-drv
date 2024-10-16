# GEMA Sound Driver (GEMA-drv)
A Sound driver for the Genesis with support for Sega CD, Sega 32X and Sega CD32X<br>

## FEATURES

* Runs entirely on Z80<br>
* All sound chips supported: PSG, YM2612, RF5C164 and PWM and can be used at the same time, a single track can use up to 26 channels<br>
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

* Go to `/src/tools`<br>
* Extract the AS assembler to these locations depending of the system you are currently using:<br>
`/tools/AS/win32`<br>
`/tools/AS/linux`<br>

### Building the sound tester

* Run `make_tester.sh` on Linux or `make_tester.bat` on Windows
* Output ROMS will be located at bin, `rom_(system)` are for real hardware and `rom_emu_(system)` are for emulators, SegaCD/CD32X: the letters j, u, e represent th region.

The tester uses code from NikonaMD which you can check here: https://github.com/GenesisFan64/NikonaMD

### Building the Z80 driver binary

* Run `make_driver.sh` on Linux or `make_driver.bat` on Windows
* Output binaries are located at /drvbin, `zdrv_(system)` are for real hardware and `zdrv_emu(system)` for emulation, only difference is a few NOPs with the DAC playback.

## TODO

Partial documentation for the driver is located at /doc *in Spanish, I'll do english later.*<br>

Currently the standard driver (PSG+YM2612) is the only one that can be used on other SEGA-dev environments like SGDK, Support for the PCM and PWM chips require special playback code on SCD's Sub-CPU and 32X's Slave SH2<br>
