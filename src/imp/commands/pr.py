import shutil
import subprocess

import typer

from imp import ai, console, git, prompts


def _parse_response (content: str) -> tuple [str, str]:
   title = ""
   for line in content.splitlines ():
      if line.startswith ("TITLE:"):
         title = line [6:].strip ()
         break

   description = ""
   parts = content.split ("DESCRIPTION:", 1)
   if len (parts) > 1:
      description = parts [1].strip ()

   return title, description


def pr (
   yes: bool = typer.Option (False, "--yes", "-y", help="Accept AI description without review"),
   whisper: str = typer.Option ("", "--whisper", "-w", help="Hint to guide the AI"),
):
   """Create a GitHub pull request with AI-generated description.

   Diffs the current branch against the base branch, then uses AI to
   generate a PR title and description. Pushes to origin if needed and
   creates the PR via the gh CLI. Requires gh to be installed.
   """

   git.require ()

   if not shutil.which ("gh"):
      console.hint ("https://cli.github.com")
      console.fatal ("GitHub CLI (gh) not installed")

   console.header ("Pull Request")

   b = git.branch ()
   base = git.base_branch ()

   if b == base:
      console.hint ("imp branch <description>")
      console.fatal (f"Cannot create PR from {base}")

   log = git.log_oneline (rev_range=f"{base}..{b}")

   if not log:
      console.fatal (f"No commits on {b}")

   console.label ("Branch")
   console.item (f"{b} → {base}")
   console.out.print ()

   console.items ("Commits", log)

   d = git.diff_range (f"{base}..{b}", max_lines=ai.MAX_DIFF_LINES)

   pr_content = console.spin (
      "Thinking...",
      ai.smart,
      prompts.pr (b, log, d, whisper),
      False,
   )

   title, description = _parse_response (pr_content)

   if not title:
      console.warn ("Could not parse title, using branch name")
      title = b

   console.label ("Title")
   console.item (title)
   console.out.print ()

   console.label ("Description")
   console.divider ()
   console.md (description)
   console.divider ()
   console.out.print ()

   if not yes:
      choice = console.choose ("Create PR?", [ "Yes", "Edit", "No" ])

      if choice == "Edit":
         edited = console.edit (f"{title}\n\n{description}")
         lines = edited.splitlines ()
         title = lines [0] if lines else title
         description = "\n".join (lines [2:]) if len (lines) > 2 else description
      elif choice == "No":
         console.muted ("Cancelled")
         raise typer.Exit (0)

   if not git.has_upstream ():
      console.spin ("Pushing to origin...", git.push, False, True, b)

   try:
      result = subprocess.run (
         [
            "gh", "pr", "create",
            "--title", title,
            "--body", description,
            "--base", base,
         ],
         capture_output=True,
         text=True,
         check=True,
      )
      pr_url = result.stdout.strip ()
   except subprocess.CalledProcessError:
      console.fatal ("Failed to create PR")

   console.out.print ()
   console.success ("Created PR")
   console.item (pr_url)

   console.hint ("gh pr view --web to open in browser")
