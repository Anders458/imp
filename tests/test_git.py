import subprocess

import pytest
import typer

from imp import git

from tests.conftest import git_run


class TestRequire:

   def test_passes_in_repo (self, repo):
      git.require ()

   def test_fails_outside_repo (self, tmp_path, monkeypatch):
      monkeypatch.chdir (tmp_path)
      with pytest.raises (typer.Exit):
         git.require ()


class TestDiff:

   def test_empty_when_clean (self, repo):
      assert git.diff (staged=True) == ""

   def test_staged_changes (self, repo):
      (repo / "file.txt").write_text ("changed\n")
      git_run (repo, "add", "file.txt")
      assert "changed" in git.diff (staged=True)

   def test_unstaged_changes (self, repo):
      (repo / "file.txt").write_text ("changed\n")
      assert "changed" in git.diff ()


class TestBranch:

   def test_returns_current (self, repo):
      assert git.branch () == "main"


class TestStage:

   def test_stage_all (self, repo):
      (repo / "new.txt").write_text ("new\n")
      git.stage (all=True)
      result = git_run (repo, "diff", "--cached", "--name-only")
      assert "new.txt" in result.stdout


class TestIsClean:

   def test_clean_repo (self, repo):
      assert git.is_clean ()

   def test_dirty_repo (self, repo):
      (repo / "file.txt").write_text ("dirty\n")
      assert not git.is_clean ()


class TestBaseBranch:

   def test_returns_main (self, repo):
      assert git.base_branch () == "main"

   def test_returns_master (self, repo):
      git_run (repo, "branch", "-m", "main", "master")
      assert git.base_branch () == "master"


class TestTagCommitMap:

   def test_returns_dict (self, repo):
      result = git.tag_commit_map ()
      assert isinstance (result, dict)

   def test_maps_tag_to_commit (self, repo):
      head = git.rev_parse ("HEAD")
      git.tag ("v1.0.0")
      result = git.tag_commit_map ()
      assert result ["v1.0.0"] == head


class TestLogFull:

   def test_returns_list (self, repo):
      result = git.log_full ()
      assert isinstance (result, list)
      assert len (result) >= 1

   def test_entry_has_fields (self, repo):
      result = git.log_full ()
      entry = result [0]
      assert "hash" in entry
      assert "subject" in entry
      assert "date" in entry

   def test_respects_since_hash (self, repo):
      subprocess.run ([ "git", "commit", "--allow-empty", "-m", "feat: second" ], check=True)
      first = git.log_full () [0] ["hash"]
      result = git.log_full (since=first)
      hashes = [ e ["hash"] for e in result ]
      assert first not in hashes


class TestTagWithRef:

   def test_tags_specific_commit (self, repo):
      subprocess.run ([ "git", "commit", "--allow-empty", "-m", "feat: second" ], check=True)
      first = git.log_full () [0] ["hash"]
      git.tag ("v1.0.0", ref=first)
      assert git.tag_exists ("v1.0.0")
      result = git.tag_commit_map ()
      assert result ["v1.0.0"] == first


class TestLogAfterDate:

   def test_returns_commit_after_date (self, repo):
      result = git.log_after_date ("2000-01-01")
      assert result != ""

   def test_returns_empty_for_future_date (self, repo):
      result = git.log_after_date ("2099-01-01")
      assert result == ""
