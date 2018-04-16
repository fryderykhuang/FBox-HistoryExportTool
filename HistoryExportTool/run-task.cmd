cd /d %~dp0

rem goto END
rem schtasks /create /tn FBox_HistoryExport /sc daily /st 00:30 /tr "'%cd%\historyexporttool.exe' exporthdata --yesterday --output-dir output --timestamp-format yyyyMMddHHmmss --output-file-name-pattern {BoxSN}-{ItemName}-{CurrentTime:yyyyMMddHHmmss}.csv --box-sn-file csvr:BoxSnList.csv" /ru SYSTEM  /f
historyexporttool.exe exporthdata --export-last-segment --segments-per-day 4 --output-dir output/{BoxSN} --timestamp-format yyyyMMddHHmmss --output-file-name-pattern {ItemName}-{CurrentTime:yyyyMMddHHmmss}.csv --box-sn-file csvr:BoxSnList.csv --null-substitution "N/A" --no-overwrite

:END
