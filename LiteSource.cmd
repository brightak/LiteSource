@ECHO OFF

SETLOCAL ENABLEDELAYEDEXPANSION

rem SET File Differencer here (e.g. "C:\Program Files (x86)\Folder\Application.exe" "%%1" "%%2").
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

rem Unset all variables starting with ?.  ASSUMES ? is an illegal char for a filename.
FOR  /F "delims==" %%a In ('set ? 2^>Nul') DO SET "%%a="

rem If no arguments, just start.
if [%1] EQU [] GOTO :NoArgs

rem Unset _FilesSpecified_
set _FilesSpecified_=

rem Unset _Date_
SET _Date_=

rem GOTO LoopArgs
GOTO :LoopArgs

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

:LoopArgs

:: If this argument is /?, help.
If '%1' EQU '/?' GOTO :Help

:: If it's not /C, look for a date.
IF '%1' NEQ '/C' IF '%1' NEQ '/c' GOTO :SeekDifferencer

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

:SeekDifferencer

:: If this argument isn't /F, look for a date.
IF '%1' NEQ '/F' IF '%1' NEQ '/f' GOTO :SeekDate

:: Otherwise, get the next arg and set it as the file differencer.
SHIFT /1
SET _Diff_App_=%~1

:: If the file differencer needs %1, add it and %2
IF "!_Diff_App_!" EQU "!_Diff_App_:%%1=!" SET _Diff_App_="!_Diff_App_!" "%%1" "%%2"

SET _Diff_App_=!_Diff_App_:""="!

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
	rem FOR /F "TOKENS=1-2 DELIMS=^=" %%F IN ('FIND "SET PJCT_FLDR=" "%REPO_FLDR%\Restore.cmd"') DO SET ?%%f?=?%%g
	
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

:NoArgs

color 1f

::If Old.txt is a thing, it's not a new archive.
If EXIST "%REPO_FLDR%\Old.txt" GOTO :GotOldText

:FirstRodeo

CLS

:: If this is your first rodeo, unset the PJCT_FLDR.
SET PJCT_FLDR=

SET Batch=%~nx0
:: Look for the files in this folder and if any are different from this batch file, this is the path.
for /f %%a in ('forfiles /c "cmd /c if @isdir==FALSE fc "@path" """%Batch:)=^^)%""">Nul || echo @file"') do SET PJCT_FLDR=!CD!& GOTO :NoArchives

:: Otherwise, ask for a folder to track.
set /p PJCT_FLDR=Please specify a folder to track (or enter nothing to quit): 

:: If the user enters nothing, quit.
if not defined PJCT_FLDR COLOR&GOTO :EOF

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

:: FOR ROBOCOPY, ensure Project Folder does not end in \
SET PJCT_FLDR="%PJCT_FLDR%"
SET PJCT_FLDR=%PJCT_FLDR:\"="%
SET PJCT_FLDR=%PJCT_FLDR:"=%

echo.

:NoArchives

CALL :GetExcludePatterns exclude

if defined exclude set "exclude=^| where fullname -notmatch '!exclude!' "

rem echo powershell -command "& gci '%PJCT_FLDR%' -Recurse !exclude!| ForEach-Object {$cnt+=1; $sum+=$_.Length;}; Write-Host ('Found {0} MB in {1} files in %PJCT_FLDR%' -f ($sum / 1MB), $cnt)"
rem pause
powershell -command "& gci '%PJCT_FLDR%' -Recurse !exclude!| ForEach-Object {$cnt+=1; $sum+=$_.Length;}; Write-Host ('Found {0} MB in {1} files in %PJCT_FLDR%' -f ($sum / 1MB), $cnt)"

Set Msg=
echo.
echo Enter a message (5+ chars) to commit,
echo or ^^! to select files to exclude, 
SET /P Msg=or nothing to quit: 

rem echo Msg=!Msg!

if not defined Msg COLOR & GOTO :EOF

:: Create the Repo folder if necessary.
if not exist "%REPO_FLDR%" MD "%REPO_FLDR%\"

rem If the user typed !, Exclude Patterns, then return to NoArchives.
if "!Msg!" EQU "^!" CALL :ExcludePatterns & cls & color 1f & GOTO :NoArchives

rem If the user typed something 5 chars or shorter, return to NoArchives.
IF "%Msg%" EQU "%Msg:~0,6%" cls & GOTO :NoArchives

