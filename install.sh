#!/bin/sh
# Cyrus dotfiles: install shared agent skills for Claude Code and Codex.
#
# Cyrus clones this repo and runs this script on every container boot
# (ContainerBootCommand.applyDotfiles, step 6, before `cyrus start`).
# Failures are logged and swallowed, so keep this quiet and idempotent.
#
# Agent CLIs are not guaranteed to be on PATH in the worker image, so plain
# directory copies are the supported installation route (NOR-365).
set -eu

# Pinned to the commit the claude-plugins-official marketplace ships as
# mattpocock-skills. Bump this line to take a newer set.
SKILLS_SHA=0ab1b63a410a03d3627979a109c8695de27af954

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
claude_skills_dir="$HOME/.claude/skills"
codex_skills_dir="$HOME/.codex/skills"

git clone -q https://github.com/mattpocock/skills.git "$tmp"
git -C "$tmp" checkout -q "$SKILLS_SHA"

# Replace only skills managed by this installer. Unrelated installed skills are
# preserved, while reruns cannot leave stale files behind in managed skills.
install_skills() {
  source_dir=$1
  destination_dir=$2

  mkdir -p "$destination_dir"
  for skill_dir in "$source_dir"/*; do
    [ -d "$skill_dir" ] || continue
    skill_name=${skill_dir##*/}
    rm -rf "${destination_dir:?}/$skill_name"
    cp -R "$skill_dir" "$destination_dir/$skill_name"
  done
}

# Only the categories the published plugin ships. `deprecated/`, `in-progress/`
# and `misc/` are in the repo but not in .claude-plugin/plugin.json.
for destination_dir in "$claude_skills_dir" "$codex_skills_dir"; do
  install_skills "$tmp/skills/engineering" "$destination_dir"
  install_skills "$tmp/skills/productivity" "$destination_dir"
  install_skills "$script_dir/skills" "$destination_dir"
done

claude_count=$(find "$claude_skills_dir" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
codex_count=$(find "$codex_skills_dir" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
echo "installed $claude_count skills into $claude_skills_dir and $codex_count skills into $codex_skills_dir"
