@echo off
setlocal enabledelayedexpansion
cd /d %~dp0
cls
chcp 936>nul
color 0e

:CheckAdmin
openfiles.exe 1>nul 2>&1
if not %errorlevel% equ 0 (
    echo *** 请用管理员权限运行此脚本（右键菜单-^>用管理员权限运行）***& pause
	goto END
)

:INITIALIZE
set "cfgFile=export.cfg"
FOR /F "tokens=3" %%a IN ('reg query "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Nls\Language" /v InstallLanguage ^| find "InstallLanguage"') DO set lang=%%a
if "%lang%" == "0804" (
	set "K_Status=模式:"
	set "K_LastRunTime=上次运行时间:"
	set "K_NextRunTime=下次运行时间:"
	set "K_Schedule=计划:"
	set "K_ScheduleType=计划类型:"
	set "K_StartTime=开始时间:"
	set "K_RepeatEvery=重复: 每:"
) else (
	set "K_Status=Status"
	set "K_LastRunTime=Last Run Time:"
	set "K_NextRunTime=Next Run Time:"
	set "K_Schedule=Schedule:"
	set "K_ScheduleType=Schedule Type:"
	set "K_StartTime=Start Time:"
	set "K_RepeatEvery=Repeat: Every:"
)

call :ReadCfg

:MAIN_MENU
cls
echo.
echo.
echo               FBox历史数据导出工具
echo.
echo  ------------------------------------------------
echo.
echo          1.  安装/更新计划任务
echo.
echo          2.  手工导出数据
echo.
echo          3.  修改导出参数
echo.
echo          4.  删除计划任务
echo.
echo          0.  退出
echo.
echo  ------------------------------------------------
echo.
set "choice="
set /p choice=请选择:
if /i "%choice%" equ "0" goto END
if /i "%choice%" equ "1" goto INSTALL_TASK
if /i "%choice%" equ "2" goto MANUAL_RUN
if /i "%choice%" equ "3" goto UPDATE_CFG
if /i "%choice%" equ "4" goto REMOVE_TASK
goto MAIN_MENU
goto END

:MANUAL_RUN
echo.
call :ReadCfg
:INPUT_BEGIN_TIME
set "vi_beginTime="
set /p vi_beginTime=请输入起始时间(格式为yyyyMMddHH):
echo "%vi_beginTime%"| findstr /x /r \"20[0-9][0-9][0-1][0-9][0-3][0-9][0-2][0-9]\" 2>&1 >nul
if /i "%errorlevel%" neq "0" echo 格式错误& goto INPUT_BEGIN_TIME
:INPUT_END_TIME
set "vi_endTime="
set /p vi_endTime=请输入结束时间(格式为yyyyMMddHH，导出到指定时间的前一个小时，即开区间):
echo "%vi_endTime%"| findstr /x /r \"20[0-9][0-9][0-1][0-9][0-3][0-9][0-2][0-9]\" 2>&1 >nul
if /i "%errorlevel%" neq "0" echo 格式错误& goto INPUT_END_TIME
if /i "%vi_beginTime%" geq "%vi_endTime%" echo 结束时间须大于起始时间& goto INPUT_BEGIN_TIME

set "choice="
set /p choice=确认导出 %vi_beginTime%~%vi_endTime% 的数据到 %cfg_outputDir%？(y/n)
if not "%choice%"=="y" (echo 已取消& call :Sleep 1& goto MAIN_MENU)
echo cd /d %%~dp0> manual-export.cmd
echo historyexporttool.exe exporthdata --begin-time yyyyMMddHH:%vi_beginTime% --end-time yyyyMMddHH:%vi_endTime% --output-dir "%cfg_outputDir%" --timestamp-format "%cfg_timestampFormat%" --output-file-name-pattern "%cfg_outputFileNamePattern%" --box-sn-file "csvr:%cfg_boxSnFileCsvr%" --null-substitution "%cfg_nullSubstitution%">> manual-export.cmd
call manual-export.cmd
echo.
if /i "%errorlevel%" equ "0" (echo 导出成功& call :Sleep 2) else (echo 导出失败& pause)
goto MAIN_MENU

