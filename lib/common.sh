#!/bin/bash
#
# Shared helpers
#

IMP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$IMP_ROOT/lib/ai.sh"
source "$IMP_ROOT/lib/prompts.sh"

# === Gum ===

HAS_GUM=false
if [[ "${IMP_NO_GUM:-}" != "1" ]] && command -v gum &> /dev/null; then
   HAS_GUM=true
fi

# === Colors ===

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
MUTED='\033[0;90m'
BOLD='\033[1m'
RESET='\033[0m'

# === Output ===

header() {
   echo
   echo -e "${BOLD}$1${RESET}"
   echo
}

label() {
   echo -e "${CYAN}$1${RESET}"
}

item() {
   echo -e "  ${MUTED}$1${RESET}"
}

divider() {
   echo -e "${MUTED}────────────────────────────────────────${RESET}"
}

err() {
   echo -e "${RED}error:${RESET} $1" >&2
}

warn() {
   echo -e "${YELLOW}$1${RESET}"
}

muted() {
   echo -e "${MUTED}$1${RESET}"
}

success() {
   echo -e "${GREEN}✓${RESET} $1"
}

hint() {
   echo
   echo -e "${MUTED}→ $1${RESET}"
}

# Display labeled list of items
show_items() {
   local title="$1"
   local data="$2"

   label "$title"
   echo "$data" | while read -r line; do
      item "$line"
   done
   echo
}

# === Prompts ===

# Prompt for Y/n confirmation
confirm() {
   local msg="${1:-Continue?}"
   local default="${2:-y}"

   if [[ "$HAS_GUM" == "true" ]]; then
      if [[ "$default" == "y" ]]; then
         gum confirm "$msg" --default=yes
      else
         gum confirm "$msg" --default=no
      fi
      return $?
   fi

   if [[ "$default" == "y" ]]; then
      read -rp "$msg [Y/n] "
   else
      read -rp "$msg [y/N] "
   fi

   case "$REPLY" in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      "")
         [[ "$default" == "y" ]] && return 0 || return 1
         ;;
      *) return 1 ;;
   esac
}

# Display message, prompt Y/n/e, execute git commit
# Usage: confirm_commit "$msg" [extra git flags like --amend]
# Returns 1 on cancel (caller handles cleanup)
confirm_commit() {
   local msg="$1"
   local choice

   shift

   divider
   echo "$msg"
   divider
   echo

   if [[ "$HAS_GUM" == "true" ]]; then
      choice=$(gum choose "Yes" "Edit" "No")
   else
      read -rp "Use this message? [Y/n/e] " choice
   fi

   case "$choice" in
      n | N | No) return 1 ;;
      e | E | Edit) git commit "$@" -e -m "$msg" ;;
      *) git commit "$@" -m "$msg" ;;
   esac
}

# Open text in $EDITOR, return edited content via stdout
edit_in_editor() {
   local content="$1"
   local tmpfile

   tmpfile=$(mktemp)
   # shellcheck disable=SC2064
   trap "rm -f '$tmpfile'" EXIT
   echo "$content" > "$tmpfile"
   ${EDITOR:-vim} "$tmpfile"
   cat "$tmpfile"
   rm -f "$tmpfile"
   trap - EXIT
}

# === Gum Wrappers ===

# Run command with spinner. Captures stdout.
# Usage: result=$(spin "title" command arg1 arg2)
# Runs command in background since gum spin can't call shell functions.
spin() {
   local title="$1"

   shift

   if [[ "$HAS_GUM" == "true" ]]; then
      local tmp rc=0

      tmp=$(mktemp)
      # shellcheck disable=SC2064
      trap "rm -f '$tmp'" EXIT
      "$@" > "$tmp" &
      local pid=$!
      gum spin --spinner dot --title "$title" -- bash -c "while kill -0 $pid 2>/dev/null; do sleep 0.1; done"
      wait "$pid" || rc=$?
      cat "$tmp"
      rm -f "$tmp"
      trap - EXIT
      return "$rc"
   else
      muted "$title" >&2
      echo >&2
      "$@"
   fi
}

# Prompt for text input
# Usage: value=$(gum_input "prompt" "placeholder")
gum_input() {
   local prompt="$1"
   local placeholder="${2:-}"

   if [[ "$HAS_GUM" == "true" ]]; then
      gum input --header "$prompt" --placeholder "$placeholder"
   else
      local reply

      read -rp "$prompt " reply
      echo "$reply"
   fi
}

