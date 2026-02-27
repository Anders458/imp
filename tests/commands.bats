#!/usr/bin/env bats

load helpers

setup() {
   setup_test_repo
   mock_ai "test: add unit tests"
}

teardown() {
   teardown_test_repo
}

# === imp (dispatcher) ===

@test "imp: shows usage with no args" {
   run "$IMP_ROOT/bin/imp"
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"AI-powered git workflow"* ]]
}

@test "imp: shows version" {
   run "$IMP_ROOT/bin/imp" --version
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"imp 0."* ]]
}

@test "imp: unknown command fails" {
   run "$IMP_ROOT/bin/imp" nonexistent
   [[ "$status" -ne 0 ]]
   [[ "$output" == *"Unknown command"* ]]
}

# === imp commit ===

@test "commit: fails with nothing staged" {
   run "$IMP_ROOT/bin/imp-commit"
   [[ "$status" -ne 0 ]]
   [[ "$output" == *"Nothing staged"* ]]
}

@test "commit: -a flag stages and generates message" {
   echo "new content" >> file.txt
   run "$IMP_ROOT/bin/imp-commit" -a <<< "y"
   [[ "$status" -eq 0 ]]
   # Verify commit was made
   [[ $(git log --oneline | wc -l) -eq 2 ]]
}

# === imp amend ===

@test "amend: fails with no commits beyond initial" {
   echo "change" >> file.txt
   git add file.txt
   # amend should work since there's at least 1 commit
   run "$IMP_ROOT/bin/imp-amend" <<< "y"
   [[ "$status" -eq 0 ]]
}

# === imp branch ===

@test "branch: no args lists branches" {
   echo ".bin" > .gitignore
   git add .gitignore && git commit -m "gitignore"
   git checkout -b feat/other
   git checkout main
   run "$IMP_ROOT/bin/imp-branch" <<< "1"
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"feat/other"* ]]
}

@test "branch: no args shows only branch when alone" {
   run "$IMP_ROOT/bin/imp-branch"
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"Only one branch"* ]]
}

@test "branch: creates branch from AI suggestion" {
   mock_ai "feat/test-branch"
   run "$IMP_ROOT/bin/imp-branch" "test feature" <<< "y"
   [[ "$status" -eq 0 ]]
   [[ $(git branch --show-current) == "feat/test-branch" ]]
}

@test "branch: validates AI output" {
   mock_ai "invalid branch; rm -rf"
   run "$IMP_ROOT/bin/imp-branch" "test" <<< "y"
   [[ "$status" -ne 0 ]]
   [[ "$output" == *"Invalid branch name"* ]]
}

# === imp undo ===

@test "undo: undoes last commit keeping changes staged" {
   echo "a" >> file.txt && git add file.txt && git commit -m "second"
   run "$IMP_ROOT/bin/imp-undo" <<< "y"
   [[ "$status" -eq 0 ]]
   [[ $(git log --oneline | wc -l) -eq 1 ]]
   # Changes should be staged
   [[ -n "$(git diff --cached)" ]]
}

@test "undo: fails with invalid count" {
   run "$IMP_ROOT/bin/imp-undo" abc
   [[ "$status" -ne 0 ]]
   [[ "$output" == *"Invalid count"* ]]
}

@test "undo: fails when count exceeds commits" {
   run "$IMP_ROOT/bin/imp-undo" 99
   [[ "$status" -ne 0 ]]
   [[ "$output" == *"Only 1 commits"* ]]
}

# === imp review ===

@test "review: shows no changes when clean" {
   run "$IMP_ROOT/bin/imp-review"
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"No changes"* ]]
}

# === imp status ===

@test "status: shows repo overview" {
   run "$IMP_ROOT/bin/imp-status"
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"Branch"* ]]
   [[ "$output" == *"main"* ]]
}

# === imp doctor ===

@test "doctor: runs without error" {
   run "$IMP_ROOT/bin/imp-doctor"
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"git"* ]]
}

# === imp help ===

@test "help: shows workflow guide" {
   run "$IMP_ROOT/bin/imp-help"
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"workflow"* ]]
}

