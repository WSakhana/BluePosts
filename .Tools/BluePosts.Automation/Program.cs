namespace BluePosts.Automation;

internal static class Program
{
    public static async Task<int> Main(string[] args)
    {
        using var cancellation = new CancellationTokenSource();
        Console.CancelKeyPress += (_, eventArgs) =>
        {
            eventArgs.Cancel = true;
            cancellation.Cancel();
        };

        try
        {
            var command = CommandLine.Parse(args);

            switch (command)
            {
                case HelpCommand:
                    Console.WriteLine(CommandLine.HelpText);
                    return 0;

                case BuildDataCommand buildDataCommand:
                {
                    var runner = new BuildDataRunner();
                    var result = await runner.RunAsync(buildDataCommand.Options, cancellation.Token);
                    Console.WriteLine($"Generated {result.PostCount} posts -> {result.OutputPath}");
                    return 0;
                }

                case PipelineCommand pipelineCommand:
                {
                    var runner = new PipelineRunner(new BuildDataRunner());
                    await runner.RunAsync(pipelineCommand.Options, cancellation.Token);
                    return 0;
                }

                default:
                    throw new InvalidOperationException($"Unsupported command type: {command.GetType().Name}");
            }
        }
        catch (CliException exception)
        {
            Console.Error.WriteLine(exception.Message);
            Console.Error.WriteLine();
            Console.Error.WriteLine(CommandLine.HelpText);
            return 1;
        }
        catch (OperationCanceledException)
        {
            Console.Error.WriteLine("Operation cancelled.");
            return 2;
        }
        catch (Exception exception)
        {
            Console.Error.WriteLine(exception.Message);
            return 1;
        }
    }
}