# imp

AI-powered git helpers. Small shell scripts, pluggable AI backend.

## Install

```bash
./install.sh
source ~/.bashrc  # or ~/.zshrc
```

## Commands

```bash
imp commit      # Generate commit message from staged changes
imp branch      # Create branch from description
imp describe    # Explain what a branch does
imp list        # Show current work overview
imp release     # Generate release notes since last tag
imp squash      # Squash commits with AI message
imp changelog   # Update CHANGELOG.md with new version
```

## Examples

```bash
git add .
imp commit
# → "Add rate limiting to API endpoints"
# → Use this message? [Y/n/e]

imp branch "fix the logout bug"
# → Suggested: fix/logout-bug
# → Create branch? [Y/n]

imp changelog
# → Analyzing commits...
# → Preview:
# → ### Added
# → - Rate limiting on API endpoints
# → Version bump: [p]atch / [m]inor / [M]ajor
```

## Config

Environment variables:

```bash
export IMP_AI_PROVIDER=claude     # claude, ollama
export IMP_AI_MODEL_FAST=haiku    # quick tasks
export IMP_AI_MODEL_SMART=sonnet  # complex tasks
```

For Ollama:

```bash
export IMP_AI_PROVIDER=ollama
export IMP_AI_MODEL_FAST=llama3.2
export IMP_AI_MODEL_SMART=llama3.2
```

## Structure

```
imp/
├── bin/
│   ├── imp              # dispatcher
│   ├── imp-commit
│   ├── imp-branch
│   ├── imp-describe
│   ├── imp-list
│   ├── imp-release
│   ├── imp-squash
│   └── imp-changelog
├── lib/
│   ├── ai.sh            # pluggable AI interface
│   └── common.sh        # shared helpers
├── install.sh
└── README.md
```

## Requirements

- bash
- git
- claude CLI (or ollama)
- jq (for ollama provider)
