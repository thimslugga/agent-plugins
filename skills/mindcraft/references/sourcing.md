# Sourcing the corpus

Concrete extraction per system, plus the field mappings `mindcraft.py normalize` expects.

**Contents**
- [Ground rules](#ground-rules)
- [GitHub](#github)
- [Linear](#linear)
- [Jira](#jira)
- [Git history](#git-history)
- [Local task files and notes](#local-task-files-and-notes)
- [Incident postmortems and retro docs](#incident-postmortems-and-retro-docs)
- [Agent transcripts](#agent-transcripts)
- [Normalized record schema](#normalized-record-schema)

## Ground rules

Retrieve **closed / resolved / merged / done / complete** items only. Filter by a window (default 90 days) and a scope (repo, team, project, label).

Always include the discussion. Titles and bodies describe the *what*; comments and review threads describe the *how* and the *why it was hard*, which is where the mineable procedure lives. A corpus of titles alone produces a report of vague nouns.

Redact before writing to disk if items contain credentials, customer names, or personal data — the normalized JSONL is a new copy of that data in a new place.

## GitHub

Merged pull requests, with review threads and touched files:

```bash
gh pr list \
  --repo ORG/REPO \
  --state merged \
  --limit 300 \
  --search "merged:>=2026-06-15" \
  --json number,title,url,createdAt,mergedAt,labels,body,files,comments,reviews,additions,deletions,author \
  > raw/prs.json
```

Closed issues:

```bash
gh issue list \
  --repo ORG/REPO \
  --state closed \
  --limit 300 \
  --search "closed:>=2026-06-15" \
  --json number,title,url,createdAt,closedAt,labels,body,comments,assignees,stateReason \
  > raw/issues.json
```

Reopened issues — a high-value slice, since a reopen means the work was declared done and was not:

```bash
gh issue list --repo ORG/REPO --state closed --limit 100 --search "closed:>=2026-06-15 reopened:true" --json number,title,url,body,comments \
  > raw/reopened.json
```

If `gh` is unavailable, the REST API works the same way and the mapping is identical:

```bash
curl -sSL -H "Authorization: Bearer $GITHUB_TOKEN" "https://api.github.com/repos/ORG/REPO/issues?state=closed&since=2026-06-15&per_page=100" \
  > raw/issues.json
```

Then:

```bash
python3 scripts/mindcraft.py normalize --source github-prs    --input raw/prs.json    --output work/prs.jsonl
python3 scripts/mindcraft.py normalize --source github-issues --input raw/issues.json --output work/issues.jsonl

cat work/prs.jsonl work/issues.jsonl > work/records.jsonl
```

## Linear

If Linear MCP tools are connected, use them rather than the raw API — `list_issues` with a completed-state filter, then `list_comments` per issue for the discussion. Ask for the connector if it is not present; a Linear corpus without comments is much weaker.

Sketch of the loop:

1. `list_teams` → get the team id
2. `list_issues` with that team, a completed/canceled state filter, and an `updatedAt` window
3. For each returned issue, `list_comments` to attach the thread
4. Write the combined objects as a JSON array to `raw/linear.json`

Via GraphQL instead:

```bash
curl -sSL https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ issues(filter: {completedAt: {gte: \"2026-06-15\"}}, first: 250) { nodes { identifier title url createdAt completedAt description state { name } labels { nodes { name } } comments { nodes { body user { name } } } } } }"}' \
  | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["data"]["issues"]["nodes"]))' \
  > raw/linear.json

python3 scripts/mindcraft.py normalize --source linear --input raw/linear.json --output work/records.jsonl
```

## Jira

```bash
curl -sSL -u "$JIRA_USER:$JIRA_TOKEN" \
  -G "https://YOURORG.atlassian.net/rest/api/3/search" \
  --data-urlencode 'jql=project = ENG AND statusCategory = Done AND resolutiondate >= -90d ORDER BY resolutiondate DESC' \
  --data-urlencode 'fields=summary,status,created,resolutiondate,labels,description,comment,issuetype,assignee' \
  --data-urlencode 'maxResults=200' \
  | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)["issues"]))' \
  > raw/jira.json

python3 scripts/mindcraft.py normalize --source jira --input raw/jira.json --output work/records.jsonl
```

## Git history

Useful when the tracker is thin but the repo is rich. Revert commits and repeated commit-message shapes are strong recurrence signals in their own right.

```bash
# Commit subjects in the window, grouped by conventional-commit scope
git log --since="90 days ago" --pretty='%s' | sed -n 's/^\([a-z]*\)(\([^)]*\)).*/\1 \2/p' | sort | uniq -c | sort -rn | head -40

# Reverts and hotfixes — each one is a procedure that failed
git log --since="90 days ago" --pretty='%h %ad %s' --date=short --grep='^Revert' --grep='hotfix' --grep='rollback' -i

# Files changed most often — churn concentrates where procedures repeat
git log --since="90 days ago" --name-only --pretty=format: | grep -v '^$' | sort | uniq -c | sort -rn | head -30
```

Feed these in as `generic` records (one object per commit or per cluster) or cite them as supporting evidence on candidates mined from the tracker.

## Local task files and notes

`TASKS.md`, `TODO.md`, meeting notes, a done-list — completed entries with dates are a legitimate corpus, especially for solo or small-team work where no tracker exists.

Convert to `generic` records: one object per completed entry with at minimum `id`, `title`, `closed_at`, and whatever body text exists. The normalizer passes `generic` through with light validation, so hand-built JSON is fine.

```bash
python3 scripts/mindcraft.py normalize --source generic --input raw/tasks.json --output work/records.jsonl
```

## Incident postmortems and retro docs

Treat each postmortem as one record and each **action item** as its own record linked back to it. The mining question is specifically: *which action items recur across incidents?* An action item that appears in three postmortems is a procedure nobody has encoded, and it is usually the highest-scoring candidate in the whole corpus.

## Agent transcripts

If prior agent sessions are available (`/mnt/transcripts` or a session log directory), they are the richest source available, because they record the procedure directly rather than a summary of it — including the corrections. Mine specifically for:

- **User corrections**: "no, we always deploy to staging first" — a rule that was missing from context
- **Repeated context-loading**: the same three files read at the start of many sessions
- **Repeated tool sequences**: the same commands in the same order across sessions
- **Abandoned attempts**: where the agent went down a path the user rejected

## Normalized record schema

`normalize` emits one JSON object per line. Fields it does not find are omitted rather than nulled; `signals` and `report` tolerate absence.

| Field | Type | Meaning |
|---|---|---|
| `id` | string | Stable identifier — `ENG-1423`, `#882`. Used as the evidence citation. |
| `source` | string | `github-prs`, `linear`, `jira`, `generic`, … |
| `type` | string | `issue`, `pr`, `task`, `epic`, `incident`, `action_item` |
| `title` | string | One-line summary |
| `state` | string | Terminal state as recorded |
| `url` | string | Link back to the item |
| `opened_at` / `closed_at` | ISO 8601 | Timestamps |
| `cycle_time_hours` | number | Computed from the two timestamps when both parse |
| `labels` | string[] | Labels, tags, or components |
| `assignees` | string[] | Who did the work |
| `body` | string | Description |
| `comments` | object[] | `{author, body}` — the discussion thread |
| `comment_count` | int | Length of `comments` |
| `files` | string[] | Touched paths, where the source provides them |
| `extra` | object | Anything unmapped, preserved for later inspection |

Add fields freely for a source the mappings do not cover — downstream commands ignore what they do not recognize, so extending the schema costs nothing.
