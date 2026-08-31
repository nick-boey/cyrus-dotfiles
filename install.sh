#!/bin/sh
# Cyrus dotfiles: install Matt Pocock's agent skills into ~/.claude/skills/.
#
# Cyrus clones this repo and runs this script on every container boot
# (ContainerBootCommand.applyDotfiles, step 6, before `cyrus start`).
# Failures are logged and swallowed, so keep this quiet and idempotent.
#
# `claude` is not on PATH in the worker image, so `claude plugin install` is
# unavailable — a plain directory copy is the supported route (NOR-365).
set -eu

# Pinned to the commit the claude-plugins-official marketplace ships as
# mattpocock-skills. Bump this line to take a newer set.
SKILLS_SHA=0ab1b63a410a03d3627979a109c8695de27af954

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git clone -q https://github.com/mattpocock/skills.git "$tmp"
git -C "$tmp" checkout -q "$SKILLS_SHA"

# Only the categories the published plugin ships. `deprecated/`, `in-progress/`
# and `misc/` are in the repo but not in .claude-plugin/plugin.json.
mkdir -p "$HOME/.claude/skills"
cp -R "$tmp"/skills/engineering/. "$tmp"/skills/productivity/. "$HOME/.claude/skills/"

echo "installed $(find "$HOME/.claude/skills" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ') skills into $HOME/.claude/skills"
