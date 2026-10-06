#!/usr/bin/env python3
"""
Fact gatherer for the leaf-schemas catalog.

For every `*.ex` file under
`apps/block_scout_web/lib/block_scout_web/schemas/api/v2/general/`, emits:
  - the canonical module name (`defmodule …` line)
  - the short name (`Foo` from `BlockScoutWeb.Schemas.API.V2.General.Foo`)
  - the file path (repo-relative)
  - the full source text
  - up to N callsites elsewhere under `schemas/api/v2/**` (file + line)

The cataloger agent consumes this JSON and uses the callsites only as
*input* to interpretation — they should not appear in the final catalog,
so callsite churn does not invalidate the cache.

The script is deliberately dumb: no semantic interpretation, no AST
parsing, no filtering by relevance. It enumerates and hands material off.
"""

from __future__ import annotations

import json
import pathlib
import re
import subprocess
import sys

# Resolve repo root via git — robust to the script being moved within the
# repo, unlike counting `.parents[N]` levels from __file__.
SCRIPT_PATH = pathlib.Path(__file__).resolve()
REPO_ROOT = pathlib.Path(
    subprocess.check_output(
        ["git", "-C", str(SCRIPT_PATH.parent), "rev-parse", "--show-toplevel"],
        text=True,
    ).strip()
)

SCHEMAS_DIR = (
    REPO_ROOT
    / "apps/block_scout_web/lib/block_scout_web/schemas/api/v2/general"
)
# Leaves are referenced from both schema modules and controllers (the
# latter for inline `%Parameter{schema: General.Foo}` definitions). Scope
# to the block_scout_web lib tree — broad enough to catch all callsites,
# narrow enough to keep grep fast and avoid test/fixture noise.
CALLSITE_SEARCH_ROOT = (
    REPO_ROOT / "apps/block_scout_web/lib/block_scout_web"
)

# Cap callsites per leaf. Too many = noisy; too few = thin context. Three
# distinct files is enough to disambiguate purpose for any reasonable leaf.
MAX_CALLSITES = 3

DEFMODULE_RE = re.compile(r"^\s*defmodule\s+([\w.]+)\s+do\s*$", re.MULTILINE)


def main() -> int:
    if not SCHEMAS_DIR.is_dir():
        print(
            f"ERROR: schemas dir not found: {SCHEMAS_DIR}",
            file=sys.stderr,
        )
        return 2

    leafs = []
    for path in sorted(SCHEMAS_DIR.glob("*.ex")):
        leafs.append(_collect_leaf(path))

    json.dump(
        {"leafs": leafs},
        sys.stdout,
        indent=2,
        ensure_ascii=False,
    )
    sys.stdout.write("\n")
    return 0


def _collect_leaf(path: pathlib.Path) -> dict:
    source = path.read_text()
    match = DEFMODULE_RE.search(source)
    full_module = match.group(1) if match else None
    short_name = (
        full_module.rsplit(".", 1)[-1] if full_module else path.stem
    )
    return {
        "module": full_module,
        "short_name": short_name,
        "path": str(path.relative_to(REPO_ROOT)),
        "source": source,
        "callsites": _find_callsites(short_name, exclude_path=path),
    }


def _find_callsites(
    short_name: str,
    exclude_path: pathlib.Path,
) -> list[dict]:
    """Find up to MAX_CALLSITES references to a leaf outside its own file.

    Matches either `General.<ShortName>` (qualified) or bare `<ShortName>`
    (used in files that do `alias …General.{X, Y}` and reference X without
    the prefix). Bare-name false positives on these PascalCase identifiers
    are rare; the cataloger agent reads each callsite's line context
    anyway and can sanity-check.

    Uses `\\b` to avoid prefix-matching (e.g. `AddressHash` matching
    `AddressHashNullable`). One result per distinct file to spread coverage
    rather than collapsing on a single popular caller.
    """
    pattern = rf"\b(?:General\.)?{re.escape(short_name)}\b"
    try:
        proc = subprocess.run(
            [
                "grep",
                "-rEn",
                "--include=*.ex",
                pattern,
                str(CALLSITE_SEARCH_ROOT),
            ],
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return []

    if proc.returncode not in (0, 1):
        # 1 = no matches; anything else is a real error
        print(
            f"WARN: grep failed for {short_name}: {proc.stderr.strip()}",
            file=sys.stderr,
        )
        return []

    callsites: list[dict] = []
    seen_files: set[str] = set()
    exclude_str = str(exclude_path)
    for line in proc.stdout.splitlines():
        # Format: "<path>:<lineno>:<content>"
        parts = line.split(":", 2)
        if len(parts) < 3:
            continue
        filepath, lineno_str, content = parts
        if filepath == exclude_str:
            continue
        if _is_alias_line(content, short_name):
            # Alias declarations point Haiku at the import, not the real
            # usage — skip and let a later line in the same file win.
            continue
        if filepath in seen_files:
            continue
        seen_files.add(filepath)
        try:
            lineno = int(lineno_str)
        except ValueError:
            continue
        try:
            rel = pathlib.Path(filepath).resolve().relative_to(REPO_ROOT)
        except ValueError:
            rel = pathlib.Path(filepath)
        callsites.append({"file": str(rel), "line": lineno})
        if len(callsites) >= MAX_CALLSITES:
            break
    return callsites


_ALIAS_LINE_RE = re.compile(r"^\s*alias\b")


def _is_alias_line(content: str, short_name: str) -> bool:
    """Heuristic: is this line an `alias` declaration rather than real use?

    Catches both single-line aliases (`alias Foo.NullString`) and entries
    inside multi-line alias blocks (`  NullString,` or `  NullString`).
    """
    stripped = content.strip()
    if _ALIAS_LINE_RE.match(content):
        return True
    # Multi-line `alias Foo.{Bar, Baz}` entries appear as bare-name tokens,
    # optionally with a trailing comma.
    if stripped.rstrip(",") == short_name:
        return True
    return False


if __name__ == "__main__":
    sys.exit(main())
