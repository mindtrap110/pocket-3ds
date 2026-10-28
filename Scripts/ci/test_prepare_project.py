import importlib.util
from pathlib import Path
import tempfile
import unittest


SPEC = importlib.util.spec_from_file_location('prepare_project', Path(__file__).with_name('prepare_project.py'))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class PrepareProjectTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.base = self.root / 'ManicEmu/ManicEmu/Resources/Config-Base.xcconfig'
        self.helper = self.base.with_name('JITEnablerExtension.xcconfig')
        self.project = self.root / 'ManicEmu/ManicEmu.xcodeproj/project.pbxproj'
        self.base.parent.mkdir(parents=True)
        self.project.parent.mkdir(parents=True)
        self.base.write_text('APP_BUNDLE_IDENTIFIER = com.aoshuang.manicemu\nAPP_VERSION = 2.0.1\n')
        self.helper.write_text('PRODUCT_BUNDLE_IDENTIFIER = com.aoshuang.manicemu.JITEnabler\n')
        self.project.write_text('PRODUCT_BUNDLE_IDENTIFIER = com.aoshuang.manicemu.JITEnabler;\n' * 3)

    def snapshot(self):
        return [p.read_bytes() for p in (self.base, self.helper, self.project)]

    def test_matching_host_and_helper_ids_and_idempotency(self):
        MODULE.prepare(self.root, 'io.github.example.pocket3ds')
        self.assertIn('APP_BUNDLE_IDENTIFIER = io.github.example.pocket3ds\n', self.base.read_text())
        self.assertIn('APP_VERSION = 2.0.1', self.base.read_text())
        self.assertIn('io.github.example.pocket3ds.JITEnabler', self.helper.read_text())
        self.assertEqual(self.project.read_text().count('io.github.example.pocket3ds.JITEnabler'), 3)
        first = self.snapshot()
        MODULE.prepare(self.root, 'io.github.example.pocket3ds')
        self.assertEqual(first, self.snapshot())

    def test_upstream_structure_change_fails_before_any_write(self):
        self.project.write_text(self.project.read_text().replace('PRODUCT_BUNDLE_IDENTIFIER', 'CHANGED', 1))
        before = self.snapshot()
        with self.assertRaises(ValueError):
            MODULE.prepare(self.root, 'io.github.example.pocket3ds')
        self.assertEqual(before, self.snapshot())

    def test_missing_base_setting_fails_before_any_write(self):
        self.base.write_text('APP_VERSION = 2.0.1\n')
        before = self.snapshot()
        with self.assertRaises(ValueError):
            MODULE.prepare(self.root, 'io.github.example.pocket3ds')
        self.assertEqual(before, self.snapshot())

    def test_invalid_or_original_identity_is_rejected(self):
        for bundle_id in ('com.aoshuang.manicemu', 'bad id', '*.example.app', 'app', 'com.example;touch'):
            with self.subTest(bundle_id=bundle_id), self.assertRaises(ValueError):
                MODULE.prepare(self.root, bundle_id)


if __name__ == '__main__':
    unittest.main()