# === imp fix ===

@test "fix: fails with no issue number" {
   if ! command -v gh &> /dev/null; then
      skip "gh not installed"
   fi
   run "$IMP_ROOT/bin/imp-fix"
   [[ "$status" -ne 0 ]]
   [[ "$output" == *"Missing issue number"* ]]
}

@test "fix: rejects non-numeric issue" {
   if ! command -v gh &> /dev/null; then
      skip "gh not installed"
   fi
   run "$IMP_ROOT/bin/imp-fix" abc
   [[ "$status" -ne 0 ]]
   [[ "$output" == *"numeric"* ]]
}

# === imp revert ===

@test "revert: reverts a specific commit" {
   echo "a" >> file.txt && git add file.txt && git commit -m "second commit"
   local hash
   hash=$(git rev-parse --short HEAD)
   mock_ai "Revert second commit"
   # First confirm = "Create revert commit?", second = "Use this message?"
   run "$IMP_ROOT/bin/imp-revert" "$hash" <<< $'y\ny'
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"Reverted"* ]]
}

# === imp sync ===

@test "sync: fails without upstream" {
   echo ".bin" > .gitignore
   git add .gitignore && git commit -m "gitignore"
   run "$IMP_ROOT/bin/imp-sync"
   [[ "$status" -ne 0 ]]
   [[ "$output" == *"No upstream branch"* ]]
}

# === imp status ===

@test "status: shows changes when dirty" {
   echo "dirty" >> file.txt
   run "$IMP_ROOT/bin/imp-status"
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"Changes"* ]]
   [[ "$output" == *"file.txt"* ]]
}

# === imp log ===

@test "log: shows commit graph" {
   echo "a" >> file.txt && git add file.txt && git commit -m "second"
   run "$IMP_ROOT/bin/imp-log"
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"second"* ]]
   [[ "$output" == *"Initial commit"* ]]
}

@test "log: respects -n count" {
   echo "a" >> file.txt && git add file.txt && git commit -m "second"
   echo "b" >> file.txt && git add file.txt && git commit -m "third"
   run "$IMP_ROOT/bin/imp-log" -n 1
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"third"* ]]
   [[ "$output" != *"Initial commit"* ]]
}

# === imp release ===

@test "release: creates tag and updates changelog" {
   echo ".bin" > .gitignore
   git add .gitignore && git commit -m "chore: add gitignore"
   git tag v0.0.1
   echo "a" >> file.txt && git add file.txt && git commit -m "feat: add feature"
   echo "b" >> file.txt && git add file.txt && git commit -m "fix: resolve bug"
   # p=patch, y=confirm changelog, n=don't push
   run "$IMP_ROOT/bin/imp-release" <<< $'p\ny\nn'
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"Tagged v0.0.2"* ]]
   # Changelog must exist and contain the version
   [[ -f CHANGELOG.md ]]
   grep -q "0.0.2" CHANGELOG.md
   # Changelog should contain categorized entries
   grep -q "Added: add feature" CHANGELOG.md
   grep -q "Fixed: resolve bug" CHANGELOG.md
   # Changelog must be in the commit, not just on disk
   git show --stat HEAD | grep -q "CHANGELOG.md"
}

@test "release: squashes commits since last tag" {
   echo ".bin" > .gitignore
   git add .gitignore && git commit -m "chore: add gitignore"
   git tag v1.0.0
   echo "a" >> file.txt && git add file.txt && git commit -m "feat: add one"
   echo "b" >> file.txt && git add file.txt && git commit -m "feat: add two"
   echo "c" >> file.txt && git add file.txt && git commit -m "fix: resolve three"
   run "$IMP_ROOT/bin/imp-release" <<< $'p\ny\nn'
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"Squashed 3 commits"* ]]
   # Should be one commit after the tag, not three
   local count
   count=$(git log --oneline v1.0.0..HEAD | wc -l | tr -d ' ')
   [[ "$count" -eq 1 ]]
}

# === imp done ===