rem Unless Restore.cmd is a thing...
if not exist "%REPO_FLDR%\Restore.cmd" (
(
ECHO @ECHO OFF
ECHO SET NoArgs=
ECHO IF '%%1' NEQ '' (GOTO :Prepare^) ELSE SET NoArgs=Y
ECHO :Help
ECHO ECHO Restores a project folder, or updates an archive folder.
ECHO ECHO.
ECHO ECHO RESTORE destination [source] [/U] [/Y]
ECHO ECHO.
ECHO ECHO  destination  The destination folder to restore or update.
ECHO ECHO  source       The name of the Archive folder to restore to or update from.
ECHO ECHO               If omitted, updates all except initial commit or restores all.
ECHO ECHO  /U           Update mode.
ECHO ECHO  /Y           Does not ask before overwriting or creating a new folder.
ECHO ECHO.
ECHO findstr /r ":[0-9][0-9]*" "%%~f0"^>Nul ^&^& ECHO Known Archives:
ECHO for /f "tokens=1* delims=: " %%%%f in ('findstr /r ":[0-9][0-9]*" "%%~f0"'^) DO ECHO %%%%f: %%%%g
ECHO ECHO.
ECHO ECHO Use this application to:
ECHO ECHO	A^) Restore a project completely.                 e.g. Restore N:\MyProject
ECHO ECHO	B^) Restore a project to a certain point.         e.g. Restore N:\MyProject EndingArchiveName
ECHO ECHO	C^) Apply only recent changes to an archive.      e.g. Restore C:\Archive1 StartingArchiveName /U
ECHO ECHO	D^) Fill a folder with only updated/added files.  e.g. Restore C:\Archive1 /U
ECHO ECHO.
ECHO IF DEFINED NoArgs PAUSE
ECHO GOTO :EOF
ECHO :Prepare
ECHO SETLOCAL ENABLEDELAYEDEXPANSION
ECHO SET REPO_FLDR=%%~dp0
IF "%PJCT_FLDR%" EQU "%CD%" ECHO SET PJCT_FLDR=
IF "%PJCT_FLDR%" NEQ "%CD%" ECHO SET PJCT_FLDR=%PJCT_FLDR%
ECHO SET _Confirmed=
ECHO SET _verb_=restore
ECHO SET _Target_=
ECHO SET _Archive_=
ECHO :Top
ECHO rem If no more arguments, start.
ECHO IF '%%1' EQU '' GOTO :Start
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
ECHO IF NOT DEFINED _Target_ SET _Target_=%%1^&SHIFT^&GOTO :Top
ECHO rem Otherwise, if the archive folder is not a thing but the argument is, set the archive folder.
ECHO IF NOT DEFINED _Archive_ SET _Archive_=%%1^&SHIFT^&GOTO :Top
ECHO rem If a Target folder is not specified, quit gracefully.
ECHO GOTO :Help
ECHO :Start
ECHO rem Take the single quotes from the Target folder name.
ECHO SET _Target_=%%_Target_:'=%%
ECHO rem Take the double quotes from the Target folder name.
ECHO SET _Target_=%%_Target_:"=%%
ECHO rem If specified target is not an existing folder...
ECHO DIR /b /ad "%%_Target_%%" ^| FIND /i "File Not Found" ^&^& (
ECHO    rem ...and confirmation is required...
ECHO    If NOT DEFINED _Confirmed (
ECHO        rem ...ask if you can create the target folder...
ECHO        CHOICE /M "Folder not found '%%_Target_%%'.  Create it"
ECHO        rem ...and if you can't, quit...
ECHO        IF ^^!ERRORLEVEL^^! EQU 2 EXIT /B 1
ECHO    ^)
ECHO    rem ...otherwise, create the Target folder.
ECHO    MD "%%_Target_%%"
ECHO ^)
ECHO.
ECHO rem If the user is updating and an archive is not specified...
ECHO IF '%%_verb_%%' == 'update' IF NOT DEFINED _Archive_ (
ECHO     rem ...find the second archive from Restore.cmd and get the archive folder name...
ECHO     for /f "tokens=1-2 delims=: " %%%%f in ('findstr /r ":[0-9][0-9]*" "%%~f0" ^^^| find ":" /n ^^^| findstr /b "[2]:"'^) DO SET _Archive_=%%%%g
ECHO     rem ...and if _Archive_ is still not a thing (no second backup in Restore.cmd^), warn the user and quit.
ECHO     IF NOT DEFINED _Archive_ ECHO Please specify an existing archive to update.^&PAUSE^&EXIT /B 1
ECHO ^)
ECHO.
ECHO SET AdditionalWhere=
ECHO If defined _Archive_ (
ECHO    if "%%_verb_%%" == "update" (
ECHO        Set AdditionalWhere=$arc -ge %%_Archive_%% -and 
ECHO    ^) else (
ECHO        Set AdditionalWhere=$arc -le %%_Archive_%% -and 
ECHO    ^)
ECHO ^)
ECHO.
ECHO rem If the target is not defined, set it to the PJCT_FLDR.
ECHO IF NOT DEFINED _Target_ SET _Target_=%%PJCT_FLDR%%
ECHO rem ASSUME if you can read this and PJCT_FLDR is not a thing, it's the parent directory.
ECHO IF NOT DEFINED _Target_ FOR %%%%a IN ("%%REPO_FLDR:~0,-1%%"^) DO SET _Target_=%%%%~dpa
ECHO rem Escape the Regex Metacharacters that are legal in a windows file path.
ECHO SET _Target_=%%_Target_:\=\\%%
ECHO SET _Target_=%%_Target_:+=\+%%
ECHO SET _Target_=%%_Target_:^^=^^^^%%
ECHO SET _Target_=%%_Target_:$=\$%%
ECHO SET _Target_=%%_Target_:.=\.%%
ECHO SET _Target_=%%_Target_:"=%%
ECHO.
ECHO SET _Confirm_=
ECHO IF NOT DEFINED _Confirmed SET _Confirm_= foreach ($result in $results.GetEnumerator(^)^) {if ($result.Value -eq ''^^^) {Write-Host Delete $result.Name} else {$msg='Update {0} from {1}' -f $result.Name, [DateTime]::ParseExact($result.Value, 'yyyyMMddHHmmssff',[System.Globalization.CultureInfo]::InvariantCulture^^^); Write-Host $msg}}; $resp = Read-Host 'Enter Y to continue'; if ($resp.ToUpper(^^^) -ne 'Y'^^^) {exit 1;}
ECHO.
ECHO echo.
ECHO powershell -command "& {$Files = @{}; gc '%%REPO_FLDR%%Restore.cmd' | foreach-object { if ($_ -match ':(\d+)') {$arc=$matches[1]} else {if (%%AdditionalWhere%%$_ -match ':: (\w+) ""(.+)""""') {if ($matches[1] -eq 'Deleted') {$Files[$matches[2]]='';} else {$Files[$matches[2]]=$arc;} } } }; $I=0; $results=@{}; foreach ($k in $Files.Keys) {$I++; Write-Progress -Activity ('Scanning {0} files' -f $Files.Count) -Status $k -PercentComplete($I/$Files.Count*100); if (&{if ($Files.Item($k) -eq '') {Test-Path ('%%_Target_%%' + $k)} else {(-not (Test-Path ('%%_Target_%%\' + $k)) -or (Get-filehash $('%%REPO_FLDR%%\' + $Files.Item($k) + $k)).hash -ne (get-filehash $('%%_Target_%%\' + $k)).hash)} }) {$results.Add($k, $Files.Item($k));}} if ($results.length -eq 0) {Write-Host No changes made.; exit 1;} %%_Confirm_%% foreach ($result in $results.GetEnumerator()) {$dst='%%_Target_%%{0}' -f $result.Name; if ($result.Value -ne '') {$src='%%REPO_FLDR%%{0}{1}' -F $result.Value, $result.Name; New-Item -ItemType File -Path ""$dst"""" -force | out-null; Copy-Item ""$src"""" -Destination ""$dst"""" -force} else {if (Test-Path ""$dst"""") {Remove-Item ""$dst""""}}}; Write-Host Folder updated.;}"
ECHO.
ECHO if %%errorlevel%% == 1 exit /B 1
ECHO exit /B 0
ECHO.
)>"%REPO_FLDR%\Restore.cmd"
)
:: Delete New.txt if necessary.
if exist "%REPO_FLDR%\New.txt" del "%REPO_FLDR%\New.txt"

