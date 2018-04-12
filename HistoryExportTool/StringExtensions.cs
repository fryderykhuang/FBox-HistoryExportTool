using System;
using System.Collections.Generic;
using System.Text;

namespace HistoryExportTool
{
    public static class StringExtensions
    {
        public static (string, string) SplitByFirst(this string input, string splitter)
        {
            var ind = input.IndexOf(splitter, StringComparison.InvariantCulture);
            var first = input.Substring(0, ind);
            var rest = input.Substring(ind + 1);
            return (first, rest);
        }
    }
}
