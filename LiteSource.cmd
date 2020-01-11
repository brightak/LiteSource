@ECHO OFF

SETLOCAL ENABLEDELAYEDEXPANSION

rem SET File Differencer here (e.g. "C:\Program Files (x86)\Folder\Application.exe" %%1 %%2).
SET _Diff_App_=

SET _ForceCommit_=Y
SET _Folder_=
SET _SubFolderSwitch_=
SET REPO_FLDR=+%~n0
SET delims=
SET ChangeCount=0
rem Unset _exc_
SET _exc_=
rem Unset _inc_
SET _inc_=
rem Unset Msg
SET Msg=
SET _NothingIsDeleted_=

rem If no arguments, just start.
if [%1] EQU [] GOTO :NoArgs

set _FilesSpecified_=
SET _Date_=
:: Unset all variables starting with ?.  ASSUMES ? is an illegal char for a filename.
FOR  /F "delims==" %%a In ('set ? 2^>Nul') DO SET "%%a="
:LoopArgs

:: If this argument is /?, help.
If '%1' EQU '/?' GOTO :Help

color 1f

:: If it's not /C, look for a date.
IF '%1' NEQ '/C' IF '%1' NEQ '/c' GOTO :SeekDate

::If the next arg is not a thing, goto help.
IF [%2] EQU [] ECHO Please specify a message when committing. & PAUSE & GOTO :EOF

::If Msg is already assigned, goto help.
IF defined Msg GOTO :Help

:: Otherwise, get the next arg and set it as the commit message.
SHIFT /1
SET Msg=%1

:: Trim any leading or trailing quotes.  TODO: What if the message has quotes?
for /f delims^=^"^ tokens^=1* %%f in ('echo %Msg%') do set Msg=%%f

:: If the message is not more than 5 chars, complain and quit.
IF "!Msg:~0,5!" EQU "!Msg!" ECHO Commit Message must be 5 chars+. & pause & GOTO :eof

GOTO :RinseAndRepeat
:SeekDate
:: If this argument isn't /D, look for a file.
IF '%1' NEQ '/D' IF '%1' NEQ '/d' GOTO :SeekFile

:: If the arg is /D, ensure that %2 is a thing.
IF [%2] EQU [] ECHO Please specify a date when using /D. & pause & GOTO :EOF

:: If Date is already a thing, goto help.
IF DEFINED _Date_ GOTO :HELP

:: Otherwise, get the next arg and set it as the date.
SHIFT /1
SET _date_=%1

:: If it's numeric...
call :IsNumeric _date_ && (
	rem ...if the date is less than 1900...
	if !_date_! LSS 1900 (
		:: Otherwise, get today's date in julian format...
		CALL :JDate d
		:: ...subtract the input...
		set /a d-=%_date_%
		:: ...and save the result as a date.
		call :JulianToDate d _date_
		:: Then rinse and repeat.
		GOTO :RinseAndRepeat.
	)
	rem Otherwise, assume it was in YYYYMMDD format.
	set _date_=%_date_:~5,2%/%_date_:~7,2%/%_date_:~1,4%
)

set "MM=%_date_:~4,2%"
set "DD=%_date_:~6,2%"
set "YYYY=%_date_:~0,4%"
set /A month=1%MM%-100, day=1%DD%-100, year=1%YYYY%-10000 2>NUL
if errorlevel 1 GOTO :Help

:: If the day is less than the first, quit gracefully.
if '%DD%' LSS '01' ECHO Please specify a valid date. & pause & GOTO :eof

:: If the month is less than the first, quit gracefully.
if '%MM%' LSS '01' ECHO Please specify a valid date. & pause & GOTO :eof

:: If the month is more than the twelfth, quit gracefully.
if '%MM%' GTR '12' ECHO Please specify a valid date. & pause & GOTO :eof

:: If the century wasn't specified, assume the 21st.
if '%YYYY%' LSS '0100' SET YYYY=20%YYYY:~-2%

:: Assume the maximum number of days is 30.
SET MaxDays=30

:: If the month is February...
IF '%MM%' EQU '02' (

	:: ...set the maximum days to 28...
	SET MaxDays=28

	:: ...and find out if the year is a leap year...
	IF '%YYYY:~-2%' NEQ '00' (
		:: ...and if it is...
		SET /A Y=%YYYY%%%4
		:: ...set the maximum days to 29.
		IF !Y! EQU 0 SET MaxDays=29
	)

) ELSE (

	:: Otherwise, unless the month is April, June, September or November, set the maximum days to 31.
	if '%MM%' NEQ '04' if '%MM%' NEQ '06' if '%MM%' NEQ '09' if '%MM%' NEQ '11' SET MaxDays=31

)

:: If the day is more than the last for this month, quit gracefully.
IF '%DD%' gtr '%MaxDays%' ECHO Please specify a valid date. & pause & GOTO :eof

SET _date_=%MM%/%DD%/%YYYY%

GOTO :RinseAndRepeat
:SeekFile
If '%1' EQU '/S' SET _SubFolderSwitch_= /S&GOTO :RinseAndRepeat
If '%1' EQU '/s' SET _SubFolderSwitch_= /S&GOTO :RinseAndRepeat
	
:: If it's not one of the above, assume it's a file or folder.
:: If it doesn't exist...
If not exist %1 (
	:: ...complain...
	ECHO File/folder not found: %1
	:: ...wait for user response...
	pause
	:: ...and quit.
	GOTO :EOF
)

:: If _Folder_ is already assigned and this is a first rodeo, quit.
if defined _Folder_ if not exist "%REPO_FLDR%\Restore.cmd" (
	ECHO Please specify one path only.
	pause
	goto :EOF
)

:: Otherwise...
set str=%1
:: ...remove all quotes.
set str=%str:"=%
:: Ensure no \\.
rem set str=%str:\\=\%

:: If this is a folder, remember it.  Otherwise, remember the subfolder.
call :IsFolder "%str%" && SET _Folder_=%str% || for /f "delims=" %%f in ("%str%") do SET _Folder_=%%~dpf

:: Wrap str in quotes...
SET str="%str%"
:: ...drop any trailing \...
SET str=%str:\"="%
:: ...and remove quotes.
SET str=%str:"=%

:: If Restore.cmd is a thing...
if exist "%REPO_FLDR%\Restore.cmd" (

	:: ...get the Project folder from Restore.cmd...
	FOR /F "TOKENS=1-2 DELIMS=^=" %%F IN ('FIND "SET PJCT_FLDR=" "%REPO_FLDR%\Restore.cmd"') DO SET _Project_Folder_=%%G
	rem for /f tokens^=1-2^ delims^=^" %%f in ('findstr /R /N "^.*$" "%REPO_FLDR%\Include.txt" ^| findstr /B "1:"') do SET _Project_Folder_=%%g
	
	:: ...and if the input is not in the Project Folder, Goto Help.  TODO: \\ vs P:
	echo %_Folder_% | findstr /B "%_Project_Folder_%" || Goto :Help

) ELSE (

	:: For each path already specified in the file list...
	for /f "delims=?" %%f in ('set ? 2^>Nul') do (
		:: ...unset _SameFolder_
		SET _SameFolder_=
		:: If this file is a folder, save it.  Otherwise, save the subfolder.
		call :IsFolder "%%f" && (set _Folder2_=%%f) || set _Folder2_=%%~dpf
		:: If the input is in the file, it's the same folder. TODO: Do we need /IB?
		echo !_Folder_! | findstr /I "!_Folder2_!" > Nul && SET _SameFolder_=Y
		:: If the file is in the input, it's the same folder.
		echo !_Folder2_! | findstr /I "!_Folder_!" > Nul && SET _SameFolder_=Y
		:: If it's not in the same folder, break.
		If not defined _SameFolder_ goto :Help
	)
)

:: Now, add str to the file list.
SET ?%str%?=?

SET _FilesSpecified_=Y

:RinseAndRepeat
SHIFT /1
SET Arg=%1
If defined Arg GOTO :LoopArgs

if defined _FilesSpecified_ (

	if not exist "%REPO_FLDR%\Restore.cmd" GOTO :Help
	
	:: New.txt is a clean slate.
	if exist "%REPO_FLDR%\New.txt" DEL "%REPO_FLDR%\New.txt"
	
	SET _NothingIsDeleted_=Y
	
	::Ensure the files are set to /S if applicable.
	for /f "delims=?" %%f in ('set ? 2^>Nul') do set ?%%f?=?!_SubFolderSwitch_!
	

) ELSE (

	:: ...if Restore.cmd is not a thing...
	if not exist "%REPO_FLDR%\Restore.cmd" (
		
		:: ...and no files exist in this folder except this one, break.
		dir /b /s | find /v "%~0" > Nul || GOTO :Help
		
		:: Otherwise, if the Repo folder doesn't exist, create it...
		if not exist "%REPO_FLDR%\" MD "%REPO_FLDR%"

	)
	
	:: ...use the files from Restore.cmd to populate the file list.
	FOR /F "TOKENS=1-2 DELIMS=^=" %%F IN ('FIND "SET PJCT_FLDR=" "%REPO_FLDR%\Restore.cmd"') DO SET ?%%f?=?%%g

	:: If Old.txt is a thing, use it to overwrite New.txt.
	rem if exist "%REPO_FLDR%\Old.txt" copy "%REPO_FLDR%\Old.txt" "%REPO_FLDR%\New.txt" /y > Nul


)

rem TODO Fix this.

