import sys

def fix_dead_code():
    path = r'C:\DOSSIER TRAVAIL\DOSSIER TRAVAIL\OUTIL_FODEP\FODEP\frontend\lib\core\services\rwa_api_service.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
        
    lines = content.split('\n')
    new_lines = []
    
    skip = False
    for line in lines:
        if 'return _withDelay(' in line or 'return _nextExposureId(' in line:
            skip = True
        
        if not skip:
            new_lines.append(line)
            
        if skip and line.strip().endswith(';'):
            skip = False
            
    content = '\n'.join(new_lines)
    
    # Also remove some dangling comments about mock
    import re
    content = re.sub(r'\s*// En mode démo[^\n]*', '', content)
    content = re.sub(r'\s*// Le hors bilan suit[^\n]*', '', content)
    
    # Let's remove the _withDelay function itself since it's only for mocks
    idx = content.find('Future<T> _withDelay<T>(T data, [Duration')
    if idx != -1:
        idx2 = content.find('}', content.find('{', idx)) + 1
        content = content[:idx] + content[idx2:]
        
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

fix_dead_code()
