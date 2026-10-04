import dis
import sys
import types
from pathlib import Path

path = Path(sys.argv[1])
line = int(sys.argv[2])
root = compile(path.read_bytes(), str(path), "exec")


def candidates(code):
    yield code
    for constant in code.co_consts:
        if isinstance(constant, types.CodeType):
            yield from candidates(constant)


matches = []
for code in candidates(root):
    starts = [number for _, number in dis.findlinestarts(code)]
    if starts and min(starts) <= line <= max(starts):
        matches.append(code)
selected = max(matches, key=lambda code: code.co_firstlineno) if matches else root
print(f"Saved source: {path}:{line}\nCode object: {selected.co_name}\n")
dis.dis(selected)
