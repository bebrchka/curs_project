using RestaurantApi.Services;
using Xunit;

namespace RestaurantApi.Tests;

public sealed class CsvTests
{
    [Fact]
    public void Escape_QuotesSemicolonAndQuotes()
    {
        Assert.Equal("\"Борщ; со сметаной\"", Csv.Escape("Борщ; со сметаной"));
        Assert.Equal("\"Салат \"\"Цезарь\"\"\"", Csv.Escape("Салат \"Цезарь\""));
        Assert.Equal("Чай", Csv.Escape("Чай"));
    }

    [Fact]
    public void ParseLine_HandlesQuotedFields()
    {
        var columns = Csv.ParseLine("1;\"Борщ; со сметаной\";320,00;\"Суп\"");

        Assert.Equal(4, columns.Count);
        Assert.Equal("1", columns[0]);
        Assert.Equal("Борщ; со сметаной", columns[1]);
        Assert.Equal("320,00", columns[2]);
        Assert.Equal("Суп", columns[3]);
    }

    [Fact]
    public void ToCsv_JoinsRows()
    {
        var csv = Csv.ToCsv(new[]
        {
            new string?[] { "A", "B" },
            new string?[] { "1;2", "x" }
        });

        Assert.Contains("A;B", csv);
        Assert.Contains("\"1;2\";x", csv);
    }
}
