#!/usr/bin/env bash
# Build flat dist/skills/<name>/ from nested skills/<category>/<name>/.
# Validates SKILL.md frontmatter (name matches dir, description present).
# Idempotent: rm -rf dist/skills before copying. Does not auto-commit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$SCRIPT_DIR/../skills"
DIST_DIR="$SCRIPT_DIR/../dist/skills"

# Validate source directory.
if [[ ! -d "$SKILLS_DIR" ]]; then
  echo "ERROR: skills directory not found at $SKILLS_DIR" >&2
  exit 1
fi

# Clean dist/skills (idempotent).
rm -rf "${DIST_DIR:?}"
mkdir -p "$DIST_DIR"

synced=0
warned=0
failed=0
skipped=0

# Walk skills/*/*/ (two-level nesting).
for category_dir in "$SKILLS_DIR"/*/; do
  [[ -d "$category_dir" ]] || continue
  for skill_dir in "$category_dir"*/; do
    [[ -d "$skill_dir" ]] || continue

    skill_path="${skill_dir%/}"
    skill_name="$(basename "$skill_path")"

    if [[ ! -f "$skill_dir/SKILL.md" ]]; then
      echo "  WARN: no SKILL.md in $skill_path, skipping" >&2
      skipped=$((skipped + 1))
      continue
    fi

    # Validate frontmatter: name and description.
    validation="$(python3 -c '
import sys, re

skill_path = sys.argv[1]
skill_name = sys.argv[2]

with open(skill_path + "/SKILL.md", "r") as f:
    content = f.read()

# Extract YAML frontmatter between --- delimiters.
match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
if not match:
    print("WARN\t" + skill_name + "\tno frontmatter block found")
    sys.exit(0)

fm = match.group(1)

# Extract name field.
name_match = re.search(r"^name:\s*(.+?)\s*$", fm, re.MULTILINE)
if not name_match:
    print("WARN\t" + skill_name + "\tfrontmatter missing name field")
else:
    fm_name = name_match.group(1).strip().strip(chr(34)+chr(39))
    if fm_name != skill_name:
        print("WARN\t" + skill_name + "\tfrontmatter name (" + fm_name + ") != dir name (" + skill_name + ")")

# Extract description field.
if not re.search(r"^description:\s*\S", fm, re.MULTILINE):
    print("WARN\t" + skill_name + "\tfrontmatter missing or empty description")
' "$skill_path" "$skill_name" 2>&1)"

    if [[ -n "$validation" ]]; then
      echo "  $validation" >&2
      warned=$((warned + 1))
    fi

    # Copy to dist/skills/<name>/ (flat), excluding .git.
    target="$DIST_DIR/$skill_name"
    mkdir -p "$target"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --exclude='.git' "$skill_dir" "$target/"
    else
      # Fallback: tar pipe excluding .git (portable, no rsync needed).
      ( cd "$skill_dir" && tar -cf - --exclude='./.git' . ) | ( cd "$target" && tar -xf - )
    fi

    # Remove upstream .claude-plugin if present in the copied skill.
    if [[ -d "$target/.claude-plugin" ]]; then
      rm -rf "${target:?}/.claude-plugin"
    fi

    echo "  built: $skill_name"
    synced=$((synced + 1))
  done
done

echo ""
echo "Build complete: $synced built, $warned warned, $failed failed."