SET ?>Nul 2>&1
:: If files are unspecified...
IF ERRORLEVEL 0 (

	:: ...create New.txt from PJCT_FLDR.
	CALL :FeedNewTxt "%PJCT_FLDR%" /S

) ELSE (

pause
	:: Feed the files to New.txt with any specified arguments.
	for /f "tokens=1-3* delims=?" %%f in ('set ?') do (
	
		:: Get the filename.
		SET _Line_="%%f"

		:: If it's a folder and subfolders are defined, add /S.
		CALL :IsFolder "%%f" && SET _Line_=!_Line_!%%h

		CALL :FeedNewTxt !_Line_! !_DATE_!
	
	)
)

:: Alphabetize New.txt and remove duplicates.
CALL :CleanFile "%REPO_FLDR%\New.txt"

:: Ensure an Old.txt....
if exist "%REPO_FLDR%\New.txt" if not exist "%REPO_FLDR%\Old.txt" ren "%REPO_FLDR%\New.txt" Old.txt

:: ...and if a Commit Message was specified, commit.
if "%Msg%" NEQ "" CALL :StartCommit

rem Quit or return from whence you're called.
GOTO :EOF

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

rem set PJCT_FLDR=!PJCT_FLDR:^)=^\^)!
rem set PJCT_FLDR=!PJCT_FLDR:^(=^\^(!

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
(
ECHO @ECHO OFF
ECHO SET NoArgs=
ECHO IF '%%1' EQU '' SET NoArgs=Y
ECHO IF '%%1' NEQ '' IF '%%1' NEQ '/?' GOTO :Start
ECHO.
ECHO ECHO Commits a change or changes from !PJCT_FLDR!
ECHO.
ECHO ECHO COMMIT message destination [A [+B] [+C]...]
ECHO.
ECHO ECHO message            The message pertaining to the new Archive (5 chars+^)
ECHO ECHO destination        The name of the new Archive.
ECHO ECHO a [+b] [+c]...     The files to commit.  If omitted, commits all.
ECHO ECHO.
ECHO findstr /r ":[A-Z][A-Z]*)[^-]" "%%~f0"^>Nul ^&^& ECHO Targeted Files:
ECHO FOR /F "tokens=1-2* delims=:^) " %%%%f IN ('findstr /R "^:[A-Z][A-Z]*)[^-]" "%%~f0"'^) DO echo %%%%f: %%%%h
ECHO ECHO.
ECHO IF DEFINED NoArgs PAUSE
ECHO GOTO :EOF
ECHO ECHO.
ECHO :Start
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
)>"!REPO_FLDR!\Commit.cmd"

SET "ChangeCount=0"

:: If New.txt is not a thing...
If NOT EXIST "%REPO_FLDR%\New.txt" (
	rem echo on
	:: ...every file in Old.txt (ASSUMES filenames in Old.txt are delimited by ") is a creation.
	for /f delims^=^" %%f IN ('type "%REPO_FLDR%\Old.txt"') do CALL :AppendCommit ChangeCount Created "%%f"
	rem pause
) ELSE (

	CALL :GetExcludePatterns exclude

	if defined exclude SET exclude=^| where InputObject -notmatch {!exclude!} &rem
	
	:: Otherwise, find the differences between Old.txt and New.txt, change >= to > and <= to < in case = is in the file name, and save to Diff.tmp...
	rem TODO When the folder is empty, New.txt is null!!!  Add a line so no crashee.
	rem echo powershell -Command "& {Compare-Object (Get-Content '%REPO_FLDR%\Old.txt') (Get-Content '%REPO_FLDR%\New.txt') !exclude!| ft inputobject, @{n='file';e={ if ($_.SideIndicator -eq '=>') { '>' }  else { '<' } }} | out-file -width 1000 '%REPO_FLDR%\Diff.tmp'}" 
	rem pause
	powershell -Command "& {Compare-Object (Get-Content '%REPO_FLDR%\Old.txt') (Get-Content '%REPO_FLDR%\New.txt') !exclude!| ft inputobject, @{n='file';e={ if ($_.SideIndicator -eq '=>') { '>' }  else { '<' } }} | out-file -width 1000 '%REPO_FLDR%\Diff.tmp'}" 

	:: ...and if any are found...
	FOR %%A IN ("%REPO_FLDR%\Diff.tmp") DO IF %%~zA EQU 0 GOTO :CloseCommit

	:: Unset all variables starting with ?.  ASSUMES ? is an illegal char in a file name.
	FOR /F "delims==" %%a In ('set ? 2^>Nul') DO SET "%%a="

	:: For each filename in Old.txt, if it's not in New.txt, flag it as deleted. ASSUMES filenames in Old.txt are delimited by "
	if not defined _NothingIsDeleted_ for /f delims^=^" %%f IN ('type "%REPO_FLDR%\Diff.tmp" ^| findstr ^^^<') do type "!REPO_FLDR!\Diff.tmp" | findstr ^> | findstr /C:"%%f" > Nul || SET ?%%f?=?Deleted
	
	:: For each filename in New.txt, if it's in Old.txt, flag it as updated.  Otherwise, flag it as created.
	for /f delims^=^" %%f IN ('type "%REPO_FLDR%\Diff.tmp" ^| findstr ^^^>') do type "!REPO_FLDR!\Diff.tmp" | findstr ^< | findstr /C:"%%f" > Nul && SET ?%%f?=?Updated || SET ?%%f?=?Created

	:: Now, for each variable that starts with ?, use the var (filename) and value (Created/Updated/Deleted) to append Commit.cmd.
	FOR  /F "tokens=1-3 delims=?" %%f In ('set ? 2^>Nul') DO CALL :AppendCommit ChangeCount %%h "%%f"
	
)

:CloseCommit
rem TODO: What if folders are in New.txt but not Old.txt?

call :ASCII %ChangeCount% chr
(
ECHO.
ECHO :%chr%^)
ECHO rem For each deleted file, tell Restore.cmd to unset the var.
ECHO FOR /F "tokens=1-3 delims=?" %%%%a In ('set ? 2^^^>Nul'^) DO ECHO SET ?%%%%a?=^>^>"%REPO_FLDR%\Restore.cmd"
ECHO rem Tell Restore.cmd to return.
ECHO ECHO GOTO :EOF^>^>"%REPO_FLDR%\Restore.cmd"
)>>"%REPO_FLDR%\Commit.cmd"

rem If a Msg was specified, run Commit.cmd.
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
	powershell -command "& {$ctr=0; (gc '.\%REPO_FLDR%\Restore.cmd') | ForEach-Object { if ($_ -match ':(\d+) (.+)') {$ts = NEW-TIMESPAN ([DateTime]::ParseExact($matches[1], 'yyyyMMddHHmmssff',[System.Globalization.CultureInfo]::InvariantCulture)) (GET-DATE); $ctr++; $line=([string]$ctr) + ')'; $line=$line.PadRight(5); $q=$ts.minutes; $i=' minute'; if ($ts.days -ne 0) { $q=$ts.days; $i=' day';} else {if ($ts.hours -ne 0) { $q=$ts.hours; $i=' hour';}} if ($q -ne 1) {$i+='s'} $line=$line + $q + $i + ' ago.'; Write-Host $line.PadRight(20) $matches[2];}}}"
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
SET /P Msg=^^! to toggle exclude patterns, or nothing to quit: 

rem If input is nothing, quit.
IF not defined Msg (color & cls & GOTO :EOF)

if "!Msg!" EQU "^!" CALL :ExcludePatterns&GOTO :GetNewText

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

REM echo !Msg!

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
	:: Otherwise, explore the file minus the Project Folder.
	CALL :ExploreFile !_File_:%PJCT_FLDR:)=^)%=!
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
::            Verb [in] -- The verb that applies to this update (e.g. "Created", "Deleted", "Updated").
::            Filename [in] -- The absolute name of the file to update.

