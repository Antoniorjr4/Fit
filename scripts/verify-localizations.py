#!/usr/bin/env python3
"""Check resource parity, format arguments and UI lookup coverage before Xcode."""
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
resources = root / 'ios/FitLambda/Localization'
expected_languages = {'pt-BR', 'en', 'es', 'fr', 'de', 'it'}
tables = {}
entry = re.compile(r'("(?:[^"\\]|\\.)*")\s*=\s*("(?:[^"\\]|\\.)*");')
for path in sorted(resources.glob('*.lproj/Localizable.strings')):
    table = {}
    for line_number, line in enumerate(path.read_text().splitlines(), 1):
        if not line.strip() or line.lstrip().startswith('/*'):
            continue
        match = entry.fullmatch(line)
        assert match, f'{path}:{line_number}: invalid string entry'
        key, value = map(json.loads, match.groups())
        assert key not in table, f'{path}: duplicate {key}'
        assert value.strip(), f'{path}: empty {key}'
        table[key] = value
    tables[path.parent.stem] = table
assert set(tables) == expected_languages, 'Language/resource mismatch'
base = tables['en']
for language, table in tables.items():
    assert table.keys() == base.keys(), f'{language}: missing or extra keys'
    for key, value in table.items():
        assert value.count('%@') == base[key].count('%@'), f'{language}: format mismatch in {key}'
        assert '%' not in value.replace('%@', '').replace('%%', ''), f'{language}: unsafe format in {key}'
        assert value != key, f'{language}: untranslated resource key {key}'

keys = set()
for path in (root / 'ios/FitLambda').glob('*.swift'):
    keys.update(re.findall(r'\.(?:t|text)\("([^"\\]+)"', path.read_text()))
keys.update(['language.continue', 'language.save', 'pairing.finish', 'pairing.next',
             'state.retry', 'state.reviewPermission', 'state.guidance', 'state.searchAgain',
             'state.reconnect', 'empty.connect'])
keys.update(f'sheet.{kind}.title' for kind in ['goal', 'heart', 'sleep', 'welcome', 'pairing', 'faces', 'health', 'privacy', 'sync', 'name'])
keys.update(f'pairing.{part}.{step}' for part in ['title', 'body'] for step in range(3))
keys.update(f'empty.{kind}.{part}' for kind in ['today', 'trends', 'sleep'] for part in ['title', 'body'])
keys.update(f'state.{state}.{part}' for state in ['standard', 'firstUse', 'permissionNeeded', 'permissionDenied', 'bluetoothOff', 'notFound', 'disconnected', 'syncFailed', 'partial'] for part in ['title', 'body'])
assert keys <= base.keys(), f'Missing UI keys: {sorted(keys - base.keys())}'
print(f'Localization integrity passed: {len(tables)} languages, {len(base)} keys each; format arguments and UI keys match.')
