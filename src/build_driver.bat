@ECHO OFF
CLS
set AS_MSGPATH=tools/AS
set USEANSI=n

echo *** Building driver for EMULATOR-ONLY ***
echo * MD
"tools/AS/asw" driver_only.asm -i "%cd%" -olist "../drvbin/lst/zdrv_emu_md.lst" -q -xx -A -L -D MCD=0,MARS=0,MARSCD=0,PICO=0,EMU=1
python3 "tools/p2bin.py" driver_only.p "../drvbin/zdrv_emu_md.bin"
REM echo * PICO
REM "tools/AS/asw" driver_only.asm -i "%cd%" -olist "../drvbin/lst/zdrv_emu_pico.lst" -q -xx -A -L -D MCD=0,MARS=0,MARSCD=0,PICO=1,EMU=1
REM python3 "tools/p2bin.py" driver_only.p "../drvbin/zdrv_emu_pico.bin"
echo * 32X
"tools/AS/asw" driver_only.asm -i "%cd%" -olist "../drvbin/lst/zdrv_emu_mars.lst" -q -xx -A -L -D MCD=0,MARS=1,MARSCD=0,PICO=0,EMU=1
python3 "tools/p2bin.py" driver_only.p "../drvbin/zdrv_emu_mars.bin"
echo * SCD
"tools/AS/asw" driver_only.asm -i "%cd%" -olist "../drvbin/lst/zdrv_emu_mcd_u.lst" -q -xx -A -L -D MCD=1,MARS=0,MARSCD=0,PICO=0,EMU=1,CDREGION=1
python3 "tools/p2bin.py" driver_only.p "../drvbin/zdrv_emu_mcd_u.bin"
echo * CD32X
"tools/AS/asw" driver_only.asm -i "%cd%" -olist "../drvbin/lst/zdrv_emu_marscd_u.lst" -q -xx -A -L -D MCD=0,MARS=0,MARSCD=1,PICO=0,EMU=1,CDREGION=1
python3 "tools/p2bin.py" driver_only.p "../drvbin/zdrv_emu_marscd_u.bin"

echo *** Building driver for REAL HARDWARE ***
echo * MD
"tools/AS/asw" driver_only.asm -i "%cd%" -olist "../drvbin/lst/zdrv_md.lst" -q -xx -A -L -D MCD=0,MARS=0,MARSCD=0,PICO=0,EMU=0
python3 "tools/p2bin.py" driver_only.p "../drvbin/zdrv_md.bin"
REM echo * PICO
REM "tools/AS/asw" driver_only.asm -i "%cd%" -olist "../drvbin/lst/zdrv_pico.lst" -q -xx -A -L -D MCD=0,MARS=0,MARSCD=0,PICO=1,EMU=0
REM python3 "tools/p2bin.py" driver_only.p "../drvbin/zdrv_pico.bin"
echo * 32X
"tools/AS/asw" driver_only.asm -i "%cd%" -olist "../drvbin/lst/zdrv_mars.lst" -q -xx -A -L -D MCD=0,MARS=1,MARSCD=0,PICO=0,EMU=0
python3 "tools/p2bin.py" driver_only.p "../drvbin/zdrv_mars.bin"
echo * SCD
"tools/AS/asw" driver_only.asm -i "%cd%" -olist "../drvbin/lst/zdrv_mcd_u.lst" -q -xx -A -L -D MCD=1,MARS=0,MARSCD=0,PICO=0,EMU=0,CDREGION=1
python3 "tools/p2bin.py" driver_only.p "../drvbin/zdrv_mcd_u.bin"
echo * CD32X
"tools/AS/asw" driver_only.asm -i "%cd%" -olist "../drvbin/lst/zdrv_marscd_u.lst" -q -xx -A -L -D MCD=0,MARS=0,MARSCD=1,PICO=0,EMU=0,CDREGION=1
python3 "tools/p2bin.py" driver_only.p "../drvbin/zdrv_marscd_u.bin"

IF EXIST driver_only.p del driver_only.p
REM IF EXIST driver_only.h del driver_only.h
