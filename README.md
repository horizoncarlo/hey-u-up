Usage:
  ./hey-u-up.sh -u URL -t NTFY_TOPIC [options]

Required:
  -u URL              Website URL to check
  -t NTFY_TOPIC       NTFY topic to publish alerts to

Options:
  -i SECONDS          Check interval in seconds, default 60 seconds
  -c SECONDS          Cooldown seconds before notifying again, default 28800 (8 hours)
  -g TEXT             Optional text to search for in response body

Examples:
  ./hey-u-up.sh -u https://example.com -t my-alert-topic

  ./hey-u-up.sh -u https://example.com -t my-alert-topic -i 300 -c 3600 -g "Welcome"
