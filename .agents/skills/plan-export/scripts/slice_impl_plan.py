#!/usr/bin/env python3
"""Validate and slice a marker-delimited implementation plan into per-section files.

Why this exists
---------------
``plan-export`` writes each implementation plan as one big Markdown file. A
future implementation-plan orchestrator would want to dispatch each phase to
its own subagent by file path rather than re-embedding the same bytes in every
prompt — the shared preamble and each phase's verbatim text would otherwise be
copied into context repeatedly, bloating the orchestrator and risking mid-run
compaction.

So the plan is split **once** into files under ``.ai/tmp/impl/<plan>/``, ready
for a future orchestrator to dispatch by file path, with each subagent reading
only the slice it needs. Today this script is used by ``plan-export`` alone,
as a self-check (``--inspect``) that the plan it just wrote is machine-sliceable.

Slicing reliably by Markdown headings is impossible: implementation plans embed
fenced code blocks and exact documentation snippets that legitimately contain
``#``/``##`` headings as *content*, which a naive ``grep '^## '`` would mistake
for a phase boundary. So the producer (the ``plan-export`` skill) wraps every
section in explicit, namespaced HTML-comment markers, and this script is the
single source of truth that both validates and cuts them.

Marker contract
---------------
Each section is wrapped in a *paired* begin/end marker, anchored at column 0::

    <!-- impl-plan:begin slug="preamble" -->
    # Implementation Plan for Issue #4821
    ...
    ## Applicable Guidelines
    ...
    <!-- impl-plan:end slug="preamble" -->

    <!-- impl-plan:begin slug="phase-1" title="Add PRO API key configuration" -->
    ## Phase 1: ...
    <!-- impl-plan:end slug="phase-1" -->

    <!-- impl-plan:begin slug="final-checklist" -->
    ## Final Checklist
    ...
    <!-- impl-plan:end slug="final-checklist" -->

Rules enforced (any violation fails loudly rather than slicing silently wrong):

* begin/end markers are balanced, never nested, and the end slug matches the
  open begin slug;
* slugs are unique;
* regions appear as exactly ``preamble`` first, then ``phase-1 .. phase-N`` in
  ascending contiguous order, then ``final-checklist`` last;
* every non-blank line that is not a ``---`` rule lives inside some region —
  no content may sit in the gaps (this is what catches a section the producer
  forgot to wrap);
* a light content-sanity layer confirms each ``phase-N``/``final-checklist``
  region actually wraps the heading its slug claims (``final-checklist`` opens
  with ``## Final Checklist``; each ``phase-N`` opens with its ``## Phase N``
  heading) — this catches a marker placed in the wrong spot. ``preamble`` has
  no fixed heading to anchor on in this repo's plan template (there is no
  mandatory "Definition of Done" section here), so it only gets the structural
  checks above.

Usage
-----
Validate only (no files written) — used by ``plan-export`` as a self-check at
the end of plan generation::

    python3 .claude/skills/plan-export/scripts/slice_impl_plan.py PLAN.md --inspect

Validate and write slices — for a future orchestrator to use before dispatching::

    python3 .claude/skills/plan-export/scripts/slice_impl_plan.py PLAN.md [--out-dir DIR]

Exit codes (a caller branches on these)::

    0  plan is valid; slices written (or, with --inspect, would slice cleanly)
    1  markers are present but malformed — caller should escalate, not guess
    2  no markers found at all — a legacy plan; caller may fall back to its own
       heading-based slicing
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

BEGIN_RE = re.compile(
    r'^<!--\s*impl-plan:begin\s+slug="(?P<slug>[a-z0-9-]+)"(?:\s+title="(?P<title>[^"]*)")?\s*-->\s*$'
)
END_RE = re.compile(r'^<!--\s*impl-plan:end\s+slug="(?P<slug>[a-z0-9-]+)"\s*-->\s*$')
# A line allowed in the gaps between regions: blank, or a horizontal rule.
GAP_RE = re.compile(r"^\s*(?:-{3,}\s*)?$")

EXIT_OK = 0
EXIT_INVALID = 1  # markers present but malformed -> caller should escalate
EXIT_NO_MARKERS = 2  # no markers at all -> caller may fall back


@dataclass
class Region:
    """One marker-delimited section of the plan."""

    slug: str
    title: str | None
    begin_line: int  # 1-based line number of the begin marker
    end_line: int  # 1-based line number of the end marker
    body: list[str]  # content lines strictly between the markers (markers excluded)

    @property
    def content_span(self) -> str:
        first, last = self.begin_line + 1, self.end_line - 1
        return f"{first}-{last}" if last >= first else "empty"


def has_markers(lines: list[str]) -> bool:
    """True if the file contains any impl-plan marker at all."""
    return any(BEGIN_RE.match(line) or END_RE.match(line) for line in lines)


def parse_regions(lines: list[str]) -> tuple[list[Region], list[str]]:
    """Scan lines into ordered regions. Returns (regions, structural_errors).

    Structural errors (unbalanced/nested/mismatched markers) are returned rather
    than raised so the CLI can report all of them at once. When this list is
    non-empty the regions are unreliable and downstream checks are skipped.
    """
    regions: list[Region] = []
    errors: list[str] = []
    open_slug: str | None = None
    open_title: str | None = None
    open_line = 0
    body_start = 0  # 0-based index of the first body line of the open region

    for idx, line in enumerate(lines):
        lineno = idx + 1
        begin = BEGIN_RE.match(line)
        end = END_RE.match(line)
        if begin:
            if open_slug is not None:
                errors.append(
                    f'line {lineno}: begin slug="{begin["slug"]}" while region slug="{open_slug}" '
                    f"(opened at line {open_line}) is still open — nested markers are not allowed"
                )
            open_slug = begin["slug"]
            open_title = begin.group("title")
            open_line = lineno
            body_start = idx + 1
        elif end:
            if open_slug is None:
                errors.append(f'line {lineno}: end slug="{end["slug"]}" with no open region')
                continue
            if end["slug"] != open_slug:
                errors.append(
                    f'line {lineno}: end slug="{end["slug"]}" does not match open region '
                    f'slug="{open_slug}" (opened at line {open_line})'
                )
            regions.append(
                Region(
                    slug=open_slug,
                    title=open_title,
                    begin_line=open_line,
                    end_line=lineno,
                    body=lines[body_start:idx],
                )
            )
            open_slug = None

    if open_slug is not None:
        errors.append(f'line {open_line}: begin slug="{open_slug}" is never closed')

    return regions, errors


def check_schema(regions: list[Region]) -> list[str]:
    """Verify slug set and ordering: preamble, phase-1..N contiguous, final-checklist."""
    errors: list[str] = []
    slugs = [r.slug for r in regions]

    seen: set[str] = set()
    for slug in slugs:
        if slug in seen:
            errors.append(f'slug "{slug}" appears more than once')
        seen.add(slug)

    if not regions:
        errors.append("no regions found")
        return errors
    if slugs[0] != "preamble":
        errors.append(f'first region must be slug="preamble", found slug="{slugs[0]}"')
    if slugs[-1] != "final-checklist":
        errors.append(f'last region must be slug="final-checklist", found slug="{slugs[-1]}"')

    middle = slugs[1:-1] if len(slugs) >= 2 else []
    if not middle:
        errors.append('no phases found (expected at least slug="phase-1")')
    for position, slug in enumerate(middle, start=1):
        expected = f"phase-{position}"
        if slug != expected:
            errors.append(f'expected slug="{expected}" in phase sequence, found slug="{slug}"')
            break

    return errors


def check_coverage(lines: list[str], regions: list[Region]) -> list[str]:
    """Every non-blank, non-rule line must live inside a region — no orphan content."""
    covered = [False] * len(lines)
    for region in regions:
        for i in range(region.begin_line - 1, region.end_line):  # markers inclusive
            covered[i] = True

    errors: list[str] = []
    for idx, line in enumerate(lines):
        if covered[idx] or GAP_RE.match(line):
            continue
        errors.append(f"line {idx + 1}: content outside any marked region: {line.strip()!r}")
    return errors


def _first_nonblank(body: list[str]) -> str | None:
    for line in body:
        if line.strip():
            return line
    return None


def check_content(regions: list[Region]) -> list[str]:
    """Light sanity layer: each phase/final-checklist region opens with its claimed heading.

    ``preamble`` has no fixed heading to anchor on in this repo's plan
    template (there is no mandatory "Definition of Done" section), so it is
    covered only by the structural checks in check_schema/check_coverage.
    """
    errors: list[str] = []
    for region in regions:
        if region.slug == "final-checklist":
            head = _first_nonblank(region.body) or ""
            if not re.match(r"^##\s+Final Checklist\b", head):
                errors.append('region slug="final-checklist" does not open with a "## Final Checklist" heading')
        elif region.slug.startswith("phase-"):
            number = region.slug.split("-", 1)[1]
            head = _first_nonblank(region.body) or ""
            if not re.match(rf"^##\s+Phase\s+{re.escape(number)}\b", head):
                errors.append(f'region slug="{region.slug}" does not open with a "## Phase {number}" heading')
    return errors


def validate_text(text: str) -> tuple[list[Region], list[str], bool]:
    """Validate plan text. Returns (regions, errors, markers_present).

    When ``markers_present`` is False the plan is a legacy/unmarked one and the
    caller should treat it as not machine-sliceable. When ``errors`` is
    non-empty the markers are malformed.
    """
    lines = text.splitlines()
    if not has_markers(lines):
        return [], [], False

    regions, errors = parse_regions(lines)
    if errors:
        return regions, errors, True  # structure broken; skip cascading checks

    errors += check_schema(regions)
    errors += check_coverage(lines, regions)
    errors += check_content(regions)
    return regions, errors, True


def find_project_root(start: Path) -> Path:
    """Nearest ancestor containing pyproject.toml or .git, else the cwd."""
    for directory in (start, *start.parents):
        if (directory / "pyproject.toml").is_file() or (directory / ".git").exists():
            return directory
    return Path.cwd()


def default_out_dir(plan_path: Path) -> Path:
    root = find_project_root(plan_path.resolve().parent)
    return root / ".ai" / "tmp" / "impl" / plan_path.stem


def write_slices(regions: list[Region], out_dir: Path) -> list[Path]:
    """Write each region body to ``<out_dir>/<slug>.md`` (markers stripped)."""
    out_dir.mkdir(parents=True, exist_ok=True)
    for stale in out_dir.glob("*.md"):  # avoid leftovers from an earlier, longer plan
        stale.unlink()
    written: list[Path] = []
    for region in regions:
        target = out_dir / f"{region.slug}.md"
        body = "\n".join(region.body).strip("\n")
        target.write_text(body + "\n", encoding="utf-8")
        written.append(target)
    return written


def print_manifest(plan_path: Path, regions: list[Region], out_dir: Path, *, inspect: bool) -> None:
    note = "  (inspect only — nothing written)" if inspect else ""
    print(f"plan:    {plan_path}")
    print(f"out-dir: {out_dir}{note}")
    print(f"regions: {len(regions)}")
    for region in regions:
        title = region.title or "-"
        print(f"  {region.slug:<16} lines {region.content_span:<10} file={out_dir / f'{region.slug}.md'}")
        print(f"  {'':<16}                  title={title}")
    verb = "would slice cleanly into" if inspect else "sliced into"
    print(f"RESULT: OK — {plan_path.name} {verb} {len(regions)} regions")


def parse_args(argv: list[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="slice_impl_plan.py",
        description="Validate and slice a marker-delimited implementation plan.",
    )
    parser.add_argument("plan", type=Path, help="path to the implementation-plan Markdown file")
    parser.add_argument(
        "--inspect",
        action="store_true",
        help="validate only and report; do not write any files (used by plan-export as a self-check)",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=None,
        help="directory to write slices into (default: <project-root>/.ai/tmp/impl/<plan-stem>/)",
    )
    return parser.parse_args(argv)


def run_cli(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    plan_path: Path = args.plan

    if not plan_path.is_file():
        print(f"error: plan file not found: {plan_path}", file=sys.stderr)
        return EXIT_INVALID

    regions, errors, markers = validate_text(plan_path.read_text(encoding="utf-8"))

    if not markers:
        print(
            f"no impl-plan markers found in {plan_path} — plan is not machine-sliceable",
            file=sys.stderr,
        )
        return EXIT_NO_MARKERS

    if errors:
        print(f"INVALID: {plan_path} has {len(errors)} marker problem(s):", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return EXIT_INVALID

    out_dir = args.out_dir or default_out_dir(plan_path)
    print_manifest(plan_path, regions, out_dir, inspect=args.inspect)
    if not args.inspect:
        write_slices(regions, out_dir)
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(run_cli())
