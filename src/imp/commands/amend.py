import typer

from imp import ai, console, git, prompts


def amend (
   yes: bool = typer.Option (False, "--yes", "-y", help="Accept AI message without review"),
   whisper: str = typer.Option ("", "--whisper", "-w", help="Hint to guide the AI"),
):
   """Amend last commit with a new AI-generated message.

   Stages any uncommitted changes, regenerates the commit message from the
   full diff, and amends the previous commit. You can review, edit, or
   cancel the new message before it's applied.
   """

   git.require ()

   console.header ("Amend")

   total = git.commit_count ()
   if total == 0:
      console.err ("No commits to amend")
      console.hint ("imp commit first")
      raise typer.Exit (1)

   last_msg = git.show ("HEAD", fmt="%s")

   if total == 1:
      combined = git.show ("HEAD")
      changes = git.diff ()
      if changes:
         combined = combined + "\n" + changes
   else:
      combined = git.diff_range ("HEAD~1")

   if not combined:
      console.err ("Nothing to amend")
      raise typer.Exit (1)

   msg = ai.commit_message (prompts.commit (combined, whisper=whisper))

   console.label ("Previous")
   console.item (last_msg)
   console.out.print ()

   git.stage (all=True)

   if yes:
      console.item (msg)
      git.commit (msg, amend=True)
   else:
      choice = console.review (msg)

      if choice == "Edit":
         msg = console.edit (msg)
         if not msg.strip ():
            console.muted ("Empty message, cancelled")
            raise typer.Exit (0)
         git.commit (msg, amend=True)
      elif choice == "Yes":
         git.commit (msg, amend=True)
      else:
         console.muted ("Cancelled")
         raise typer.Exit (0)

   console.success ("Amended")
   console.hint ("imp commit again, or imp release when ready")
