#!/bin/bash
#
# AI prompt templates
#

prompt_commit() {
   local diff="$1"
   local branch="${2:-}"
   local ticket=""

   # Extract ticket from branch name (e.g. IMP-123, JIRA-456, feat/ABC-789)
   if [[ "$branch" =~ ([A-Z]+-[0-9]+) ]]; then
      ticket="${BASH_REMATCH[1]}"
   fi

   local ticket_rule=""
   if [[ -n "$ticket" ]]; then
      ticket_rule="- Include ticket $ticket after the type, e.g. \"fix: $ticket message\""
   fi

   cat << EOF
Generate a Conventional Commits message for this diff.

Format: type: message
Types: feat, fix, refactor, build, chore, docs, test, style, perf, ci
$ticket_rule

Rules:
- Subject only, one line, max 72 chars, no period
- ALL LOWERCASE after the colon (except ticket IDs like IMP-123)
- Imperative mood: "add" not "added", "fix" not "fixes"
- Pick the type that best fits the primary change
- No markdown, no backticks, no quotes
- No body, no bullet points, just the subject line
- Output will be validated against commitlint rules; it must pass

Diff:
$diff

Output ONLY the commit message, nothing else:
EOF
}

prompt_branch() {
   cat << EOF
Suggest a git branch name for: $1

Rules:
- Lowercase, hyphens only, no spaces
- Max 30 chars
- Format: type/short-name
- Types: feat, fix, refactor, docs, test, chore

Output ONLY the branch name:
EOF
}

prompt_revert() {
   local commit_msg="$1"
   local diff="$2"

   cat << EOF
Generate a commit message for reverting this change. Start with 'Revert:'. Max 50 chars:

Original: $commit_msg

Changes reverted:
$diff

Output ONLY the commit message:
EOF
}

prompt_review() {
   cat << EOF
Review this code diff. Be concise and actionable.

Check for:
- Bugs or logic errors
- Security issues
- Performance problems
- Code style issues
- Missing error handling

If the code looks good, say so briefly.

Diff:
$1

Output ONLY the review:
EOF
}

prompt_fix() {
   local title="$1"
   local body="$2"

   cat << EOF
Suggest a git branch name for fixing this issue:

Title: $title
Description: $body

Rules:
- Lowercase, hyphens only
- Max 30 chars
- Format: fix/<short-name>
- Include issue number if fits

Output ONLY the branch name:
EOF
}

prompt_pr() {
   local branch="$1"
   local log="$2"
   local diff="$3"

   cat << EOF
Generate a GitHub pull request title and description.

Branch: $branch
Commits:
$log

Diff summary:
$diff

Format:
TITLE: <50 char title>

DESCRIPTION:
## Summary
<2-3 bullet points>

## Changes
<list main changes>

Output ONLY in this format:
EOF
}

prompt_split() {
   local file_diffs="$1"
   local branch="${2:-}"
   local ticket=""

   # Extract ticket from branch name (e.g. IMP-123, JIRA-456, feat/ABC-789)
   if [[ "$branch" =~ ([A-Z]+-[0-9]+) ]]; then
      ticket="${BASH_REMATCH[1]}"
   fi

   local ticket_rule=""
   if [[ -n "$ticket" ]]; then
      ticket_rule="- Include ticket $ticket after the type, e.g. \"fix: $ticket message\""
   fi

   cat << EOF
Group these changed files into logical commits. Each group = one commit.

Format: type: message
Types: feat, fix, refactor, build, chore, docs, test, style, perf, ci
$ticket_rule

Rules:
- Output a JSON array, no markdown fences, no explanation
- Each element: {"files": ["path1", "path2"], "message": "type: description"}
- ALL LOWERCASE after the colon (except ticket IDs like IMP-123)
- Imperative mood: "add" not "added", "fix" not "fixes"
- Max 72 chars per message, no period at end
- Every file must appear in exactly one group
- Minimize number of groups (prefer fewer, larger groups)
- Group by logical change, not by directory

Branch: $branch

File diffs:
$file_diffs

Output ONLY the JSON array:
EOF
}
