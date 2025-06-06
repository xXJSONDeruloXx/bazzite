#!/usr/bin/env bash

echo "$(date) - System woke from suspend, checking for audio sink..." >> /tmp/mute-wake.log
for i in {1..10}; do
  DEFAULT=$(pactl get-default-sink 2>/dev/null)
  echo "$(date) - pactl get-default-sink output: $DEFAULT" >> /tmp/mute-wake.log
  if [[ -n "$DEFAULT" && "$DEFAULT" != @DEFAULT_SINK@ ]]; then
    echo "$(date) - Sink: $DEFAULT found. Setting volume to 0%..." >> /tmp/mute-wake.log
    pactl set-sink-volume "$DEFAULT" 0%
    echo "$(date) - Done." >> /tmp/mute-wake.log
    exit 0
  fi
  sleep 0.3
done
echo "$(date) - No usable sink found after 3s. Skipping wake mute." >> /tmp/mute-wake.log