:ReadCfg
set "K_NULL_SUBSTITUTION=--null-substitution"
set "K_BOX_SN_FILE_CSVR=--box-sn-file-csvr"
set "K_OUTPUT_FILE_NAME_PATTERN=--output-file-name-pattern"
set "K_OUTPUT_DIR=--output-dir"
set "K_TIMESTAMP_FORMAT=--timestamp-format"

for /f "tokens=2*" %%a in ('type "%cfgFile%" ^| find "%K_BOX_SN_FILE_CSVR%"') do ( set cfg_boxSnFileCsvr=%%a)
for /f "tokens=2*" %%a in ('type "%cfgFile%" ^| find "%K_OUTPUT_FILE_NAME_PATTERN%"') do ( set cfg_outputFileNamePattern=%%a) 
for /f "tokens=2*" %%a in ('type "%cfgFile%" ^| find "%K_OUTPUT_DIR%"') do ( set cfg_outputDir=%%a)
for /f "tokens=2*" %%a in ('type "%cfgFile%" ^| find "%K_NULL_SUBSTITUTION%"') do ( set cfg_nullSubstitution=%%a)
for /f "tokens=2*" %%a in ('type "%cfgFile%" ^| find "%K_TIMESTAMP_FORMAT%"') do ( set cfg_timestampFormat=%%a)

call :Trim cfg_boxSnFileCsvr %cfg_boxSnFileCsvr%
call :Trim cfg_outputFileNamePattern %cfg_outputFileNamePattern%
call :Trim cfg_outputDir %cfg_outputDir%
call :Trim cfg_nullSubstitution %cfg_nullSubstitution%
call :Trim cfg_timestampFormat %cfg_timestampFormat%


exit /b

:WriteCfg
echo %K_BOX_SN_FILE_CSVR% %cfg_boxSnFileCsvr%>%cfgFile%
echo %K_OUTPUT_FILE_NAME_PATTERN% %cfg_outputFileNamePattern%>>%cfgFile%
echo %K_OUTPUT_DIR% %cfg_outputDir%>>%cfgFile%
echo %K_NULL_SUBSTITUTION% %cfg_nullSubstitution%>>%cfgFile%
echo %K_TIMESTAMP_FORMAT% %cfg_timestampFormat%>>%cfgFile%
exit /b

:UPDATE_CFG
call :ReadCfg
cls
echo.
echo.
echo               FBox历史数据导出工具
echo.
echo  ------------------------------------------------
echo.
echo          1.  FBox列表文件路径
echo.
echo          2.  输出文件名格式
echo.
echo          3.  输出目录
echo.
echo          4.  输出内容时间戳格式
echo.
echo          5.  值为空时的替代文本
echo.
echo          0.  返回
echo.
echo  ------------------------------------------------
echo.
set "choice="
set /p choice=请选择:
if /i "%choice%" equ "0" goto MAIN_MENU
if /i "%choice%" equ "1" goto UPDATE_CFG_1
if /i "%choice%" equ "2" goto UPDATE_CFG_2
if /i "%choice%" equ "3" goto UPDATE_CFG_3
if /i "%choice%" equ "4" goto UPDATE_CFG_4
if /i "%choice%" equ "5" goto UPDATE_CFG_5
goto UPDATE_CFG