SETLOCAL EnableDelayedExpansion

:: Get the ASCII equivalent of the number.
SET /a "cnt=%~1"
call :ASCII %cnt% chr

FOR /f "delims=" %%f IN (%3) DO (
	rem Remember the Filename's name and extension...
	SET fln=%%~nxf
	rem ...and escape end parentheses.
	SET fln=!fln:^)=^^^)!
	rem Remember the Filename's drive and path, surrounded by "...
	SET src="%%~dpf"
	rem ...so you can drop the trailing \...
	SET src=!src:\"="!
	rem ...and remove all quotes from src.
	SET src=!src:"=!
	rem The destination is the source after the Project folder.
	SET dst=!src:%PJCT_FLDR%=!
)

(
ECHO.
ECHO :%chr%^) %2 %3
SET /A cnt+=1
call :ASCII !cnt! chr
ECHO rem if _FilesToCommit_ is a thing and %3 is not in it, skip.
ECHO IF DEFINED _FilesToCommit_ ECHO %%_FilesToCommit_%% ^| FIND """%src%\!fln!""" ^> nul ^|^| GOTO :!chr!

if "%2" == "Deleted" (
	ECHO rem Remember !_FileName_! is deleted.
	ECHO SET ?!fln!?=?%%%%_Target%%%%
) ELSE (
	ECHO rem Copy %3 to the archive, creating the archive if necessary.
	ECHO robocopy "%src%" "%%_Archive_%%%dst%" "!fln!"^>Nul
)
ECHO ECHO %2 %3
ECHO ECHO :: %2 "%dst%\!fln!"^>^>"%REPO_FLDR%\Restore.cmd"
)>>"%REPO_FLDR%\Commit.cmd"


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
		rem if !cnt! GTR 26 SET _Line_=!_Line_:~1!
		:: If three, drop a second.
		rem if !cnt! GTR 676 SET _Line_=!_Line_:~1!
		:: If four, drop a third.
		rem if !cnt! GTR 17576 SET _Line_=!_Line_:~1!
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
	CALL :ExploreFile !_Target_! "%REPO_FLDR%\!_Archive_!!_Target_:"=!"
	if !ERRORLEVEL! equ 1 SET _ArchiveChanged_=Y
	rem Refresh the menu.
	if "%chr%" NEQ "A" CLS&GOTO :StartExploreArchive
)

if defined _ArchiveChanged_ (endlocal & exit /b 1)
endlocal
exit /b 0

:ExploreFile <FileName> <Default>
::           <FileName> relative name of the file to explore.
::			 <Default>  default filename to use as the control when exploring.
setlocal EnableDelayedExpansion

:: Set DashboardMode.
Set DashboardMode=Y

SET _FileName_=%~1

set _FileChanged_=

:: ...ensure one and only one pair of quotes...
SET _FileName_="%_FileName_:"=%"

:: ...drop any leading \...
SET _FileName_=%_FileName_:"\="%

:: ...and all quotes.
SET _FileName_=!_FileName_:"=!

:: Escape all parentheses
SET _FileName_=!_FileName_:^)=^\^)!

rem SET _FileName_=!_FileName_:\=\\!

rem echo _FileName_=%_FileName_%

