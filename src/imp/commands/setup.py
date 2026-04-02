import subprocess
from pathlib import Path

import typer

from imp import ai, console, git, prompts


def _is_repo () -> bool:
   result = subprocess.run (
      [ "git", "rev-parse", "--git-dir" ],
      capture_output=True,
      text=True,
      check=False,
   )
   return result.returncode == 0


def _remote_url () -> str:
   result = subprocess.run (
      [ "git", "remote", "get-url", "origin" ],
      capture_output=True,
      text=True,
      check=False,
   )
   return result.stdout.strip ()


def _init ():
   subprocess.run ([ "git", "init" ], capture_output=True, text=True, check=True)
   console.success ("Initialized git repository")


def _add_remote (url: str):
   existing = _remote_url ()

   if existing == url:
      console.muted ("Origin already set")
      return

   if existing:
      choice = console.choose (
         f"Origin is {existing}, replace?",
         [ "Yes", "No" ],
      )

      if choice == "No":
         return

      subprocess.run (
         [ "git", "remote", "set-url", "origin", url ],
         capture_output=True,
         text=True,
         check=True,
      )
      console.success (f"Updated origin → {url}")
   else:
      subprocess.run (
         [ "git", "remote", "add", "origin", url ],
         capture_output=True,
         text=True,
         check=True,
      )
      console.success (f"Added origin → {url}")


def _scan_files () -> str:
   entries = sorted (p.name for p in Path (".").iterdir () if not p.name.startswith ("."))
   return "\n".join (entries)


def _setup_gitignore (files: str):
   path = Path (".gitignore")
   existing = path.read_text ().strip () if path.exists () else ""

   result = ai.fast (prompts.gitignore (files, existing))
   result = result.strip ()

   if not result or result == "NONE":
      console.muted ("No new .gitignore entries needed")
      return

   if existing:
      combined = existing + "\n" + result + "\n"
   else:
      combined = result + "\n"

   path.write_text (combined)
   console.success ("Updated .gitignore")


def setup (
   url: str = typer.Argument (help="GitHub repository URL"),
):
   """Initialize a git repo with remote and .gitignore."""

   console.header ("Setup")

   if _is_repo ():
      console.muted ("Already a git repository")
   else:
      _init ()

   _add_remote (url)

   files = _scan_files ()

   if files:
      _setup_gitignore (files)
   else:
      console.muted ("Empty directory, skipping .gitignore")

   console.out.print ()
   console.success ("Done")
