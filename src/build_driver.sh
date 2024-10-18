clear

echo "*** Building driver for EMULATOR-ONLY ***"
echo "-> MD"
tools/AS/asl driver_only.asm -i "." -olist ../drvbin/lst/zdrv_emu_md.lst -q -xx -A -L -D MCD=0,MARS=0,MARSCD=0,PICO=0,EMU=1
python3 "tools/p2bin.py" driver_only.p ../drvbin/zdrv_emu_md.bin
echo "-> 32X"
tools/AS/asl driver_only.asm -i "." -olist ../drvbin/lst/zdrv_emu_mars.lst -q -xx -A -L -D MCD=0,MARS=1,MARSCD=0,PICO=0,EMU=1
python3 "tools/p2bin.py" driver_only.p ../drvbin/zdrv_emu_mars.bin
echo "-> SCD"
tools/AS/asl driver_only.asm -i "." -olist ../drvbin/lst/zdrv_emu_mcd_u.lst -q -xx -A -L -D MCD=1,MARS=0,MARSCD=0,PICO=0,CDREGION=1,EMU=1
python3 "tools/p2bin.py" driver_only.p ../drvbin/zdrv_emu_mcd_u.bin
echo "-> CD32X"
tools/AS/asl driver_only.asm -i "." -olist ../drvbin/lst/zdrv_emu_marscd_u.lst -q -xx -A -L -D MCD=0,MARS=0,MARSCD=1,PICO=0,CDREGION=1,EMU=1
python3 "tools/p2bin.py" driver_only.p ../drvbin/zdrv_emu_marscd_u.bin

echo "*** Building driver for REAL HARDWARE ***"
echo "-> MD"
tools/AS/asl driver_only.asm -i "." -olist ../drvbin/lst/zdrv_md.lst -q -xx -A -L -D MCD=0,MARS=0,MARSCD=0,PICO=0,EMU=0
python3 "tools/p2bin.py" driver_only.p ../drvbin/zdrv_md.bin
echo "-> 32X"
tools/AS/asl driver_only.asm -i "." -olist ../drvbin/lst/zdrv_mars.lst -q -xx -A -L -D MCD=0,MARS=1,MARSCD=0,PICO=0,EMU=0
python3 "tools/p2bin.py" driver_only.p ../drvbin/zdrv_mars.bin
echo "-> SCD"
tools/AS/asl driver_only.asm -i "." -olist ../drvbin/lst/zdrv_mcd_u.lst -q -xx -A -L -D MCD=1,MARS=0,MARSCD=0,PICO=0,CDREGION=1,EMU=0
python3 "tools/p2bin.py" driver_only.p ../drvbin/zdrv_mcd_u.bin
echo "-> CD32X"
tools/AS/asl driver_only.asm -i "." -olist ../drvbin/lst/zdrv_marscd_u.lst -q -xx -A -L -D MCD=0,MARS=0,MARSCD=1,PICO=0,CDREGION=1,EMU=0
python3 "tools/p2bin.py" driver_only.p ../drvbin/zdrv_marscd_u.bin

# delete out files
rm driver_only.p
# rm main.h
