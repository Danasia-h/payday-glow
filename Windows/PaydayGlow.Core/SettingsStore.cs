using System.Text.Json;

namespace PaydayGlow.Core;

public sealed record SavedState
{
    public WageSettings Settings { get; init; } = new();
    public bool Configured { get; init; }
    public string? LastShiftId { get; init; }
}

public sealed class SettingsStore(string directory)
{
    public string FilePath { get; } = Path.Combine(directory, "settings.json");
    public string? LoadWarning { get; private set; }
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true };
    public SavedState Load()
    {
        if (!File.Exists(FilePath)) return new();
        try
        {
            var value = JsonSerializer.Deserialize<SavedState>(File.ReadAllText(FilePath));
            if (value is null || value.Settings is null || value.Settings.Validate() is not null)
                throw new JsonException("Invalid configuration");
            return value;
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException or ArgumentException)
        {
            LoadWarning = "本机设置文件无法读取，已使用默认值。请重新设置；原文件在你保存前不会被覆盖。";
            return new();
        }
    }

    public void Save(SavedState value)
    {
        if (value.Settings.Validate() is string error) throw new ArgumentException(error);
        Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
        string temporary = FilePath + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try
        {
            File.WriteAllText(temporary, JsonSerializer.Serialize(value, Options));
            File.Move(temporary, FilePath, true);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
}
