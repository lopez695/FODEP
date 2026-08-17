import sys

with open('lib/core/services/rwa_api_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove the pieafp_models import
content = content.replace("import '../../modules/icap/models/pieafp_models.dart';", "")

# Find where the PIEAFP section starts
# Use a partial match for 'PIEAFP' in a comment
marker = "PIEAFP (Pilier 2"
idx = content.find(marker)

if idx != -1:
    # Find the preceding '//' to get the start of the section comment
    start_idx = content.rfind('//', 0, idx)
    if start_idx != -1:
        # Find the last closing brace in the file
        last_brace = content.rfind('}')
        if last_brace != -1:
            # We want to remove from start_idx up to last_brace
            content = content[:start_idx] + "\n}\n"

with open('lib/core/services/rwa_api_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Done removing PIEAFP section!')
