import os

directory = r'C:\DOSSIER TRAVAIL\DOSSIER TRAVAIL\OUTIL_FODEP\FODEP\frontend\lib'
count = 0

for root, _, files in os.walk(directory):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if 'ListView.builder(' in content or 'ListView.separated(' in content:
                content = content.replace('ListView.builder(', 'ListView.builder(addSemanticIndexes: false,')
                content = content.replace('ListView.separated(', 'ListView.separated(addSemanticIndexes: false,')
                
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                count += 1

print(f'Updated {count} files')
