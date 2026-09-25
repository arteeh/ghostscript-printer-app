#!/usr/bin/env python3
"""Exercise promotion invariants using real, isolated Git histories."""
import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[1] / 'scripts/verify-promotion.sh'


class PromotionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = self.temp.name
        self.git('init', '-q')
        self.git('config', 'user.name', 'Promotion Test')
        self.git('config', 'user.email', 'promotion@example.invalid')
        self.base = self.commit('base')
        self.source = self.commit('source')

    def git(self, *args):
        return subprocess.check_output(
            ['git', *args], cwd=self.repo, text=True, stderr=subprocess.PIPE
        ).strip()

    def commit(self, content):
        pathlib.Path(self.repo, 'payload').write_text(content)
        self.git('add', 'payload')
        self.git('commit', '-qm', content)
        return self.git('rev-parse', 'HEAD')

    def check(self, base, source, merge):
        return subprocess.run(
            [str(SCRIPT), base, source, merge], cwd=self.repo,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )

    def test_exact_source_merge_passes(self):
        tree = self.git('rev-parse', self.source + '^{tree}')
        merge = self.git('commit-tree', tree, '-p', self.base,
                         '-p', self.source, '-m', 'promotion')
        result = self.check(self.base, self.source, merge)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(self.source, result.stdout)

    def test_stable_divergence_fails(self):
        self.git('checkout', '-q', '--detach', self.base)
        divergent = self.commit('stable-only change')
        self.assertNotEqual(self.check(divergent, self.source, self.source).returncode, 0)

    def test_changed_merge_tree_fails(self):
        changed = self.commit('untested merge change')
        self.assertNotEqual(self.check(self.base, self.source, changed).returncode, 0)

    def test_squashed_source_fails(self):
        tree = self.git('rev-parse', self.source + '^{tree}')
        squash = self.git('commit-tree', tree, '-p', self.base, '-m', 'squash')
        self.assertNotEqual(self.check(self.base, self.source, squash).returncode, 0)


if __name__ == '__main__':
    unittest.main()
