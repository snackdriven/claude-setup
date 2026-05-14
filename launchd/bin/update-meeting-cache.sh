#!/bin/bash
# Updates ~/.claude/next-meeting.txt with next upcoming calendar event
# Run via cron every 30 minutes

set -euo pipefail

CACHE_FILE="$HOME/.claude/next-meeting.txt"
FULL_DAY_FILE="$HOME/.claude/today-meetings.txt"
CONFIG_FILE="$(dirname "$0")/calendar-config.json"

# Verify dependencies
command -v jq >/dev/null 2>&1 || { echo "Error: jq is required" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "Error: curl is required" >&2; exit 1; }

# Read calendar URLs from config
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE" >&2
    exit 1
fi

calendar_urls=$(jq -r '.calendars[] | select(.enabled == true) | .url' "$CONFIG_FILE" 2>/dev/null || {
    echo "Error: Failed to parse calendar config" >&2
    exit 1
})

# Fetch and combine calendar data from all enabled calendars
ical_data=""
while IFS= read -r url; do
    if [ -n "$url" ]; then
        data=$(curl -s -f "$url" 2>/dev/null || echo "")
        if [ -z "$data" ]; then
            echo "Warning: Failed to fetch calendar: $url" >&2
        fi
        ical_data+="$data"
        ical_data+=$'\n'
    fi
done <<< "$calendar_urls"

if [ -z "$ical_data" ]; then
    echo "Error: No calendar data retrieved" >&2
    exit 1
fi

# Get current time and date for comparison
now=$(date +%Y%m%dT%H%M%S)

# Platform-agnostic date calculation for next 7 days
dates_and_dows=""
for i in {0..6}; do
    if date -v+1d >/dev/null 2>&1; then
        # BSD date (macOS)
        day_date=$(date -v+${i}d +%Y%m%d)
        day_dow=$(date -v+${i}d +%w)
    else
        # GNU date (Linux)
        day_date=$(date -d "+${i} days" +%Y%m%d)
        day_dow=$(date -d "+${i} days" +%w)
    fi
    dates_and_dows+="${day_date}:${day_dow} "
done