# Choose from a list of options
# Usage: choice=$(gum_choose "header" "opt1" "opt2" "opt3")
gum_choose() {
   local hdr="$1"

   shift

   if [[ "$HAS_GUM" == "true" ]]; then
      gum choose --header "$hdr" "$@"
   else
      local i=1
      local opts=("$@")

      echo "$hdr" >&2
      for opt in "${opts[@]}"; do
         echo "  $i) $opt" >&2
         ((i++))
      done

      local reply

      read -rp "Choice [1-${#opts[@]}]: " reply
      if [[ "$reply" =~ ^[0-9]+$ ]] \
         && [[ "$reply" -ge 1 ]] \
         && [[ "$reply" -le "${#opts[@]}" ]]; then
         echo "${opts[$((reply - 1))]}"
      else
         echo "${opts[0]}"
      fi
   fi
}

# === Git Helpers ===

require_git() {
   git rev-parse --git-dir > /dev/null 2>&1 || {
      err "Not a git repository"
      exit 1
   }
}

# Require clean working tree
require_clean() {
   if [[ -n "$(git status --porcelain)" ]]; then
      err "Uncommitted changes"
      hint "${1:-imp commit or imp stash first}"
      exit 1
   fi
}

require_gh() {
   if ! command -v gh &> /dev/null; then
      err "GitHub CLI (gh) not installed"
      hint "https://cli.github.com"
      exit 1
   fi
}

require_jq() {
   if ! command -v jq &> /dev/null; then
      err "jq not installed"
      hint "https://jqlang.github.io/jq/download"
      exit 1
   fi
}

# Returns "main" or "master"
base_branch() {
   if git rev-parse --verify main &> /dev/null; then
      echo "main"
   elif git rev-parse --verify master &> /dev/null; then
      echo "master"
   else
      echo "main"
   fi
}

last_tag() {
   git describe --tags --abbrev=0 2> /dev/null || echo ""
}

has_upstream() {
   git rev-parse --verify "@{u}" &> /dev/null
}

# shellcheck disable=SC1083
count_ahead() {
   git rev-list --count "@{u}..HEAD" 2> /dev/null || echo "0"
}

# shellcheck disable=SC1083
count_behind() {
   git rev-list --count "HEAD..@{u}" 2> /dev/null || echo "0"
}

commit_count() {
   git rev-list --count HEAD 2> /dev/null || echo "0"
}

# Get current diff. Sets globals: DIFF, DIFF_CONTEXT
# Returns 1 if no changes found
get_diff() {
   local range="${1:-}"

   if [[ -n "$range" ]]; then
      DIFF=$(git diff "$range")
      DIFF_CONTEXT="$range"
   elif [[ -n "$(git diff --cached)" ]]; then
      DIFF=$(git diff --cached)
      DIFF_CONTEXT="staged changes"
   elif [[ -n "$(git diff)" ]]; then
      DIFF=$(git diff)
      DIFF_CONTEXT="unstaged changes"
   else
      # shellcheck disable=SC2034
      DIFF=""
      # shellcheck disable=SC2034
      DIFF_CONTEXT=""
      return 1
   fi
}

# === Validation ===

# Validate branch name contains only safe characters
validate_branch() {
   local name="$1"

   if [[ ! "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9/_.-]*$ ]]; then
      err "Invalid branch name: $name"
      exit 1
   fi
}

# === Semver ===

bump_version() {
   local version="$1"
   local bump="$2"

   if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "$bump"
      return
   fi

   local major minor patch

   IFS='.' read -r major minor patch <<< "$version"

   case "$bump" in
      major) echo "$((major + 1)).0.0" ;;
      minor) echo "$major.$((minor + 1)).0" ;;
      patch) echo "$major.$minor.$((patch + 1))" ;;
      *) echo "$bump" ;;
   esac
}

# === Sanitization ===

# Strip newlines and leading/trailing whitespace from AI output
# Used for single-line values (branch names, commit subjects, stash messages)
sanitize() {
   tr -d '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# === Rendering ===

# Render markdown to ANSI (glow > gum > sed fallback)
md() {
   local input

   input=$(cat)
   input=$(echo "$input" | sed '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')

   if command -v glow &> /dev/null; then
      echo "$input" | glow -s dark -w 80 -
   elif [[ "$HAS_GUM" == "true" ]]; then
      echo "$input" | gum format -t markdown
   else
      echo "$input" \
         | sed -E "s/^### (.*)$/$(printf '\033[1;36m')\\1$(printf '\033[0m')/" \
         | sed -E "s/^## (.*)$/$(printf '\033[1;33m')\\1$(printf '\033[0m')/" \
         | sed -E "s/^# (.*)$/$(printf '\033[1;35m')\\1$(printf '\033[0m')/" \
         | sed -E "s/\*\*([^*]+)\*\*/$(printf '\033[1m')\\1$(printf '\033[0m')/g" \
         | sed -E "s/\*([^*]+)\*/$(printf '\033[3m')\\1$(printf '\033[0m')/g" \
         | sed -E "s/\`([^\`]+)\`/$(printf '\033[36m')\\1$(printf '\033[0m')/g" \
         | sed -E "s/^- /  • /"
   fi
}
