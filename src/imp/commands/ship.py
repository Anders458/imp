import typer

from imp import ai, console, git, prompts, version
from imp.commands.release import (
   current_version,
   do_release,
   release_scope,
)


def ship (
   level: str = typer.Argument ("patch", help="Version bump: patch, minor, or major"),
   whisper: str = typer.Option ("", "--whisper", "-w", help="Hint to guide the AI"),
):
   """Commit all changes and release in one shot.

   Stages everything, generates a commit message, bumps the version,
   updates the changelog, squashes, tags, and pushes. No prompts.
   Equivalent to imp commit -a followed by imp release with auto-accept.
   """

   git.require ()

   base = git.base_branch ()
   if git.branch () != base:
      console.warn (f"Releasing from {git.branch ()}, not {base}")

   if level not in ("patch", "minor", "major"):
      console.hint ("use patch, minor, or major")
      console.fatal (f"Invalid level: {level}")

   console.header ("Ship")

   git.stage (all=True)
   d = git.diff (staged=True)

   if not d:
      console.muted ("No changes to ship")
      raise typer.Exit (0)

   b = git.branch ()
   msg = ai.commit_message (prompts.commit (d, b, whisper))

   console.label ("Commit")
   console.item (msg)
   git.commit (msg)
   console.success ("Committed")
   console.out.print ()

   tag, _log, count = release_scope ()

   new_version = version.bump (current_version (), level)

   if git.tag_exists (f"v{new_version}"):
      console.hint (f"pick a different version, or: git tag -d v{new_version}")
      console.fatal (f"Tag v{new_version} already exists")

   will_push = git.remote_exists ()

   do_release (new_version, tag, count, will_push)

   if not will_push:
      console.muted ("No remote, skipped push")
