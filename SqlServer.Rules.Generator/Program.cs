﻿using SqlServer.Rules.Report;
using System;
using System.Text.RegularExpressions;

namespace SqlServer.Rules.Generator
{
    public class Program
    {
        private static void Main(string[] args)
        {
            if (args.Length < 1)
            {
                Console.WriteLine("Usage: SSRG.exe <input file path> [<output file path>]");
                return;
            }

            var request = new ReportRequest
            {
                Solution = args[0],
                InputPath = args[0],
                OutputFileName = args.Length > 1 ? args[1] : string.Empty,
                Suppress = p => Regex.IsMatch(p.Problem.RuleId, @"Microsoft\.Rules.*(SR0001|SR0016|SR0005|SR0007)", RegexOptions.IgnoreCase)
            };

            var factory = new ReportFactory();

            factory.Notify += Factory_Notify;

            factory.Create(request);
        }

        private static void Factory_Notify(string notificationMessage, NotificationType type)
        {
            switch (type)
            {
                case NotificationType.Error:
                    Console.ForegroundColor = ConsoleColor.Red;
                    break;
                case NotificationType.Warning:
                    Console.ForegroundColor = ConsoleColor.Yellow;
                    break;
            }
            Console.WriteLine(notificationMessage);
            Console.ResetColor();
        }
    }
}