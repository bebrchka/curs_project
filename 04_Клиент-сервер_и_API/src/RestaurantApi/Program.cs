using System.Security.Claims;
using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Data.SqlClient;
using Microsoft.IdentityModel.Tokens;
using RestaurantApi.Data;
using RestaurantApi.Endpoints;
using RestaurantApi.Middleware;
using RestaurantApi.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<Db>();
builder.Services.AddScoped<RestaurantRepository>();
builder.Services.AddSingleton<PasswordHasher>();
builder.Services.AddSingleton<TokenService>();

builder.Services.AddHttpClient<ReportsClient>(client =>
{
    client.BaseAddress = new Uri(builder.Configuration["ReportsService:BaseUrl"] ?? "http://localhost:5100");
    client.DefaultRequestHeaders.Add("X-Service-Key",
        builder.Configuration["ReportsService:ServiceKey"] ?? "change-me");
    client.Timeout = TimeSpan.FromSeconds(30);
});

var jwtKey = builder.Configuration["Jwt:Key"]
    ?? throw new InvalidOperationException("Не задан Jwt:Key");
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "RestaurantApi";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "RestaurantWeb";

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtIssuer,
            ValidAudience = jwtAudience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
            NameClaimType = ClaimTypes.Name,
            RoleClaimType = ClaimTypes.Role,
            ClockSkew = TimeSpan.FromMinutes(1)
        };
    });

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("Staff", policy =>
        policy.RequireRole("Director", "Manager", "Waiter", "Cashier", "Chef"));
    options.AddPolicy("ManagerOrDirector", policy =>
        policy.RequireRole("Director", "Manager"));
    options.AddPolicy("DirectorOnly", policy =>
        policy.RequireRole("Director"));
    options.AddPolicy("CashierOrManager", policy =>
        policy.RequireRole("Director", "Manager", "Cashier"));
    options.AddPolicy("ManagerOrWaiter", policy =>
        policy.RequireRole("Director", "Manager", "Waiter"));
    options.AddPolicy("KitchenOrManager", policy =>
        policy.RequireRole("Director", "Manager", "Chef"));
});

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("public", context =>
        RateLimitPartition.GetFixedWindowLimiter(
            context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 30,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0
            }));
});

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.WithOrigins(
                builder.Configuration.GetSection("Cors:Origins").Get<string[]>()
                ?? ["http://localhost:5000", "https://localhost:5001"])
            .AllowAnyHeader()
            .AllowAnyMethod());
});

var app = builder.Build();

app.Use(async (context, next) =>
{
    context.Response.Headers["X-Content-Type-Options"] = "nosniff";
    context.Response.Headers["X-Frame-Options"] = "DENY";
    context.Response.Headers["Referrer-Policy"] = "no-referrer";
    context.Response.Headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()";
    context.Response.Headers["Content-Security-Policy"] =
        "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; " +
        "connect-src 'self'; font-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self';";
    await next();
});

app.UseMiddleware<ExceptionMiddleware>();
app.UseCors();
app.UseRateLimiter();
app.UseDefaultFiles();
app.UseStaticFiles();
app.UseAuthentication();
app.UseAuthorization();

if (!app.Environment.IsDevelopment())
    app.UseHttpsRedirection();

app.MapGet("/api/health", async (Db db, CancellationToken cancellationToken) =>
{
    await using var connection = await db.OpenAsync(cancellationToken);
    await using var command = new SqlCommand("SELECT 1", connection);
    await command.ExecuteScalarAsync(cancellationToken);
    return Results.Ok(new { status = "ok", time = DateTime.UtcNow });
}).AllowAnonymous().WithTags("Служебные");

app.MapGet("/api/openapi.yaml", (IWebHostEnvironment environment) =>
{
    var path = Path.Combine(environment.ContentRootPath, "wwwroot", "openapi.yaml");
    if (!File.Exists(path))
        return Results.NotFound(new { message = "openapi.yaml не найден" });
    return Results.File(path, "application/yaml", "openapi.yaml");
}).AllowAnonymous().WithTags("Служебные");

app.MapGet("/admin", () => Results.Redirect("/admin.html")).AllowAnonymous();
app.MapGet("/reports", () => Results.Redirect("/reports.html")).AllowAnonymous();

app.MapAuthEndpoints();
app.MapPublicEndpoints();
app.MapStaffEndpoints();
app.MapSettingsEndpoints();
app.MapAdminEndpoints();
app.MapReportsEndpoints();

app.Run();

public partial class Program;
