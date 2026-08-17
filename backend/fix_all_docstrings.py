import os

backend_dir = 'C:/DOSSIER TRAVAIL/DOSSIER TRAVAIL/OUTIL_FODEP/FODEP/backend'
for root, dirs, files in os.walk(backend_dir):
    if '.venv' in root or '__pycache__' in root:
        continue
    for file in files:
        if file.endswith('.py'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            modified = False
            # Check for exactly 4 quotes """" or "\"\" at the start
            if content.startswith('\"\\\"\\\"'):
                content = '"""' + content[4:]
                modified = True
            elif content.startswith('"""\"'):
                content = '"""' + content[4:]
                modified = True
            
            # Check for inner """ and replace with """
            if '\\\"\\\"\\\"' in content:
                content = content.replace('\\\"\\\"\\\"', '"""')
                modified = True
                
            if modified:
                print(f'Fixed {filepath}')
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