rem :: For each file/folder in the list...
rem for /f "tokens=1-2* delims=?" %%f in ('set ? 2^>Nul') do (

rem 	:: ...if it's a folder...
rem 	CALL :IsFolder "%%f" && (
rem 		:: ...and _date_ is defined...
rem 		if defined _date_ (
rem 			:: ...echo each applicable file in said folder to Include.txt.
rem 			forfiles /P "%%f"%%h /D !_date_! /C "cmd /c Echo @path">>"%REPO_FLDR%\Include.txt"
rem 			if !ERRORLEVEL! NEQ 0 PAUSE&GOTO :EOF
rem 		) else (
rem 			rem Otherwise, put the folder name (with possible /S) in Include.txt.
rem 			Echo "%%f"%%h>>"%REPO_FLDR%\Include.txt"
rem 		)
rem 	) || (
rem 		rem If it's not a folder and _date_ is defined...
rem 		if defined _date_ (
rem 			rem ...echo the file (if it's applicable) into Include.txt.
rem 			forfiles /P "%%~dpf" /M "%%~nxf" /D !_date_! /C "cmd /c Echo @path">>"%REPO_FLDR%\Include.txt"
rem 			if !ERRORLEVEL! NEQ 0 PAUSE&GOTO :EOF
rem 		) else (
rem 			Echo "%%~dpf">>"%REPO_FLDR%\Include.txt"
rem 		)
rem 	)
	
rem )

:: Get the Project folder from Restore.cmd.
FOR /F "TOKENS=1-2 DELIMS=^=" %%F IN ('FIND "SET PJCT_FLDR=" "%REPO_FLDR%\Restore.cmd"') DO SET PJCT_FLDR=%%G

if not defined PJCT_FLDR SET PJCT_FLDR=%CD%

:: If it's a file, get the parent folder.
CALL :IsFolder "!PJCT_FLDR!" || for /f "delims=" %%f in ("!PJCT_FLDR!") do SET PJCT_FLDR=%%~dpf

:: Delete New.txt if necessary.
if exist "%REPO_FLDR%\New.txt" del "%REPO_FLDR%\New.txt"

:: Feed the files to New.txt with any specified arguments.
for /f "tokens=1-3* delims=?" %%f in ('set ?') do (

	:: Get the filename.
	SET _Line_="%%f"

	:: If it's a folder and subfolders are defined, add /S.
	CALL :IsFolder "%%f" && SET _Line_=!_Line_!%%h

	CALL :FeedNewTxt !_Line_! !_DATE_!
	
)

:: Alphabetize New.txt and remove duplicates.
CALL :CleanFile "%REPO_FLDR%\New.txt"

:MakeRestore
rem If Restore.cmd is a thing...
if exist "%REPO_FLDR%\Restore.cmd" GOTO :AfterRestore

rem rem Get the length of the current directory with repository folder.
rem CALL :strLen "%CD%\%REPO_FLDR%\" len

:: ...Start a Restore.cmd file.
:: TODO Make Restore.cmd paths relative.
(
ECHO @ECHO OFF
ECHO.
ECHO SETLOCAL ENABLEDELAYEDEXPANSION
ECHO.
ECHO SET REPO_FLDR=%%~dp0
ECHO.
ECHO SET PJCT_FLDR=%INCL_FLDR%
ECHO.
ECHO GOTO :Start
ECHO :Help
ECHO ECHO Restores a project folder, or updates an archive folder.
ECHO ECHO.
ECHO ECHO RESTORE destination [source] [/U] [/Y]
ECHO ECHO.
ECHO ECHO  destination  The destination folder to restore or update.
ECHO ECHO  source       The name of the Archive folder to restore to or update from.
ECHO ECHO               If ommitted, restores all or updates all except initial commit.
ECHO ECHO  /U           Update mode.
ECHO ECHO  /Y           Does not ask before overwriting or creating a new folder.
ECHO ECHO.
ECHO ECHO Use this application to:
ECHO ECHO	A^) Restore a project completely.                 e.g. Restore N:\MyProject
ECHO ECHO	B^) Restore a project to a certain point.         e.g. Restore N:\MyProject EndingArchiveName
ECHO ECHO	C^) Apply only recent changes to an archive.      e.g. Restore C:\Archive1 StartingArchiveName /U
ECHO ECHO	D^) Fill a folder with only updated/added files.  e.g. Restore C:\Archive1 /U
ECHO GOTO :EOF
ECHO :Start
ECHO SET _Confirmed=
ECHO SET _verb_=restore
ECHO SET _Target=
ECHO SET _Backup=
ECHO :Top
ECHO rem If the argument is /? goto Help.
ECHO IF '%%1' EQU '/?' GOTO :Help
ECHO rem If the argument is /Y remember to update or restore without prompts.
ECHO IF '%%1' EQU '/Y' SET _Confirmed=1^&SHIFT^&GOTO :Top
ECHO rem If the argument is /y remember to update or restore without prompts.
ECHO IF '%%1' EQU '/y' SET _Confirmed=1^&SHIFT^&GOTO :Top
ECHO rem If the argument is /U remember to update, not restore.
ECHO IF '%%1' EQU '/U' SET _verb_=update^&SHIFT^&GOTO :Top
ECHO rem If the argument is /u remember to update, not restore.
ECHO IF '%%1' EQU '/u' SET _verb_=update^&SHIFT^&GOTO :Top
ECHO rem If the target folder is not a thing but the argument is, set the target folder.
ECHO IF '%%1' NEQ '' IF NOT DEFINED _Target SET _Target=%%1^&SHIFT^&GOTO :Top
ECHO rem If the target folder is a thing but the archive folder is and the argument is, set the backup folder.
ECHO IF '%%1' NEQ '' IF DEFINED _Target SET _Backup=%%1^&SHIFT^&GOTO :Top
ECHO rem If a Target folder is not specified, quit gracefully.
ECHO IF NOT DEFINED _Target ECHO Please specify a folder to %%_verb_%%.^&pause^&GOTO :EOF
ECHO rem If the Target folder doesn't exist...
ECHO rem Take the single quotes from the Target folder name.
ECHO SET _Target=%%_Target:'=%%
ECHO rem Take the double quotes from the Target folder name.
ECHO SET _Target=%%_Target:"=%%
ECHO rem If specified target is not an existing folder...
ECHO DIR /b /ad "%%_Target%%" ^| FIND /i "File Not Found" ^&^& (
ECHO    rem ...and confirmation is required...
ECHO    If NOT DEFINED _Confirmed (
ECHO        rem ...ask if you can create the target folder...
ECHO        CHOICE /M "Folder not found '%%_Target%%'.  Create it"
ECHO        rem ...and if you can't, quit...
ECHO        IF ^^!ERRORLEVEL^^! EQU 2 EXIT /B 1
ECHO    ^)
ECHO    rem ...otherwise, create the Target folder.
ECHO    MD "%%_Target%%"
ECHO ^)
ECHO.
ECHO rem If the user is updating and a Backup is not specified...
ECHO IF '%%_verb_%%' == 'update' IF NOT DEFINED _Backup (
ECHO     rem ...find the second backup from Restore.cmd and get the archive folder name...
ECHO     for /f "tokens=1-2 delims=: " %%%%f in ('findstr /r ":[0-9][0-9]*" "%%REPO_FLDR%%\\Restore.cmd" ^^^| find ":" /n ^^^| findstr /b "[2]:"'^) DO SET _Backup=%%%%g
ECHO     rem ...and if _Backup is still not a thing (no second backup in Restore.cmd^), warn the user and quit.
ECHO     IF NOT DEFINED _Backup ECHO Please specify an existing archive to update.^&PAUSE^&EXIT /B 1
ECHO ^)
ECHO.
ECHO SET AdditionalWhere=
ECHO If defined _Backup (
ECHO    if "%%_verb_%%" == "update" (
ECHO        Set AdditionalWhere=$arc -ge %%_Backup%% -and 
ECHO    ^) else (
ECHO        Set AdditionalWhere=$arc -le %%_Backup%% -and 
ECHO    ^)
ECHO ^)
ECHO.
ECHO rem If the target is not defined, set it to the PJCT_FLDR.
ECHO IF NOT DEFINED _Target SET _Target=%%PJCT_FLDR%%
ECHO rem ASSUME if you can read this and PJCT_FLDR is not a thing, it's the parent directory.
ECHO IF NOT DEFINED PJCT_FLDR FOR %%%%a IN ("%%REPO_FLDR:~0,-1%%"^) DO SET pjt=%%%%~dpa
ECHO rem Escape the Regex Metacharacters that are legal in a windows file path.
ECHO SET _Target=%%_Target:\=\\%%
ECHO SET _Target=%%_Target:+=\+%%
ECHO SET _Target=%%_Target:^^=^^^^%%
ECHO SET _Target=%%_Target:$=\$%%
ECHO SET _Target=%%_Target:.=\.%%
ECHO SET _Target=%%_Target:"=%%
ECHO.
ECHO SET _Confirm_=
ECHO IF NOT DEFINED _Confirmed SET _Confirm_= foreach ($result in $results.GetEnumerator(^)^) {if ($result.Value -eq ''^^^) {Write-Host Delete $result.Name} else {$msg='Update {0} from {1}' -f $result.Name, [DateTime]::ParseExact($result.Value, 'yyyyMMddHHmmssff',[System.Globalization.CultureInfo]::InvariantCulture^^^); Write-Host $msg}}; $resp = Read-Host 'Enter Y to continue'; if ($resp.ToUpper(^^^) -ne 'Y'^^^) {exit 1;}
ECHO.
ECHO echo.
ECHO powershell -command "& {$Files = @{}; gc '%%REPO_FLDR%%Restore.cmd' | foreach-object { if ($_ -match ':(\d+)') {$arc=$matches[1]} else {if (%%AdditionalWhere%%$_ -match ':: (\w+) ""(.+)""""') {if ($matches[1] -eq 'Deleted') {$Files[$matches[2]]='';} else {$Files[$matches[2]]=$arc;} } } }; $I=0; $results=@{}; foreach ($k in $Files.Keys) {$I++; Write-Progress -Activity ('Scanning {0} files' -f $Files.Count) -Status $k -PercentComplete($I/$Files.Count*100); if (&{if ($Files.Item($k) -eq '') {Test-Path ('%%_Target%%' + $k)} else {(-not (Test-Path ('%%_Target%%\' + $k)) -or (Get-filehash $('%%REPO_FLDR%%\' + $Files.Item($k) + $k)).hash -ne (get-filehash $('%%_Target%%\' + $k)).hash)} }) {$results.Add($k, $Files.Item($k));}} if ($results.length -eq 0) {Write-Host No changes made.; exit 1;} %%_Confirm_%% foreach ($result in $results.GetEnumerator()) {$dst='%%_Target%%{0}' -f $result.Name; if ($result.Value -ne '') {$src='%%REPO_FLDR%%{0}{1}' -F $result.Value, $result.Name; New-Item -ItemType File -Path ""$dst"""" -force | out-null; Copy-Item ""$src"""" -Destination ""$dst"""" -force} else {if (Test-Path ""$dst"""") {Remove-Item ""$dst""""}}}; Write-Host Folder updated.;}"
ECHO.
ECHO if %%errorlevel%% == 1 exit /B 1
ECHO exit /B 0
ECHO.
)>"%REPO_FLDR%\Restore.cmd"

:AfterRestore

:: Ensure an Old.txt....
if exist "%REPO_FLDR%\New.txt" if not exist "%REPO_FLDR%\Old.txt" ren "%REPO_FLDR%\New.txt" Old.txt

:: ...and if a Commit Message was specified, commit.
if "%Msg%" NEQ "" CALL :StartCommit

rem Quit or return from whence you're called.
GOTO :EOF

