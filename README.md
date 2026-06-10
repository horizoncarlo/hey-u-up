## hey-u-up 
#### Cheap and Easy Website Monitor

```
Usage:
  ./hey-u-up.sh -u URL -t NTFY_TOPIC [options]

Required:
  -u URL              Website URL to check
  -t NTFY_TOPIC       NTFY topic to publish alerts to

Options:
  -1                  Run the script ONCE instead of an interval, then exit (useful in cron/systemctl timers)
  -i SECONDS          Check interval in seconds, default 1800 seconds (30 minutes)
  -c SECONDS          Cooldown seconds before notifying again, default 28800 (8 hours)
  -g TEXT             Optional text to search for in response body

Examples:
  Basic:     ./hey-u-up.sh -u https://example.com -t my-alert-topic

  Customize: ./hey-u-up.sh -u https://example.com -t my-alert-topic -i 300 -c 3600 -g "Welcome"

  Run once:  ./hey-u-up.sh -u https://example.com -t my-alert-topic -1
```