:: Look for archived versions of _FileName_, and if not found, complain and quit.
dir "%REPO_FLDR%" /b /s | findstr /RC:"%CD:\=\\%\\%REPO_FLDR%\\[0-9][0-9]*\\%_FileName_:\=\\%" > Nul || (
	ECHO %_FileName_% not archived.
	PAUSE
	ENDLOCAL
	EXIT /B 1
)

rem Set _Current_ to the Current directory.
SET _Current_=%CD%
rem Drop the spaces.
SET _Current_=%_Current_: =%
rem Drop the end parentheses (they mess with the for loop).
SET _Current_=%_Current_:)=%
rem Count the number of backslashes.
set backslashes=0&for %%a in (%_Current_:\= %) do set /a backslashes+=1

:: If a default was specified...
if "%~2" neq "" (

	:: ...make it the control file.
	SET _Control_=%~2

) else (

	:: Otherwise, set _Control_ to the newest archive of this file, minus the CD.
	for /f "tokens=%backslashes%* delims=\" %%f in ('dir "%REPO_FLDR%" /b /s /n ^| findstr /RC:"%CD:\=\\%\\%REPO_FLDR%\\[0-9][0-9]*\\%_FileName_:\=\\%"') do set _Control_=%%g

)

:: Set compare to the current version.
SET _Compare_=%PJCT_FLDR%\!_FileName_!

:: And if it's a thing, start comparing.
if exist "%_Compare_%" GOTO :StartCompare

::Otherwise, look for the newest archive before _Control_.
FOR /F "tokens=%backslashes%* delims=\" %%f IN ('dir "%REPO_FLDR%" /b /s ^| findstr /RC:"%CD:\=\\%\\%REPO_FLDR%\\[0-9][0-9]*\\%_FileName_:\=\\%"') DO (
	IF "%%g" EQU "%_Control_%" GOTO :FoundCompare
	SET _Compare_=%%g
)

:FoundCompare

::If _Compare_ did not change...
if "%_Compare_%" EQU "%PJCT_FLDR%\!_FileName_!" (
	::...look for the oldest archive after _Control_.
	FOR /F "tokens=%backslashes%* delims=\" %%f IN ('dir "%REPO_FLDR%" /b /s ^| findstr /RC:"%CD:\=\\%\\%REPO_FLDR%\\[0-9][0-9]*\\%_FileName_:\=\\%"') DO (
		if "%%g" NEQ "%_Control_%" (
			SET _Compare_=%%g
			GOTO :StartCompare
		)
	)
)

:StartCompare

echo off

color 7

cls

call :EchoCenterPad " %~1 " "-"

:: Get the differences in the input.
fc /n "%_Control_%" "%_Compare_%" > "%REPO_FLDR%\Comp.tmp"

:: If there were no differences, exit 0.
if !errorlevel! equ 0 echo No differences found.& pause & endlocal & exit /b 0

:: From the FC result, print the lines that begin with letters.
for /f "delims=" %%f in ('type "%REPO_FLDR%\Comp.tmp" ^| FINDSTR /rc:"^[A-Z]"') do echo %%f

call :initColorPrint

:: If DashboardMode is not defined...
if not defined DashboardMode (

	SET _File1_=%_Control_%
	
	:: If _Control_ is the Current Version...
	if "!_File1_!" NEQ "!_File1_:%PJCT_FLDR%=!" (
		
		:: ...copy it to the repo folder.
		COPY "!_File1_!" "%REPO_FLDR%\Current.bkp" /Y > Nul
	
	) else (

		:: Otherwise, get the repo date and time.
		for /f "tokens=1-2 delims=\" %%f in ("%_Control_%") do SET _File1_=%%g
		:: Set File1 to the REPO_FLDR\date and time.
		SET _File1_=%REPO_FLDR%\!_File1_:~4,2!-!_File1_:~6,2!-!_File1_:~2,2! !_File1_:~8,2!.!_File1_:~10,2!.!_File1_:~12,2!.bkp
		:: If that file exists, make it writeable...
		IF EXIST "!_File1_!" ATTRIB -R "!_File1_!"
		:: ...so you can overwrite it...
		COPY "%_Control_%" "!_File1_!" /Y > Nul
		:: ...and make it read-only.
		ATTRIB +R "!_File1_!"

	)
	
	SET _File2_=%_Compare_%
	
	:: If _File2_ is the Current Version...
	if "!_File2_!" NEQ "!_File2_:%PJCT_FLDR%=!" (
		
		:: ...copy it to the repo folder.
		COPY "!_File2_!" "%REPO_FLDR%\Current.bkp" /Y > Nul


	) else (
	
		:: Otherwise, get the repo date and time.
		for /f "tokens=1-2 delims=\" %%f in ("%_Compare_%") do SET _File2_=%%g
		:: Set File2 to the REPO_FLDR\date and time.
		SET _File2_=%REPO_FLDR%\!_File2_:~4,2!-!_File2_:~6,2!-!_File2_:~2,2! !_File2_:~8,2!.!_File2_:~10,2!.!_File2_:~12,2!.bkp
		:: If that file exists, make it writeable...
		IF EXIST "!_File2_!" ATTRIB -R "!_File2_!"
		:: ...so you can overwrite it.
		COPY "%_Compare_%" "!_File2_!" /Y > Nul
		:: Make it read-only.
		ATTRIB +R "!_File2_!"
		
	)
	
	CALL :CompareFiles "!_File1_!" "!_File2_!"
	
	:: If File 1 was the current version, and it differs from the backup, exit 1.
	if "!_Control_!" NEQ "!_Control_:%PJCT_FLDR%=!" FC "!_Control_!" "%REPO_FLDR%\Current.bkp" > Nul || (
		endlocal 
		exit /b 1
	)

	:: If File 2 was the current version, and it differs from the backup, exit 1.
	if "!_Compare_!" NEQ "!_Compare_:%PJCT_FLDR%=!" FC "!_Compare_!" "%REPO_FLDR%\Current.bkp" > Nul || (
		endlocal 
		exit /b 1
	)
	
	:: Otherwise, show the menu.
	GOTO :ShowVersions
	
)