:Help
CALL :JDate d
set /a d-=3
call :JulianToDate d _date_
ECHO.
ECHO %~0 -- A light source control batch script.
ECHO.
ECHO %~n0 [+ path {[/S]^|[+...]}] [/D {YYYYMMDD ^| dd}] [/C Message]
ECHO.
ECHO path          Path to track.  If already defined, files or folders to commit.
ECHO.
ECHO /C Message    Commits specified files with Message.  If no files are specified, 
ECHO               commits recent changes with Message.  Message must be 5 chars+.
ECHO.
ECHO /D date       Selects files used in dd days, or since YYYYMMDD if dd ^>= 1900.
ECHO.
ECHO /S            Includes SubFolders.
ECHO.
ECHO./?            Displays this help message.
ECHO.
ECHO Type %~n0 without parameters to examine subsequent changes to files that have
ECHO been specified.  If nothing has been specified, %~n0 defers to CD.  If CD 
ECHO is empty except for %~0, %~n0 requests a folder to track recursively.
ECHO.
ECHO Examples:
ECHO     %~n0 N:\MyFolderOnly
ECHO     %~n0 N:\MyFolderAndSubfolders\ /S
ECHO     %~n0 /C "Committing all changes."
ECHO     %~n0 N:\SomeProjectFolder\FileToCommit.txt /C "Committing one file."
ECHO     %~n0 N:\SomeProjectFolder\File1.txt N:\SomeProjectFolder\File2.txt /C "Committing numerous files."
ECHO     %~n0 N:\ThreeDayOldFiles\*.* /D 3 /C "Committing changes three days or newer."
ECHO     %~n0 N:\ThreeDayOldFiles\*.* /D %_date_% /C "Committing changes made since %_date_%."
ECHO     %~n0 N:\ThreeDayOldFiles\*.* /D %_date_:~6,4%%_date_:~0,2%%_date_:~3,2% /C "Committing changes made since %_date_%."
GOTO :EOF

:NoArgs

color 1f

::If Old.txt is a thing, it's not a new archive.
If EXIST "%REPO_FLDR%\Old.txt" GOTO :GotOldText

REM BRANCHES

rem Unset all variables starting with ?.  ASSUMES ? is an illegal char in a file name.
FOR /F "delims==" %%a In ('set ? 2^>Nul') DO SET "%%a="

rem Find all files in this root folder and if any are identical to this file, remember the repo folder and its date.
for /f "delims=" %%f in ('dir /b /s /a-d ^| find /v "%~dpnx0" ^| findstr /vrc:"%CD:\=\\%\\.*\\.*"') do (
	fc "%~0" "%%f" > Nul && (
		for /f "tokens=1-2 delims= " %%g in ('dir /T:C ^| findstr /e "+%%~nf"') do (
			CALL :JDate d "%%g"
			CALL :JTime t "%%h"
			SET ?!d!!t!?=?+%%~nf
		)
	)
)

rem If nothing is set, it's the first rodeo.
set ? && (

	cls

	rem Otherwise, create the repo folder if necessary.
	if not exist "%REPO_FLDR%" md "%REPO_FLDR%"

	FOR /F "tokens=1-3 delims=?" %%a In ('set ? 2^>Nul') DO (
		if exist "%%c\*.ini" COPY "%%c\*.ini" "!REPO_FLDR!" /Y > Nul
		COPY "%%c\*.txt" "!REPO_FLDR!" /Y > Nul
		CALL :StartCommit
		goto :eof
	)

)
:FirstRodeo

CLS

:: If this is your first rodeo, unset the PJCT_FLDR.
SET PJCT_FLDR=

:: If this folder has any files except this batch file, this is the path.
dir /b /s | find /v "%~dpnx0" | find /v "%~dp0%REPO_FLDR%" > Nul && GOTO :GotPath

:: Otherwise, ask for a folder to track.
set /p PJCT_FLDR=Please specify a folder to track (or enter nothing to quit): 

:: If the user enters nothing, quit.
if not defined PJCT_FLDR GOTO :EOF

:: Ensure backslashes after colons.
SET PJCT_FLDR=!PJCT_FLDR:^:=^:\!

:: Drop duplicate backslashes.
SET PJCT_FLDR=!PJCT_FLDR:\\=\!

:: Remove any quotes.
SET PJCT_FLDR=%PJCT_FLDR:"=%

:: If what the user entered is not a folder or file, tell the user, then retry.
if not exist "%PJCT_FLDR%" echo "%PJCT_FLDR%" does not exist. & PAUSE & GOTO :FirstRodeo

:: If it's a file, get the parent folder.
CALL :IsFolder "%PJCT_FLDR%" || FOR /F "delims=" %%f in ("%PJCT_FLDR%") DO SET PJCT_FLDR=%%~dpf

:: Enforce backslashes and capitalization.
pushd "%PJCT_FLDR%"
set PJCT_FLDR=%CD%
popd

:: Remove any quotes.
SET PJCT_FLDR=%PJCT_FLDR:"=%

:GotPath
SET INCL_FLDR=
if defined PJCT_FLDR (
	SET INCL_FLDR="%PJCT_FLDR%"
) else (
	SET PJCT_FLDR=%CD%
)

:: FOR ROBOCOPY, ensure Project Folder does not end in \
SET PJCT_FLDR="%PJCT_FLDR%"
SET PJCT_FLDR=%PJCT_FLDR:\"="%
SET PJCT_FLDR=%PJCT_FLDR:"=%

SET PJCT_FLDR=!PJCT_FLDR:^)=^\^)!
SET PJCT_FLDR=!PJCT_FLDR:^(=^\^(!

:: Create the Repo folder if necessary.
if not exist "%REPO_FLDR%" MD "%REPO_FLDR%\"

:: Create New.txt...
CALL :FeedNewTxt "%PJCT_FLDR%" /S

:: ...and sort the file and drop all dupes.
CALL :CleanFile "%REPO_FLDR%\New.txt"

:: Count the number of lines in New.txt.
SET fileCount=0
for /f %%a in ('type "%REPO_FLDR%\New.txt"^|find "" /v /c') do set /a fileCount=%%a

if %filecount% GTR 1000 (
	ECHO %PJCT_FLDR% has %fileCount% files.
) ELSE (
	SET byteCount=0
	for /f delims^=^"^ tokens^=1 %%f IN ('Type "%REPO_FLDR%\New.txt"') do SET /A byteCount+=%%~zf
	if %filecount% EQU 1 (
		ECHO !PJCT_FLDR:^)=^\^)! has %fileCount% file in !byteCount! bytes.
	) else (
		ECHO !PJCT_FLDR:^)=^\^)! has %fileCount% files in !byteCount! bytes.
	)
)

:: Make the Restore.cmd file.
CALL :MakeRestore

ECHO.
ECHO Enter a message (5 chars+^) if you wish to backup all files now.
SET /P Msg=Or nothing to quit: 

:: If the response is more than 5 chars, commit.
IF DEFINED Msg IF "!Msg!" NEQ "!Msg:~0,6!" (CALL :StartCommit) 

:: In any case, ensure an Old.txt.
Copy "%REPO_FLDR%\New.txt" "%REPO_FLDR%\Old.txt" /y >NUL

:: Quit.
goto :EOF

:GotOldText
CLS

:: Get the Project Folder from Restore.cmd...
FOR /F "TOKENS=1-2 DELIMS=^=" %%F IN ('FIND "SET PJCT_FLDR=" "%REPO_FLDR%\Restore.cmd"') DO SET PJCT_FLDR=%%G
REM for /f tokens^=1-2^ delims^=^" %%f in ('findstr /R /N "^.*$" "%REPO_FLDR%\Include.txt" ^| findstr /B "1:"') do SET PJCT_FLDR=%%g

if not defined PJCT_FLDR SET PJCT_FLDR=%CD%

:: EXPECTS NO QUOTES!!!
set PJCT_FLDR=%PJCT_FLDR:"=%

:: If the Project Folder is not connected, complain.
if not exist "%PJCT_FLDR%" ECHO "%PJCT_FLDR%" not found.&pause&GOTO ShowSummary

