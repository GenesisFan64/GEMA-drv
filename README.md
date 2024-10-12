# GEMA-drv
A Sound driver for the Genesis with support for Sega CD, Sega 32X and Sega CD32X running on the Z80

## FEATURES

* Support for Sega CD, Sega 32X and Sega CD32X<br>
* All sound chips supported: PSG, YM2612, RF5C164 (Sega CD) and PWM (Sega 32X), all chips can be used at the same time<br>
* Can read data from RAM with a workaround (a must when using SegaCD's stamps)<br>

### PSG
* Can use Attack, Decay, Sustain and Release<br>
* Noise freq-steal mode "Tone3"<br>


### YM2612
* FM3 Special mode with custom frequencies<br>
* DAC with Sample rate at 16000hz, pitch controlled, can be looped, with DMA protection to keep stable playback.<br>


### RF5C164 (SCD)
* Sample rate at 16000hz, can be looped.<br>
* Support for larger samples with the help of data streaming on Sub-CPU (from Sub's memory to PCM memory)<br>


### PWM (32X)
* Sample rate at 16000hz, can be looped.<br>
* Supports STEREO samples<br>
* Samples are stored in either SDRAM (CD32X compatibilty) or ROM (Cartridge only), if it stored on ROM there's DMA protection when the RV bit is active (WIP, needs more testing)<br>


## REQUIREMENTS

* AS Macro Assembler improved by Flamewing: https://github.com/flamewing/asl-releases/releases/ original AS will not work.<br>
* Python 3<br>

## HOW TO USE

* Extract the AS assembler to these locations depending of the system you are currently using:<br>
/tools/AS/win32<br>
/tools/AS/linux<br>
* Python 3 is required for a script to convert the .p file output into a working binary, it's is also required to convert the music modules.
* Run build.bat (Windows) or build.sh (Linux) to compile the sound tester<br>

#### Making a test track

All the sound data is stored in /sound<br>

Making a test track: You can use the test.it located at /sound/tracks/trkr/<br>
Open it with OpenMPT or any other tracker that supports ImpulseTracker files, after saving the file you need to go back one folder and run the Python3 script itextrct.py and load the file with this command:<br>

python itextrct.py test<br>

It will output the files test_blk.bin and test_patt.bin:<br>
_blk contains the pattern order and _patt contains the music data and it's pointers<br>

To change the instrumentation:<br>
Open the file tracks.asm locate .ins after gtrk_Test0 you'll see the macros gIns(chip), check driver/gema_macros.asm for more info on each chip.

Now run build.bat or build.sh to see the result.<br>

## TODO

Documentation and the limitations of this driver.
