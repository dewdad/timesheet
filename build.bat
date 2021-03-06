@ECHO OFF
set zip="C:\Program Files\7-Zip\7z.exe"

ECHO ==============================================
ECHO Removing aftifacts from the previous build ...
IF EXIST .\build\timesheet.exe del .\build\timesheet.exe
IF EXIST .\build\timesheet.app del .\build\timesheet.app
IF EXIST .\build\timesheet.bin del .\build\timesheet.bin
IF EXIST .\build\timesheet.yaml del .\build\timesheet.yaml
IF EXIST .\build\MS_Windows_64bit.zip del .\build\MS_Windows_64bit.zip
IF EXIST .\build\Linux_64bit.zip del .\build\Linux_64bit.zip
IF EXIST .\build\Mac_OS_X_64bit.zip del .\build\Mac_OS_X_64bit.zip
IF EXIST .\build\client\dist\ @RD /S /Q .\build\client\dist
del .\build\data\*.csv /F /Q

ECHO ======================
ECHO Compiling frontend ...
cd .\client
call npm run build
xcopy .\dist .\..\build\client\dist\ /s /e
cd ..

ECHO =====================
ECHO Compiling backend ...
copy .\timesheet.yaml .\build\timesheet.yaml
copy .\data\consultants_demo.csv .\build\data\consultants_demo.csv
copy .\data\holidays_us_2019.csv .\build\data\holidays_us_2019.csv
copy .\data\projects_demo.csv .\build\data\projects_demo.csv
copy .\data\rates_demo.csv .\build\data\rates_demo.csv
copy .\data\reportedRecords_demo.csv .\build\data\reportedRecords_demo.csv
ECHO MS Windows ...
set GOOS=windows
set GOARCH=amd64
go build -o .\build\timesheet.exe .\timesheet.go
ECHO Linux ...
set GOOS=linux
set GOARCH=amd64
go build -o .\build\timesheet.bin .\timesheet.go
ECHO MAC OS X ...
set GOOS=darwin
set GOARCH=amd64
go build -o .\build\timesheet.app .\timesheet.go

ECHO =========================
ECHO Compressing artifacts ...
cd .\build
call %zip% a -r MS_Windows_64bit.zip timesheet.exe timesheet.yaml client/ data/
call %zip% a -r Linux_64bit.zip ./timesheet.bin ./timesheet.yaml client/ data/
call %zip% a -r Mac_OS_X_64bit.zip ./timesheet.app ./timesheet.yaml client/ data/
cd ..

ECHO ===========
ECHO Builds ready

@ECHO ON