set PJCT_FLDR=!PJCT_FLDR:^)=^\^)!
set PJCT_FLDR=!PJCT_FLDR:^(=^\^(!

:: If it's a file, get the parent folder.
CALL :IsFolder "!PJCT_FLDR!" || for /f "delims=" %%f in ("!PJCT_FLDR!") do SET PJCT_FLDR=%%~dpf

:: EXPECTS NO QUOTES!!!
set PJCT_FLDR=%PJCT_FLDR:"=%

:GetNewText
SET Msg=
SET ChangeCount=0

:: Delete New.txt if necessary.
if exist "%REPO_FLDR%\New.txt" del "%REPO_FLDR%\New.txt"

:: Create New.txt from the Project Folder.
CALL :FeedNewTxt "%PJCT_FLDR%" /S

:: Alphabetize and remove duplicates from New.txt.
CALL :CleanFile "%REPO_FLDR%\New.txt"

rem If no differences are found between New.txt and Old.txt, and Msg is not a thing, jump straight to ShowSummary.
FC "%REPO_FLDR%\New.txt" "%REPO_FLDR%\Old.txt">Nul && if [%Msg%] EQU [] GOTO :ShowSummary

rem Otherwise, start the Commit.cmd file.

:StartCommit -- Make the Commit.cmd file by comparing New.txt to Old.txt.
:: TODO Make Commit.cmd paths relative.
(
ECHO @ECHO OFF
ECHO IF '%%1' NEQ '' IF '%%1' NEQ '/?' GOTO :StartCommit
ECHO.
ECHO ECHO Commits a change or changes from %PJCT_FLDR%
ECHO.
ECHO ECHO COMMIT message destination [a [+b] [+c]...]
ECHO.
ECHO ECHO message            The message pertaining to the new Archive (5 chars+^)
ECHO ECHO destination        The name of the new Archive.
ECHO ECHO a [+b] [+c]...     The files to commit.  If omitted, commits all.
ECHO pause
ECHO GOTO :EOF
ECHO.
ECHO :StartCommit
ECHO SET _Message_=%%1
ECHO SET _Message_=%%_Message_:"=%%
ECHO SET _Archive_=%%2
ECHO SET _FilesToCommit_=
ECHO.
ECHO rem Tell Restore.cmd to start the next label.
ECHO ECHO :%%_Archive_%% %%_Message_%%^>^>"%REPO_FLDR%\Restore.cmd"
ECHO.
ECHO rem Unless _Archive_ begins with a drive letter, _Archive_ is in the Current Directory.
ECHO ECHO %%_Archive_%% ^| FINDSTR /RC:^^[A-Z]:^>NUL ^|^| SET _Archive_=%%~dp0%%_Archive_%%
ECHO ECHO Archive: %%_Archive_%%
ECHO.
ECHO rem Unset all vars beginning with ?.
ECHO FOR /F "delims==" %%%%a In ('set ? 2^^^>Nul'^) DO SET "%%%%a="
ECHO.
ECHO :LoopArgs
ECHO IF [%%3] EQU [] GOTO :A^)
ECHO SET _FilesToCommit_=%%_FilesToCommit_%% %%2
ECHO SHIFT
ECHO GOTO :LoopArgs
)>"%REPO_FLDR%\Commit.cmd"

SET "ChangeCount=0"

:: If New.txt is not a thing...
If NOT EXIST "%REPO_FLDR%\New.txt" (
	rem echo on
	:: ...every file in Old.txt (ASSUMES filenames in Old.txt are delimited by ") is a creation.
	for /f delims^=^" %%f IN ('type "%REPO_FLDR%\Old.txt"') do CALL :AppendCommit ChangeCount Created "%%f"
	rem pause
) ELSE (

	:: Otherwise, find the differences between Old.txt and New.txt, change >= to > and <= to < in case = is in the file name, and save to Diff.tmp...
	rem TODO When the folder is empty, New.txt is null!!!  Add a line so no crashee.
	rem echo powershell -Command "& {Compare-Object (Get-Content '%REPO_FLDR%\Old.txt') (Get-Content '%REPO_FLDR%\New.txt') | ft inputobject, @{n='file';e={ if ($_.SideIndicator -eq '=>') { '>' }  else { '<' } }} | out-file -width 1000 '%REPO_FLDR%\Diff.tmp'}" 
	rem pause
	powershell -Command "& {Compare-Object (Get-Content '%REPO_FLDR%\Old.txt') (Get-Content '%REPO_FLDR%\New.txt') | ft inputobject, @{n='file';e={ if ($_.SideIndicator -eq '=>') { '>' }  else { '<' } }} | out-file -width 1000 '%REPO_FLDR%\Diff.tmp'}" 

	:: ...and if any are found...
	FOR %%A IN ("%REPO_FLDR%\Diff.tmp") DO IF %%~zA EQU 0 GOTO :CloseCommit

	:: Unset all variables starting with ?.  ASSUMES ? is an illegal char in a file name.
	FOR /F "delims==" %%a In ('set ? 2^>Nul') DO SET "%%a="

	:: For each filename in Old.txt, if it's not in New.txt, flag it as deleted. ASSUMES filenames in Old.txt are delimited by "
	if not defined _NothingIsDeleted_ for /f delims^=^" %%f IN ('type "%REPO_FLDR%\Diff.tmp" ^| findstr ^^^<') do type "!REPO_FLDR!\Diff.tmp" | findstr ^> | findstr /C:"%%f" > Nul || SET ?%%f?=?Deleted
	
	rem For each filename in New.txt, if it's in Old.txt, flag it as updated.  Otherwise, flag it as created.
	for /f delims^=^" %%f IN ('type "%REPO_FLDR%\Diff.tmp" ^| findstr ^^^>') do type "!REPO_FLDR!\Diff.tmp" | findstr ^< | findstr /C:"%%f" > Nul && SET ?%%f?=?Updated || SET ?%%f?=?Created

	:: Now, for each variable that starts with ?, use the var (filename) and value (Created/Updated/Deleted) to append Commit.cmd.
	FOR  /F "tokens=1-3 delims=?" %%a In ('set ? 2^>Nul') DO CALL :AppendCommit ChangeCount %%c "%%a"
	
)

:CloseCommit
rem TODO: What if folders are in New.txt but not Old.txt?

(
ECHO rem For each deleted file, tell Restore.cmd to unset the var.
ECHO FOR /F "tokens=1-3 delims=?" %%%%a In ('set ? 2^^^>Nul'^) DO ECHO SET ?%%%%a?=^>^>"%REPO_FLDR%\Restore.cmd"
ECHO rem Tell Restore.cmd to return.
ECHO ECHO GOTO :EOF^>^>"%REPO_FLDR%\Restore.cmd"
)>>"%REPO_FLDR%\Commit.cmd"

rem If a Msg was specified (from the command line), run Commit.cmd.
if "%Msg%" NEQ "" (
	if !ChangeCount! equ 0 (
		echo No changes found.
		color
		goto :eof
	)
	GOTO :RunCommit
)

:ShowSummary
:: Unset _ForceCommit_
SET _ForceCommit_=
SET _inc_=
SET Msg=
CLS
color 1F
for %%a in (.) do set title=%%~nxa\%~n0

CALL :EchoCenterPad " %title% " "-"

:: Count the number of archives listed in Restore.cmd.
for /f %%a in ('findstr /r ":[0-9][0-9]*" "%REPO_FLDR%\Restore.cmd"^|find ":" /c') do set i=%%a

if i NEQ 0 (
	ECHO.
	powershell -command "& {$ctr=0; (gc .\%REPO_FLDR%\Restore.cmd) | ForEach-Object { if ($_ -match ':(\d+) (.+)') {$ts = NEW-TIMESPAN ([DateTime]::ParseExact($matches[1], 'yyyyMMddHHmmssff',[System.Globalization.CultureInfo]::InvariantCulture)) (GET-DATE); $ctr++; $line=([string]$ctr) + ')'; $line=$line.PadRight(5); $q=$ts.minutes; $i=' minute'; if ($ts.days -ne 0) { $q=$ts.days; $i=' day';} else {if ($ts.hours -ne 0) { $q=$ts.hours; $i=' hour';}} if ($q -ne 1) {$i+='s'} $line=$line + $q + $i + ' ago.'; Write-Host $line.PadRight(20) $matches[2];}}}"
)

ECHO.

SET n=
SET _FileDesc_=
IF !ChangeCount! EQU 0 GOTO :NoChanges 

SET _LastChange=

SET title=!ChangeCount! Change

IF !ChangeCount! GTR 1 SET title=%title%s
CALL :EchoCenterPad " %title% " "-"
ECHO.

CALL :strLen PJCT_FLDR len

rem Look in Commit.cmd for lines that begin with ":" followed by one or more upper case letters, parenthesis and a space...
FOR /F "tokens=1-2* delims=:) " %%f IN ('findstr /R "^:[A-Z][A-Z]*)[^-]" "%REPO_FLDR%\Commit.cmd"') DO (

	rem ...get the filename...
	set fln=%%h
	rem ...and remove the quotes...
	set fln=!fln:^"=!
	rem ...and the Project folder...
	set fln=!fln:~%len%!

	rem ...and if the label is on the exclude list, echo [ ] (otherwise, [+]) followed by the rest of the line.
	echo ,!_exc_!, | find /i ",%%f," > nul && echo [ ] %%f^)%%g || ECHO [+] %%f^) %%g "!fln!"
		
	rem Set the Last Change.
	SET _LastChange=%%f
		
)

ECHO.
ECHO Please enter a description (5 chars+) to commit changes, or
if !_LastChange! NEQ A (
	SET _FileDesc_=* to toggle all changes, or (A-!_LastChange!^) to toggle a change to commit, or @(A-!_LastChange!^) to explore a file, or
) ELSE (
	SET _FileDesc_=@A to explore the file, or
)
:NoChanges
IF %i% EQU 1 (
	IF EXIST "%PJCT_FLDR%" (
		ECHO (1^) to restore a commit, or @(1^) to explore a commit, or
	) ELSE (
		ECHO @(1^) to explore a commit, or
	)
) ELSE IF %i% GTR 1 (
	IF EXIST "%PJCT_FLDR%" (
		ECHO (1-%i%^) to restore a commit, or @(1-%i%^) to explore a commit, or
	) ELSE (
		ECHO @(1-%i%^) to explore a commit, or		
	)
) ELSE IF !ChangeCount! EQU 0 (
	echo No changes to commit and no commits to restore.
	pause
	color
	cls
	goto :eof
)
if not exist !PJCT_FLDR! SET i=0
if defined _FileDesc_ echo !_FileDesc_!
SET /P Msg=nothing to quit: 

rem If input is nothing, quit.
IF not defined Msg (color & cls & GOTO :EOF)

rem If the input is a description, run Commit.cmd.
IF "!Msg!" NEQ "!Msg:~0,5!" GOTO :RunCommit

rem If the user is toggling the changes...
if "!Msg!" == "*" (

	rem ...if anything is excluded, now nothing is excluded.
	if defined _exc_ (SET _exc_=) ELSE (
	
		rem Otherwise, look through the commit.cmd for labels...
		FOR /F "tokens=1* delims=:)" %%f IN ('findstr /R "^:[A-Z][A-Z]*)[^-]" "%REPO_FLDR%\Commit.cmd"') DO (
		
			rem ...and add each label to a comma delimited exclude list.
			if not defined _exc_ (set _exc_=%%f) else set _exc_=!_exc_!,%%f
			
		)
		
	)
	
	GOTO :ShowSummary
	
)

rem If the user is exploring a commit or a change.
if "%Msg:~0,1%" NEQ "@" GOTO :NoHistory

rem Drop the leading @
set Msg=!Msg:~1!

SET "var="&for /f "delims=0123456789" %%i in ("%Msg%") do set var=%%i

rem If the input is numeric...
if not defined var (
	rem ...vitiate all leading zeros.
	set /a Msg=%Msg%
	rem If the input is 0, complain and quit.
	if %Msg% EQU 0 echo 0 is too low. & PAUSE & GOTO :ShowSummary
	rem If the input is too high, complain and quit.
	if %Msg% GTR %i% echo %Msg% is too high. & PAUSE & GOTO :ShowSummary
	rem Explore this archive.
	CALL :ExploreArchive %Msg%
) else (
	set _File_=
	:: Find the line this entry indicates and capture the filename.
	FOR /F "tokens=1-2* delims= " %%f IN ('findstr /I /B ":%Msg%) " "%REPO_FLDR%\Commit.cmd"') DO Set _File_=%%h
	:: If no filename is found, complain and quit.
	if not defined _File_ echo %Msg% is not found. & pause & goto :ShowSummary
	:: Otherwise, explore this file.
	CALL :ExploreFile !_File_!
)

rem Refresh this menu, and Msg and Commit.cmd if necessary.
IF !ERRORLEVEL! EQU 1 (GOTO :GetNewText) else goto :ShowSummary

