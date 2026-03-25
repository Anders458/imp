import subprocess
from pathlib import Path

import typer
from rich.panel import Panel

from imp import ai, console, git, prompts
from imp.theme import theme

MARKER = "<<<<<<<"


def _theirs_branch () -> str:
   git_dir = subprocess.run (
      [ "git", "rev-parse", "--git-dir" ],
      capture_output=True,
      text=True,
      check=False,
   ).stdout.strip ()

   merge_msg = Path (git_dir, "MERGE_MSG")
   if merge_msg.exists ():
      first_line = merge_msg.read_text ().splitlines () [0]
      parts = first_line.split ("'")
      if len (parts) >= 2:
         return parts [1]

   return "incoming"


def _checkout_ours (path: str):
   subprocess.run (
      [ "git", "checkout", "--ours", "--", path ],
      check=True,
      capture_output=True,
   )


def _checkout_theirs (path: str):
   subprocess.run (
      [ "git", "checkout", "--theirs", "--", path ],
      check=True,
      capture_output=True,
   )


def resolve (
   whisper: str = typer.Option ("", "--whisper", "-w", help="Hint to guide the AI"),
):
   """Resolve merge conflicts with AI assistance.

   Walks through each conflicted file, sends it to AI for resolution,
   and lets you accept, edit, or choose ours/theirs for each file.
   """

   git.require ()

   files = git.conflicts ()
   if not files:
      console.muted ("No conflicts to resolve")
      raise typer.Exit (0)

   console.header ("Resolve")

   console.label (f"{len (files)} conflicted file(s)")
   for f in files:
      console.item (f)
   console.out.print ()

   ours = git.branch () or "HEAD"
   theirs = _theirs_branch ()

   num_resolved = 0
   num_skipped = 0

   for path in files:
      console.label (path)

      content = git.conflict_content (path)
      has_markers = MARKER in content

      if not has_markers:
         console.muted ("No conflict markers (delete/rename conflict)")

         choice = console.choose (
            "Resolution",
            [ "Keep", "Delete", "Skip" ],
         )

         if choice == "Keep":
            git.add ([ path ])
            num_resolved += 1
         elif choice == "Delete":
            subprocess.run (
               [ "git", "rm", "--", path ],
               check=True,
               capture_output=True,
            )
            num_resolved += 1
         else:
            num_skipped += 1

         continue

      result = ai.smart (prompts.resolve (content, path, ours, theirs, whisper))

      if MARKER in result:
         console.warn ("AI left conflict markers, retrying...")
         result = ai.smart (prompts.resolve (content, path, ours, theirs, whisper))

         if MARKER in result:
            console.warn ("AI still left markers, showing best attempt")

      console.out.print (Panel (
         result,
         border_style=theme.accent,
         title=path,
         title_align="left",
         padding=(1, 2),
      ))
      console.out.print ()

      choice = console.choose (
         "Resolution",
         [ "AI suggestion", "Ours", "Theirs", "Edit", "Skip" ],
      )

      if choice == "AI suggestion":
         Path (path).write_text (result)
         git.add ([ path ])
         num_resolved += 1
      elif choice == "Ours":
         _checkout_ours (path)
         git.add ([ path ])
         num_resolved += 1
      elif choice == "Theirs":
         _checkout_theirs (path)
         git.add ([ path ])
         num_resolved += 1
      elif choice == "Edit":
         edited = console.edit (result)
         if edited.strip ():
            Path (path).write_text (edited)
            git.add ([ path ])
            num_resolved += 1
         else:
            console.muted ("Empty content, skipped")
            num_skipped += 1
      else:
         num_skipped += 1

   console.out.print ()
   console.success (f"{num_resolved} resolved, {num_skipped} skipped")

   if num_skipped == 0 and num_resolved > 0:
      if git.merge_in_progress ():
         console.hint ("git merge --continue")
      elif git.rebase_in_progress ():
         console.hint ("git rebase --continue")
      else:
         console.hint ("All conflicts resolved")
