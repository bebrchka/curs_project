using System.Globalization;
using System.Text;
using RestaurantApi.Data;
using RestaurantApi.Models;
using RestaurantApi.Services;

namespace RestaurantApi.Endpoints;

public static class AdminEndpoints
{
    public static IEndpointRouteBuilder MapAdminEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api").WithTags("Администрирование")
            .RequireAuthorization("ManagerOrDirector");

        group.MapGet("/export/menu.csv", async (
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
        {
            var dishes = await repository.GetDishesAsync(null, false, cancellationToken);
            var rows = new List<IEnumerable<string?>>
            {
                new[] { "DishID", "CategoryID", "CategoryName", "DishName", "Price", "WeightGr", "Description", "IsAvailable" }
            };
            rows.AddRange(dishes.Select(dish => new string?[]
            {
                dish.DishId.ToString(),
                dish.CategoryId.ToString(),
                dish.CategoryName,
                dish.DishName,
                dish.Price.ToString("F2", CultureInfo.InvariantCulture),
                dish.WeightGr?.ToString("F1", CultureInfo.InvariantCulture),
                dish.Description,
                dish.IsAvailable ? "1" : "0"
            }));

            var bytes = WithBom(Csv.ToCsv(rows));
            return Results.File(bytes, "text/csv; charset=utf-8", "menu.csv");
        });

        group.MapGet("/export/orders.csv", async (
            DateTime? from,
            DateTime? to,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
        {
            var orders = await repository.GetOrdersAsync(from, to, null, cancellationToken);
            var rows = new List<IEnumerable<string?>>
            {
                new[] { "OrderID", "OrderDate", "OrderStatus", "OrderType", "TableNumber", "Customer", "Employee", "TotalAmount", "DiscountPercent" }
            };
            rows.AddRange(orders.Select(order => new string?[]
            {
                order.OrderId.ToString(),
                order.OrderDate.ToString("yyyy-MM-dd HH:mm", CultureInfo.InvariantCulture),
                order.OrderStatus,
                order.OrderType,
                order.TableNumber,
                order.CustomerFullName,
                order.EmployeeFullName,
                order.TotalAmount.ToString("F2", CultureInfo.InvariantCulture),
                order.DiscountPercent.ToString("F2", CultureInfo.InvariantCulture)
            }));

            var bytes = WithBom(Csv.ToCsv(rows));
            return Results.File(bytes, "text/csv; charset=utf-8", "orders.csv");
        });

        group.MapPost("/import/dishes", async (
            IFormFile file,
            RestaurantRepository repository,
            CancellationToken cancellationToken) =>
        {
            if (file is null || file.Length == 0)
                throw new ApiException("VALIDATION", "Файл не передан", StatusCodes.Status400BadRequest);
            if (file.Length > 1_048_576)
                throw new ApiException("VALIDATION", "Файл больше 1 МБ", StatusCodes.Status400BadRequest);

            using var reader = new StreamReader(file.OpenReadStream(), Encoding.UTF8, true);
            var content = await reader.ReadToEndAsync(cancellationToken);
            var lines = content.Split('\n', StringSplitOptions.RemoveEmptyEntries)
                .Select(line => line.TrimEnd('\r'))
                .Where(line => !string.IsNullOrWhiteSpace(line))
                .ToList();

            if (lines.Count == 0)
                throw new ApiException("VALIDATION", "Файл пуст", StatusCodes.Status400BadRequest);

            var start = lines[0].StartsWith("CategoryID", StringComparison.OrdinalIgnoreCase) ? 1 : 0;
            var errors = new List<string>();
            var imported = 0;

            for (var i = start; i < lines.Count; i++)
            {
                var columns = Csv.ParseLine(lines[i]);
                if (columns.Count < 3)
                {
                    errors.Add($"Строка {i + 1}: нужно минимум 3 колонки");
                    continue;
                }

                try
                {
                    var categoryId = int.Parse(columns[0].Trim(), CultureInfo.InvariantCulture);
                    var name = columns[1].Trim();
                    var price = decimal.Parse(columns[2].Replace(',', '.'), CultureInfo.InvariantCulture);
                    decimal? weight = columns.Count > 3 && !string.IsNullOrWhiteSpace(columns[3])
                        ? decimal.Parse(columns[3].Replace(',', '.'), CultureInfo.InvariantCulture)
                        : null;
                    var description = columns.Count > 4 ? columns[4].Trim() : null;
                    var available = columns.Count <= 5 || columns[5].Trim() is not ("0" or "false" or "нет");

                    if (name.Length < 2)
                    {
                        errors.Add($"Строка {i + 1}: название слишком короткое");
                        continue;
                    }

                    await repository.InsertDishAsync(new DishRequest(
                        categoryId, name, price, weight,
                        string.IsNullOrWhiteSpace(description) ? null : description,
                        available), cancellationToken);
                    imported++;
                }
                catch (Exception exception) when (exception is FormatException or OverflowException)
                {
                    errors.Add($"Строка {i + 1}: неверный формат числа");
                }
                catch (Exception exception)
                {
                    errors.Add($"Строка {i + 1}: {exception.Message}");
                }
            }

            return Results.Ok(new ImportResult(imported, lines.Count - start - imported, errors));
        }).DisableAntiforgery();

        return app;
    }

    private static byte[] WithBom(string text)
    {
        var preamble = Encoding.UTF8.GetPreamble();
        var body = Encoding.UTF8.GetBytes(text);
        var result = new byte[preamble.Length + body.Length];
        preamble.CopyTo(result, 0);
        body.CopyTo(result, preamble.Length);
        return result;
    }
}
