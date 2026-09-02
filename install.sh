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

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
claude_skills_dir="$HOME/.claude/skills"
codex_skills_dir="$HOME/.codex/skills"
claude_plugin_dir="$HOME/.claude/plugins/cache/claude-plugins-official/mattpocock-skills"
codex_plugin_dir="$HOME/.codex/plugins/cache/claude-plugins-official/mattpocock-skills"

# Install a third-party skill only when the application cannot already see it
# through its plugin, the shared agent directory, or its own skill directory.
install_skills() {
  source_dir=$1
  destination_dir=$2
  application=$3
  plugin_dir=$4

  mkdir -p "$destination_dir"
  for skill_dir in "$source_dir"/*; do
    [ -d "$skill_dir" ] || continue
    skill_name=${skill_dir##*/}
    existing_location=
    for location in \
      "$plugin_dir"/*/skills/engineering/"$skill_name" \
      "$plugin_dir"/*/skills/productivity/"$skill_name" \
      "$HOME/.agents/skills/$skill_name" \
      "$destination_dir/$skill_name"
    do
      [ -f "$location/SKILL.md" ] || continue
      existing_location=$location
      break
    done

    if [ -n "$existing_location" ]; then
      echo "Skill $skill_name already installed for $application in $existing_location. Skipping install."
      continue
    fi

    cp -R "$skill_dir" "$destination_dir/$skill_name"
  done
}

# Repository-owned skills are updated on each run and never installed into the
# shared or plugin locations, so replacing them does not create duplicates.
replace_skills() {
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

main() {
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  git clone -q https://github.com/mattpocock/skills.git "$tmp"
  git -C "$tmp" checkout -q "$SKILLS_SHA"

  # Only the categories the published plugin ships. `deprecated/`, `in-progress/`
  # and `misc/` are in the repo but not in .claude-plugin/plugin.json.
  install_skills "$tmp/skills/engineering" "$claude_skills_dir" "Claude Code" "$claude_plugin_dir"
  install_skills "$tmp/skills/productivity" "$claude_skills_dir" "Claude Code" "$claude_plugin_dir"
  install_skills "$tmp/skills/engineering" "$codex_skills_dir" "Codex" "$codex_plugin_dir"
  install_skills "$tmp/skills/productivity" "$codex_skills_dir" "Codex" "$codex_plugin_dir"
  replace_skills "$script_dir/skills" "$claude_skills_dir"
  replace_skills "$script_dir/skills" "$codex_skills_dir"

  claude_count=$(find "$claude_skills_dir" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
  codex_count=$(find "$codex_skills_dir" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
  echo "$claude_count skill directories in $claude_skills_dir and $codex_count in $codex_skills_dir"
}

if [ "${INSTALL_SH_SOURCE_ONLY:-0}" != 1 ]; then
  main
fi
