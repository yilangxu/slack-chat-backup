#!/bin/bash

source config.sh

if [[ $# -lt 1 ]]; then
  exit
fi

t=$1
shift

  for i in $@; do
    if [[ $# -gt 0 ]]; then
      matched=0
      for a in $@; do
        if [[ "X$i" == "X$a" ]]; then
          matched=1
          break
        fi
      done
      if [[ $matched -eq 0 ]]; then
        continue
      fi
    fi
    echo "#### PROCESSING THIS OBJECT: $t - $i"
    #cat meta/boot.json | jq -r '.'$t'[]|select(.id=="'$i'")'

    latest=''

    mkdir -p messages/$t/$i
    mkdir -p log/$t/$i
    output=latest
    has_more=true

    newest=$(basename $(ls -1 messages/$t/$i/*.*.json 2>/dev/null | sort | tail -n 1) .json || echo 0)

    echo -n "Downloading.."
    while [[ "X$has_more" == "Xtrue" ]]; do
      x_ts=$(gdate +%s.%3N)
      boundary='---------------------------'$(generate-digits 29)
      curl -sv "https://$team_name.slack.com/api/conversations.history?_x_id=$x_id-$x_ts&slack_route=$team_id&_x_version_ts=$x_version_ts" \
      -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:76.0) Gecko/20100101 Firefox/76.0' \
      -H 'Accept: */*' \
      -H 'Accept-Language: en-US,en;q=0.5' \
      -H 'Content-Type: multipart/form-data; boundary='$boundary \
      -H 'Origin: https://app.slack.com' \
      -H "Cookie: $cookie" \
      --data-binary $'--'$boundary$'\r\nContent-Disposition: form-data; name="channel"\r\n\r\n'$i$'\r\n--'$boundary$'\r\nContent-Disposition: form-data; name="limit"\r\n\r\n42\r\n--'$boundary$'\r\nContent-Disposition: form-data; name="ignore_replies"\r\n\r\ntrue\r\n--'$boundary$'\r\nContent-Disposition: form-data; name="include_pin_count"\r\n\r\ntrue\r\n--'$boundary$'\r\nContent-Disposition: form-data; name="inclusive"\r\n\r\ntrue\r\n--'$boundary$'\r\nContent-Disposition: form-data; name="no_user_profile"\r\n\r\ntrue\r\n--'$boundary$'\r\nContent-Disposition: form-data; name="latest"\r\n\r\n'$latest$'\r\n--'$boundary$'\r\nContent-Disposition: form-data; name="token"\r\n\r\n'$token$'\r\n--'$boundary$'\r\nContent-Disposition: form-data; name="_x_reason"\r\n\r\nmessage-pane/requestHistory\r\n--'$boundary$'\r\nContent-Disposition: form-data; name="_x_mode"\r\n\r\nonline\r\n--'$boundary$'\r\nContent-Disposition: form-data; name="_x_sonic"\r\n\r\ntrue\r\n--'$boundary$'--\r\n' \
      >messages/$t/$i/$output.json 2>log/$t/$i/$output.log

      status_code=$(cat log/$t/$i/$output.log | grep "^< HTTP/" | awk '{ print $3 }')
      if [[ $status_code -ne 200 ]]; then
        # try again
        if [[ $status_code -eq 429 ]]; then
          echo -n s
          sleep 3
        else
          echo -n x
        fi
        sleep 1
      else
        jq . messages/$t/$i/$output.json >/dev/null 2>&1
        if [[ $? -gt 0 ]]; then
          echo -n j
        else
          echo -n .
          has_more=$(cat messages/$t/$i/$output.json | jq -r .has_more)
          latest=$(cat messages/$t/$i/$output.json | jq -r '.messages[].ts' | sort -n | head -n 1)
          output=$latest
          newest_done=0
          if [[ "X$newest" > "X$output" ]]; then
            newest_done=1
          fi
          if [[ "X$newest" == "X$output" ]]; then
            newest_done=1
          fi
          if [[ $newest_done -gt 0 ]]; then
            oldest=$(basename $(ls -1 messages/$t/$i/*.*.json 2>/dev/null | sort | tail -n 1) .json || echo 0)
            if [[ -f messages/$t/$i/$oldest.json ]]; then
              has_more=$(cat messages/$t/$i/$oldest.json | jq -r .has_more)
              latest=$(cat messages/$t/$i/$oldest.json | jq -r '.messages[].ts' | sort -n | head -n 1)
              output=$latest
            else
              break
            fi
          fi
        fi
        sleep 0.2
      fi
    done
    echo
  done

exit
