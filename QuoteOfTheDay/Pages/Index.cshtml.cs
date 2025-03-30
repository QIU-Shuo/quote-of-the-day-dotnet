using Microsoft.ApplicationInsights;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.FeatureManagement;
using System.Diagnostics;
using System.Text.Json.Serialization;

namespace QuoteOfTheDay.Pages;

public class Quote
{
    public string Message { get; set; }

    public string Author { get; set; }
}

public class TodoItem
{
    [JsonPropertyName("id")]
    public int Id { get; set; }

    [JsonPropertyName("title")]
    public string Title { get; set; }

    [JsonPropertyName("completed")]
    public bool Completed { get; set; }
}

public class IndexModel : PageModel
{
    private readonly ILogger<IndexModel> _logger;
    private readonly IVariantFeatureManagerSnapshot _featureManager;
    private readonly TelemetryClient _telemetryClient;
    private readonly ActivitySource _activitySource;
    private readonly HttpClient _httpClient;
    private const string GreetingFeatureFlag = "Greeting";

    private readonly Quote[] _quotes = [
        new Quote()
        {
            Message = "You cannot change what you are, only what you do.",
            Author = "Philip Pullman"
        }];

    public Quote? Quote { get; set; }
    public string Greeting { get; set; }
    public TodoItem? ApiData { get; set; }
    public string ApiError { get; set; }

    public IndexModel(
        ILogger<IndexModel> logger,
        IVariantFeatureManagerSnapshot featureManager,
        TelemetryClient telemetryClient,
        IHttpClientFactory httpClientFactory)
    {
        _logger = logger;
        _featureManager = featureManager;
        _telemetryClient = telemetryClient;
        _httpClient = httpClientFactory.CreateClient();
    }

    public async Task OnGetAsync()
    {
        Quote = _quotes[new Random().Next(_quotes.Length)];

        Variant variant = await _featureManager.GetVariantAsync(GreetingFeatureFlag, HttpContext.RequestAborted);

        if (variant != null)
        {
            Greeting = variant.Configuration?.Get<string>() ?? "";
        }
        else
        {
            _logger.LogWarning($"Greeting variant not found. Please define a variant feature flag in Azure App Configuration named '{GreetingFeatureFlag}'.");
        }

        try
        {
            // Get a random todo item (between 1-10)
            int todoId = new Random().Next(1, 11);
            ApiData = await _httpClient.GetFromJsonAsync<TodoItem>(
                $"https://jsonplaceholder.typicode.com/todos/{todoId}");

            _logger.LogInformation($"Successfully fetched todo item {todoId}");
        }
        catch (Exception ex)
        {
            ApiError = $"API Error: {ex.Message}";
            _logger.LogError(ex, "Error fetching data from API");
        }
    }

    public IActionResult OnPostHeartQuoteAsync()
    {
        string? userId = User.Identity?.Name;

        // Send telemetry to Application Insights
        _telemetryClient.TrackEvent("Like");

        return new JsonResult(new { success = true });
    }
}