REM Skype for Business Collection script
REM Created by Arjan.Sturkenboom
REM Date: 6 July 2018
REM Dependencies:
REM   1. sha256deep.exe from hashdeep. Download and extract the md5deep  package (https://github.com/jessek/hashdeep/releases). Add the extract location to the system’s path variable
REM	  2. run the batch file with the appropriate client privileges
REM   3. Volume Shadow Copies should be active on the Windows target client
REM Version 0.3
REM Be Aware: this is a beta version and will finally be reprogrammed into a python script.

@Echo off

REM user input variables
SET /P collection_folder=[insert full destination collection path:]
SET /P host_name=[insert target host_name:]
SET /P ip_addr=[insert target IP address:]
SET /P target_username=[insert target username:]

REM create user log folder
md "%collection_folder%\log\%target_username%"
md "%collection_folder%\%target_username%\registry"

ECHO Starting Skype for Business collection at %date% – %time% of the user %target_username% from the host %host_name% with the IP %ip_addr% >>"%collection_folder%\log\%target_username%\SfB_collection_%host_name%_%target_username%.log"

REM list VSC's
psexec -e \\%ip_addr% vssadmin list shadows >> "%collection_folder%\log\%target_username%\SfB_collection_%host_name%_%target_username%.log"

SET /P Harddisk_VolumeShadowCopy=[Copy the Shadow Copy Volume value from the log file:]

REM mount VSC
psexec -e \\%ip_addr% cmd /c mklink /J c:\Windows\krnl\ %Harddisk_VolumeShadowCopy%\

REM copy SfB Tracing folder not recursive
robocopy \\%ip_addr%\c$\windows\krnl\users\%target_username%\AppData\Local\Microsoft\Office\16.0\Lync\Tracing "%collection_folder%\%target_username%" "Lync*.etl" "Lync*.bak" "Lync*.UccApilog" /XN /V /TS /TEE /COPY:DAT /R:3 /W:3 /LOG+:"%collection_folder%\log\%target_username%\SfB_collection_%host_name%_%target_username%.log"

REM Copy NTUSER.dat file
ECHO Starting copying at %date% – %time% >> "%collection_folder%\log\%target_username%\SfB_collection_%host_name%_%target_username%.log"
robocopy \\%ip_addr%\c$\windows\krnl\users\%target_username% "%collection_folder%\%target_username%\registry" "ntuser.dat" /XN /V /TS /TEE /COPY:DAT /R:3 /W:3 /LOG+:"%collection_folder%\log\%target_username%\SfB_collection_%host_name%_%target_username%.log"

REM hash the destination files
ECHO Hashing (SHA256) destination files at %date% – %time% >> "%collection_folder%\log\%target_username%\SfB_hash_values.sha256"
sha256deep64 -r "%collection_folder%" >> "%collection_folder%\log\%target_username%\SfB_hash_values.sha256"
ECHO Hashing finished at %date% – %time% >> "%collection_folder%\log\%target_username%\SfB_hash_values.sha256"

REM choose to remove VSC
:choice_remove_vsc
set /P remvsc=Would you like to remove the mounted VSC[y/n]?
if /I "%remvsc%" EQU "y" goto :rem_vsc
if /I "%remvsc%" EQU "n" goto :end
goto :choice_remove_vsc

:rem_vsc
ECHO Removing mlink to VSC %date% – %time% >> "%collection_folder%\log\%target_username%\SfB_collection_%host_name%_%target_username%.log"
psexec -e \\%ip_addr% cmd /c rmdir c:\Windows\krnl >> "%collection_folder%\log\%target_username%\SfB_collection_%host_name%_%target_username%.log"

ECHO Mount point to the VSC on the client has been removed. >> "%collection_folder%\log\%target_username%\SfB_collection_%host_name%_%target_username%.log"

:end
ECHO "Skype for Business collection of %target_username% finished at %date% – %time%" >> "%collection_folder%\log\%target_username%\SfB_collection_%host_name%_%target_username%.log"
