from pathlib import Path
import runpy
import sys
import tracemalloc
from python_run import fresh_project_imports

root, filename, *args = sys.argv[1:]
fresh_project_imports(root)
sys.argv = [filename, *args]
sys.path[0] = str(Path(filename).parent)
tracemalloc.start(10)
print("Backend: Python tracemalloc\nRetained allocations are not by themselves proof of a leak.\n", flush=True)
try:
    runpy.run_path(filename, run_name="__main__")
finally:
    current, peak = tracemalloc.get_traced_memory()
    print(f"\nCurrent traced memory: {current:,} bytes\nPeak traced memory: {peak:,} bytes\n")
    snapshot = tracemalloc.take_snapshot().filter_traces([
        tracemalloc.Filter(True, str(Path(root) / "*")),
        tracemalloc.Filter(False, str(Path(root) / ".venv" / "*")),
        tracemalloc.Filter(False, str(Path(root) / "venv" / "*")),
    ])
    for stat in snapshot.statistics("lineno")[:30]:
        frame = stat.traceback[0]
        print(f"{frame.filename}:{frame.lineno}: {stat.size:,} bytes in {stat.count} blocks")
