import sys

with open('temp_api.dart', 'r', encoding='utf-16') as f:
    temp_content = f.read()

# Extract from 'Future<OpRiskInput> fetchBicInput' to the end
marker = 'Future<OpRiskInput> fetchBicInput'
idx = temp_content.find(marker)

# Backtrack to the start of the comment
comment = '//'
comment_idx = temp_content.rfind(comment, 0, idx)
extracted = temp_content[comment_idx:temp_content.rfind('}')]

with open('lib/core/services/rwa_api_service.dart', 'r', encoding='utf-8') as f:
    api_content = f.read()

idx_last_brace = api_content.rfind('}')
new_api_content = api_content[:idx_last_brace] + '\n  ' + extracted + '\n}\n'

with open('lib/core/services/rwa_api_service.dart', 'w', encoding='utf-8') as f:
    f.write(new_api_content)
print('Done!')
