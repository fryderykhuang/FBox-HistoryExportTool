## FBox历史数据导出工具
此工具用于导出指定时间段内（目前有4种指定时间的方式）指定盒子（目前支持单行逗号分隔FBox序列号列表文件）的历史数据内容。如需要定时重复导出，可使用平台相关的计划任务工具创建，如Linux的cron，Windows的计划任务服务。

### 使用方法
1. 在Release区下载最新可执行代码或自己编译源码（见下面的编译方法）。
2. 获取FBox开发者账号，填入appsettings.json里面的CLIENTID和CLIENTSECRET处。
3. 到[FBox官网](fbox360.com)注册账号，把用户名密码填入appsettings.json里面的USERNAME和PASSWORD处。
4. 用 HistoryExportTool exporthdata --help 查看工具帮助：
~~~~
Usage: HistoryExportTool exporthdata [options]

Options:
  -?|-h|--help                Show help information
  --begin-time                Specify the beginning of export time range.
  --end-time                  Specify the ending of export time range.
  --date                      Specify a certain day to export.
  --yesterday                 Export data in yesterday.
  --output-file-name-pattern  Output file name pattern. Available substitution is {CurrentTime} {BeginTime} {EndTime} {BoxSN} {ItemName}.
  --output-dir                The directory exported files are stored in. Available substitution is {CurrentTime} {BeginTime} {EndTime} {BoxSN} {ItemName}.
  --timestamp-format          Timestamp format.
  --utc                       Indicate the input time is specified as UTC time.
  --box-sn-file               A file holds a list of box serial numbers.
  --segments-per-day          The number of equal parts a day will be divided into. Use with --export-last-segment
  --export-last-segment       Export last time segment, must be also specify --segments-per-day
  --null-substitution         Substitute null value with this string.
  --no-overwrite              Do not overwrite target file if exists.

Examples:
  Export the data in yesterday:
    HistoryExportTool exporthdata --yesterday --output-dir output --timestamp-format yyyyMMddHHmmss --output-file-name-pattern {BoxSN}-{ItemName}-{CurrentTime:yyyyMMddHHmmss}.csv --box-sn-file csvr:BoxSnList.csv

  Export the data in last time segment. (e.g. If current time is 13:20, the following command will export data in time range: 06:00(inclusive) ~ 12:00(exclusive). If current time is 5:30, the result time range will be 18:00 of yesterday ~ 00:00 of today). ):
    HistoryExportTool exporthdata --export-last-segment --segments-per-day 4 --output-dir output/{BoxSN} --timestamp-format yyyyMMddHHmmss --output-file-name-pattern {ItemName}-{CurrentTime:yyyyMMddHHmmss}.csv --box-sn-file csvr:BoxSnList.csv

  Export data from 2018/03/30 06:00 to 2018/04/02(exclusive)
    HistoryExportTool exporthdata --begin-time yyyyMMddHH:2018033006 --end-time yyyyMMdd:20180402 --output-dir output --timestamp-format yyyyMMddHHmmss --output-file-name-pattern {BoxSN}-{ItemName}-{CurrentTime:yyyyMMddHHmmss}.csv --box-sn-file csvr:BoxSnList.csv

All substitution pattern can use C# composite formatting. (https://docs.microsoft.com/en-us/dotnet/standard/base-types/composite-formatting).
For the date and time format string used above please refer to:
  https://docs.microsoft.com/en-us/dotnet/standard/base-types/custom-date-and-time-format-strings
  https://docs.microsoft.com/en-us/dotnet/standard/base-types/standard-date-and-time-format-strings
~~~~
此工具需要以下基本信息：
* 导出的时间范围。以下4种类型任选一个。
  * 用--begin-time, --end-time 指定具体时间范围。
  * 用--date指定某一天整天
  * 用--yesterday指定昨天一整天
  * 用--export-last-segment指定导出上一个时间段的数据。需要用--segments-per-day指定要将一天等分成多少个时间段。举例：--segments-per-day 4 表示将一天划分成`00:00~06:00,6:00:~12:00,12:00~18:00,18:00~24:00` 4个等分区间。如果当前时间是7:25，那么运行了此工具后会导出`00:00~6:00`的数据（因为7:25所在区间是`6:00~12:00`，它的上一个区间是`00:00~6:00`），如果当前时间是5:30,那么会导出昨天`18:00~24:00`的内容。
* 导出文件存放的目录 --output-dir （支持替换变量:{CurrentTime} {BeginTime} {EndTime} {BoxSN} {ItemName}）
* 导出文件名格式 --output-file-name-pattern（支持替换变量:{CurrentTime} {BeginTime} {EndTime} {BoxSN} {ItemName}）
* appsettings.json中的服务器地址，和开发者账号信息
* 用--box-sn-file指定的FBox序列号列表文件（比如要指定程序目录下的BoxSnList.csv作为输入，则--box-sn-file csvr:任意/文件/路径/BoxSnList.csv。文件路径前面的csvr是格式标识，csvr表示单行逗号分隔的列表，如BoxSnList.csv内容所示。文件路径如有空格，需要给参数内容加双引号。如：--box-sn-file "csvr:c:/Program Files/XXX/File.csv"）。

替换变量可以加额外的格式化符。具体用法参照[C#组合格式化用法](https://docs.microsoft.com/en-us/dotnet/standard/base-types/composite-formatting)
[C#自定义日期格式符](https://docs.microsoft.com/en-us/dotnet/standard/base-types/custom-date-and-time-format-strings)
[C#标准日期格式符](https://docs.microsoft.com/en-us/dotnet/standard/base-types/standard-date-and-time-format-strings)

### 添加为计划任务（Windows）
1. 根据情况修改run-task.cmd里面的运行命令
2. 用管理员权限运行install-task.cmd

### 实际场景举例（Windows）
比如需要每天导出4个文件（`00:00~6:00, 6:00~12:00, 12:00~18:00, 18:00~24:00`）那么：
1. install-task.cmd中修改创建计划任务的命令为：
~~~~
schtasks /create /tn FBox_HistoryExport /sc hourly /mo 6 /st 00:30 /tr "%cd%\run-task.cmd" /ru SYSTEM  /f
~~~~
以上命令注册了一个从当天的00:30之后开始执行，每4小时重复一次的任务。也可以直接在windows的任务计划管理工具中修改。

2. 修改run-task.cmd中的参数，指定 --export-last-segment --segments-per-day 4
3. 管理员权限运行install-task.cmd脚本，注册计划任务。

### 编译方法
1. 用git工具clone这个工程。
2. 去[微软.NET官网](http://dot.net)下载最新的.NET Core SDK。
3. 打开命令行窗口到工程根目录执行以下命令
dotnet publish -c Release -r win81-x64 
Linux 系统选择对应发行版的[runtime identifier](https://docs.microsoft.com/en-us/dotnet/core/rid-catalog)编译即可。