:UPDATE_CFG_1:
set /p cfgi_boxSnFileCsvr=请粘贴或输入文件路径，直接回车则使用当前值(%cfg_boxSnFileCsvr%):
if not exist %cfgi_boxSnFileCsvr% echo 文件不存在。& goto UPDATE_CFG_1
set cfg_boxSnFileCsvr=%cfgi_boxSnFileCsvr%
call :WriteCfg
goto UPDATE_CFG
goto END
:UPDATE_CFG_2:
echo 设置导出文件的文件名，支持替换变量:{CurrentTime} {BeginTime} {EndTime} {BoxSN} {ItemName}。替换变量自定义格式用法请参考：https://docs.microsoft.com/zh-cn/dotnet/standard/base-types/composite-formatting
set /p cfg_outputFileNamePattern=请输入新值，或回车使用当前值(%cfg_outputFileNamePattern%):
call :WriteCfg
goto UPDATE_CFG
goto END
:UPDATE_CFG_3:
echo 设置导出目录，支持替换变量:{CurrentTime} {BeginTime} {EndTime} {BoxSN} {ItemName}。替换变量自定义格式用法请参考：https://docs.microsoft.com/zh-cn/dotnet/standard/base-types/composite-formatting
set /p cfg_outputDir=请输入新值，或回车使用当前值(%cfg_outputDir%):
call :WriteCfg
goto UPDATE_CFG
goto END
:UPDATE_CFG_4:
set /p cfg_timestampFormat=请输入新值，或回车使用当前值(%cfg_timestampFormat%):
call :WriteCfg
goto UPDATE_CFG
goto END
:UPDATE_CFG_5:
set /p cfg_nullSubstitution=请输入新值，或回车使用当前值(%cfg_nullSubstitution%):
call :WriteCfg
goto UPDATE_CFG
goto END

:INSTALL_TASK
call :ReadCfg
echo.
call :PrintCurrentSchedule
:INSTALL_TASK_INPUT_NR_SEGMENTS
echo.
set vi_nrSegments=-1
set /p vi_nrSegments=请输入每天期望的导出次数(1,2,3,4,6,8,12,24)：
set v_sc=hourly
if /i "%vi_nrSegments%" equ "1" set v_sc=daily& set vi_nrSegments=24& goto :INSTALL_TASK_DO_INSTALL
if /i "%vi_nrSegments%" equ "2" goto :INSTALL_TASK_DO_INSTALL
if /i "%vi_nrSegments%" equ "3" goto :INSTALL_TASK_DO_INSTALL
if /i "%vi_nrSegments%" equ "4" goto :INSTALL_TASK_DO_INSTALL
if /i "%vi_nrSegments%" equ "6" goto :INSTALL_TASK_DO_INSTALL
if /i "%vi_nrSegments%" equ "8" goto :INSTALL_TASK_DO_INSTALL
if /i "%vi_nrSegments%" equ "12" goto :INSTALL_TASK_DO_INSTALL
if /i "%vi_nrSegments%" equ "24" goto :INSTALL_TASK_DO_INSTALL
goto :INSTALL_TASK_INPUT_NR_SEGMENTS

:INSTALL_TASK_DO_INSTALL:
echo.
set "vi_runAsUser="
set /p vi_runAsUser=请输入运行账户名(回车使用当前用户，使用非系统内置账户需要输入密码)：
call :Trim vi_runAsUser %vi_runAsUser%
if "%vi_runAsUser%"=="" set "vi_runAsUser=%USERNAME%"
set "choice="
set /p choice=确认更新计划任务？(y/n)
if not "%choice%"=="y" (echo 已取消& call :Sleep 1& goto MAIN_MENU)
echo cd /d %%~dp0> run-task.cmd
echo historyexporttool.exe exporthdata --export-last-segment --segments-per-day %vi_nrSegments% --output-dir "%cfg_outputDir%" --timestamp-format "%cfg_timestampFormat%" --output-file-name-pattern "%cfg_outputFileNamePattern%" --box-sn-file "csvr:%cfg_boxSnFileCsvr%" --null-substitution "%cfg_nullSubstitution%" --no-overwrite>> run-task.cmd
set /a v_mo=24/vi_nrSegments

echo cd /d %%~dp0> install-task.cmd
echo schtasks /create /tn FBox_HistoryExport /sc %v_sc% /mo %v_mo% /st 00:30 /tr "%%~dp0\run-task.cmd" /ru "%vi_runAsUser%" /rp /rl HIGHEST /f>> install-task.cmd
call install-task.cmd
echo.
if /i "%errorlevel%" equ "0" (echo 计划任务更新成功& call :Sleep 2) else (echo 计划任务更新失败& pause)
goto MAIN_MENU

