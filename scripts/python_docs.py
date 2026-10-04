import ast
import pydoc
import sys
from pathlib import Path

name = sys.argv[1]
if len(sys.argv) > 2:
    try:
        tree = ast.parse(Path(sys.argv[2]).read_bytes())
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for alias in node.names:
                    local = alias.asname or alias.name.split(".")[0]
                    if name == local or name.startswith(local + "."):
                        name = (alias.name if alias.asname else local) + name[len(local):]
            elif isinstance(node, ast.ImportFrom) and node.module and node.level == 0:
                for alias in node.names:
                    local = alias.asname or alias.name
                    if name == local or name.startswith(local + "."):
                        name = node.module + "." + alias.name + name[len(local):]
    except (OSError, SyntaxError):
        pass
sys.path.insert(0, str(Path.cwd()))
try:
    target = pydoc.locate(name)
    if target is None:
        print(f"No runtime documentation for {name}. Use K for source documentation or :PyDoc module.symbol.")
        sys.exit(1)
    print(pydoc.render_doc(target, renderer=pydoc.plaintext))
except (ImportError, pydoc.ErrorDuringImport) as error:
    print(str(error))
    sys.exit(1)