rem Unset DashboardMode
if defined _Diff_App_ SET DashboardMode=

set verbose=
Set SetNum=1

:: Get the number of columns on the screen.
for /f "tokens=1* delims= " %%f in ('mode con ^| find /i "columns"') do set /a cols=%%g - 2
set _Line_=&for /l %%f in (1,1,%cols%) do set _Line_=!_Line_!-

:ShowDifference

rem Get the line number of the Control SetNumth difference.
set oldChange=&for /f "tokens=1-2 delims=]:" %%f in ('findstr /nic:"***** %_Control_%" "%REPO_FLDR%\Comp.tmp" ^| find "*" /n ^| findstr /bc:"[%SetNum%]"') do set oldChange=%%g

if defined oldChange (
	
	if defined verbose echo _Compare_=%_Compare_:)=^)% & echo newChange=!newChange! & ECHO on
	
	rem Get the line number of the Compare SetNumth difference.
	for /f "tokens=1-2 delims=]:" %%f in ('findstr /nic:"***** %_Compare_:)=^)%" "%REPO_FLDR%\Comp.tmp" ^| find "*" /n ^| findstr /bc:"[%SetNum%]"') do set newChange=%%g

	if defined verbose ECHO off & echo newChange=!newChange!

	rem Get the line number of the end of the difference.
	for /f "tokens=1-2 delims=]:" %%f in ('findstr /nbec:"*****" "%REPO_FLDR%\Comp.tmp" ^| find "*" /n ^| findstr /bc:"[%SetNum%]"') do set endChange=%%g

	if defined verbose echo oldChange=!oldChange! & endChange=!endChange!
	
	:: Get the beginning and ending lines of the old set.
	SET /a o1=!oldChange!+1
	SET /a o2=!newChange!-1

	:: Get the beginning and ending lines of the new set.
	SET /a n1=!newChange!+1
	SET /a n2=!endChange!-1

	if defined verbose echo o1=!o1! & echo o2=!o2! & echo n1=!n1! & echo n2=!n2! & pause

	ECHO !_Line_!

	:: Set _OldStart_ to the o1th line in Comp.tmp.
	for /f "tokens=1* delims=:" %%f in ('findstr /nr "." "%REPO_FLDR%\Comp.tmp" ^| findstr /b "!o1!:"') do SET _OldStart_=%%g
	:: Set _NewStart_ to the n1th line in Comp.tmp.
	for /f "tokens=1* delims=:" %%f in ('findstr /nr "." "%REPO_FLDR%\Comp.tmp" ^| findstr /b "!n1!:"') do SET _NewStart_=%%g
	
	:: Set _OldEnding_ to the o2th line in Comp.tmp.  WARNING: The o2th line must be a thing or _OldEnding_ will not get overwritten.
	for /f "tokens=1* delims=:" %%f in ('findstr /nr "." "%REPO_FLDR%\Comp.tmp" ^| findstr /b "!o2!:"') do SET _OldEnding_=%%g
	:: Set _NewEnding_ to the n2th line in Comp.tmp.  WARNING: The n2th line must be a thing or _NewEnding_ will not get overwritten.
	for /f "tokens=1* delims=:" %%f in ('findstr /nr "." "%REPO_FLDR%\Comp.tmp" ^| findstr /b "!n2!:"') do SET _NewEnding_=%%g

	:: If the two sets start the same way (except, maybe, for line numbers)...
	if "!_OldStart_:~6!" EQU "!_NewStart_:~6!" (
		:: ...print the first line in white...
		for /f "tokens=1* delims=:" %%f in ('find /v "" /n "%REPO_FLDR%\Comp.tmp" ^| findstr /b "[!o1!\]"') do (
			set str=%%g
			set str=!str:"=""!
			call :colorPrint 0f "      !str!" /n
		)
		:: ...and drop the first line of the new set.
		set /a n1+=1
		:: If the two sets end the same way (except, maybe, for line numbers), drop the last line of the old set...
		if "!_OldEnding_:~6!" EQU "!_NewEnding_:~6!" set /a o2-=1
		:: ...then print what remains of the old set in red.
		for /f "tokens=1* delims=[]" %%f in ('find /v "" /n "%REPO_FLDR%\Comp.tmp"') do if %%f gtr !o1! if %%f leq !o2! (
			set str=%%g
			set str=!str:"=""!
			call :colorPrint 04 "!str!" /n
		)
	) ELSE (
		:: Otherwise, just print the old set in red.
		for /f "tokens=1* delims=[]" %%f in ('find /v "" /n "%REPO_FLDR%\Comp.tmp"') do if %%f geq !o1! if %%f leq !o2! (
			set str=%%g
			set str=!str:"=""!
			call :colorPrint 40 "!str!" /n
		)
	)

	:: If the two sets end the same way (except, maybe, for line numbers)...
	if "!_OldStart_:~6!" EQU "!_NewStart_:~6!" (
		:: Print all but the last line of the new set in green.
		for /f "tokens=1* delims=[]" %%f in ('find /v "" /n "%REPO_FLDR%\Comp.tmp"') do if %%f geq !n1! if %%f lss !n2! (
			set str=%%g
			set str=!str:"=""!
			call :colorPrint 02 "!str!" /n
		)
		:: ...print what remains of the new set in white.
		for /f "tokens=1* delims=:" %%f in ('find /v "" /n "%REPO_FLDR%\Comp.tmp" ^| findstr /b "[!n2!\]"') do (
			set str=%%g
			set str=!str:"=""!
			call :colorPrint 0f "      !str!" /n
		)
	) ELSE (
		:: Otherwise, just print the new set in green.
		for /f "tokens=1* delims=[]" %%f in ('find /v "" /n "%REPO_FLDR%\Comp.tmp"') do if %%f geq !n1! if %%f leq !n2! (
			set str=%%g
			set str=!str:"=""!
			call :colorPrint 02 "!str!" /n
		)
	)
	
	:: Increment SetNum
	SET /a SetNum+=1
	
	:: Loop
	GOTO :ShowDifference
)

