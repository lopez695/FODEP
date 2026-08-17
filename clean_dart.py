import re

path = r'C:\DOSSIER TRAVAIL\DOSSIER TRAVAIL\OUTIL_FODEP\FODEP\frontend\lib\core\services\rwa_api_service.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

mock_start = content.find('// ============================================================================')
if mock_start != -1 and 'MOCK' in content[mock_start:mock_start+500]:
    content = content[:mock_start] + '\n}\n'

content = re.sub(r'\s*this\.useMockData\s*=\s*true,?', '', content)
content = re.sub(r'final bool useMockData;', 'final bool useMockData = false;', content)

content = re.sub(r'\s*return _withDelay\([^;]*;\n', "\n    throw Exception('Mock data removed');\n", content)
content = re.sub(r'\s*return fetchDashboard\(\);\n', "\n    throw Exception('Mock data removed');\n", content)
content = re.sub(r'\s*return createExposure\(draft\);\n', "\n    throw Exception('Mock data removed');\n", content)

content = re.sub(r'\s*_expositionsFuture = null;\n', '\n', content)
content = re.sub(r'\s*_reportsFuture = null;\n', '\n', content)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
