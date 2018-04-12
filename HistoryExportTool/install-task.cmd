cd /d %~dp0
schtasks /create /tn FBox_HistoryExport /sc hourly /mo 6 /st 00:30 /tr "%cd%\run-task.cmd" /ru SYSTEM  /f
pause
