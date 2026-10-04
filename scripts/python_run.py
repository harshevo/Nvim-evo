import importlib.machinery
import os
import runpy
import sys


def fresh_project_imports(root):
    root = os.path.realpath(root)
    original = importlib.machinery.SourceFileLoader.get_code

    def get_code(loader, fullname):
        path = os.path.realpath(loader.path)
        try:
            local = os.path.commonpath([root, path]) == root
        except ValueError:
            local = False
        relative = os.path.relpath(path, root).split(os.sep)
        if local and not any(part in {".venv", "venv", "env", "site-packages"} for part in relative):
            return loader.source_to_code(loader.get_data(loader.path), loader.path)
        return original(loader, fullname)

    importlib.machinery.SourceFileLoader.get_code = get_code


def main():
    root, mode, target, *args = sys.argv[1:]
    fresh_project_imports(root)
    if mode == "file":
        sys.argv = [target, *args]
        sys.path[0] = os.path.dirname(os.path.abspath(target))
        runpy.run_path(target, run_name="__main__")
    elif mode == "module":
        sys.argv = [target, *args]
        sys.path[0] = os.getcwd()
        runpy.run_module(target, run_name="__main__", alter_sys=True)


if __name__ == "__main__":
    main()
