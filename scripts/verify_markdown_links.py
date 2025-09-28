#!/usr/bin/env python3
import os, re, sys

errors = 0
link_re = re.compile(r'\[[^\]]+\]\(([^)]+)\)')

for root, _, files in os.walk('.'):
  if root.startswith('./archive'):
    continue
  for f in files:
    if not f.endswith('.md'):
      continue
    p = os.path.join(root, f)
    try:
      with open(p, 'r', encoding='utf-8', errors='ignore') as fh:
        for i, line in enumerate(fh, 1):
          for m in link_re.finditer(line):
            target = m.group(1)
            if '://' in target or target.startswith('#') or target.startswith('mailto:'):
              continue
            q = os.path.normpath(os.path.join(root, target))
            if not os.path.exists(q):
              print(f"Broken link {p}:{i} -> {target}")
              errors += 1
    except Exception as e:
      print(f"Error reading {p}: {e}")

if errors:
  sys.exit(1)