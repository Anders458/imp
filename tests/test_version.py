import pytest

from imp.version import bump, changelog_from_commits


class TestBump:

   @pytest.mark.parametrize ("current, level, expected", [
      ("1.2.3", "patch", "1.2.4"),
      ("1.2.3", "minor", "1.3.0"),
      ("1.2.3", "major", "2.0.0"),
      ("0.0.0", "patch", "0.0.1"),
      ("1.2.3", "5.0.0", "5.0.0"),
      ("not-a-version", "patch", "patch"),
      ("99.99.99", "patch", "99.99.100"),
      ("2.5.8", "major", "3.0.0"),
      ("2.5.8", "minor", "2.6.0"),
   ])
   def test_bump (self, current, level, expected):
      assert bump (current, level) == expected


class TestChangelogFromCommits:

   def test_feat (self):
      result = changelog_from_commits ("feat: add login page")
      assert "### Added" in result
      assert "Add login page" in result

   def test_fix (self):
      result = changelog_from_commits ("fix: resolve crash on startup")
      assert "### Fixed" in result
      assert "Resolve crash on startup" in result

   def test_other_types (self):
      result = changelog_from_commits ("refactor: simplify auth flow")
      assert "### Changed" in result
      assert "Simplify auth flow" in result

   def test_mixed (self):
      subjects = "feat: add dark mode\nfix: resolve null pointer\nchore: update deps"
      result = changelog_from_commits (subjects)
      assert "### Added" in result
      assert "### Fixed" in result
      assert "### Changed" in result

   def test_non_conventional (self):
      result = changelog_from_commits ("some random commit")
      assert "### Changed" in result
      assert "Some random commit" in result

   def test_strips_hash_prefix (self):
      result = changelog_from_commits ("abc1234 feat: add feature")
      assert "### Added" in result
      assert "Add feature" in result

   def test_empty (self):
      result = changelog_from_commits ("")
      assert result == ""

   def test_scoped_commit (self):
      result = changelog_from_commits ("feat(auth): add oauth support")
      assert "### Added" in result
      assert "Add oauth support" in result
