using System;
using System.Collections.Generic;
using System.Text;

namespace HistoryExportTool
{
    static class DateTimeExtensions
    {
        internal static readonly long InitialJavaScriptDateTicks = 621355968000000000;

        internal static DateTime ConvertJavaScriptTicksToDateTime(long javaScriptTicks)
        {
            DateTime dateTime = new DateTime((javaScriptTicks * 10000) + InitialJavaScriptDateTicks, DateTimeKind.Utc);

            return dateTime;
        }
    }
}