:NoHistory
SET "var="&for /f "delims=0123456789" %%i in ("%Msg%") do set var=%%i
rem If the input is numeric...
IF not defined var (
	
	rem If it's 0, complain it's out of range and return to the Summary.
	if %Msg% EQU 0 echo 0 is too low. & PAUSE & GOTO :ShowSummary

	rem Get the difference between the input and the number of possible commits.
	SET /a diff=!i!-!Msg!
	
	rem If the input was out of the range of possible commits complain and return to the Summary.
	IF !diff! LSS 0 ECHO '%Msg%' is too high. & PAUSE & GOTO :ShowSummary

	rem If changes were found...
	IF !ChangeCount! NEQ 0 (
		rem ...tell the user.
		echo *************************************************************
		ECHO ** YOU HAVE UNCOMMITTED CHANGES THAT MAY BE OVERWRITTEN^^!^^!^^! **
		echo *************************************************************
	rem If no changes were found and the last commit was selected...
	) else IF !diff! EQU 0 (
		rem ...say everything's up to date and return to the Summary.
		ECHO All files are up to date. & PAUSE & GOTO :ShowSummary
	)
	
	echo.
	:: Get the name of the archive specified by the input number.
	for /f "tokens=1-2* delims=: " %%f in ('findstr /r ":[0-9][0-9]*" "%REPO_FLDR%\Restore.cmd" ^| find ":" /n ^| findstr /b "\[%Msg%\]:"') do SET _Archive_=%%g&CALL :EchoCenterPad " %%h " "-"

	rem Update or restore the Project folder to the specified archive name.  ASSUMES Restore.cmd asks "Are you sure?"
	CALL "%REPO_FLDR%\Restore.cmd" "!PJCT_FLDR!" !_Archive_!

	:: If the user said "Yes, I'm sure", pause and quit.  Otherwise, refresh menu.
	if !errorlevel! neq 0 goto :ShowSummary

	Echo.

	Echo Project restored.
	
	rem Wait 4 seconds.
	PING.EXE -n 4 127.0.0.1 > NUL

	::Reset color
	color
	GOTO :EOF
	
)

rem If input is not numeric and no changes are found complain that the input is not numeric before continuing.
if !ChangeCount! EQU 0 echo.&echo '%Msg%' NOT numeric. & PAUSE & GOTO :ShowSummary

rem Trim the input.  ASSUMES Change labels have no spaces.
SET n=%n: =%

rem If the input does not correspond to a label in Commit.cmd -- e.g. :A) -- complain and return.
findstr /ib ":%Msg%)" "%REPO_FLDR%\commit.cmd" > nul || (echo.&ECHO '%Msg%' is not recognized. & PAUSE & GOTO :ShowSummary)

SET _IsExcluded_=

if defined _exc_ echo ,%_exc_%, | find /i ",%Msg%," > nul && SET _IsExcluded_=1

rem If it's not on the _exc_ list...
IF not defined _IsExcluded_ (
	rem ...add it...
	if not defined _exc_ (SET _exc_=%Msg%) else set _exc_=%_exc_%,%Msg%
	rem ...and return.
	goto :ShowSummary
)

rem Otherwise, start a blank array...
SET _tmp_=

rem ...create an array of everything in EXC besides the input...
FOR %%i IN (%_exc_:,= %) DO echo ,%%i, | find /I ",!Msg!," || if defined _tmp_ (set _tmp_=%%q) else SET _tmp_=!_tmp_!,%%i

rem ...and set EXC to that.
SET _exc_=!_tmp_!

GOTO :ShowSummary

:RunCommit

:: Unset _inc_
SET _inc_=
if not defined _ForceCommit_ (

	if !ChangeCount! EQU 0 echo No changes to commit. & pause & GOTO :ShowSummary

	rem If the include list is not a thing, for each change in Commit.cmd not correlating to the exclude list, add the file name to the (space delimited) include list.  ASSUMES: _exc_ is a comma delimited list of labels.
	FOR /F delims^=^"^ tokens^=1-2 %%f IN ('type "%REPO_FLDR%\commit.cmd" ^| findstr /irc:":[A-Z][A-Z]*) " ^| findstr /virc:":[!_exc_!]) "') DO SET _inc_=!_inc_! "%%g"

	rem If _inc_ is still not defined, complain and return.
	if not defined _inc_ (echo.&echo Please specify a change to commit. & pause & GOTO :ShowSummary)

	rem If nothing is explicitly excluded, unset _inc_
	if not defined _exc_ set _inc_=
	
)

CALL :TimeStamp NEXT_ARCHIVE

rem Commit only what was included if specified.
CALL "%REPO_FLDR%\Commit.cmd" "!Msg!" !NEXT_ARCHIVE!!_inc_!> "%REPO_FLDR%\Commit.log"

rem If no includes were specified...
if not defined _inc_ (

	rem ...the New.txt file is now the Old.txt file.
	COPY "%REPO_FLDR%\New.txt" "%REPO_FLDR%\Old.txt" /Y > NUL
	
) ELSE (

	rem Otherwise, re-seek each included filename...
	FOR /F delims^=^"^ tokens^=1-2 %%f IN ('type "%REPO_FLDR%\commit.cmd" ^| findstr /irc:":[A-Z][A-Z]*) " ^| findstr /virc:":[!_exc_!]) "') DO (
		
		rem ...strip the included file from Old.txt to make Old.tmp...
		(TYPE "!REPO_FLDR!\Old.txt" | find /v /i """%%g""")>"!REPO_FLDR!\Old.tmp"
		
		rem ...if the file is not a deletion, add it from New.txt...
		(TYPE "!REPO_FLDR!\New.txt" | find /i """%%g""")>>"!REPO_FLDR!\Old.tmp"
		
		rem ...and overwrite Old.txt.
		copy "!REPO_FLDR!\Old.tmp" "!REPO_FLDR!\Old.txt" /Y>Nul
		
	)
	
	rem If Old.tmp is a thing, delete it.
	if exist "!REPO_FLDR!\Old.tmp" del "!REPO_FLDR!\Old.tmp"
	
	rem Alphabetize Old.txt.
	CALL :CleanFile "%REPO_FLDR%\Old.txt"

)

Echo.

Echo Archive created.

rem Wait 4 seconds.
PING.EXE -n 4 127.0.0.1 > NUL

rem Quit.
GOTO :EOF

:AppendCommit Number Verb Filename
::            Number [in/out] -- The 1-based index number that applies to this update.
::            Verb [in] -- The verb that applies to this update (e.g. "Created", "Deleted", "Modified").
::            Filename [in] -- The filename that applies to this update.

:: If Exclude.txt is a thing and it applies to this filename, exit.
if exist "%CD%\%REPO_FLDR%\Exclude.txt" echo %3 | findstr /rig:"%CD%\%REPO_FLDR%\Exclude.txt" > Nul && exit /b 1

SETLOCAL EnableDelayedExpansion
rem echo Entering AppendCommit %1 %2 %3
FOR /f "delims=" %%f IN (%3) DO (
	rem Remember the Filename's name and extension.
	SET fln=%%~nxf
	rem Remember the Filename's drive and path, surrounded by ".
	SET src="%%~dpf"
	rem Drop the trailing \.
	SET src=!src:\"="!
)

rem Remove all quotes from src.
SET src=!src:"=!

rem Get the length of the Project folder.
CALL :strLen PJCT_FLDR len
rem Subtract 2 for the quotes in PJCT_FLDR.
rem SET /a len-=2
rem The destination is the source after the Project folder.
SET dst=!src:~%len%!

:: Get the ASCII equivalent of the number.
SET /a "cnt=%~1"
call :ASCII %cnt% chr

(
ECHO.
ECHO :%chr%^) %2 %3
ECHO rem if _FilesToCommit_ is a thing and %3 is not in it, skip.
rem Escape end parentheses from fln.
ECHO IF DEFINED _FilesToCommit_ ECHO %%_FilesToCommit_%% ^| FIND """%src%\!fln:^)=^^^)!""" ^> nul ^|^| GOTO :After%chr%

if "%2" == "Deleted" (
	ECHO rem Remember !_FileName_! is deleted.
	ECHO SET ?!fln:^)=^^^)!?=?%%%%_Target%%%%
) ELSE (
	ECHO rem Copy %3 to the archive, creating the archive if necessary.
	ECHO robocopy "%src%" "%%_Archive_%%%dst%" "!fln:^)=^^^)!"^>Nul
)
ECHO ECHO %2 %3
ECHO ECHO :: %2 "%dst%\%fln%" ^>^>"%REPO_FLDR%\Restore.cmd"
ECHO :After%chr%
)>>"%REPO_FLDR%\Commit.cmd"

SET /A cnt+=1

ENDLOCAL & SET "%~1=%cnt%"

exit /b 0

:Erase <str1> <str2> <str3>
SETLOCAL EnableDelayedExpansion
	Set f=%~1
    Set s=%~2
    SET t=%f:!s!=%
	ENDLOCAL & SET %~3=%t%
EXIT /B


:ExploreArchive <Archive>
SETLOCAL EnableDelayedExpansion
SET _ArchiveChanged_=
:StartExploreArchive
cls
color 2E
:: Get the %1th archive from Restore.cmd.  WARNING: If %1th archive is not a thing, _Archive_ is not set.
for /f "tokens=1* delims=:" %%f in ('findstr /r ":[0-9][0-9]*" "%REPO_FLDR%\Restore.cmd" ^| find ":" /n ^| findstr /b "[%1\]:"') do SET _Archive_=%%g

for /f "tokens=1* delims= " %%f in ('mode con ^| find /i "columns"') do set /a cols=%%g - 2

:: For each word in the line
for /f "tokens=1* delims= " %%f in ("!_Archive_!") do (
	:: ...save the first word...
	SET _Archive_=%%f
	:: ...and echo the rest.
	set txt= %%g 
	CALL :strLen txt len
	:: The Counter is the difference between the width of the screen and the length of the input.
	SET /a ctr=!cols!-!len!
	:: Get the remainder of the counter divided by 2.
	SET /a r=!ctr! %% 2
	:: If the remainder is 1, increment the counter.
	IF !r!==0 SET /a ctr+=1
	:: Halve the counter.
	SET /a ctr/=2

	rem For 1 to counter, add the character to the beginning and end of the input.
	FOR /L %%? IN (0,1,!ctr!) DO SET txt=-!txt!-

	rem ECHO the result.
	ECHO !txt!

	REM CALL :EchoCenterPad " %%g " "-"
)

:: Skip a line.
ECHO.

rem Unset all variables starting with ?.
FOR /F "delims==" %%a In ('set ? 2^>Nul') DO SET "%%a="

rem From Restore.cmd, get the line number of the specified archive.
for /f "delims=:" %%f in ('findstr /N :!_Archive_! "!REPO_FLDR!\Restore.cmd"') do SET n=%%f

:: Increment the line number by 2
SET /a n+=2
:: Determine if the 2nd line after the archive label describes a comment.
findstr /nr "." "%REPO_FLDR%\Restore.cmd" | findstr /b "%n%:::" > Nul && SET _MultipleFilesFound_=Y || SET _MultipleFilesFound_=
:: Decrement the line number by 2.
SET /a n-=2

set /a cnt=0
:GetComment	
:: Increment n...
SET /a n+=1

