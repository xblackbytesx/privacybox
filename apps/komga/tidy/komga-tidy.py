#!/usr/bin/env python3
"""
Normalise a manga library's folder and file names for Komga.

Komga has no renamer of its own, so this is the Sonarr-style tidy pass it is
missing. It reads a library root, works out what each folder and file is meant
to be, and renames them to one consistent scheme. Everything it strips out on
the way (release group, year, scan tags) is written to a sidecar in the series
folder, so the information is parked rather than lost.

Nothing is deleted, ever. The only filesystem operation is rename, and every
rename is written to a manifest before it happens so the whole run can be
reversed with --undo.

Safety, in the order it matters:

  1. Dry run is the default. --apply is required to touch anything.
  2. Take a snapshot first. On ZFS that is instant and free, and it is a better
     safety net than anything this script can offer.
  3. Check Komga's file hashing is on and a scan has completed BEFORE running
     this. Komga re-matches renamed files by hash, and that is what preserves
     read progress, metadata and read lists. Without a hash on record, a rename
     looks like a delete plus an add and the read progress is gone.
  4. Collisions abort the whole run rather than the offending file, because a
     half-renamed library is worse than an untouched one.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from pathlib import Path

SIDECAR_NAME = ".komga-tidy.json"
MANIFEST_PREFIX = "komga-tidy-manifest"

# Komga reads these. Anything else in a series folder is left strictly alone,
# including the .nfo files that ship with most scene releases.
BOOK_EXTENSIONS = {".cbz", ".cbr", ".cb7", ".zip", ".rar", ".7z", ".pdf", ".epub"}

# Bracketed groups, in any of the three flavours releases use.
GROUP_RE = re.compile(r"[\(\[\{]([^\)\]\}]*)[\)\]\}]")
YEAR_RE = re.compile(r"^(?:19|20)\d{2}$")
YEAR_RANGE_RE = re.compile(r"^(?:19|20)\d{2}\s*-\s*(?:19|20)\d{2}$")

# Volume markers, longest first so "volume" is not eaten by "vol".
VOLUME_RE = re.compile(
    r"(?:^|[\s._-])(?:volume|vol\.?|v)\s*(\d{1,4})(?:\s*-\s*\d{1,4})?\s*$",
    re.IGNORECASE,
)
# Explicit chapter markers.
CHAPTER_RE = re.compile(
    r"(?:^|[\s._-])(?:chapter|chap\.?|ch\.?|c|#)\s*(\d{1,5}(?:\.\d+)?)\s*$",
    re.IGNORECASE,
)
# A bare trailing number, which in this corpus means a loose chapter.
BARE_NUMBER_RE = re.compile(r"^(.*?)[\s._-]+(\d{1,5}(?:\.\d+)?)\s*$")

# Descriptors that are format or quality tags rather than a release group.
TAG_WORDS = {
    "digital", "digital tpb", "tpb", "web", "webrip", "scan", "c2c", "f", "fixed",
    "hd", "hq", "lq", "raw", "official", "omnibus", "colored", "colour", "color",
    "danke", "empire", "manga", "oneshot", "one-shot", "artbook", "databook",
}


def normalise_spacing(text: str) -> str:
    """Collapse separators into single spaces and trim the result."""
    text = re.sub(r"[\s_]+", " ", text)
    text = re.sub(r"\s*-\s*$", "", text)
    return text.strip(" -.")


def dots_to_spaces(name: str) -> str:
    """
    Turn Death.Note.(v01-v12) into Death Note (v01-v12).

    Only when the name has no spaces at all. Applying it unconditionally would
    wreck the many real titles that contain a full stop, Dr. Stone being the one
    everybody hits first.
    """
    if " " in name:
        return name
    return name.replace(".", " ")


@dataclass
class Descriptors:
    """What was in brackets, sorted into the things it can be."""

    year: int | None = None
    year_range: str | None = None
    group: str | None = None
    tags: list[str] = field(default_factory=list)
    volume_range: str | None = None


def split_descriptors(name: str) -> tuple[str, Descriptors]:
    """Pull every bracketed group out of a name and classify each one."""
    found = GROUP_RE.findall(name)
    stripped = normalise_spacing(GROUP_RE.sub(" ", name))

    d = Descriptors()
    leftovers: list[str] = []
    for raw in found:
        item = raw.strip()
        if not item:
            continue
        if YEAR_RE.match(item):
            # Keep the earliest year seen. Volume 1 of a long series is the one
            # that dates it, not whichever file happened to be read last.
            year = int(item)
            d.year = year if d.year is None else min(d.year, year)
        elif YEAR_RANGE_RE.match(item):
            d.year_range = item
        elif re.match(r"^v\d{1,4}\s*-\s*v?\d{1,4}$", item, re.IGNORECASE):
            d.volume_range = item
        else:
            leftovers.append(item)

    # In this naming scheme the release group is conventionally last, and the
    # descriptors before it are format tags. Matching on a word list alone would
    # misfile any group whose name happens to be a normal word.
    for index, item in enumerate(leftovers):
        is_last = index == len(leftovers) - 1
        if is_last and item.lower() not in TAG_WORDS:
            d.group = item
        else:
            d.tags.append(item)

    return stripped, d


@dataclass
class ParsedBook:
    path: Path
    original: str
    series_guess: str
    kind: str  # "volume", "chapter" or "single"
    number: float | None
    descriptors: Descriptors
    target: str = ""

    @property
    def extension(self) -> str:
        return self.path.suffix.lower()


def parse_book(path: Path, series: str) -> ParsedBook:
    """Work out what one book file is, from its name."""
    stem = dots_to_spaces(path.stem)
    stripped, descriptors = split_descriptors(stem)

    kind = "single"
    number: float | None = None
    remainder = stripped

    match = VOLUME_RE.search(stripped)
    if match:
        kind = "volume"
        number = float(match.group(1))
        remainder = stripped[: match.start()]
    else:
        match = CHAPTER_RE.search(stripped)
        if match:
            kind = "chapter"
            number = float(match.group(1))
            remainder = stripped[: match.start()]
        else:
            bare = BARE_NUMBER_RE.match(stripped)
            # A trailing number is a chapter only if what precedes it still looks
            # like the series. Without that check, Mobile Suit Gundam 0079 gets
            # filed as chapter 79 of a series called Mobile Suit Gundam.
            #
            # "Contains" rather than "equals", because a nested folder gives a
            # short series name while the files keep the long one: the folder
            # "Cyberpunk 2077/Psycho Squad" holds files called "Cyberpunk 2077 -
            # Psycho Squad 01". Under equality none of them parsed a number, so
            # all four wanted the same target name and the collision guard aborted
            # the whole library over one folder.
            prefix = normalise_spacing(bare.group(1)).lower() if bare else ""
            if bare and series.lower() in prefix:
                kind = "chapter"
                number = float(bare.group(2))
                remainder = bare.group(1)

    return ParsedBook(
        path=path,
        original=path.name,
        series_guess=normalise_spacing(remainder) or series,
        kind=kind,
        number=number,
        descriptors=descriptors,
    )


def format_number(value: float, width: int) -> str:
    """Zero-pad, keeping a decimal chapter like 135.5 intact."""
    if value == int(value):
        return f"{int(value):0{width}d}"
    whole = int(value)
    fraction = f"{value - whole:.4f}".rstrip("0").split(".")[1]
    return f"{whole:0{width}d}.{fraction}"


def pad_width(numbers: list[float], minimum: int) -> int:
    """
    Width that keeps the whole series sorting correctly by filename.

    Computed per series from its own largest number rather than fixed, because a
    two-digit pad silently breaks the moment a series reaches chapter 100 and the
    reader starts finding chapter 100 filed before chapter 11.
    """
    if not numbers:
        return minimum
    return max(minimum, len(str(int(max(numbers)))))


@dataclass
class SeriesPlan:
    source_dir: Path
    series: str
    target_dir: Path
    descriptors: Descriptors
    books: list[ParsedBook]
    others: list[Path]

    @property
    def renames(self) -> list[tuple[Path, Path]]:
        moves = []
        for book in self.books:
            if book.target and book.target != book.original:
                moves.append((self.source_dir / book.original, self.source_dir / book.target))
        return moves


def plan_series(directory: Path) -> SeriesPlan | None:
    """Build the rename plan for one series folder."""
    series_raw = dots_to_spaces(directory.name)
    series, descriptors = split_descriptors(series_raw)
    series = normalise_spacing(series)
    if not series:
        return None

    books: list[ParsedBook] = []
    others: list[Path] = []
    for entry in sorted(directory.iterdir()):
        if entry.is_dir() or entry.name == SIDECAR_NAME:
            continue
        if entry.suffix.lower() in BOOK_EXTENSIONS:
            books.append(parse_book(entry, series))
        else:
            others.append(entry)

    if not books:
        return None

    volume_width = pad_width([b.number for b in books if b.kind == "volume" and b.number], 2)
    chapter_width = pad_width([b.number for b in books if b.kind == "chapter" and b.number], 3)

    for book in books:
        if book.kind == "volume" and book.number is not None:
            token = f" v{format_number(book.number, volume_width)}"
        elif book.kind == "chapter" and book.number is not None:
            token = f" c{format_number(book.number, chapter_width)}"
        else:
            token = ""
        book.target = f"{series}{token}{book.extension}"

    return SeriesPlan(
        source_dir=directory,
        series=series,
        target_dir=directory.parent / series,
        descriptors=descriptors,
        books=books,
        others=others,
    )


def find_collisions(plan: SeriesPlan) -> list[str]:
    """Two different files wanting one name is a bug in the parse, not a rename."""
    seen: dict[str, str] = {}
    clashes = []
    for book in plan.books:
        if book.target in seen:
            clashes.append(f"{plan.series}: {seen[book.target]} and {book.original} -> {book.target}")
        else:
            seen[book.target] = book.original
    return clashes


def sidecar_payload(plan: SeriesPlan) -> dict:
    return {
        "version": 1,
        "generated": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "series": plan.series,
        "original_folder": plan.source_dir.name,
        "folder_descriptors": asdict(plan.descriptors),
        "books": [
            {
                "original": b.original,
                "renamed": b.target,
                "kind": b.kind,
                "number": b.number,
                "year": b.descriptors.year,
                "group": b.descriptors.group,
                "tags": b.descriptors.tags,
            }
            for b in plan.books
        ],
        "untouched": [p.name for p in plan.others],
    }


def flattened_name(root: Path, directory: Path) -> str:
    """
    What a nested series would be called if its folders were collapsed into one.

    Joins each level's cleaned name with " - ", skipping any level whose name a
    deeper one already contains, so "Cyberpunk 2077/Cyberpunk 2077 - Psycho Squad"
    does not come out doubled.
    """
    parts: list[str] = []
    for raw in directory.relative_to(root).parts:
        name = normalise_spacing(split_descriptors(dots_to_spaces(raw))[0])
        if name and name not in parts:
            parts.append(name)
    kept = [
        part for index, part in enumerate(parts)
        if not any(part.lower() in deeper.lower() for deeper in parts[index + 1:])
    ]
    return " - ".join(kept)


def scan(root: Path) -> list[SeriesPlan]:
    """
    Every folder holding book files is a series, at any depth.

    This mirrors Komga's own rule rather than inventing one: Komga walks the whole
    tree and turns each folder that directly contains books into a series, while a
    folder holding only other folders becomes nothing at all.

    Scanning only the top level, which is what this did first, meant a library
    with any nesting was silently half-processed. It reported no series folders
    found and exited zero, which reads exactly like a library that is already tidy.
    """
    plans = []
    for directory in sorted(d for d in root.rglob("*") if d.is_dir()):
        p = plan_series(directory)
        if p:
            plans.append(p)
    return plans


def loose_books(root: Path) -> list[Path]:
    """Book files sitting directly in the library root, belonging to no series."""
    return sorted(
        p for p in root.iterdir()
        if p.is_file() and p.suffix.lower() in BOOK_EXTENSIONS
    )


def report(plans: list[SeriesPlan], root: Path, verbose: bool) -> None:
    loose = loose_books(root)
    if loose:
        print(f"\n  {len(loose)} book file(s) sit directly in the library root.")
        print("    Komga makes each of those its own one-shot series. Move them")
        print("    into a folder named after the series to group them.")

    total_renames = 0
    for plan in plans:
        folder_change = plan.target_dir.name != plan.source_dir.name
        renames = plan.renames
        total_renames += len(renames) + (1 if folder_change else 0)

        if not folder_change and not renames:
            if verbose:
                print(f"  ok      {plan.series}")
            continue

        print(f"\n  {plan.series}")
        if folder_change:
            print(f"    folder  {plan.source_dir.name}")
            print(f"         -> {plan.target_dir.name}")
        for source, target in renames:
            print(f"    file    {source.name}")
            print(f"         -> {target.name}")

        if plan.source_dir.parent != root:
            # Komga's library view is flat. A nested folder still becomes a
            # series, but it is listed under its own short name with nothing
            # connecting it to the folder above, so the extra level costs a
            # recognisable name and buys no grouping at all.
            under = plan.source_dir.parent.relative_to(root)
            print(f"    note    nested under '{under}'. Komga's library list is flat,")
            print(f"            so this appears as '{plan.series}' with no visible link")
            print("            to the parent. Flattening is usually better:")
            print(f"              {flattened_name(root, plan.source_dir)}")

        kinds = {b.kind for b in plan.books}
        if "volume" in kinds and "chapter" in kinds:
            # Worth saying out loud: Komga sorts a series by filename, so c135
            # lands before v01. Usually these loose chapters are also collected
            # in the last volume, which makes them duplicates rather than extras.
            print("    note    mixes volumes and loose chapters, so they will")
            print("            sort chapters first. If the chapters are already")
            print("            inside the volumes they are duplicates: delete them.")
            print(f"            If not, move them to '{plan.series} - Chapters' and")
            print("            bind the two with a Komga collection. Set the series")
            print("            title in Komga and lock it, or ComicInfo will")
            print("            overwrite it back to the original name on rescan.")
        cbr = [b for b in plan.books if b.extension in {".cbr", ".rar"}]
        if cbr:
            print(f"    note    {len(cbr)} rar-based file(s). Komga reads these but not")
            print("            RAR5 or solid archives. Converting to cbz is safer.")

    print(f"\n{total_renames} rename(s) across {len(plans)} series.")


def write_manifest(root: Path, plans: list[SeriesPlan], destination: Path) -> dict:
    manifest = {
        "version": 1,
        "generated": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "root": str(root),
        "moves": [],
    }
    for plan in plans:
        for source, target in plan.renames:
            manifest["moves"].append({"from": str(source), "to": str(target)})
        if plan.target_dir.name != plan.source_dir.name:
            manifest["moves"].append(
                {"from": str(plan.source_dir), "to": str(plan.target_dir), "dir": True}
            )
    destination.write_text(json.dumps(manifest, indent=2))
    return manifest


def apply_plans(plans: list[SeriesPlan], manifest_path: Path, root: Path) -> None:
    # The manifest is written first, in full, so an interrupted run is still
    # reversible. Writing it afterwards would mean a crash halfway leaves renames
    # on disk that nothing has a record of.
    write_manifest(root, plans, manifest_path)
    print(f"manifest: {manifest_path}")

    for plan in plans:
        for source, target in plan.renames:
            source.rename(target)
        # The sidecar is written into the folder before the folder itself moves,
        # so the path is still valid at the moment of writing.
        (plan.source_dir / SIDECAR_NAME).write_text(
            json.dumps(sidecar_payload(plan), indent=2)
        )
        if plan.target_dir.name != plan.source_dir.name:
            if plan.target_dir.exists():
                print(f"  skip    {plan.target_dir.name} already exists, folder left alone")
                continue
            plan.source_dir.rename(plan.target_dir)


def undo(manifest_path: Path) -> None:
    manifest = json.loads(manifest_path.read_text())
    moves = manifest["moves"]
    # Reversed, because directories were renamed after the files inside them and
    # undoing in the same order would look for files under a path that no longer
    # exists.
    restored = 0
    for move in reversed(moves):
        target = Path(move["to"])
        source = Path(move["from"])
        if not target.exists():
            print(f"  missing {target}")
            continue
        if source.exists():
            print(f"  occupied {source}")
            continue
        target.rename(source)
        restored += 1
    print(f"reversed {restored} of {len(moves)} move(s).")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Normalise manga folder and file names for Komga.",
        epilog="Dry run by default. Snapshot the dataset before using --apply.",
    )
    parser.add_argument("root", nargs="?", default="/data/manga", type=Path)
    parser.add_argument("--apply", action="store_true", help="actually rename")
    parser.add_argument("--undo", metavar="MANIFEST", type=Path, help="reverse a previous run")
    parser.add_argument("--verbose", action="store_true", help="also list series already correct")
    args = parser.parse_args()

    if args.undo:
        undo(args.undo)
        return 0

    if not args.root.is_dir():
        print(f"not a directory: {args.root}", file=sys.stderr)
        return 2

    plans = scan(args.root)
    if not plans:
        print(f"no series folders with book files under {args.root}")
        return 0

    clashes = [c for plan in plans for c in find_collisions(plan)]
    if clashes:
        # Abort everything. A half-renamed library is worse than an untouched one,
        # and a collision means the parse is wrong rather than the file.
        print("name collisions, nothing was changed:", file=sys.stderr)
        for clash in clashes:
            print(f"  {clash}", file=sys.stderr)
        return 1

    report(plans, args.root, args.verbose)

    if not args.apply:
        print("\nDry run. Nothing was changed. Re-run with --apply to rename.")
        print("Before you do:")
        print("  1. Snapshot the dataset. On ZFS this is instant.")
        print("  2. Confirm Komga file hashing is on and a scan has finished, or")
        print("     renaming will cost you read progress on every book.")
        return 0

    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    manifest_path = args.root / f"{MANIFEST_PREFIX}-{stamp}.json"
    apply_plans(plans, manifest_path, args.root)
    print("\nDone. Rescan the library in Komga.")
    print(f"To reverse: --undo {manifest_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
