# GEMA-drv
A Sound driver for the Genesis with support for Sega CD, Sega 32X and Sega CD32X running on the Z80

## FEATURES

* Support for Sega CD, Sega 32X and Sega CD32X (REQUIRES special playback code for SCD's Sub-CPU and 32X's Slave SH2)<br>
* All sound chips supported and can be used at the same time<br>
* Works on real hardware (ONLY tested Genesis and 32X, I don't have the Sega CD but it should work)


### PSG
* Can use Attack, Decay, Sustain and Release<br>
* Support for NOISE channel's frequency-steal mode<br>


### YM2612
* FM3 Special mode with manual OP frequencies<br>
* DAC with Sample rate at 16000hz base<br>
* Pitch controlled, can be looped.<br>
* Has DMA-protection to keep stable playback<br>


### RF5C164 (SCD)
* Sample rate at 16000hz base, can be looped.<br>
* Support for larger samples with the help of data streaming on Sub-CPU (from Sub's memory to PCM memory)<br>


### PWM (32X)
* Sample rate at 16000hz base, can be looped.<br>
* Supports STEREO samples<br>
* Samples are stored in either SDRAM (CD32X compatibilty) or ROM (Cartridge only)<br>
* For the samples stored at ROM: DMA protection when the RV bit is active (WIP, needs more testing)<br>


## REQUIREMENTS

* AS Macro Assembler improved by Flamewing: https://github.com/flamewing/asl-releases/releases/ ORIGINAL AS WILL NOT WORK.<br>
* Python 3, already included on most Linux distros<br>

## HOW TO USE

* Go to /tester
* Extract the AS assembler to these locations depending of the system you are currently using:<br>
/tools/AS/win32<br>
/tools/AS/linux<br>
* Python 3 is required for a script to convert the .p file output into a working binary, It is also required to convert the music modules.<br>
* Run build.bat (Windows) or build.sh (Linux) to compile the sound tester<br>

## TODO

Documentation is located at /sound/doc/<br>
work-in-progress<br>