@test "done: switches to main and deletes branch" {
   echo ".bin" > .gitignore
   git add .gitignore && git commit -m "gitignore"
   git checkout -b feat/cleanup
   echo "a" >> file.txt && git add file.txt && git commit -m "work"
   git checkout main
   git merge feat/cleanup
   git checkout feat/cleanup
   run "$IMP_ROOT/bin/imp-done"
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"Deleted local branch feat/cleanup"* ]]
   [[ $(git branch --show-current) == "main" ]]
   # Branch should be gone
   run git branch --list feat/cleanup
   [[ -z "$output" ]]
}

@test "done: fails on base branch" {
   run "$IMP_ROOT/bin/imp-done"
   [[ "$status" -ne 0 ]]
   [[ "$output" == *"Already on main"* ]]
}

@test "done: fails with dirty working tree" {
   git checkout -b feat/dirty
   echo "dirty" >> file.txt
   run "$IMP_ROOT/bin/imp-done"
   [[ "$status" -ne 0 ]]
   [[ "$output" == *"Uncommitted changes"* ]]
}

# === imp clean ===

@test "clean: deletes merged branches" {
   git checkout -b feat/merged
   echo "a" >> file.txt && git add file.txt && git commit -m "work"
   git checkout main
   git merge feat/merged
   run "$IMP_ROOT/bin/imp-clean" <<< "y"
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"Deleted feat/merged"* ]]
   run git branch --list feat/merged
   [[ -z "$output" ]]
}

@test "clean: nothing to clean when no merged branches" {
   run "$IMP_ROOT/bin/imp-clean" <<< "y"
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"No merged branches"* ]]
}

# === imp split ===

@test "split: fails with no changes" {
   run "$IMP_ROOT/bin/imp-split"
   [[ "$status" -ne 0 ]]
   [[ "$output" == *"No changes"* ]]
}

@test "split: fails with only 1 file" {
   echo "change" >> file.txt
   run "$IMP_ROOT/bin/imp-split"
   [[ "$status" -ne 0 ]]
   [[ "$output" == *"Only 1 file"* ]]
}

@test "split: creates multiple commits" {
   echo "auth code" > auth.sh
   echo "db code" > db.sh
   git add auth.sh db.sh
   mock_ai '[{"files":["auth.sh"],"message":"feat: add auth module"},{"files":["db.sh"],"message":"feat: add db module"}]'
   run "$IMP_ROOT/bin/imp-split" <<< "y"
   [[ "$status" -eq 0 ]]
   # Initial + 2 split commits
   [[ $(git log --oneline | wc -l) -eq 3 ]]
   [[ "$output" == *"Group 1"* ]]
   [[ "$output" == *"Group 2"* ]]
}

@test "split: rejects invalid JSON" {
   echo "a" > a.txt
   echo "b" > b.txt
   mock_ai "this is not json at all"
   run "$IMP_ROOT/bin/imp-split"
   [[ "$status" -ne 0 ]]
   [[ "$output" == *"invalid JSON"* ]]
}

@test "split: rejects file mismatch" {
   echo "a" > a.txt
   echo "b" > b.txt
   echo "c" > c.txt
   mock_ai '[{"files":["a.txt"],"message":"feat: add a"},{"files":["b.txt"],"message":"feat: add b"}]'
   run "$IMP_ROOT/bin/imp-split"
   [[ "$status" -ne 0 ]]
   [[ "$output" == *"mismatch"* ]]
}

@test "split: cancellation preserves state" {
   echo "a" > a.txt
   echo "b" > b.txt
   mock_ai '[{"files":["a.txt"],"message":"feat: add a"},{"files":["b.txt"],"message":"feat: add b"}]'
   run "$IMP_ROOT/bin/imp-split" <<< "n"
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"Cancelled"* ]]
   # Only the initial commit
   [[ $(git log --oneline | wc -l) -eq 1 ]]
}

@test "split: handles single group response" {
   echo "a" > a.txt
   echo "b" > b.txt
   mock_ai '[{"files":["a.txt","b.txt"],"message":"feat: add files"}]'
   run "$IMP_ROOT/bin/imp-split"
   [[ "$status" -eq 0 ]]
   [[ "$output" == *"single commit"* ]]
}