:: ...unset _Line_ and get the nth line in Restore.cmd and if it starts with ::, set _Line_ to it preempted by three spaces.
SET _Line_=&for /f "tokens=1* delims=:" %%f in ('findstr /nr "." "%REPO_FLDR%\Restore.cmd" ^| findstr /b "%n%:::"') do SET _Line_=   %%g

:: If _Line_ is a thing...
if defined _Line_ (
	:: ...get the count's corresponding ASCII character(s)...
	call :ASCII !cnt! chr
	:: ...increment cnt...
	SET /a cnt+=1
	:: ...save everything after the second word.
	for /f "tokens=1* delims= " %%f in ("%_Line_%") do set ?!chr!?=%%g
	if defined _MultipleFilesFound_ (
		:: If the label is two letters, drop a space from _Line_
		if !cnt! GTR 26 SET _Line_=!_Line_:~1!
		:: If three, drop a second.
		if !cnt! GTR 676 SET _Line_=!_Line_:~1!
		:: If four, drop a third.
		if !cnt! GTR 17576 SET _Line_=!_Line_:~1!
		:: Echo the label and the line.
		ECHO !chr!^) !_Line_!
	)
	:: Loop.
	GOTO :GetComment
)

if "%chr%" EQU "A" (
	SET Msg=A
) ELSE (
	echo.
	SET Msg=
	ECHO Enter A-%chr% to explore a file
	set /p Msg=or nothing to return: 
)

set Selection=%Msg%
rem In case the user typed @, ignore it.
if "!Selection:~0,1!" EQU "@" set Selection=!Msg:~1!
	
rem Unless the user just clicked Enter...
if defined Selection (
	rem If the target is still not defined, complain and retry.
	if not defined ?%Selection%? echo %Selection% not found.&pause&CLS&GOTO :StartExploreArchive
	rem Set the target.
	set _Target_=!?%Selection%?!
	rem Explore the file.
	CALL :ExploreFile !_Target_! !_Archive_!
	if !ERRORLEVEL! equ 1 SET _ArchiveChanged_=Y
	rem Refresh the menu.
	if "%chr%" NEQ "A" CLS&GOTO :StartExploreArchive
)

if defined _ArchiveChanged_ (endlocal & exit /b 1)
endlocal
exit /b 0

:ExploreFile <FileName> <Archive-opt>
::           <FileName> relative name of the file to explore.
::           <Archive> optional operative archive.  If omitted, current version is assumed.
rem setlocal EnableDelayedExpansion

cls

color 7

SET _HighlightedFile_=%~1

SET _FileName_=%1

SET _DefaultArchive_=%2

set _FileChanged_=

SET _SkipDiffIni_=Y

:: The filename is everything after the Project Folder...
SET _FileName_=!_FileName_:%PJCT_FLDR%=!

:: ...ensure one and only one pair of quotes...
SET _FileName_="%_FileName_:"=%"

:: ...drop any leading \...
SET _FileName_=%_FileName_:"\="%

:: ...and all quotes.
SET _FileName_=!_FileName_:"=!
:: Look for archived versions of this file.
SET FilesFound=&FOR /F "DELIMS=" %%F IN ('DIR /B /S /A-D /ON "%REPO_FLDR%" ^| FindStr /IRC:"!_FileName_:\=\\!$"') DO SET FilesFound=Y
:: If not found, complain and quit.
if not defined FilesFound echo No archive files found. & pause & cls & color 1F & exit /b 0

:: If a default archive is specified and it's a thing, change _HighlightedFile_ to that archive.
if defined _DefaultArchive_ if exist "%REPO_FLDR%\%_DefaultArchive_%\%_FileName_%" SET _HighlightedFile_=%REPO_FLDR%\%_DefaultArchive_%\%_FileName_%

:: Find the last update of this file before _HighlightedFile_.
SET _SelectedFile_=&FOR /F "DELIMS=" %%F IN ('DIR /B /S /A-D /ON "%REPO_FLDR%" ^| FindStr /IRC:"!_FileName_:\=\\!$"') DO IF "%%F" EQU "%CD%\!_HighlightedFile_!" (GOTO :StartExploreFile) ELSE SET _SelectedFile_=%%F

:StartExploreFile


if defined _SelectedFile_ (

	:: _SelectedFile_ is _SelectedFile_ without the current directory.
	SET _SelectedFile_=!_SelectedFile_:%CD%\=!
	
	rem Unset all variables starting with *.  ASSUMES * is an illegal char in a file name.
	FOR /F "delims==" %%a In ('set * 2^>Nul') DO SET "%%a="

	set *%_SelectedFile_%=*%_SelectedFile_%
	
	:: If the selected file is not the current version...
	if "%_SelectedFile_%" NEQ "%~1" (
		:: ...set *%_SelectedFile_% to the _SelectedFile_ parent folder.
		for /f "tokens=1-2 delims=\" %%f IN ("%_SelectedFile_%") do set *%_SelectedFile_%=%%g
		:: Now change the value to the corresponding date and time, preceded by the REPO_FLDR and ending with bkp.
		SET *%_SelectedFile_%=%REPO_FLDR%\\!*%_SelectedFile_%:~4,2!-!*%_SelectedFile_%:~6,2!-!*%_SelectedFile_%:~2,2! !*%_SelectedFile_%:~8,2!.!*%_SelectedFile_%:~10,2!.!*%_SelectedFile_%:~12,2!.bkp
		:: If *%_SelectedFile_% is a thing, ensure it's writable...
		if exist "!*%_SelectedFile_%!" attrib -R "!*%_SelectedFile_%!"
		:: ...so you can copy over it with the selected file...
		copy "%_SelectedFile_%" "!*%_SelectedFile_%!" /y > Nul
		:: ...and make it read only.
		attrib +R "!*%_SelectedFile_%!"
		:: Ensure the Selected file value begins with *.
		SET *%_SelectedFile_%=*!*%_SelectedFile_%!
	)

	set *%_HighlightedFile_%=*%_HighlightedFile_%
	
	:: If the highlighted file is not the current version...
	if "!_HighlightedFile_!" NEQ "%~1" (
		:: ...set *%_HighlightedFile_% to the _HighlightedFile_ parent folder.
		for /f "tokens=1* delims=\" %%f IN ("%_HighlightedFile_%") do set *%_HighlightedFile_%=%%g
		:: Now change the value to the corresponding date and time, preceded by the REPO_FLDR and ending with bkp.
		SET *%_HighlightedFile_%=%REPO_FLDR%\\!*%_HighlightedFile_%:~4,2!-!*%_HighlightedFile_%:~6,2!-!*%_HighlightedFile_%:~2,2! !*%_HighlightedFile_%:~8,2!.!*%_HighlightedFile_%:~10,2!.!*%_HighlightedFile_%:~12,2!.bkp
		:: If *%_HighlightedFile_% is a thing, ensure it's writable...
		if exist "!*%_HighlightedFile_%!" attrib -R "!*%_HighlightedFile_%!"
		:: ...so you can copy over it with the highlighted file...
		copy "%_HighlightedFile_%" "!*%_HighlightedFile_%!" /y > Nul
		:: ...and make it read only.
		attrib +R "!*%_HighlightedFile_%!"
		:: Ensure the highlighted file value begins with *.
		SET *%_HighlightedFile_%=*!*%_HighlightedFile_%!
	)

	REM Before comparing, alphabetize (chronologize) the two files. ASSUMES REPO_FLDR predates current folder (because it starts with '+').
	
	REM Unset _title_, and compare the two titles in alphabetical (chronological) order.  ASSUMES REPO_FLDR starts with +, which precedes any absolute path.
	set _title_=&FOR /F "tokens=1-2 delims=*" %%a In ('set * 2^>Nul') DO if not defined _title_ (SET _title_=%%b) ELSE CALL :FileCompare "!_title_!" "%%b" "%_SkipDiffIni_%"

	IF !ERRORLEVEL! EQU 1 SET _FileChanged_=Y

	:: Unset _SkipDiffIni_
	SET _SkipDiffIni_=

	:: Unset _HighlightedFile_
	SET _HighlightedFile_=
)

call :EchoCenterPad " %~1 " "-"

echo.

if exist "%REPO_FLDR%\Catalog.tmp" del "%REPO_FLDR%\Catalog.tmp"

powershell -command "& {FUNCTION ASCII {Param([int] $i) if ($i -le 0) {return '';} $r=$i %% 26; if ($r -eq 0) {$r=26;} return $(ASCII (($i-$r)/26)) + [char]($r+64);}; $ctr=1; gci '.\%REPO_FLDR%\' -recurse -include '%_FileName_%' | resolve-path -Relative | ForEach-Object {$_ -match '\.\\[^\\]+\\(\d+)\\.+' | out-null; if ('%_DefaultArchive_%' -eq $matches[1]) {$str='--';} else {$str=ASCII($ctr++);} Write-output $('{0} {1}\{2}\{3}' -f $str, '%REPO_FLDR%', $matches[1], '%_FileName_%') | out-file .\%REPO_FLDR%\CATALOG.TMP -Append; if ('%_DefaultArchive_%' -eq $matches[1]) {$str=$str + '>';} else {$str=$str + ')';} $str=$str.PadRight(4); $ts = NEW-TIMESPAN ([DateTime]::ParseExact($matches[1], 'yyyyMMddHHmmssff',[System.Globalization.CultureInfo]::InvariantCulture)) (GET-DATE); if ($ts.days -ne 0) { $str=$str + $ts.days + ' day'; } elseif ($ts.hours -ne 0) { $str=$str + $ts.hours + ' hour'; } else { $str=$str + $ts.minutes + ' minute'; } if (-not ($str -match '[A-Z-]+.\s+1 ')) { $str=$str + 's';} $str+=' ago.'; $str=$str.PadRight(20); gc .\%REPO_FLDR%\Restore.cmd | Where-Object { $_ -match ':{0} (.+)' -f $matches[1] | out-null }; $str + $matches[1];}; $str=ASCII($ctr); '{0}  Current Version' -f $str; Write-output $('{0} {1}' -f $str, '%~1') | out-file .\%REPO_FLDR%\CATALOG.TMP -Append;}"

echo.

rem Unset all variables starting with ?.  ASSUMES ? is an illegal char in a file name.
FOR /F "delims==" %%a In ('set ? 2^>Nul') DO SET "%%a="

SET cnt=0

set dft=%PJCT_FLDR%
if defined _DefaultArchive_ set dft=%REPO_FLDR%\%_DefaultArchive_%

rem For 1 to counter, add the character to the beginning and end of the input.
rem FOR /L %%? IN (0,1,%len%) DO SET txt=!c!!txt!!c!

SET Desc=Current Version.

