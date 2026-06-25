from pathlib import Path
root = Path('lib')
files = []
for path in sorted(root.rglob('*.dart')):
    text = path.read_text(encoding='utf-8', errors='ignore')
    if 'localizationServiceProvider' in text and 'core/providers/providers.dart' not in text:
        files.append(path)

print('files to fix:', len(files))
for path in files:
    rel = path.parent.relative_to(root)
    # compute relative path from file to lib/core/providers/providers.dart
    relative_import = Path(*(['..'] * len(rel.parts))) / 'core' / 'providers' / 'providers.dart'
    import_line = f"import '{relative_import.as_posix()}';\n"
    marker = "import 'package:flutter_riverpod/flutter_riverpod.dart';\n"
    text = path.read_text(encoding='utf-8', errors='ignore')
    if marker in text:
        if import_line not in text:
            text = text.replace(marker, marker + import_line)
            path.write_text(text, encoding='utf-8')
            print('patched', path, '->', import_line.strip())
        else:
            print('already has import', path)
    else:
        print('ERROR missing flutter_riverpod import in', path)
