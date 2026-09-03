# baseballr-mlb-raw

Raw MLB capture for the SportsDataverse baseball stack. Two per-game surfaces —
the **MLB Stats API** `feed/live` payload and the **Baseball Savant** per-game
Statcast export — committed as gzipped files, one per game, plus a per-season
schedule and manifest.

This repo is **scraping-only**. It fetches, validates, and commits payloads. It
does no reshaping, no modeling, and publishes no release assets — that is
[`baseballr-data`](https://github.com/sportsdataverse/baseballr-data)'s job.

## Where this sits

```mermaid
graph LR
  statsapi["statsapi.mlb.com<br/>feed/live"] --> raw
  savant["baseballsavant.mlb.com<br/>statcast_search"] --> raw
  raw["baseballr-mlb-raw<br/><i>(this repo)</i>"] --> data["baseballr-data"]
  data --> rel["sportsdataverse-data<br/>release assets"]
```

```mermaid
flowchart TB
  subgraph this["baseballr-mlb-raw (capture)"]
    s1["python/mlb_raw_01_schedule_scrape.py<br/>-> mlb/raw/schedule/{season}.json.gz"]
    s2["python/mlb_raw_02_statsapi_scrape.py<br/>-> mlb/raw/statsapi/{season}/{game_pk}.json.gz"]
    s3["python/mlb_raw_03_savant_scrape.py<br/>-> mlb/raw/savant/{season}/{game_pk}.csv.gz"]
    s1 --> s2 --> s3
    s1 --> man["mlb/raw/manifest/{season}.csv + index.csv"]
  end
  subgraph sib["baseballr-data (reshape + publish)"]
    r1["python/mlb_model_01_game_state.py"]
    r2["python/mlb_model_02_hitting.py"]
    r3["python/mlb_model_03_pitching.py"]
    r4["python/mlb_model_04_fielding.py"]
  end
  s2 --> r1
  s3 --> r1
  r1 --> r2 & r3 & r4
```

Stage 01 must run before 02/03: the schedule is what enumerates `game_pk`s, and
the manifest it writes is the work list both capture stages filter.

## Reading it without cloning

The tree is ~465 MB, so a consumer should read per-game files over HTTP rather
than clone. Paths are stable and derivable from the schedule — build the URL,
don't list the directory:

```
https://raw.githubusercontent.com/sportsdataverse/baseballr-mlb-raw/main/mlb/raw/statsapi/2024/744795.json.gz
https://raw.githubusercontent.com/sportsdataverse/baseballr-mlb-raw/main/mlb/raw/savant/2024/744795.csv.gz
https://raw.githubusercontent.com/sportsdataverse/baseballr-mlb-raw/main/mlb/raw/schedule/2024.json.gz
https://raw.githubusercontent.com/sportsdataverse/baseballr-mlb-raw/main/mlb/raw/manifest/2024.csv
```

`mlb/raw/manifest/index.csv` is the one file to read first: one row per season
with the captured counts and byte totals.

## Coverage

| season | scheduled | captured (statsapi) | captured (savant) | statsapi bytes | savant bytes |
|---|---:|---:|---:|---:|---:|
| 2024 | 2,959 | 2,472 | 2,472 | 325,457,984 | 147,877,879 |

Scheduled counts every game on the schedule feed including spring training
(`S`: 472) and exhibitions (`E`: 13, `A`: 1); captured counts **completed**
regular-season and postseason games (`R`, `D`, `L`, `W`, `F`), which is what the
stages filter to. The gap is not loss.

2024 is the proof season. Earlier seasons backfill into this same tree.

## Running a capture

See [`RUNBOOK.md`](RUNBOOK.md) for the full operator guide. The short form:

```sh
bash scripts/run_mlb_01_schedule_scrape.sh --season 2024
bash scripts/run_mlb_02_statsapi_scrape.sh --season 2024
bash scripts/run_mlb_03_savant_scrape.sh   --season 2024
```

Every stage is **resumable and idempotent**. Resume is presence-based: a game is
outstanding when its file is missing or too small on disk, so an interrupted run
is restarted by re-running the same command — there is no checkpoint file to
corrupt and no flag to remember. Re-capturing an unchanged payload rewrites it to
byte-identical content (gzip is stamped with `mtime=0` and an empty filename
field), so a redundant run is a git no-op rather than a churn commit.

`--limit N` caps a run at N games; `--root` (or `$SDV_MLB_RAW_ROOT`) points the
same code at a different capture tree.

## Design notes

[`docs/mlb-raw-layer.md`](docs/mlb-raw-layer.md) covers the capture contract in
full: the validators and why each floor is set where it is, the manifest schema,
the Savant 25,000-row cap and the headroom measurement behind it, and the
reshape contract `baseballr-data` reads.

## Automation & status

No scheduled workflow yet — captures are operator-run from `RUNBOOK.md` while the
backfill is in progress. CI runs the offline test gate on every push and PR:

[![tests](https://github.com/sportsdataverse/baseballr-mlb-raw/actions/workflows/tests.yml/badge.svg)](https://github.com/sportsdataverse/baseballr-mlb-raw/actions/workflows/tests.yml)

| workflow | trigger | what it gates |
|---|---|---|
| `tests.yml` | push to `main`, PR, manual | pytest (offline), ruff, `bash -n` over `scripts/` |

This repo publishes **no release assets**; its output is the committed tree.
