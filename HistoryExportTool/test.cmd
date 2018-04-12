cd /d %~dp0

rmdir /s /q  output1
rmdir /s /q  output2
rmdir /s /q  output3

"%cd%\historyexporttool.exe" exporthdata --yesterday --output-dir output1 --timestamp-format yyyyMMddHHmmss --output-file-name-pattern {BoxSN}-{ItemName}-{CurrentTime:yyyyMMddHHmmss}.csv --box-sn-file csvr:BoxSnList.csv
"%cd%\historyexporttool.exe" exporthdata --export-last-segment --segments-per-day 4 --output-dir output2/{BoxSN} --timestamp-format yyyyMMddHHmmss --output-file-name-pattern {ItemName}-{CurrentTime:yyyyMMddHHmmss}.csv --box-sn-file csvr:BoxSnList.csv --null-substitute "N/A"
"%cd%\historyexporttool.exe" exporthdata --begin-time yyyyMMddHH:2018033006 --end-time yyyyMMdd:20180402 --output-dir output3 --timestamp-format yyyyMMddHHmmss --output-file-name-pattern {BoxSN}-{ItemName}-{CurrentTime:yyyyMMddHHmmss}.csv --box-sn-file csvr:BoxSnList.csv

:END
