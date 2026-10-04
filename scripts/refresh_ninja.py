"""Invalidate only editor-saved dependencies, including saves within one timestamp tick."""
import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

build = Path(sys.argv[1]).resolve()
changed = {Path(path).resolve() for path in sys.argv[2:]}
commands_path = build / 'compile_commands.json'
if not changed or not commands_path.exists():
    sys.exit(0)

result = subprocess.run(['ninja', '-C', str(build), '-t', 'deps'], capture_output=True, text=True, check=True)
deps = {}
current = None
for line in result.stdout.splitlines():
    match = re.match(r'^(.+): #deps \d+', line)
    if match:
        current = (build / match[1]).resolve()
        deps[current] = set()
    elif current and line.startswith('    '):
        deps[current].add((build / line.strip()).resolve())

removed = set()
for command in json.loads(commands_path.read_text()):
    args = command.get('arguments') or shlex.split(command.get('command', ''))
    output = command.get('output')
    if not output and '-o' in args:
        output = args[args.index('-o') + 1]
    if not output:
        continue
    obj = (Path(command['directory']) / output).resolve()
    source = (Path(command['directory']) / command['file']).resolve()
    dependencies = deps.get(obj, {source}) | {source}
    if dependencies & changed and obj.is_relative_to(build) and obj.suffix in ('.o', '.obj'):
        obj.unlink(missing_ok=True)
        target = re.search(r'/CMakeFiles/(.+?)\.dir/', str(obj))
        if target:
            removed.add(target[1])

reply = build / '.cmake/api/v1/reply'
indices = sorted(reply.glob('index-*.json'))
if not removed or not indices:
    sys.exit(0)
index = json.loads(indices[-1].read_text())
model = next((entry for entry in index.get('objects', []) if entry.get('kind') == 'codemodel'), None)
if model is None:
    sys.exit(0)
configuration = json.loads((reply / model['jsonFile']).read_text())['configurations'][0]
targets = [json.loads((reply / entry['jsonFile']).read_text()) for entry in configuration['targets']]
affected = {target['id'] for target in targets if target['name'] in removed}
while True:
    dependents = {target['id'] for target in targets if any(item['id'] in affected for item in target.get('dependencies', []))}
    if dependents <= affected:
        break
    affected |= dependents
for target in targets:
    if target['id'] not in affected:
        continue
    for artifact in target.get('artifacts', []):
        path = (build / artifact['path']).resolve()
        if path.is_relative_to(build) and not path.is_dir():
            path.unlink(missing_ok=True)