for /f "tokens=1* delims= " %%L in ('type "%REPO_FLDR%\catalog.tmp"') do (
	REM if '%%L' NEQ '--' (
		REM ECHO %%M...
		set ?%%L?=%%M
		if "!dft!\!_FileName_!" NEQ "%%M" (
			set /a cnt+=1
			set chr=%%L
		) ELSE (
			REM PAUSE
			if "%%M" equ "Current Version" (
				SET _HighlightedFile_=%~1
			) else (
				SET _HighlightedFile_=%%M
				for /f "tokens=1-2 delims=\" %%F in ('type "!REPO_FLDR!\CATALOG.TMP" ^| findstr /BIC:%%L ') do (for /F "tokens=1* delims= " %%A in ('type "!REPO_FLDR!\Restore.cmd" ^| findstr /BC:":%%G"') do SET Desc=%%B)
			)
		)
	REM )
)

REM ECHO %dft%\%_FileName_%...
REM PAUSE

if %cnt% == 0 pause & endlocal & cls & color 1F & exit /b 0

:: Unset the response.
SET rsp=

if %cnt% GTR 1 (
	echo Enter [A-%chr%]-[A-%chr%] to compare two files
	echo or A-%chr% to compare to %Desc%
) ELSE (
	echo Enter A to compare to %Desc%
)
set /p rsp=or nothing to return: 

:: If the user entered nothing, clean the repository folder and return.
if not defined rsp (
	del "%REPO_FLDR%\CATALOG.tmp" >Nul
	del "%REPO_FLDR%\*.bkp" /F /Q >Nul
	cls
	color 1F
	if defined _FileChanged_ (endlocal & exit /b 1)
	endlocal
	exit /b 0
)

:: Get the selected file, and if the response includes -, we have a new Highlighted file.
for /f "tokens=1-2" %%f in ("%rsp:-= %") do (
	SET _SelectedFile_=!?%%f?!
	if defined ?%%g? SET _HighlightedFile_=!?%%g?!
)

:: Refresh the menu.
if not defined _SelectedFile_ (
	echo.
	echo Selected file not found.
	pause
)

GOTO :StartExploreFile

:FileCompare <File1> <File2> <File3/SkipDiffIni>
setlocal enabledelayedexpansion

Set Verbose=

:: Unset SkipDiffIni.
Set SkipDiffIni=

:: If the third arg is specified and it's not a file, set SkipDiffIni.
if '%~3' NEQ '' if not exist "%~3" SET SkipDiffIni=Y

REM cls

ECHO.

:: Get the differences in the input.
fc /n %1 %2 > "%REPO_FLDR%\Comp.tmp"
:: From the FC result, print the lines that begin with letters.
for /f "delims=" %%f in ('type "%REPO_FLDR%\Comp.tmp" ^| FINDSTR /rc:"^[A-Z]"') do echo %%f
:: If there were no differences, exit 0.
if !errorlevel! equ 0 endlocal & exit /b 0

:: If _Diff_App_ is not a thing, set CmdLine to the last (only?) line in Diff.ini.
if not defined _Diff_App_ for /f "delims=" %%f in ('type "!REPO_FLDR!\Diff.ini"') do SET _Diff_App_=%%f

:: If Diff.ini is a thing and SkipDiffIni is not defined...
if defined _Diff_App_ if not defined SkipDiffIni (

	:: Copy the last file to the repo folder.
	COPY "%~2" "%REPO_FLDR%\Current.bkp" /Y > Nul
	
	:: Set CmdLine to the last (only?) line in Diff.ini.
	SET CmdLine=!_Diff_App_!
	:: Replace %1 in the CmdLine with the first file name.
	SET CmdLine=!CmdLine:%%1=%1!
	:: Replace %2 in the CmdLine with the second file name.
	SET CmdLine=!CmdLine:%%2=%2!

	:: Use the differencing application, and wait for it to close.
	start /wait "diff" !CmdLine!
	
	cls
	
	:: Compare the last file to the repo folder.  If they differ, exit 1.
	FC "%~2" "%REPO_FLDR%\Current.bkp" > Nul || endlocal & exit /b 1

	:: Otherwise, exit 0.
	endlocal
	exit /b 0
	
)

rem Make a space delimited list of numbers of each line in Comp.tmp beginning with "***** %~2"
SET NewList=&for /f "delims=[]" %%f IN ('TYPE "%REPO_FLDR%\Comp.tmp" ^| find /n /i "***** %~2"') DO SET NewList=!NewList!%%f 
rem Add . to the end of NewList.
SET NewList=!NewList!.

If defined Verbose echo NewList=!NewList!

rem Make a space delimited list of numbers of each line in Comp.tmp beginning with "***** %~1"
SET OldList=&for /f "delims=[]" %%f IN ('TYPE "%REPO_FLDR%\Comp.tmp" ^| find /n /i "***** %~1"') DO SET OldList=!OldList!%%f 
rem Add . to the end of OldList.
SET OldList=!OldList!.

If defined Verbose echo OldList=!OldList!

rem Make a space delimited list of numbers of each line in Comp.tmp of the other lines beginning with "*****"
SET EndList=&for /f "delims=:" %%f IN ('TYPE "%REPO_FLDR%\Comp.tmp" ^| findstr /NBE "*****"') DO SET EndList=!EndList!%%f 
rem Add . to the end of EndList.
SET EndList=!EndList!.

If defined Verbose echo EndList=!EndList!

If defined Verbose pause

Set SetNum=1
:StartCompares
rem echo SetNum=!SetNum!
rem Get the next line number in NewList and if the result is the end of the list, pause and quit.
for /f "tokens=%SetNum%" %%f in ("!NewList!") do if "%%f" NEQ "." (set n=%%f) ELSE (ECHO.&ENDLOCAL&GOTO :EOF)

rem Get the next line number in OldList.
for /f "tokens=%SetNum%" %%f in ("!OldList!") do set o=%%f

rem Get the next line number in EndList.
for /f "tokens=%SetNum%" %%f in ("!EndList!") do set _end_=%%f

:: Get the beginning and ending lines of the old set.
SET /a o1=%o%+1
SET /a o2=%n%-1

:: Get the beginning and ending lines of the new set.
SET /a n1=%n%+1
SET /a n2=%_end_%-1

:: Get the number of columns on the screen.
for /f "tokens=1* delims= " %%f in ('mode con ^| find /i "columns"') do set /a cols=%%g - 2

set _Line_=
for /l %%f in (1,1,%cols%) do set _Line_=!_Line_!-
ECHO %_Line_%

:: Set _OldLine_ to the o1th line in Comp.tmp.
for /f "tokens=1* delims=:" %%f in ('findstr /nr "." "%REPO_FLDR%\Comp.tmp" ^| findstr /b "%o1%:"') do SET _OldLine_=%%g
:: Set _NewLine_ to the n1th line in Comp.tmp.
for /f "tokens=1* delims=:" %%f in ('findstr /nr "." "%REPO_FLDR%\Comp.tmp" ^| findstr /b "%n1%:"') do SET _NewLine_=%%g

if defined Verbose echo OldLine(!o1!): !_OldLine_!
if defined Verbose echo NewLine(!n1!): !_NewLine_!

:: Unless the two lines are equal except line numbers...
if "!_OldLine_:~6!" NEQ "!_NewLine_:~6!" (
	:: ...print the old set in red.
	powershell -command "& {gc "%REPO_FLDR%\Comp.tmp" -TotalCount %o2% | Select-Object -Last (%o2%-%o1%+1) | ForEach-Object {write-host -ForegroundColor red -$_}}"
) ELSE (
	:: Otherwise, print the first line in white...
	powershell -command "& {gc "%REPO_FLDR%\Comp.tmp" -TotalCount %n1% | Select-Object -Last 1 | ForEach-Object {write-host '~     '$_.substring(6)}}"
	:: ...then print the remainder in red.
	powershell -command "& {gc "%REPO_FLDR%\Comp.tmp" -TotalCount (%o2%-1) | Select-Object -Last (%o2%-%o1%-1) | ForEach-Object {write-host -ForegroundColor red -$_}}"
)

:: Set _OldLine_ to the o2th line in Comp.tmp.  WARNING: The o2th line must be a thing or _OldLine_ will not get overwritten.
for /f "tokens=1* delims=:" %%f in ('findstr /nr "." "%REPO_FLDR%\Comp.tmp" ^| findstr /b "%o2%:"') do SET _OldLine_=%%g
:: Set _NewLine_ to the n2th line in Comp.tmp.  WARNING: The n2th line must be a thing or _NewLine_ will not get overwritten.
for /f "tokens=1* delims=:" %%f in ('findstr /nr "." "%REPO_FLDR%\Comp.tmp" ^| findstr /b "%n2%:"') do SET _NewLine_=%%g

REM echo "!_OldLine_:~6!" NEQ "!_NewLine_:~6!"?

:: Unless the two lines are equal except line numbers...
if "!_OldLine_:~6!" NEQ "!_NewLine_:~6!" (
	:: ...print all of the new set in green.
	powershell -command "& {gc "%REPO_FLDR%\Comp.tmp" -TotalCount %n2% | Select-Object -Last (%n2%-%n1%+1) | ForEach-Object {write-host -ForegroundColor green +$_}}"
) ELSE (
	:: Otherwise, print all but the last line in green...
	powershell -command "& {gc "%REPO_FLDR%\Comp.tmp" -TotalCount (%n2%-1) | Select-Object -Last (%n2%-%n1%-1) | ForEach-Object {write-host -ForegroundColor green +$_}}"
	:: ...then print the remainder in white.
	powershell -command "& {gc "%REPO_FLDR%\Comp.tmp" -TotalCount (%n%-1) | Select-Object -Last 1 | ForEach-Object {write-host '~     '$_.substring(6)}}"
)

:: Increment SetNum
SET /a SetNum+=1

:: Loop
GOTO :StartCompares

:: Exit 0.
endlocal
exit /b 0

:IsNumeric <num>
echo %1| findstr /rc:"^[0-9][0-9]*$" > Nul && (Exit /b 0) || (Exit /b 1)

:ASCII
setlocal EnableDelayedExpansion

SET inp=%1

:: define characters
set alphabet=ABCDEFGHIJKLMNOPQRSTUVWXYZ
 
set character=

:NextASCII
:: get the index
set /a idx=%inp% %% 26

:: retrieve letter
set character=!alphabet:~%idx%,1!%character%

:: end the routine and return result as second parameter (out)
IF %inp% GEQ 26 (
	SET /A inp/=26
	SET /A inp-=1
	GOTO :NextASCII
)
endlocal & set %2=^%character%
GOTO :EOF

:jtime JD DateStr -- converts a time string to number of seconds since midnight
::                -- JT      [out,opt] - julian time
::                -- TimeStr [in,opt]  - time string, e.g. "3:31:20 PM"
SETLOCAL

