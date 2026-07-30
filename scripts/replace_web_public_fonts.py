"""Replace GoogleFonts.inter/interTight runtime fetches with CSS-backed V2FontStyles."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "lib" / "features" / "web_public"

REPLACEMENTS = [
    ("GoogleFonts.interTight(", "V2FontStyles.inter("),
    ("GoogleFonts.inter(", "V2FontStyles.inter("),
    ("GoogleFonts.jetBrainsMono(", "V2FontStyles.inter("),
    ("GoogleFonts.manrope(", "V2FontStyles.display("),
    ("GoogleFonts.poppins(", "V2FontStyles.display("),
    ("GoogleFonts.merriweather(", "V2FontStyles.accentItalic("),
    ("GoogleFonts.nunito(", "V2FontStyles.display("),
    ("GoogleFonts.robotoMono(", "V2FontStyles.inter("),
]

IMPORT_OLD = "import 'package:google_fonts/google_fonts.dart';"
IMPORT_NEW = "import '../v2_font_styles.dart';"

# depth-based relative import for pages/static etc.
def import_for(path: Path) -> str:
    rel = path.relative_to(ROOT)
    depth = len(rel.parts) - 1
    prefix = "../" * depth
    return f"import '{prefix}v2/v2_font_styles.dart';"


def process_file(path: Path) -> bool:
    text = path.read_text(encoding="utf-8")
    if "GoogleFonts." not in text:
        return False
    original = text
    for old, new in REPLACEMENTS:
        text = text.replace(old, new)
    if "google_fonts" in text:
        if IMPORT_OLD in text:
            text = text.replace(IMPORT_OLD, import_for(path))
        else:
            # insert import after first import block
            lines = text.splitlines()
            insert_at = 0
            for i, line in enumerate(lines):
                if line.startswith("import "):
                    insert_at = i + 1
            lines.insert(insert_at, import_for(path))
            text = "\n".join(lines)
    if text != original:
        path.write_text(text, encoding="utf-8")
        return True
    return False


def main() -> None:
    changed = 0
    for dart in ROOT.rglob("*.dart"):
        if dart.name == "v2_text.dart":
            continue
        if process_file(dart):
            changed += 1
            print(dart.relative_to(ROOT))
    print(f"Updated {changed} files")


if __name__ == "__main__":
    main()
