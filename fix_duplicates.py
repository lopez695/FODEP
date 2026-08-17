import os

directory = r'C:\DOSSIER TRAVAIL\DOSSIER TRAVAIL\OUTIL_FODEP\FODEP\frontend\lib'
count = 0

for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if 'addSemanticIndexes: false,addSemanticIndexes: false,' in content:
                content = content.replace('addSemanticIndexes: false,addSemanticIndexes: false,', 'addSemanticIndexes: false,')
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                count += 1

print(f'Fixed {count} files with duplicated arguments')