set TimeStr=%~2&if "%~2"=="" set TimeStr=%time%
rem Get the current time.
For /f "tokens=1-5 delims=/:. " %%a in ("%TimeStr%") do (
	SET HH=%%a
	SET MM=%%b
	SET SS=%%c
	SET MilliSeconds=%%d
	SET Meridian=%%e
)
SET /a "HH=100%HH% %% 100,MM=100%MM% %% 100,SS=100%SS% %% 100"
IF '%Meridian%' EQU 'PM' SET /a HH=%HH%+12
SET /a JT=%HH%*3600+%MM%*60+%SS%
ENDLOCAL & IF "%~1" NEQ "" (SET %~1=%JT%) ELSE (echo.%JT%)
EXIT /b

:jdate JD DateStr -- converts a date string to julian day number with respect to regional date format
::                -- JD      [out,opt] - julian days
::                -- DateStr [in,opt]  - date string, e.g. "03/31/2006" or "Fri 03/31/2006" or "31.3.2006"
:$reference http://groups.google.com/group/alt.msdos.batch.nt/browse_frm/thread/a0c34d593e782e94/50ed3430b6446af8#50ed3430b6446af8
:$created 20060101 :$changed 20080219
:$source http://www.dostips.com
SETLOCAL
set DateStr=%~2&if "%~2"=="" set DateStr=%date%
for /f "skip=1 tokens=2-4 delims=(-)" %%a in ('"echo.|date"') do (
    for /f "tokens=1-3 delims=/.- " %%A in ("%DateStr:* =%") do (
        set %%a=%%A&set %%b=%%B&set %%c=%%C))
set /a "yy=10000%yy% %%10000,mm=100%mm% %% 100,dd=100%dd% %% 100"
set /a JD=dd-32075+1461*(yy+4800+(mm-14)/12)/4+367*(mm-2-(mm-14)/12*12)/12-3*((yy+4900+(mm-14)/12)/100)/4
ENDLOCAL & IF "%~1" NEQ "" (SET %~1=%JD%) ELSE (echo.%JD%)
EXIT /b

:JulianToDate <in> <out>
REM CONVERT JULIAN DAY NUMBER TO MONTH, DAY, YEAR
REM ANTONIO PEREZ AYALA
SET /A W=(%1*100-186721625)/3652425, X=W/4, A=%1+1+W-X, B=A+1524, C=(B*100-12210)/36525, D=36525*C/100, E=(B-D)*10000/306001, F=306001*E/10000, DD=B-D-F, MM=E-1, YY=C-4716
IF %MM% GTR 12 SET /A MM-=12, YY+=1
REM INSERT LEFT ZEROS, IF NEEDED
IF %DD% LSS 10 SET DD=0%DD%
IF %MM% LSS 10 SET MM=0%MM%
REM SHOW THE DATE
SET %2=%MM%/%DD%/%YY%
exit /b

:TimeStamp ret -- returns a unique string based on a date-time-stamp, YYYYMMDDhhmmsscc
::          -- ret    [out,opt] - unique string
:$created 20060101 :$changed 20080219 :$categories StringOperation,DateAndTime
:$source http://www.dostips.com
SETLOCAL

rem Get the current Date.
For /f "tokens=2-4 delims=/ " %%a in ("%DATE%") DO SET TIMESTAMP=%%c%%a%%b

rem Get the current time.
For /f "tokens=1-4 delims=/:." %%a in ("%TIME%") DO (
	SET HH24=%%a
	SET HH24=0!HH24: =!
	SET TIMESTAMP=!TIMESTAMP!!HH24:~-2!%%b%%c%%d
)

ENDLOCAL & IF "%~1" NEQ "" (SET %~1=%TIMESTAMP%) ELSE echo.%TIMESTAMP%
EXIT /b

:EchoCenterPad <text> <char>
SETLOCAL

SET txt=%~1

:: If the text is not specified, default to space.
if '%~2' EQU '' (SET c= ) ELSE set c=%~2

rem Save the length of the input.
CALL :strLen txt len

for /f "tokens=1* delims= " %%f in ('mode con ^| find /i "columns"') do set /a cols=%%g - 2

rem The Counter is the difference between the width of the screen and the length of the input.
SET /a ctr=%cols%-%len%
rem Get the remainder of the counter divided by 2.
SET /a r=%ctr% %% 2
rem If the remainder is 1, increment the counter.
IF %r%==0 SET /a ctr=%ctr% + 1
SET /a ctr=%ctr% / 2

rem For 1 to counter, add the character to the beginning and end of the input.
FOR /L %%? IN (0,1,%ctr%) DO SET txt=!c!!txt!!c!

rem ECHO the result.
ECHO %txt%

ENDLOCAL

EXIT /b

:FeedNewTxt <in> <opt> <opt> -- Echoes file names, dates and times specified by the given expression (e.g. "P:\ProjectFolder" /S)
::          %~1 file or folder to seek.
::          %~2 /S if subfolders are specified.
::          %~3 # if ModifiedDate is specified.

setlocal EnableDelayedExpansion

:: TODO When inp has parentheses or spaces.

:: Remember the input
set "inp=%~1"

:: Trim the input
set inp=%inp:" ="%

:: Set the path to the input minus all quotes.
set pth=%inp:"=%

:: Unset the mask.
set msk=

:: If pth is a folder...
call :IsFolder '%pth%' && (

	:: ...get the subfolder of the input.
	for /f "delims=" %%f in ("%inp%") do set pth=%%~dpf

	:: If no path was returned, quit.
	if not defined pth exit /b

	:: Without this line, it crashes (!!!!)
	echo inp=%inp%
	
	:: The mask is the input minus the path.
	set msk=!inp:%pth%=!
	
)

:: Wrap the path in single quotes.
set pth='%pth%'

:: Drop any trailing backslashes from path.
set pth=%pth:\'='%

:: Unset CmdLine
SET CmdLine=

:: If %~2 is /S, tell powershell to recurse, then shift.
:: ASSUMES /S precedes #.
If '%~2' EQU '/S' SET CmdLine=%CmdLine% -Recurse&shift /1

:: ASSUMES If %~2 is a thing, it's a date.
If '%~2' NEQ '' SET CmdLine= %CmdLine% ^^^| ? {$_.LastWriteTime -gt '%~2'}

if defined msk set CmdLine= -Filter '%msk%' %CmdLine%

SET CmdLine=gci -af -Path %pth% %CmdLine%

rem Remember to filter out this file as well as the repo folder.  For now, use \* to delimit filters.
SET Filter=%CD:\=\\%\\%~nx0\*%CD:\=\\%\\%REPO_FLDR%

rem If Exclude.txt is a thing, add each line (except lines starting in #) to the filter.
if exist "%REPO_FLDR%\Exclude.txt" for /f "eol=# delims=" %%f in ('Type "%REPO_FLDR%\Exclude.txt"') do Set Filter=!Filter!\*%%f

rem Escape the Regex Metacharacters that are legal in a windows filename.
SET Filter=%Filter:+=\+%
SET Filter=%Filter:^=^^%
SET Filter=%Filter:$=\$%

rem Replace the asterisks with pipes in the filter.
SET Filter=%Filter:\*=^|%

rem Escape all parentheses in the Filter.
SET Filter=!Filter:^)=^\^)!
SET Filter=!Filter:^(=^\^(!

rem echo Filter:!Filter!

rem Run the PowerShell command.
rem echo powershell -command "& {$Count=( %CmdLine% | where fullname -notmatch '!Filter!' | Measure-Object).Count; $I=0; %CmdLine% | where fullname -notmatch '!Filter!' | foreach {$I++; Write-Progress -Activity ('Scanning {0} files in %PJCT_FLDR%' -f $Count) -Status $_.FullName -PercentComplete($I/$Count*100); """"""""""{0}""""""""|""""""""{1}"""""""""" -f $_.FullName, (Get-Filehash($_.FullName)).hash;} | out-file -append '%REPO_FLDR%\New.txt'}"
rem pause
powershell -command "& {$Count=( %CmdLine% | where fullname -notmatch '!Filter!' | Measure-Object).Count; $I=0; %CmdLine% | where fullname -notmatch '!Filter!' | foreach {$I++; Write-Progress -Activity ('Scanning {0} files in %PJCT_FLDR%' -f $Count) -Status $_.FullName -PercentComplete($I/$Count*100); """"""""""{0}""""""""|""""""""{1}"""""""""" -f $_.FullName, (Get-Filehash($_.FullName)).hash;} | out-file -append '%REPO_FLDR%\New.txt'}"

endlocal
EXIT /b

:IsFolder <Path>
rem echo Is %~1 a folder?
PUSHD "%~1" 2> Nul && POPD || EXIT /b 1
EXIT /b 0

:CleanFile string -- alphabetizes lines in a file and omits duplicates.
powershell -command "& {gc '%~1' | sort -u | ? {$_ -ne ''} | Out-file '%REPO_FLDR%\Temp.del'}"
Type "%REPO_FLDR%\Temp.del" > %~1
del "%REPO_FLDR%\Temp.del"
exit /b

:trimSpaces varref -- trims spaces around string variable
::                 -- varref [in,out] - variable to be trimmed
:$created 20060101 :$changed 20080223 :$categories StringManipulation
:$source https://www.dostips.com
call call:trimSpaces2 %~1 %%%~1%%
EXIT /b

:trimSpaces2 retval string -- trims spaces around string and assigns result to variable
::                         -- retvar [out] variable name to store the result in
::                         -- string [in]  string to trim, must not be in quotes
:$created 20060101 :$changed 20080219 :$categories StringManipulation
:$source https://www.dostips.com
for /f "tokens=1*" %%A in ("%*") do set "%%A=%%B"
EXIT /b

:strLen string len -- returns the length of a string
::                 -- string [in]  - variable name containing the string being measured for length
::                 -- len    [out] - variable to be used to return the string length
:: Many thanks to 'sowgtsoi', but also 'jeb' and 'amel27' dostips forum users helped making this short and efficient
:$created 20081122 :$changed 20101116 :$categories StringOperation
:$source http://www.dostips.com
(   SETLOCAL ENABLEDELAYEDEXPANSION
    set "str=A!%~1!"&rem keep the A up front to ensure we get the length and not the upper bound
                     rem it also avoids trouble in case of empty string
    set "len=0"
    for /L %%A in (12,-1,0) do (
        set /a "len|=1<<%%A"
        for %%B in (!len!) do if "!str:~%%B,1!"=="" set /a "len&=~1<<%%A"
    )
)
( ENDLOCAL & REM RETURN VALUES
    IF "%~2" NEQ "" SET /a %~2=%len%
)
EXIT /b
