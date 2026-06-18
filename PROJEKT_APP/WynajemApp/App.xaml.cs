using System.IO;
using System.Windows;
using System.Windows.Threading;
using Microsoft.Extensions.Configuration;

namespace WynajemApp;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        AppDomain.CurrentDomain.UnhandledException += (_, args) => Log("AppDomain", args.ExceptionObject as Exception);
        DispatcherUnhandledException += (_, args) => { Log("Dispatcher", args.Exception); args.Handled = false; };

        base.OnStartup(e);

        try
        {
            var basePath = AppContext.BaseDirectory;
            var builder = new ConfigurationBuilder()
                .SetBasePath(basePath)
                .AddJsonFile("appsettings.example.json", optional: true, reloadOnChange: false)
                .AddJsonFile("appsettings.json", optional: true, reloadOnChange: false);

            AppServices.Init(builder.Build());
        }
        catch (Exception ex)
        {
            Log("OnStartup", ex);
            MessageBox.Show(ex.ToString(), "Blad startu", MessageBoxButton.OK, MessageBoxImage.Error);
            Shutdown(1);
        }
    }

    private static void Log(string source, Exception? ex)
    {
        try
        {
            var path = Path.Combine(AppContext.BaseDirectory, "crash.log");
            File.AppendAllText(path, $"[{DateTime.Now:O}] {source}: {ex}\n\n");
        }
        catch { }
    }
}
