#!/usr/bin/env bash
source .github/notion_api.sh

DATABASE_ID=a2a984bf5563447ba4bcb1bf191498a4

jq_base64() {
    echo "${1}" | base64 --decode | jq -r ${2}
}

get_next_date() {
    local date="$1"
    local freq="$2"
    local update=""
    # Keep the same timezone setting
    IFS='T' read -ra date_array <<< "$date"
    # 1 is Monday
    weekday=$(date --date "${date_array[0]}" +'%u')
    if [[ "${1}" == "Daily" ]]; then
        update="+1 day"
        # If it's friday, take the next monday
        if [[ "${weekday}" == "5" ]]; then
            update="+3 days"
        fi
    elif [[ "${1}" == "Weekly" ]]; then
        update="+1 week"
    elif [[ "${1}" == "Bi-weekly" ]]; then
        update="+2 weeks"
    elif [[ "${1}" == "Monthly" ]]; then
        update="+4 weeks"
    fi
    echo "$(date --date "${date_array[0]} ${update}" +'%Y-%m-%d')T${date_array[1]}"
}

checked_run() {
    # $@ expand from $1
    local result=$("$@")
    local object=$(echo "$result" | jq -r '.object')
    # using object not status (no status in the success)
    if [[ ${object} == "error" ]]; then
        echo 1>&2 "error: ${result}"
        echo 1>&2 "error from $1 $2 ..."
        exit 1
    fi
    echo "${result}"
}

update_page() {
    local url="${NOTION_PREFIX}/pages/${1}"
    local end="${3}"
    # if date is not null, need "" around in the json
    if [[ ${end} != "null" ]]; then
        end="\"${end}\""
    fi
    local update=$(cat << EOT
{
  "properties": {
    "Date": {
      "date": {
        "start": "${2}",
        "end": ${end}
      }
    }
  }
}
EOT
    )
    # avoid print the result out
    tmp=$(checked_run notion_patch "${url}" "${update}")
}

filter_time="$(date --date '-1 hour' +'%Y-%m-%dT%H:%M:%S.000%:z')"

filter_json=$(cat << EOT
{
  "filter": {
    "and": [{
        "property": "Frequency",
        "select": {
          "is_not_empty": true
        }
      },
      {
        "property": "Date",
        "date": {
          "before": "${filter_time}"
        }
      }
    ]
  }
}
EOT
)

result=$(checked_run notion_post "${NOTION_PREFIX}/databases/${DATABASE_ID}/query" "${filter_json}")
# There are many quote in content, with compact-output, jq does not clear all of them.
for row in $(echo $result | jq -r '.results | .[] | @base64'); do
    id=$(jq_base64 ${row} '.id')
    start=$(jq_base64 ${row} '.properties.Date.date.start')
    freq=$(jq_base64 ${row} '.properties.Frequency.select.name')
    end=$(jq_base64 ${row} '.properties.Date.date.end')

    update=$(freq_update ${freq})
    # Keep the same timezone setting
    IFS='T' read -ra date_array <<< "$start"
    new_start="$(get_next_date "${start}" "${freq}")"
    new_end="${end}"
    if [[ ${end} != "null" ]]; then
        # Notion can only filter by the start date
        comp_filter=$(date --date "${filter_time}" +'%Y%m%d%H%M')
        comp_end=$(date --date "${end}" +'%Y%m%d%H%M')
        if [ ${comp_filter} -le ${comp_end} ]; then
            # ending date is not passed yet
            continue
        fi
        new_end="$(get_next_date "${end}" "${freq}")"
    fi
    update_page "${id}" "${new_start}" "${new_end}"
done
