#!/usr/bin/env bash
# Copyright 2026 Anthropic PBC
# SPDX-License-Identifier: Apache-2.0
# run a redshift data api query end-to-end with curl + jq: submit ExecuteStatement, poll
# DescribeStatement until terminal, page GetStatementResult on NextToken, and decode the typed
# one-key cell objects ({"longValue":42}, {"isNull":true}, ...) into tsv or jsonl. generic to any
# cluster or serverless workgroup — everything instance-specific comes from env vars or flags.

set -euo pipefail

usage() {
  cat <<'EOF'
usage:
  rs_query.sh [options] "SELECT ..."           # sql as a single quoted argument
  echo "SELECT ..." | rs_query.sh [options]    # sql on stdin

options:
  --param NAME=VALUE   named query parameter, repeatable. referenced as :NAME in the sql. all
                       parameter values are strings (the database casts to the column type).
                       example: --param start=2024-01-01 --param limit=100
  --database DB        database to connect through (defaults to $RS_DATABASE)
  --name NAME          StatementName label for the query (shows in ListStatements / monitoring)
  --max-rows N         stop fetching after N rows (default 10000; 0 = fetch everything)
  --max-wait SECONDS   give up waiting for the statement after this long (default 600)
  --json               emit one json object per row (jsonl) instead of tsv
  -h, --help           show this help

environment:
  AWS_DEFAULT_REGION  region of the cluster / workgroup (required unless RS_DATA_URL is set)
  RS_TARGET           connection-target json — one of {"WorkgroupName": "..."},
                      {"ClusterIdentifier": "...", "DbUser": "..."}, or {"SecretArn": "..."} with
                      either identifier (required)
  RS_DATABASE         database to connect through (required unless --database is given)
  RS_DATA_URL         api endpoint override (default https://redshift-data.<region>.amazonaws.com/)

output:
  rows on stdout — tsv with a header row by default, jsonl with --json. statement id, status,
  duration, and row counts go to stderr.

exit codes:
  0 success    1 submit/request failed or sql FAILED/ABORTED    2 timed out (id printed on stderr)
EOF
}

err() { printf '%s\n' "$*" >&2; }

command -v curl >/dev/null || { err "curl is required"; exit 1; }
command -v jq >/dev/null || { err "jq is required"; exit 1; }

DATABASE="${RS_DATABASE:-}"
TARGET="${RS_TARGET:-}"
STMT_NAME=""
MAX_ROWS=10000
MAX_WAIT=600
POLL_INTERVAL=2
FORMAT=tsv
PARAMS='[]'
SQL=""

# require_int FLAG VALUE — flags that take a count must get a non-negative integer
require_int() {
  case "$2" in
    ''|*[!0-9]*) err "$1 needs a non-negative integer, got '${2:-nothing}'"; exit 1 ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    --param)
      SPEC="${2:-}"
      PNAME="${SPEC%%=*}"
      PVALUE="${SPEC#*=}"
      if [ -z "$PNAME" ] || [ "$PNAME" = "$SPEC" ]; then
        err "bad --param '$SPEC' (expected NAME=VALUE, e.g. start=2024-01-01)"
        exit 1
      fi
      PARAMS="$(jq -c --arg n "$PNAME" --arg v "$PVALUE" \
        '. + [{name: $n, value: $v}]' <<<"$PARAMS")"
      shift 2 ;;
    --database)
      if [ -z "${2:-}" ]; then err "--database needs a name"; exit 1; fi
      DATABASE="$2"; shift 2 ;;
    --name)
      if [ -z "${2:-}" ]; then err "--name needs a value"; exit 1; fi
      STMT_NAME="$2"; shift 2 ;;
    --max-rows) require_int --max-rows "${2:-}"; MAX_ROWS="$2"; shift 2 ;;
    --max-wait) require_int --max-wait "${2:-}"; MAX_WAIT="$2"; shift 2 ;;
    --json) FORMAT=json; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) err "unknown option: $1 (see --help)"; exit 1 ;;
    *)
      if [ -n "$SQL" ]; then
        err "unexpected extra argument: $1 (pass the sql as one quoted string)"; exit 1
      fi
      SQL="$1"; shift ;;
  esac
done

if [ -z "$SQL" ]; then
  if [ -t 0 ]; then err "no sql given (pass it as an argument or on stdin; see --help)"; exit 1; fi
  SQL="$(cat)"
fi
if [ -z "${SQL//[[:space:]]/}" ]; then err "no sql given"; exit 1; fi
if [ -z "$DATABASE" ]; then err "set RS_DATABASE or pass --database"; exit 1; fi
if [ -z "$TARGET" ]; then err "set RS_TARGET to the connection-target json (see --help)"; exit 1; fi
if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$TARGET"; then
  err "RS_TARGET must be a json object, got: $TARGET"; exit 1
fi

if [ -n "${RS_DATA_URL:-}" ]; then
  ENDPOINT="$RS_DATA_URL"
elif [ -n "${AWS_DEFAULT_REGION:-}" ]; then
  ENDPOINT="https://redshift-data.${AWS_DEFAULT_REGION}.amazonaws.com/"
else
  err "set AWS_DEFAULT_REGION (or RS_DATA_URL to override the endpoint)"; exit 1
fi

# rs_api ACTION BODY — post one data api action; the runtime replaces the placeholder auth header
rs_api() {
  curl -sS --max-time 120 "$ENDPOINT" \
    -H "Content-Type: application/x-amz-json-1.1" \
    -H "X-Amz-Target: RedshiftData.$1" \
    -H "Authorization: placeholder" \
    -d "$2"
}

