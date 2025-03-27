using Microsoft.FeatureManagement.FeatureFilters;

namespace QuoteOfTheDay
{
    public class RandomIdAccessor : ITargetingContextAccessor
    {
        private static readonly Random _random = new Random();

        ValueTask<TargetingContext> ITargetingContextAccessor.GetContextAsync()
        {
            var targetingContext = new TargetingContext
            {
                UserId = Guid.NewGuid().ToString(),
                Groups = Array.Empty<string>()
            };

            return new ValueTask<TargetingContext>(targetingContext);
        }

    }
}
