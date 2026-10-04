import ast
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    ast.parse(path.read_bytes(), filename=str(path))
except SyntaxError as error:
    print(json.dumps({"file": str(path), "line": error.lineno or 1,
                      "col": error.offset or 1, "message": error.msg}))
    sys.exit(1)
except (OSError, ValueError) as error:
    print(json.dumps({"file": str(path), "line": 1, "col": 1, "message": str(error)}))
    sys.exit(1)
