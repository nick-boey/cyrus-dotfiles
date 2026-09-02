#!/bin/sh
set -eu

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

HOME="$test_root/home"
export HOME INSTALL_SH_SOURCE_ONLY=1
. "$(dirname -- "$0")/install.sh"

source_dir="$test_root/source"
destination_dir="$HOME/.claude/skills"
plugin_dir="$HOME/.claude/plugins/cache/claude-plugins-official/mattpocock-skills"
mkdir -p \
  "$source_dir/from-plugin" \
  "$source_dir/from-shared" \
  "$source_dir/from-direct" \
  "$source_dir/new-skill" \
  "$plugin_dir/1.2.3/skills/engineering/from-plugin" \
  "$HOME/.agents/skills/from-shared" \
  "$destination_dir/from-direct"
touch \
  "$source_dir/from-plugin/SKILL.md" \
  "$source_dir/from-shared/SKILL.md" \
  "$source_dir/from-direct/SKILL.md" \
  "$source_dir/new-skill/SKILL.md" \
  "$plugin_dir/1.2.3/skills/engineering/from-plugin/SKILL.md" \
  "$HOME/.agents/skills/from-shared/SKILL.md" \
  "$destination_dir/from-direct/SKILL.md"

output=$(install_skills "$source_dir" "$destination_dir" "Claude Code" "$plugin_dir")

[ ! -e "$destination_dir/from-plugin" ]
[ ! -e "$destination_dir/from-shared" ]
[ -f "$destination_dir/from-direct/SKILL.md" ]
[ -f "$destination_dir/new-skill/SKILL.md" ]
echo "$output" | grep -Fqx "Skill from-plugin already installed for Claude Code in $plugin_dir/1.2.3/skills/engineering/from-plugin. Skipping install."
echo "$output" | grep -Fqx "Skill from-shared already installed for Claude Code in $HOME/.agents/skills/from-shared. Skipping install."
echo "$output" | grep -Fqx "Skill from-direct already installed for Claude Code in $destination_dir/from-direct. Skipping install."
