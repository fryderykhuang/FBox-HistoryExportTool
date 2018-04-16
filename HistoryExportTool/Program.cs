using Microsoft.Extensions.CommandLineUtils;
using System;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using CsvHelper;
using FBoxClientDriver.Lite;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace HistoryExportTool
{
    class Program
    {
        private static IConfigurationRoot _configuration;

        static int Main(string[] args)
        {
            Console.WriteLine(Directory.GetCurrentDirectory());
            TaskScheduler.UnobservedTaskException += TaskScheduler_UnobservedTaskException;
            var cfgBuilder = new ConfigurationBuilder()
                .SetBasePath(Directory.GetCurrentDirectory())
                .AddJsonFile("appsettings.json", true, true);

            _configuration = cfgBuilder.Build();
            var spFactory = new DefaultServiceProviderFactory();
            var sc = new ServiceCollection();
            ConfigureServices(sc);
            var spBuilder = spFactory.CreateBuilder(sc);
            var container = spFactory.CreateServiceProvider(spBuilder);
            var loggerFactory = container.GetRequiredService<ILoggerFactory>();
            loggerFactory.AddConsole(_configuration.GetSection("Logging"));

            var localNow = DateTime.Now;
            var appname = "HistoryExportTool";
            var app = new CommandLineApplication {Name = appname};
            app.HelpOption("-?|-h|--help");
            app.Command("exporthdata", command =>
            {
                command.Description = "Export fbox history data";
                command.HelpOption("-?|-h|--help");
                command.ExtendedHelpText = $@"
Examples:
  Export the data in yesterday: 
    {appname} exporthdata --yesterday --output-dir output --timestamp-format yyyyMMddHHmmss --output-file-name-pattern {{BoxSN}}-{{ItemName}}-{{CurrentTime:yyyyMMddHHmmss}}.csv --box-sn-file csvr:BoxSnList.csv

  Export the data in last time segment. (e.g. If current time is 13:20, the following command will export data in time range: 06:00(inclusive) ~ 12:00(exclusive). If current time is 5:30, the result time range will be 18:00 of yesterday ~ 00:00 of today). ): 
    {appname} exporthdata --export-last-segment --segments-per-day 4 --output-dir output/{{BoxSN}} --timestamp-format yyyyMMddHHmmss --output-file-name-pattern {{ItemName}}-{{CurrentTime:yyyyMMddHHmmss}}.csv --box-sn-file csvr:BoxSnList.csv

  Export data from 2018/03/30 06:00 to 2018/04/02(exclusive) 
    {appname} exporthdata --begin-time yyyyMMddHH:2018033006 --end-time yyyyMMdd:20180402 --output-dir output --timestamp-format yyyyMMddHHmmss --output-file-name-pattern {{BoxSN}}-{{ItemName}}-{{CurrentTime:yyyyMMddHHmmss}}.csv --box-sn-file csvr:BoxSnList.csv

All substitution pattern can use C# composite formatting. (https://docs.microsoft.com/en-us/dotnet/standard/base-types/composite-formatting).
For the date and time format string used above please refer to:
  https://docs.microsoft.com/en-us/dotnet/standard/base-types/custom-date-and-time-format-strings
  https://docs.microsoft.com/en-us/dotnet/standard/base-types/standard-date-and-time-format-strings
";
                var beginTimeArg = command.Option("--begin-time", "Specify the beginning of export time range.",CommandOptionType.SingleValue);
                var endTimeArg = command.Option("--end-time", "Specify the ending of export time range.", CommandOptionType.SingleValue);
                var dateArg = command.Option("--date", "Specify a certain day to export.", CommandOptionType.SingleValue);
                var yesterdayArg = command.Option("--yesterday", "Export data in yesterday.", CommandOptionType.NoValue);
                var outputFileNamePatternArg = command.Option("--output-file-name-pattern",
                    "Output file name pattern. Available substitution is {CurrentTime} {BeginTime} {EndTime} {BoxSN} {ItemName}.",
                    CommandOptionType.SingleValue);
                var outDirArg = command.Option("--output-dir",
                    "The directory exported files are stored in. Available substitution is {CurrentTime} {BeginTime} {EndTime} {BoxSN} {ItemName}.",
                    CommandOptionType.SingleValue);
                var timestampFormatArg = command.Option("--timestamp-format", "Timestamp format.",
                    CommandOptionType.SingleValue);
//                var boxNoArg = command.Option("--box-sn", "Box serial number", CommandOptionType.SingleValue);
                var utcArg = command.Option("--utc", "Indicate the input time is specified as UTC time.", CommandOptionType.NoValue);
                var boxSnFileArg = command.Option("--box-sn-file", "A file holds a list of box serial numbers.", CommandOptionType.SingleValue);
                var segmentsPerDayArg = command.Option("--segments-per-day",
                    "The number of equal parts a day will be divided into. Use with --export-last-segment", CommandOptionType.SingleValue);
                var exportLastSegmentArg = command.Option("--export-last-segment", "Export last time segment, must be also specify --segments-per-day",
                    CommandOptionType.NoValue);
                var nullSubstitutionArg = command.Option("--null-substitution", "Substitute null value with this string.",
                    CommandOptionType.SingleValue);
                var noOverwriteArg = command.Option("--no-overwrite", "Do not overwrite target file if exists.",
                    CommandOptionType.NoValue);

                command.OnExecute(() =>
                {
                    DateTime beginTime;
                    DateTime endTime;

                    var dtStyle = DateTimeStyles.AssumeLocal | DateTimeStyles.AdjustToUniversal;
                    if (utcArg.HasValue())
                    {
                        dtStyle = DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal;
                    }

                    if (beginTimeArg.HasValue())
                    {
                        if (!endTimeArg.HasValue())
                            throw new CommandParsingException(command,
                                "Begin time and end time must be specified in pair.");
                        if (dateArg.HasValue())
                            throw new CommandParsingException(command,
                                "Either specify a time range using begin and end time options or specify a date only.");

                        (var beginTimeType, var beginTimeStr) = beginTimeArg.Value().SplitByFirst(":");
                        if (!DateTime.TryParseExact(beginTimeStr, beginTimeType,
                            DateTimeFormatInfo.InvariantInfo, dtStyle, out var bt))
                        {
                            throw new CommandParsingException(command, "Incorrect begin time format");
                        }

                        beginTime = bt;
                        (var endTimeType, var endTimeStr) = endTimeArg.Value().SplitByFirst(":");
                        if (!DateTime.TryParseExact(endTimeStr, endTimeType,
                            DateTimeFormatInfo.InvariantInfo, dtStyle, out var et))
                        {
                            throw new CommandParsingException(command, "Incorrect end time format");
                        }

                        endTime = et;

//                        fileName = $"{beginTimeArg.Value()}-{endTimeArg.Value()}-{{0}}.csv";
                    }
                    else if (yesterdayArg.HasValue())
                    {
                        var nowDate = localNow.Date;
                        beginTime = nowDate.AddDays(-1).ToUniversalTime();
                        endTime = nowDate.ToUniversalTime();

//                        fileName = $"{beginTime:yyyyMMdd}-{{0}}.csv";
                    }
                    else if (dateArg.HasValue())
                    {
                        (var dateType, var dateStr) = dateArg.Value().SplitByFirst(":");
                        DateTime.TryParseExact(dateStr, dateType, DateTimeFormatInfo.InvariantInfo,
                            dtStyle, out var dt);

                        beginTime = dt.Date;
                        endTime = dt.Date.AddDays(1);
                    }
                    else if (exportLastSegmentArg.HasValue())
                    {
                        if (!segmentsPerDayArg.HasValue())
                            throw new CommandParsingException(command, "--segments-per-day must be specified along with --export-last-segment.");

                        var nsegs = Convert.ToInt32(segmentsPerDayArg.Value());
                        if ((24 % nsegs) != 0)
                            throw new CommandParsingException(command, "24 must be divisible by --segments-per-day.");

                        var period = 24 / nsegs;
                        var lastseg = localNow.Hour / period;
                        var nowdate = localNow.Date;
                        if (lastseg == 0)
                        {
                            beginTime = nowdate.AddHours(-period);
                            endTime = nowdate;
                        }
                        else
                        {
                            beginTime = nowdate.AddHours(lastseg * period);
                            endTime = nowdate.AddHours((lastseg + 1) * period);
                        }

                        beginTime = beginTime.ToUniversalTime();
                        endTime = endTime.ToUniversalTime();
                    }
                    else
                    {
                        throw new CommandParsingException(command,
                            "Please specify the time range to export using either --begin-time --end-time or --date or --yesterday or --export-last-segment");
                    }

                    string nullSubstitution = null;

                    if (nullSubstitutionArg.HasValue())
                    {
                        nullSubstitution = nullSubstitutionArg.Value();
                    }

                    string[] boxNoList = null;
//                    string boxNo = null;
                    if (boxSnFileArg.HasValue())
                    {
                        var boxsnfilestr = boxSnFileArg.Value();
                        (var type, var file) = boxsnfilestr.SplitByFirst(":");
                        if (type == "csvr")
                        {
                            using (var sr = new StreamReader(file))
                            {
                                using (var parser = new CsvParser(sr, true))
                                {
                                    boxNoList = parser.Read();
                                }
                            }
                        }
                    }
                    else
                    {
//                        if (boxNoArg.HasValue())
//                        {
//                            boxNo = boxNoArg.Value();
//                        }
                    }

                    if (/*boxNo == null &&*/ boxNoList == null)
                        throw new CommandParsingException(command,
                            "Please specify the box serial number with --box-sn-file.");

                    string outputDirFormat;
                    if (outDirArg.HasValue())
                    {
                        outputDirFormat = outDirArg.Value()
                            .Replace("{CurrentTime", "{0")
                            .Replace("{BeginTime", "{1")
                            .Replace("{EndTime", "{2")
                            .Replace("{BoxSN", "{3")
                            .Replace("{ItemName", "{4");
                    }
                    else
                    {
                        outputDirFormat = "output";
                    }

                    if (!outputFileNamePatternArg.HasValue())
                    {
                        throw new CommandParsingException(command, "Please specify output file name pattern with --out-file-name-pattern");
                    }

                    var outputFileNameFormat = outputFileNamePatternArg.Value()
                        .Replace("{CurrentTime", "{0")
                        .Replace("{BeginTime", "{1")
                        .Replace("{EndTime", "{2")
                        .Replace("{BoxSN", "{3")
                        .Replace("{ItemName", "{4");

                    string timestampFormat = "s";

                    if (timestampFormatArg.HasValue())
                    {
                        timestampFormat = timestampFormatArg.Value();
                    }

                    var noOverwrite = noOverwriteArg.HasValue();

                    Task.Run(async () =>
                    {
                        using (var fbox =
                            new FBoxClient(container.GetRequiredService<IOptions<FBoxClientSettings>>().Value))
                        {
                            if (boxNoList != null)
                            {
                                foreach (var bn in boxNoList)
                                {
                                    var items = await fbox.GetHdataItems(bn);
                                    foreach (var hdataItem in items)
                                    {
                                        var outDir = string.Format(outputDirFormat, localNow, beginTime.ToLocalTime(),
                                            endTime.ToLocalTime(), bn, hdataItem.Name);
                                        Directory.CreateDirectory(outDir);
                                        var filename = string.Format(outputFileNameFormat, localNow, beginTime.ToLocalTime(), endTime.ToLocalTime(), bn, hdataItem.Name);
                                        var path = Path.Combine(outDir, filename);

                                        if (noOverwrite && File.Exists(path))
                                            continue;
                                        using (var outs = new StreamWriter(path, false))
                                        using (var csv = new CsvWriter(outs))
                                        { 
                                            var tcs = new TaskCompletionSource<bool>();
                                            csv.WriteField("Timestamp");
                                            foreach (var hdataItemChannel in hdataItem.Channels)
                                            {
                                                csv.WriteField(hdataItemChannel.ChannelName);
                                            }
                                            csv.NextRecord();

                                            IObservable<HdataDataRecord> result = fbox.GetHdataRecords(
                                                hdataItem.Channels.Select(x => x.Uid).ToArray(), beginTime,
                                                endTime, TimeRangeTypes.BeginCloseEndOpen);
                                            result.Subscribe(o =>
                                            {
                                                csv.WriteField(o.Timestamp.ToString(timestampFormat));

                                                foreach (var c in o.Cells)
                                                {
                                                    var v = c;
                                                    if (v == null && nullSubstitution != null)
                                                    {
                                                        v = nullSubstitution;
                                                    }
                                                    csv.WriteField(v);
                                                }

                                                csv.NextRecord();
                                            }, o => tcs.TrySetException(o), () => tcs.TrySetResult(true));

                                            await tcs.Task;
                                        }
                                    }
                                }
                            }
//                            else
//                            {
//                                fbox.GetHdataCsvStream(boxNo, beginTime, endTime,
//                                    TimeRangeTypes.BeginCloseEndOpen).Result.CopyTo(fs);
//                            }
                        }
                    }).Wait();
                    return 0;
                });
            });

            try
            {
                if (args.Length == 0)
                {
                    app.ShowHelp();
                    return -1;
                }
                return app.Execute(args);
            }
            catch (CommandParsingException ex)
            {
                Console.Error.WriteLine(ex.Message);
                app.ShowHelp();
                return -2;
            }
        }

        private static void TaskScheduler_UnobservedTaskException(object sender, UnobservedTaskExceptionEventArgs e)
        {
            Console.Error.WriteLine("Unobserved task exception: " + e.Exception);
        }

        private static void ConfigureServices(ServiceCollection services)
        {
            services.AddLogging();
            services.AddOptions();
            services.Configure<FBoxClientSettings>(_configuration.GetSection("FBox"));
        }
    }
}