# Parse iCal and find current or next meeting
next_meeting=$(echo "$ical_data" | awk -v now="$now" -v dates_dows="$dates_and_dows" '
BEGIN {
    RS = "BEGIN:VEVENT"
    FS = "\n"
    current_meeting = ""
    next_start = ""
    next_summary = ""
    next_diff = 999999999999

    # Array to store all meetings for today
    meeting_count = 0

    # Day of week mapping (0=Sunday)
    dow_map["SU"] = 0; dow_map["MO"] = 1; dow_map["TU"] = 2; dow_map["WE"] = 3
    dow_map["TH"] = 4; dow_map["FR"] = 5; dow_map["SA"] = 6

    # Parse dates_dows into arrays
    split(dates_dows, date_pairs, " ")
    for (i in date_pairs) {
        if (date_pairs[i] != "") {
            split(date_pairs[i], pair, ":")
            future_dates[pair[2]] = pair[1]  # dow -> date mapping
        }
    }

    # Get today date for filtering
    today = substr(now, 1, 8)
}

# Function to check if date is in DST (2nd Sunday in March to 1st Sunday in November)
function is_dst(year, month, day) {
    # Definitely DST: April through October
    if (month >= 4 && month <= 10) return 1

    # Definitely not DST: Jan, Feb, Dec
    if (month == 1 || month == 2 || month == 12) return 0

    # March: DST starts around day 10-14 (2nd Sunday)
    if (month == 3 && day >= 10) return 1

    # November: DST ends around day 1-7 (1st Sunday)
    if (month == 11 && day <= 7) return 0

    return 0
}

# Function to convert timezone to CST/CDT
function to_cst(datestr, from_tz,    year, month, day, hour, rest, new_hour, day_offset, hour_offset) {
    if (datestr == "") return ""

    year = substr(datestr, 1, 4) + 0
    month = substr(datestr, 5, 2) + 0
    day = substr(datestr, 7, 2) + 0
    hour = substr(datestr, 10, 2) + 0
    rest = substr(datestr, 12)

    # Determine hour offset based on source timezone and DST
    if (from_tz == "utc") {
        # UTC to CST is -6, UTC to CDT is -5
        hour_offset = is_dst(year, month, day) ? -5 : -6
    } else if (from_tz == "la") {
        # LA to CST: PST is +2, PDT is +3
        hour_offset = is_dst(year, month, day) ? 3 : 2
    } else if (from_tz == "chicago") {
        # Already in CST/CDT
        return datestr
    } else {
        # Unknown timezone, assume already CST
        return datestr
    }

    new_hour = hour + hour_offset
    day_offset = 0

    # Handle hour rollover
    while (new_hour < 0) {
        new_hour += 24
        day_offset -= 1
    }
    while (new_hour >= 24) {
        new_hour -= 24
        day_offset += 1
    }

    # Adjust day if needed
    if (day_offset != 0) {
        day = day + day_offset
        # Simplified - doesnt handle month boundaries
        # For cron running every 30min, events are near-term so this works
    }

    return sprintf("%04d%02d%02dT%02d%s", year, month, day, new_hour, rest)
}

/DTSTART/ {
    summary = ""
    dtstart_raw = ""
    dtend_raw = ""
    dtstart_tz = ""
    dtend_tz = ""
    rrule = ""
    exdates = ""
    is_recurring = 0
    has_recurrence_id = 0
    recurrence_id_date = ""

    for (i = 1; i <= NF; i++) {
        if ($i ~ /^SUMMARY:/) {
            summary = $i
            gsub(/^SUMMARY:/, "", summary)
            gsub(/\r/, "", summary)
            # Unescape iCal special characters
            gsub(/\\n/, " ", summary)
            gsub(/\\,/, ",", summary)
            gsub(/\\;/, ";", summary)
            gsub(/\\\\/, "\\", summary)
        }

        if ($i ~ /^DTSTART/) {
            if ($i ~ /DTSTART;TZID=America\/Los_Angeles/) {
                split($i, parts, ":")
                dtstart_raw = parts[2]
                gsub(/[^0-9T]/, "", dtstart_raw)
                dtstart_tz = "la"
            } else if ($i ~ /DTSTART;TZID=America\/Chicago/) {
                split($i, parts, ":")
                dtstart_raw = parts[2]
                gsub(/[^0-9T]/, "", dtstart_raw)
                dtstart_tz = "chicago"
            } else if ($i ~ /DTSTART;TZID=/) {
                split($i, parts, ":")
                dtstart_raw = parts[2]
                gsub(/[^0-9T]/, "", dtstart_raw)
                dtstart_tz = "unknown"
            } else if ($i ~ /DTSTART:.*Z/) {
                dtstart_raw = $i
                gsub(/^DTSTART:/, "", dtstart_raw)
                gsub(/Z/, "", dtstart_raw)
                dtstart_tz = "utc"
            } else if ($i ~ /DTSTART;VALUE=DATE:/) {
                # All-day event, skip
                dtstart_raw = ""
            }
        }

        if ($i ~ /^DTEND/) {
            if ($i ~ /DTEND;TZID=America\/Los_Angeles/) {
                split($i, parts, ":")
                dtend_raw = parts[2]
                gsub(/[^0-9T]/, "", dtend_raw)
                dtend_tz = "la"
            } else if ($i ~ /DTEND;TZID=America\/Chicago/) {
                split($i, parts, ":")
                dtend_raw = parts[2]
                gsub(/[^0-9T]/, "", dtend_raw)
                dtend_tz = "chicago"
            } else if ($i ~ /DTEND;TZID=/) {
                split($i, parts, ":")
                dtend_raw = parts[2]
                gsub(/[^0-9T]/, "", dtend_raw)
                dtend_tz = "unknown"
            } else if ($i ~ /DTEND:.*Z/) {
                dtend_raw = $i
                gsub(/^DTEND:/, "", dtend_raw)
                gsub(/Z/, "", dtend_raw)
                dtend_tz = "utc"
            }
        }

        if ($i ~ /^RRULE:/) {
            rrule = $i
            gsub(/^RRULE:/, "", rrule)
            is_recurring = 1
        }

        if ($i ~ /^EXDATE/) {
            # Parse exception dates (can have multiple EXDATE lines)
            exdate_line = $i
            gsub(/^EXDATE[^:]*:/, "", exdate_line)
            gsub(/\r/, "", exdate_line)
            if (exdates != "") exdates = exdates ","
            exdates = exdates exdate_line
        }

        if ($i ~ /^RECURRENCE-ID/) {
            # This is a modified instance of a recurring event.
            # It has its own DTSTART with the rescheduled time.
            # Save the RECURRENCE-ID date so the base RRULE can exclude it.
            has_recurrence_id = 1
            recurrence_id_line = $i
            gsub(/^RECURRENCE-ID[^:]*:/, "", recurrence_id_line)
            gsub(/\r/, "", recurrence_id_line)
            gsub(/[^0-9T]/, "", recurrence_id_line)
            recurrence_id_date = substr(recurrence_id_line, 1, 8)

            # Store in global array so base RRULE expansion can exclude this date
            # Key: summary~date (summary set later, so we store date and check after loop)
        }
    }

    # Modified recurring instance: process normally (has its own DTSTART with new time)
    # but mark as non-recurring so we skip RRULE expansion
    if (has_recurrence_id) {
        is_recurring = 0

        # Add the RECURRENCE-ID original date to global exclusion set
        # keyed by summary so the base event can find it
        if (summary != "" && recurrence_id_date != "") {
            recurrence_exclusions[summary "," recurrence_id_date] = 1
        }
    }

    # Handle recurring events
    if (is_recurring && dtstart_raw != "") {
        # Check UNTIL date - skip if recurrence has ended
        if (index(rrule, "UNTIL=") > 0) {
            temp = rrule
            sub(/.*UNTIL=/, "", temp)
            sub(/[;Z].*/, "", temp)
            until_date = temp
            gsub(/[^0-9T]/, "", until_date)
            # Convert until_date to CST for comparison
            until_date_cst = to_cst(until_date, dtstart_tz)
            if (until_date_cst < now) {
                dtstart_raw = ""
                next
            }
        }

        byday = ""
        if (index(rrule, "BYDAY=") > 0) {
            temp = rrule
            sub(/.*BYDAY=/, "", temp)
            sub(/;.*/, "", temp)
            byday = temp
            gsub(/\r/, "", byday)
        }

        if (byday != "") {
            split(byday, days, ",")
            # Find earliest FUTURE occurrence in next 7 days
            earliest_date = ""
            for (d in days) {
                day_dow = dow_map[days[d]]
                if (day_dow in future_dates) {
                    # Build candidate datetime and check if it is in the future
                    candidate_date = future_dates[day_dow]
                    candidate_time = substr(dtstart_raw, 9)
                    candidate = candidate_date candidate_time
                    candidate_cst = to_cst(candidate, dtstart_tz)

                    # Only consider if in the future
                    if (candidate_cst > now) {
                        if (earliest_date == "" || candidate_date < earliest_date) {
                            earliest_date = candidate_date
                        }
                    }
                }
            }

            if (earliest_date != "") {
                # Extract original time component (in original timezone)
                time_part = substr(dtstart_raw, 9)
                dtstart_raw = earliest_date time_part
                if (dtend_raw != "") {
                    time_part = substr(dtend_raw, 9)
                    dtend_raw = earliest_date time_part
                }

                # Check if this occurrence is excluded via EXDATE
                if (exdates != "") {
                    split(exdates, exdate_array, ",")
                    for (ex in exdate_array) {
                        exdate = exdate_array[ex]
                        gsub(/[^0-9T]/, "", exdate)

                        # Compare in original timezone before conversion
                        if (exdate == dtstart_raw) {
                            # This occurrence is excluded
                            dtstart_raw = ""
                            break
                        }
                    }
                }

                # Check if this occurrence was moved via RECURRENCE-ID
                # (a modified instance exists with a different DTSTART)
                if (dtstart_raw != "" && summary != "") {
                    check_date = earliest_date
                    if ((summary "," check_date) in recurrence_exclusions) {
                        # This date has a modified instance — skip the base RRULE version
                        dtstart_raw = ""
                    }
                }
            } else {
                dtstart_raw = ""
            }
        }
    }

    # Skip if no valid start time
    if (dtstart_raw == "" || summary == "") next

    # Skip holidays
    if (summary ~ /Chorus Holiday Break/ || summary ~ /New Year/ || summary ~ /Independence Day/ || summary ~ /Presidents/ || summary ~ /Martin Luther King/) next

    # Convert to CST for comparison with "now"
    dtstart = to_cst(dtstart_raw, dtstart_tz)
    dtend = to_cst(dtend_raw, dtend_tz)

    # Check if event occurs today
    event_date = substr(dtstart, 1, 8)
    if (event_date == today && summary != "") {
        meeting_count++
        meetings[meeting_count "_start"] = dtstart
        meetings[meeting_count "_summary"] = summary

        # Also track if currently in meeting
        if (dtstart <= now && dtend != "" && dtend > now && current_meeting == "") {
            current_meeting = summary
        }
    }

    # Still find next upcoming event (for fallback)
    if (dtstart > now && dtstart < next_diff && summary != "") {
        next_diff = dtstart
        next_start = dtstart
        next_summary = summary
    }
}
END {
    months[1]="Jan"; months[2]="Feb"; months[3]="Mar"
    months[4]="Apr"; months[5]="May"; months[6]="Jun"
    months[7]="Jul"; months[8]="Aug"; months[9]="Sep"
    months[10]="Oct"; months[11]="Nov"; months[12]="Dec"

    # Output format: "NEXT|FULL_DAY"
    # NEXT = single next meeting for statusline
    # FULL_DAY = all meetings today (newline-separated)

    next_mtg = ""
    full_day = ""

    # Sort meetings by start time
    if (meeting_count > 0) {
        for (i = 1; i <= meeting_count; i++) {
            for (j = i + 1; j <= meeting_count; j++) {
                if (meetings[j "_start"] < meetings[i "_start"]) {
                    temp_start = meetings[i "_start"]
                    temp_summary = meetings[i "_summary"]
                    meetings[i "_start"] = meetings[j "_start"]
                    meetings[i "_summary"] = meetings[j "_summary"]
                    meetings[j "_start"] = temp_start
                    meetings[j "_summary"] = temp_summary
                }
            }
        }

        # Build full day list and find next meeting
        for (i = 1; i <= meeting_count; i++) {
            mtg_start = meetings[i "_start"]
            mtg_summary = meetings[i "_summary"]

            year = substr(mtg_start, 1, 4)
            month = substr(mtg_start, 5, 2)
            day = substr(mtg_start, 7, 2)
            hour = substr(mtg_start, 10, 2) + 0
            min = substr(mtg_start, 12, 2)

            ampm = "a"
            if (hour >= 12) {
                ampm = "p"
                if (hour > 12) hour = hour - 12
            }
            if (hour == 0) hour = 12

            month_name = months[month+0]
            sub(/^[^A-Za-z0-9]+/, "", mtg_summary)

            formatted = sprintf("%s @ %s %d %d:%02d%s", mtg_summary, month_name, day+0, hour, min+0, ampm)

            # Add to full day list
            if (full_day != "") full_day = full_day "\n"
            full_day = full_day formatted

            # Find next upcoming meeting (first one >= now, or first future if all passed)
            if (next_mtg == "") {
                if (mtg_start >= now) {
                    next_mtg = formatted
                }
            }
        }
    }

    # Fallback to next future meeting if no meetings today
    if (next_mtg == "" && next_summary != "") {
        year = substr(next_start, 1, 4)
        month = substr(next_start, 5, 2)
        day = substr(next_start, 7, 2)
        hour = substr(next_start, 10, 2) + 0
        min = substr(next_start, 12, 2)

        ampm = "a"
        if (hour >= 12) {
            ampm = "p"
            if (hour > 12) hour = hour - 12
        }
        if (hour == 0) hour = 12

        month_name = months[month+0]
        sub(/^[^A-Za-z0-9]+/, "", next_summary)

        if (length(next_summary) > 25) {
            truncated = substr(next_summary, 1, 22)
            last_space = 0
            for (i = 22; i >= 1; i--) {
                if (substr(next_summary, i, 1) == " ") {
                    last_space = i
                    break
                }
            }
            if (last_space > 10) {
                next_summary = substr(next_summary, 1, last_space - 1) "..."
            } else {
                next_summary = truncated "..."
            }
        }

        next_mtg = sprintf("%s @ %s %d %d:%02d%s", next_summary, month_name, day+0, hour, min+0, ampm)
    }

    # Output next meeting on first line, then separator, then full day
    print next_mtg
    print "<<<DELIMITER>>>"
    print full_day
}
')

# Parse output and write to separate files
if [ -n "$next_meeting" ]; then
    # Read line by line, split on delimiter
    in_full_day=false
    next_only=""
    full_day=""

    while IFS= read -r line; do
        if [ "$line" = "<<<DELIMITER>>>" ]; then
            in_full_day=true
        elif [ "$in_full_day" = false ]; then
            next_only="$line"
        else
            if [ -n "$full_day" ]; then
                full_day="$full_day"$'\n'"$line"
            else
                full_day="$line"
            fi
        fi
    done <<< "$next_meeting"

    # Write next meeting to statusline file
    echo "$next_only" > "$CACHE_FILE"

    # Write full day to separate file
    printf '%s\n' "$full_day" > "$FULL_DAY_FILE"
else
    echo "" > "$CACHE_FILE"
    echo "" > "$FULL_DAY_FILE"
fi
