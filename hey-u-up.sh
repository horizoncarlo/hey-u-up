#!/usr/bin/env bash

set -u

# Preset
NTFY_SERVER="https://ntfy.sh"
NOTIF_COUNT_BEFORE_COOLDOWN=3
CURL_TIMEOUT=20

# Customizable via flags
NTFY_TOPIC=""
WATCH_URL=""
INTERVAL_SECONDS=1800
GREP_TEXT=""
COOLDOWN_SECONDS=$((8 * 60 * 60))
RUN_ONCE=false

usage() {
  cat <<EOF
Usage:
  $0 -u URL -t NTFY_TOPIC [options]

Required:
  -u URL              Website URL to check
  -t NTFY_TOPIC       NTFY topic to publish alerts to

Options:
  -1                  Run the script ONCE instead of an interval, then exit (useful in cron/systemctl timers)
  -i SECONDS          Check interval in seconds, default 1800 seconds (30 minutes)
  -c SECONDS          Cooldown seconds before notifying again, default 28800 (8 hours)
  -g TEXT             Optional text to search for in response body

Examples:
  Basic:     $0 -u https://example.com -t my-alert-topic

  Customize: $0 -u https://example.com -t my-alert-topic -i 300 -c 3600 -g "Welcome"

  Run once:  $0 -u https://example.com -t my-alert-topic -1
EOF
}

check_site() {
  local tmp_body=""
  local output_target
  local http_code
  local curl_exit

  if [[ -n "$GREP_TEXT" ]]; then
    tmp_body="$(mktemp)"
    output_target="$tmp_body"
  else
    output_target="/dev/null"
  fi

  http_code="$(
    curl \
      --silent \
      --show-error \
      --location \
      --max-time "$CURL_TIMEOUT" \
      --output "$output_target" \
      --write-out "%{http_code}" \
      "$WATCH_URL"
  )"
  curl_exit=$?

  if [[ "$curl_exit" -ne 0 ]]; then
    [[ -n "$tmp_body" ]] && rm -f "$tmp_body"
    echo "DOWN: curl failed with exit code $curl_exit"
    return 1
  fi

  if [[ "$http_code" != "200" ]]; then
    [[ -n "$tmp_body" ]] && rm -f "$tmp_body"
    echo "DOWN: HTTP status $http_code"
    return 1
  fi

  if [[ -n "$GREP_TEXT" ]]; then
    if ! grep -Fq -- "$GREP_TEXT" "$tmp_body"; then
      rm -f "$tmp_body"
      echo "DOWN: expected text not found: $GREP_TEXT"
      return 1
    fi
  fi

  [[ -n "$tmp_body" ]] && rm -f "$tmp_body"
  echo "UP: HTTP 200"
  return 0
}

run_and_notify() {
  local output
  local timestamp
  local now
  local should_notify=false

  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  if output="$(check_site)"; then
    echo "[$timestamp] $output"

    if [[ "$failure_streak" -gt 0 ]]; then
      echo "[$timestamp] Site recovered"
    fi

    failure_streak=0
    notifications_in_current_outage=0
    last_notification_time=0
    return 0
  fi

  echo "[$timestamp] $output"

  failure_streak=$((failure_streak + 1))
  now="$(date +%s)"

  should_notify=false

  # Notify on the first X failed cycles of an outage
  if [[ "$RUN_ONCE" == true ]]; then
    should_notify=true

  elif [[ "$notifications_in_current_outage" -lt "$NOTIF_COUNT_BEFORE_COOLDOWN" ]]; then
    should_notify=true

  # After that, notify again only after the cooldown period
  elif [[ $((now - last_notification_time)) -ge "$COOLDOWN_SECONDS" ]]; then
    should_notify=true
  fi

  if [[ "$should_notify" == true ]]; then
    curl -fsS \
      -H "Title: Monitored Website DOWN" \
      -H "Priority: high" \
      -d "URL: $WATCH_URL
Time: $timestamp
$output" \
      "$NTFY_SERVER/$NTFY_TOPIC" >/dev/null || {
        echo "Warning: failed to send NTFY notification" >&2
      }

    notifications_in_current_outage=$((notifications_in_current_outage + 1))
    last_notification_time="$now"
    echo "[$timestamp] Notification sent"
  else
    echo "[$timestamp] Notification suppressed (will send again in $COOLDOWN_SECONDS seconds)"
  fi

  return 1
}

while getopts ":1u:t:i:c:g:" opt; do
  case "$opt" in
    1) RUN_ONCE=true ;;
    u) WATCH_URL="$OPTARG" ;;
    t) NTFY_TOPIC="$OPTARG" ;;
    i) INTERVAL_SECONDS="$OPTARG" ;;
    c) COOLDOWN_SECONDS="$OPTARG" ;;
    g) GREP_TEXT="$OPTARG" ;;
    :)
      echo "Missing argument for -$OPTARG" >&2
      usage
      exit 1
      ;;
    \?)
      echo "Unknown option: -$OPTARG" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$WATCH_URL" || -z "$NTFY_TOPIC" ]]; then
  echo "Error: URL and NTFY_TOPIC are required" >&2
  usage
  exit 1
fi

if ! [[ "$INTERVAL_SECONDS" =~ ^[0-9]+$ ]] || [[ "$INTERVAL_SECONDS" -lt 1 ]]; then
  echo "Error: Interval must be a positive number" >&2
  exit 1
fi

if ! [[ "$COOLDOWN_SECONDS" =~ ^[0-9]+$ ]] || [[ "$COOLDOWN_SECONDS" -lt 1 ]]; then
  echo "Error: Cooldown must be a positive number" >&2
  exit 1
fi

failure_streak=0
notifications_in_current_outage=0
last_notification_time=0

if [[ "$RUN_ONCE" == true ]]; then
  echo "Checking $WATCH_URL once for status..."
  run_and_notify
  exit $?
fi

echo "Monitoring $WATCH_URL every $INTERVAL_SECONDS seconds..."
while true; do
  run_and_notify
  sleep "$INTERVAL_SECONDS"
done
