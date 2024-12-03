@ECHO OFF
CLS
CD src
build.bat
CD ..
COPY /src/out/emu/*.bin /
