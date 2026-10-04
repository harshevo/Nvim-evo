import json
import sys
from pathlib import Path


class EditorReport:
    def __init__(self):
        self.tests = []
        self.failures = []

    def pytest_collection_finish(self, session):
        self.tests = [{"id": item.nodeid, "file": str(item.path),
                       "line": item.location[1] + 1} for item in session.items]

    def pytest_runtest_logreport(self, report):
        if report.failed:
            crash = getattr(report.longrepr, "reprcrash", None)
            self.failures.append({"id": report.nodeid,
                                  "file": str(crash.path) if crash else report.location[0],
                                  "line": crash.lineno if crash else report.location[1] + 1})


def main():
    report_path = Path(sys.argv[1])
    from python_run import fresh_project_imports
    sys.path.insert(0, str(Path.cwd()))
    fresh_project_imports(str(Path.cwd()))
    try:
        import pytest
    except ImportError:
        print("pytest is missing in this Python environment. Use :PyTestInstall to install it.")
        return 4
    import _pytest.assertion.rewrite as rewrite
    import os
    root = os.path.realpath(Path.cwd())
    read_pyc = rewrite._read_pyc

    def fresh_test_code(source, *args, **kwargs):
        path = os.path.realpath(source)
        relative = os.path.relpath(path, root).split(os.sep)
        if os.path.commonpath([root, path]) == root and not any(
            part in {".venv", "venv", "env", "site-packages"} for part in relative
        ):
            return None
        return read_pyc(source, *args, **kwargs)

    rewrite._read_pyc = fresh_test_code
    reporter = EditorReport()
    try:
        return int(pytest.main(sys.argv[2:], plugins=[reporter]))
    finally:
        report_path.write_text(json.dumps({"tests": reporter.tests, "failures": reporter.failures}))


if __name__ == "__main__":
    sys.exit(main())