:REMOVE_TASK
echo.
call :PrintCurrentSchedule
if /i "!v_status!" equ "-1" call :Sleep 2& goto MAIN_MENU
set "choice="
set /p choice=确认删除计划任务？(y/n)
if not "%choice%"=="y" (echo 已取消& call :Sleep 1& goto MAIN_MENU)
>nul schtasks /delete /tn FBox_HistoryExport /f
if /i "%errorlevel%" equ "0" (echo 成功删除计划任务& call :Sleep 2) else (echo 计划任务删除失败& pause)
goto MAIN_MENU
goto END

:PrintCurrentSchedule
set v_status=-1
set "tempFile=%temp%\%~nx0_%time::=.%.tmp"

2>nul schtasks /query /tn FBox_HistoryExport /FO LIST /V > "!tempFile!"
if /i "%errorlevel%" neq "0" goto PrintCurrentSchedule_1

for /f "tokens=2*delims=:" %%a in ('find "%K_Status%" "%tempFile%"') do ( set v_status=%%a)
for /f "tokens=2*delims=:" %%a in ('find "%K_LastRunTime%" "%tempFile%"') do ( set v_lastRunTime=%%a)
for /f "tokens=2*delims=:" %%a in ('find "%K_NextRunTime%" "%tempFile%"') do ( set v_nextRunTime=%%a)
for /f "tokens=2*delims=:" %%a in ('find "%K_Schedule%" "%tempFile%"') do ( set v_schedule=%%a)
for /f "tokens=2*delims=:" %%a in ('find "%K_ScheduleType%" "%tempFile%"') do ( set v_scheduleType=%%a)
for /f "tokens=3*delims=:" %%a in ('find "%K_RepeatEvery%" "%tempFile%"') do ( set v_repeatEvery=%%a)

call :Trim v_status !v_status!
call :Trim v_lastRunTime !v_lastRunTime!
call :Trim v_nextRunTime !v_nextRunTime!
call :Trim v_schedule !v_schedule!
call :Trim v_scheduleType !v_scheduleType!
call :Trim v_repeatEvery !v_repeatEvery!
REM echo code !exitcode! : !errorlevel!
REM if errorlevel 1 (
REM 	echo x
REM 	set status=!status: =!
REM ) else (
REM 	set status=未安装
REM )

:PrintCurrentSchedule_1
echo  当前计划任务状态:
echo  ------------------------------------------------
if "!v_status!"=="-1" (
	echo    未安装
) else (
	echo    运行状态:		!v_status!
	echo    上次运行时间:	!v_lastRunTime!
	echo    下次运行时间:	!v_nextRunTime!
rem	echo   计划:			!v_schedule!
	echo    计划类型:		!v_scheduleType!
	echo    重复方式:		!v_repeatEvery!
)
echo  ------------------------------------------------

>nul 2>nul del "!tempFile!"

exit /b

:Trim retval string -- trims spaces around string and assigns result to variable
::                         -- retvar [out] variable name to store the result in
::                         -- string [in]  string to trim, must not be in quotes
for /f "tokens=1*" %%A in ("%*") do set "%%A=%%B"
exit /b

:Sleep seconds -- waits some seconds before returning
::             -- seconds [in]  - number of seconds to wait
timeout %1 > nul
rem FOR /l %%a in (%~1,-1,1) do (ping -n 2 -w 1 127.0.0.1>NUL)
EXIT /b

:StrLen string len -- returns the length of a string
::                 -- string [in]  - variable name containing the string being measured for length
::                 -- len    [out] - variable to be used to return the string length
(   SETLOCAL ENABLEDELAYEDEXPANSION
    set "str=A!%~1!"& rem keep the A up front to ensure we get the length and not the upper bound
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

:END
color
endlocal

