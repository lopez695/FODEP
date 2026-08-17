import os

filepath = 'C:/DOSSIER TRAVAIL/DOSSIER TRAVAIL/OUTIL_FODEP/FODEP/frontend/lib/core/services/rwa_api_service.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

out = []
i = 0
while i < len(lines):
    line = lines[i]
    if 'final bool useMockData =' in line:
        i += 1
        continue
        
    if 'if (useMockData)' in line:
        depth = 1
        i += 1
        while i < len(lines) and depth > 0:
            depth += lines[i].count('{')
            depth -= lines[i].count('}')
            i += 1
        continue
        
    if 'if (!useMockData) {' in line:
        # Instead of parsing {}, I will just replace `if (!useMockData) {` with nothing
        # But wait, then we have an extra `}` at the end.
        # How to find the matching `}`?
        depth = 1
        j = i + 1
        last_brace_idx = -1
        while j < len(lines) and depth > 0:
            if '{' in lines[j]: depth += lines[j].count('{')
            if '}' in lines[j]: 
                depth -= lines[j].count('}')
                if depth == 0:
                    last_brace_idx = j
            j += 1
            
        if last_brace_idx != -1:
            # We found the block!
            # Add all lines inside the block without the wrapper
            for k in range(i + 1, last_brace_idx):
                # optionally remove one indent step (4 spaces)
                l = lines[k]
                if l.startswith('    '):
                    l = l[4:]
                elif l.startswith('\t'):
                    l = l[1:]
                out.append(l)
            i = last_brace_idx + 1
            continue

    out.append(line)
    i += 1

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(out)

print("Done cleaning useMockData!")