:ShowVersions

rem Unset all variables starting with ?.  ASSUMES ? is an illegal char in a file name.
FOR /F "delims==" %%a In ('set ? 2^>Nul') DO SET "%%a="

rem Set the CURRENT TimeStamp
SET CURRENT=&CALL :TIMESTAMP CURRENT

rem Unset the count.
set /A cnt=0

rem Unset the character.
set chr=

echo.

rem Look through the archives for (relative) _FileName_
for /f "tokens=%backslashes%* delims=\" %%f in ('dir "%REPO_FLDR%" /b /s ^| findstr /RC:"%CD:\=\\%\\%REPO_FLDR%\\[0-9][0-9]*\\%_FileName_:\=\\%"') do (

	CALL :ASCII !cnt! chr

	set ?!chr!?=%%g
	
	set /a cnt+=1

)

rem If the actual file exists...
if exist %PJCT_FLDR%%~1 (

	rem ...get the ASCII...
	CALL :ASCII !cnt! chr

	rem ...and set it to Current Version.
	set ?!chr!?=%PJCT_FLDR%%~1
	
	set /a cnt+=1
)

FOR /F "delims==?" %%a In ('set ? 2^>Nul') DO (

	rem Set str to Current Version.
	SET dsc=Current Version
	SET str=

	rem If the file is a repo file...
	echo !?%%a?!|findstr /brc:"[A-Z]:">nul || (

		SET ARCHIVE=!?%%a?!
		for /f "tokens=1-2* delims=\" %%f in ('echo !archive!') do set ARCHIVE=%%g

		rem ...if the dates are not the same...
		if "!CURRENT:~0,8!" NEQ "!ARCHIVE:~0,8!" (
			CALL :JDate d1 !ARCHIVE:~4,2!/!ARCHIVE:~6,2!/!ARCHIVE:~0,4!
			CALL :JDate d2 !CURRENT:~4,2!/!CURRENT:~6,2!/!CURRENT:~0,4!
			SET /A diff=!d2!-!d1!
			set str=!diff! day
			if !diff! NEQ 1 set str=!str!s
		) ELSE (
			CALL :JTime t1 !ARCHIVE:~8,8!
			CALL :JTime t2 !CURRENT:~8,8!
			SET /A diff=!t2!-!t1!
			if !diff! LSS 3600 (
				set /a diff=!diff! / 60
				set str=!diff! minute
			) else (
				set /a diff=!diff! / 3600
				set str=!diff! hour
			)
			if !diff! NEQ 1 SET str=!str!s
		)
		
		rem Pad right the string.
		set str=!str! ago.           &set str=!str:~0,15!
			
		rem Add the description to the end of the string.
		for /f "tokens=1* delims= " %%f in ('findstr /bc:":!ARCHIVE:~0,16!" "!REPO_FLDR!\Restore.cmd"') do set dsc=%%g

	)

	if "%_Control_%" equ "!?%%a?!" (
		set str=%%a^) !str!!dsc!
		set str=!str:"=""!
		call :colorPrint f0 "!str!" /n
		rem powershell -command "& {write-host -BackgroundColor white -ForegroundColor black '%%a) !str!!dsc!'}"
	) else (
		if "%_Compare_%" equ "!?%%a?!" (
			set str=%%a^) !str!!dsc!
			set str=!str:"=""!
			call :colorPrint 80 "!str!" /n
			rem powershell -command "& {write-host -BackgroundColor gray -ForegroundColor black '%%a) !str!!dsc!'}"
			SET Desc=!dsc!
		) else (
			echo %%a^) !str!!dsc!
		)
	)
)	
echo.

:: Unset the response.
SET rsp=

if %cnt% GTR 1 (
	echo Enter [A-%chr%]-[A-%chr%] to compare two files
	echo or A-%chr% to compare to %Desc%
) ELSE (
	echo Enter A to compare to %Desc%
)
set /p rsp=or nothing to return: 
cls
:: If the user entered nothing, clean the repository folder and return.
if not defined rsp GOTO :CleanAndExit

:: Get the selected file, and if the response includes -, we have a new second file.
for /f "tokens=1-2" %%f in ("%rsp:-= %") do (
	SET _Control_=!?%%f?!
	if defined ?%%g? SET _Compare_=!?%%g?!
)

if not defined _Control_ echo File not found. & PAUSE & GOTO :ShowVersions
if not defined _Compare_ echo File not found. & PAUSE & GOTO :ShowVersions
if "%_Control_%" equ "%_Compare_%" echo Please specify multiple files. & PAUSE & GOTO :ShowVersions

:: Refresh the dashboard.
GOTO :StartCompare

:CleanAndExit

call :cleanupColorPrint

del "%REPO_FLDR%\*.bkp" /F /Q >Nul
endlocal
exit /b 0

:CompareFiles <File1> <File2>
setLocal EnableDelayedExpansion

:: Set CmdLine to the _Diff_App_
SET CmdLine=%_Diff_App_%

:: Replace %1 in the CmdLine with File1.
SET CmdLine=!CmdLine:%%1=%~1!

:: Replace %2 in the CmdLine with File2.
SET CmdLine=!CmdLine:%%2=%~2!

:: Use the differencing application, and wait for it to close.
start /wait "diff" %CmdLine%

cls

endlocal
	
exit /b

:colorPrint Color  Str  [/n]
setlocal
set "str=%~2"
call :colorPrintVar %1 str %3
exit /b

