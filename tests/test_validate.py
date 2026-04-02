import pytest

from imp import validate


class TestCommit:

   @pytest.mark.parametrize ("msg", [
      "feat: add login page",
      "fix: resolve null pointer",
      "refactor(auth): simplify token flow",
      "build: IMP-123 update deploy script",
      "chore!: drop node 14 support",
   ])
   def test_valid (self, msg):
      assert validate.commit (msg)

   @pytest.mark.parametrize ("msg", [
      "Add login page",
      "FEAT: uppercase type",
      "feat:",
      "feat:missing space",
      "feat: Uppercase description",
   ])
   def test_invalid (self, msg):
      assert not validate.commit (msg)


class TestBranch:

   @pytest.mark.parametrize ("name", [
      "main",
      "feat/my-feature",
      "fix/bug-123",
      "release/1.0.0",
   ])
   def test_valid (self, name):
      assert validate.branch (name)

   @pytest.mark.parametrize ("name", [
      "feat/my feature",
      "feat;rm -rf",
      "-delete",
   ])
   def test_invalid (self, name):
      assert not validate.branch (name)
