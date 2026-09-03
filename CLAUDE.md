# CLAUDE.md — baseballr-mlb-raw

MLB raw capture. **Scraping-only**: this repo fetches, validates and commits
payloads. Reshaping, modeling and release publishing belong to the sibling
[`baseballr-data`](https://github.com/sportsdataverse/baseballr-data) — do not
reintroduce polars pipelines, model code, or `publish.py` here.

## Layout

```
python/mlb_raw/            capture package (core, schedule, statsapi, savant)
python/mlb_raw_0N_*.py     numbered stage shims -- the entry points
scripts/run_mlb_0N_*.sh    launchers (source scripts/_env.sh, tee to logs/)
mlb/raw/                   the committed capture tree (~465 MB)
tests/                     offline; transports are injected, never live
RUNBOOK.md                 operator guide -- stage order, flags, recovery
docs/mlb-raw-layer.md      capture contract, validators, reshape contract
```

Stage numbering is the **intended build order**, not a run log. 01 (schedule)
writes the manifest that 02 and 03 filter, so it runs first.

## Binding conventions

- **Disk is the authority on what is captured.** `core.outstanding()` is the one
  work-list test and both capture stages route through it: a manifest row is not
  proof of capture, only a present, large-enough file is. A payload deleted from
  disk requeues on the next run. Never add a skip condition that consults the
  manifest alone — that divergence is the bug this function exists to prevent.
- **Writes are atomic.** `core._write_gz` stages to `<name>.part` and only
  `tmp.replace()`s into place once the bytes are complete. This is what makes
  presence-based resume safe; a partial write must never occupy the real path.
- **Gzip is stamped for reproducibility** (`mtime=0`, `filename=""`). An
  unchanged payload re-gzips to identical bytes, so re-running a stage is a git
  no-op instead of a churn commit. Do not drop either argument.
- **Validate before writing, never after.** `core.persist_json` returns `None`
  and writes nothing when its validator rejects the payload — an error body must
  never land on disk where `already_captured` would count it as done. Every size
  floor (`MIN_STATSAPI_BYTES` and friends) is a MEASURED value with the
  measurement in its comment; re-measure before changing one.
- **`--limit 0` means zero, not unlimited** (`core.head`), and negative values
  fail at argument-parse time (`core.nonneg_int`).
- **Capture root is a flag**: `--root` > `$SDV_MLB_RAW_ROOT` > `<repo>/mlb/raw`.
  Keep every path root-relative so the tree stays relocatable.
- **polars 1.x only**, uv for everything, Conventional Commits. Never add AI
  co-author trailers — the human author is the sole attributable contributor.

## Gates

```sh
uv run pytest -q
uv run ruff check python tests
for f in scripts/*.sh; do bash -n "$f"; done
```

CI runs all three (`.github/workflows/tests.yml`) over a **sparse checkout** that
deliberately excludes `mlb/raw/` — no test reads the capture tree. `RUNBOOK.md`
IS in the checkout because `test_stage_numbering` reads it.

## Bot review

A backfill PR carries thousands of payload files and is past both CodeRabbit's
and Sourcery's file caps, so it gets **no bot review** — a green tick on such a
PR means nobody looked. Split code and payloads into separate PRs: put the
reviewable logic in the small one, and say in the bulk one that review was
skipped structurally.