:colorPrintVar  Color  StrVar  [/n]
if not defined %~2 exit /b
setlocal enableDelayedExpansion
set str=!%~2:""="!
set "str=a%DEL%!%~2:\=a%DEL%\..\%DEL%%DEL%%DEL%!"
set "str=!str:/=a%DEL%/..\%DEL%%DEL%%DEL%!"
set "str=!str:"=\"!"
pushd "%temp%"
findstr /p /A:%1 "." "!str!\..\x" nul
if /i "%~3"=="/n" echo(
exit /b

:initColorPrint
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "DEL=%%a"
<nul >"%temp%\x" set /p "=%DEL%%DEL%%DEL%%DEL%%DEL%%DEL%.%DEL%"
exit /b

:cleanupColorPrint
del "%temp%\x"
exit /b

:GetExcludePatterns str
::						-- str [out] - variable capturing the exclude patterns pipe delimited.
SETLOCAL ENABLEDELAYEDEXPANSION

SET exc=
SET Batch=%~nx0

:: If the Project Folder is the current directory, look for the files in this folder and if any are the same as this batch file, add them and their repo folder to exclude.
IF "%PJCT_FLDR%" EQU "%CD%" FOR /f %%a in ('forfiles /c "cmd /c if @isdir==FALSE fc @path """%Batch:)=^^)%""">Nul && echo @file"') do if not defined exc (SET "exc=%%~dpxna|%%~dpa+%%~na") else SET "exc=!exc!|%%~dpnxa|%%~dpa\+%%~na"

:: Escape the Regex Metacharacters that are legal in a windows path.
SET "exc=!exc:\=\\!"
SET "exc=!exc:+=\+!"
SET "exc=!exc:-=\-!"
SET "exc=!exc:.=\.!"
SET "exc=!exc:$=\$!"
SET "exc=!exc:^=\^!"
SET "exc=!exc:]=\]!"
SET "exc=!exc:[=\[!"
SET "exc=!exc:^)=^\^)!"

:: If Exclude.txt is a thing, add each line to exclude.
if exist "%REPO_FLDR%\Exclude.txt" for /F "usebackq tokens=*" %%A in ("%REPO_FLDR%\Exclude.txt") do if not defined exc (SET "exc=%%A") else SET "exc=!exc!^|%%A"

:: Set the output to the result.
ENDLOCAL & SET "%~1=%exc%"

Exit /b

:ExcludePatterns
cls
COLOR 4f
CALL :EchoCenterPad " Patterns to exclude " "-"
echo.
if exist "%REPO_FLDR%\Exclude.txt" type "%REPO_FLDR%\Exclude.txt"
echo.
SET Msg=&SET /P Msg=Enter pattern to toggle or nothing to quit:
::If the user entered nothing, quit.
if not defined Msg exit /b 0
::In case the user entered ! only, quit.
if "!Msg!" EQU "^!" exit /b 0
rem echo on
:: If Exclude.txt is a thing and Msg is in it...
if exist "%REPO_FLDR%\Exclude.txt" for /f "usebackq tokens=*" %%a in ("%REPO_FLDR%\Exclude.txt") do if "%%a" EQU "%Msg%" (
	CALL :CutExcludePattern "%Msg%"
	GOTO :ExcludePatterns
)

rem echo off
:: Otherwise, add exclude patterns.
CALL :AddExcludePattern "%Msg%"
GOTO :ExcludePatterns

:AddExcludePattern
echo %~1>>"%REPO_FLDR%\Exclude.txt"
GOTO :EOF

:CutExcludePattern
if exist "%REPO_FLDR%\Exclude.tmp" del "%REPO_FLDR%\Exclude.tmp"
ren "%REPO_FLDR%\Exclude.txt" Exclude.tmp
for /F "usebackq tokens=*" %%A in ("%REPO_FLDR%\Exclude.tmp") do if "%%A" NEQ "%~1" echo %%A>>"%REPO_FLDR%\Exclude.txt"
GOTO :EOF

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

:jTime JT DateStr -- converts a time string to number of seconds since midnight
::                -- JT      [out,opt] - julian time
::                -- TimeStr [in,opt]  - time string, e.g. "3:31:20 PM"
SETLOCAL

set TimeStr=%~2
if "%~2" EQU "" set TimeStr=%time%
set Meridian=
for /f "tokens=1* delims= " %%a in ("%~2") do (
	set TimeStr=%%a
	set Meridian=%%b
)

rem Strip the colons from the string.
Set TimeStr=%TimeStr::=%"
rem Strip the periods from the string.
Set TimeStr=%TimeStr:.=%"

rem If the result is 5 characters, pad left with a 0.
If "%TimeStr%" EQU "%TimeStr:~7%" set TimeStr=0%TimeStr%

Set HH=%TimeStr:~0,2%
Set MM=%TimeStr:~2,2%
Set SS=%TimeStr:~4,2%

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

:: TODO When inp has parentheses.

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

CALL :GetExcludePatterns exclude

if defined exclude set "exclude=^| where fullname -notmatch '!exclude!' "

rem Run the PowerShell command.
rem echo powershell -command "& {$Count=( !CmdLine! !exclude!| Measure-Object).Count; $I=0; !CmdLine! !exclude!| foreach {$I++; Write-Progress -Activity ('Scanning {0} files in %PJCT_FLDR%' -f $Count) -Status $_.FullName -PercentComplete($I/$Count*100); """"""""""{0}""""""""|""""""""{1}"""""""""" -f $_.FullName, (Get-Filehash($_.FullName)).hash;} | out-file -append '%REPO_FLDR%\New.txt'}"
rem pause
powershell -command "& {$Count=( !CmdLine! !exclude!| Measure-Object).Count; $I=0; !CmdLine! !exclude!| foreach {$I++; Write-Progress -Activity ('Scanning {0} files in %PJCT_FLDR%' -f $Count) -Status $_.FullName -PercentComplete($I/$Count*100); """"""""""{0}""""""""|""""""""{1}"""""""""" -f $_.FullName, (Get-Filehash($_.FullName)).hash;} | out-file -append '%REPO_FLDR%\New.txt'}"

endlocal
EXIT /b

:IsFolder <Path>
rem echo Is %~1 a folder?
PUSHD "%~1" 2> Nul && POPD || EXIT /b 1
EXIT /b 0

:CleanFile string -- alphabetizes lines in a file and omits duplicates.
powershell -command "& {gc '%~1' | sort -u | ? {$_ -ne ''} | Out-file '%REPO_FLDR%\Temp.del'}"
Type "%REPO_FLDR%\Temp.del" > "%~1"
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
