from pathlib import Path
root = Path('lib')
missing = []
for path in sorted(root.rglob('*.dart')):
    text = path.read_text(encoding='utf-8', errors='ignore')
    if 'localizationServiceProvider' in text:
        if 'core/providers/providers.dart' not in text and 'providers/providers.dart' not in text:
            missing.append(path)
print('missing count:', len(missing))
for path in missing:
    print(path)