# exit with the api's own message if the response is an error envelope (or not json at all)
rs_check_error() {
  if ! jq -e . >/dev/null 2>&1 <<<"$1"; then
    err "non-json response from the api:"
    printf '%s\n' "$1" | head -c 2000 >&2
    exit 1
  fi
  if [ "$(jq -r 'type == "object" and has("__type")' <<<"$1")" = "true" ]; then
    jq -r '"redshift-data error \(.__type // ""): \(.message // .Message // "unknown error")"' \
      <<<"$1" >&2
    exit 1
  fi
}

BODY="$(jq -cn \
  --argjson target "$TARGET" \
  --arg db "$DATABASE" \
  --arg sql "$SQL" \
  --arg name "$STMT_NAME" \
  --argjson params "$PARAMS" \
  '$target + {Database: $db, Sql: $sql}
   + (if $name != "" then {StatementName: $name} else {} end)
   + (if ($params | length) > 0 then {Parameters: $params} else {} end)')"

SUBMIT="$(rs_api ExecuteStatement "$BODY")"
rs_check_error "$SUBMIT"
ID="$(jq -r '.Id // empty' <<<"$SUBMIT")"
if [ -z "$ID" ]; then
  err "ExecuteStatement returned no Id:"
  printf '%s\n' "$SUBMIT" >&2
  exit 1
fi
err "statement: ${ID}"

# poll DescribeStatement until terminal; bounded by --max-wait
DEADLINE=$(( $(date +%s) + MAX_WAIT ))
DESC='{}'
STATUS=""
while :; do
  DESC="$(rs_api DescribeStatement "$(jq -cn --arg id "$ID" '{Id: $id}')")"
  rs_check_error "$DESC"
  STATUS="$(jq -r '.Status // empty' <<<"$DESC")"
  if [ -z "$STATUS" ]; then
    err "DescribeStatement returned no Status:"
    printf '%s\n' "$DESC" >&2
    exit 1
  fi
  case "$STATUS" in FINISHED|FAILED|ABORTED) break ;; esac
  if [ "$(date +%s)" -ge "$DEADLINE" ]; then
    err "gave up after ${MAX_WAIT}s; statement ${ID} is still ${STATUS}"
    err "poll it later: DescribeStatement {\"Id\": \"${ID}\"}"
    exit 2
  fi
  sleep "$POLL_INTERVAL"
done

# Duration is nanoseconds; ResultRows is -1 until finished
jq -r '"status=\(.Status) duration=\((.Duration // 0) / 1e9)s rows=\(.ResultRows // 0)"' \
  <<<"$DESC" >&2

if [ "$STATUS" = "FAILED" ] || [ "$STATUS" = "ABORTED" ]; then
  jq -r '"sql error: \(.Error // "no error message")"' <<<"$DESC" >&2
  exit 1
fi

# ddl/dml: nothing to fetch
if [ "$(jq -r '.HasResultSet // false' <<<"$DESC")" != "true" ]; then
  ROWS="$(jq -r '.ResultRows // 0' <<<"$DESC")"
  err "statement ok: ${ROWS} rows affected, no result set"
  exit 0
fi

TOTAL="$(jq -r '.ResultRows // 0' <<<"$DESC")"
COLS='[]'
FETCHED=0
NEXT=""
PAGE_NUM=0

# print up to $2 rows from page $1; each cell is a one-key typed object, isNull is its own shape
print_page() {
  if [ "$FORMAT" = "tsv" ]; then
    jq -r --argjson take "$2" \
      '[.Records[]?][:$take][]
       | [.[] | if .isNull then "" else to_entries[0].value end]
       | @tsv' <<<"$1"
  else
    jq -c --argjson take "$2" --argjson cols "$COLS" \
      '[.Records[]?][:$take][]
       | [.[] | if .isNull then null else to_entries[0].value end] as $vals
       | [$cols, $vals] | transpose | map({(.[0]): .[1]}) | add' <<<"$1"
  fi
}

while :; do
  REQ="$(jq -cn --arg id "$ID" --arg next "$NEXT" \
    '{Id: $id} + (if $next == "" then {} else {NextToken: $next} end)')"
  PAGE="$(rs_api GetStatementResult "$REQ")"
  rs_check_error "$PAGE"

  if [ "$PAGE_NUM" -eq 0 ]; then
    COLS="$(jq -c '[.ColumnMetadata[]?.name]' <<<"$PAGE")"
    if [ "$FORMAT" = "tsv" ]; then jq -r '. | @tsv' <<<"$COLS"; fi
  fi
  PAGE_NUM=$(( PAGE_NUM + 1 ))

  COUNT="$(jq -r '[.Records[]?] | length' <<<"$PAGE")"
  TAKE="$COUNT"
  if [ "$MAX_ROWS" -gt 0 ]; then
    REMAINING=$(( MAX_ROWS - FETCHED ))
    if [ "$COUNT" -gt "$REMAINING" ]; then TAKE="$REMAINING"; fi
  fi
  if [ "$TAKE" -gt 0 ]; then print_page "$PAGE" "$TAKE"; fi
  FETCHED=$(( FETCHED + TAKE ))

  NEXT="$(jq -r '.NextToken // empty' <<<"$PAGE")"
  if [ "$MAX_ROWS" -gt 0 ] && [ "$FETCHED" -ge "$MAX_ROWS" ]; then
    if [ -n "$NEXT" ] || [ "$COUNT" -gt "$TAKE" ]; then
      err "output truncated at ${FETCHED} of ${TOTAL} rows (raise --max-rows, or 0 for everything)"
    fi
    break
  fi
  if [ -z "$NEXT" ]; then break; fi
done

err "fetched ${FETCHED} of ${TOTAL} rows"
