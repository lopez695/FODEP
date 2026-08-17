import re

def remove_dead_code():
    path = r'C:\DOSSIER TRAVAIL\DOSSIER TRAVAIL\OUTIL_FODEP\FODEP\frontend\lib\core\services\rwa_api_service.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # We will remove if (true) { and its matching }.
    # And we will remove EVERYTHING after the } until the end of the enclosing block.
    # This is slightly hard, so let's just write a Python script that replaces if (true) {\n with \n,
    # then removes the closing brace of that block, and removes the dead lines.
    
    # Actually, a much safer regex since the dead code is standard:
    # return _withDelay(_buildMockDashboard());
    content = re.sub(r'\s*return _withDelay\([^;]*;\n', '\n', content)
    content = re.sub(r'\s*return _nextExposureId\(\);\n', '\n', content)
    content = re.sub(r'\s*_expositionsFuture = null;\n', '\n', content)
    content = re.sub(r'\s*_reportsFuture = null;\n', '\n', content)
    content = re.sub(r'\s*return createExposure\(draft\);\n', '\n', content)
    content = re.sub(r'\s*return fetchDashboard\(\);\n', '\n', content)
    
    # Remove all if (true) { and the matching brace? Let's just do it manually.
    content = content.replace('if (true) {\n', '\n')
    content = content.replace('if (false) {\n', 'if (false) { //\n') # keep it but make it obviously dead
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

remove_dead_code()
