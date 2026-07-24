#!/usr/bin/env bash#"ongoing":[{"record_id":"%s"},{"record_id":"%s"}],"event_type":"cncMessage","caller":"%s","call_index":%s}' \
# Sends grouped log events to OPW via nginx consistent-hash load balancer
# X-Record-ID header routes all events for the same call to the same OPW instance
# OPW Split Arrays processor break the array ongoing into logs for each record id in ongoing.record_id
# OPW Edit Fields processor remaps ongoing.record_id to record_id
# OPW reduce processor groups by record_id field and merges into 1 event per call
#
# The first call sends an event with an array of two record_ids (ongoing.record_id-0 ongoing.record_id-1)
# The next two are two fullRecords with record_ids the same as those in the array
# 1 cncMessage + 2 fullRecord
# split->remap->merge ->-> 3 logs -> 4 logs -> 2 logs -> to datadog
# client -> op worker -> datadog api
# OPW reduce flushes after 10s -> Datadog sees 1 merged event per call

set -euo pipefail

DD_API_KEY="${DD_API_KEY:?DD_API_KEY is required}"
OPW_URL="http://localhost:8282/api/v2/logs"
CALLS="${1:-1}"

for i in $(seq 1 "$CALLS"); do
  ID=0
  ID1=1
  RECORD_ID=("call-$(printf '%03d' $i)-$(date +%s)-$ID" "call-$(printf '%03d' $i)-$(date +%s)-$ID1")
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  CALLER="555-$(shuf -i 1000-9999 -n1)"
  HOST="$(hostname)"
  ONLY_IN_ONE="test_field"

  # Event 1: cncMessage
  curl -s -o /dev/null -D - -X POST "$OPW_URL" \
    -H "Content-Type: application/json" \
    -H "DD-API-KEY: $DD_API_KEY" \
    -H "X-Record-ID: ${RECORD_ID[0]}" \
    --data-binary "$(printf '{"message":"[%s] cncMessage: incoming call initiated","service":"opw-demo-via-opw","hostname":"%s","ddsource":"opw-api-demo","ddtags":"path:via-opw,demo:opw-api-comparison,event_type:cncMessage,call:%s","ongoing":[{"record_id":"%s"},{"record_id":"%s"}],"event_type":"cncMessage","caller":"%s","call_index":%s}' \
      "$TIMESTAMP" "$HOST" "$i" "${RECORD_ID[0]}" "${RECORD_ID[1]}" "$CALLER" "$i")" \
    | grep -i "x-opw-upstream" | tr -d '\r' | awk '{print $2}'

  sleep 0.2

  # Event 2: first fullRecord
  printf '{"message":"[%s] fullRecord: segment 1 duration 30s","service":"opw-demo-via-opw","hostname":"%s","ddsource":"opw-api-demo","ddtags":"path:via-opw,demo:opw-api-comparison,event_type:fullRecord,call:%s","record_id":"%s","event_type":"fullRecord","segment":1,"duration_s":30,"call_index":"%s","only_in_one":"%s"}' \
    "$TIMESTAMP" "$HOST" "$i" "${RECORD_ID[0]}" "$i" "$ONLY_IN_ONE" | \
  curl -s -o /dev/null -X POST "$OPW_URL" \
    -H "Content-Type: application/json" \
    -H "DD-API-KEY: $DD_API_KEY" \
    -H "X-Record-ID: $RECORD_ID" \
    --data-binary @-

  sleep 0.2

  # Event 3: second fullRecord
  printf '{"message":"[%s] fullRecord: segment 2 duration 45s","service":"opw-demo-via-opw","hostname":"%s","ddsource":"opw-api-demo","ddtags":"path:via-opw,demo:opw-api-comparison,event_type:fullRecord,call:%s","record_id":"%s","event_type":"fullRecord","segment":2,"duration_s":45,"call_index":%s,"only_in_one":"%s"}' \
    "$TIMESTAMP" "$HOST" "$i" "${RECORD_ID[1]}" "$i" "$ONLY_IN_ONE" | \
  curl -s -o /dev/null -X POST "$OPW_URL" \
    -H "Content-Type: application/json" \
    -H "DD-API-KEY: $DD_API_KEY" \
    -H "X-Record-ID: $RECORD_ID" \
    --data-binary @-

  sleep 1
done
