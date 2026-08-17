import urllib.request, json
try:
    response = urllib.request.urlopen('http://127.0.0.1:8000/api/v1/expositions/EXP-2026-0153/suivi')
    data = json.loads(response.read())
    print("WITH API V1:")
    print("date_octroi:", data.get('date_octroi'))
    print("grant_date:", data.get('grant_date'))
except Exception as e:
    print("API V1 error:", e)

try:
    response = urllib.request.urlopen('http://127.0.0.1:8000/expositions/EXP-2026-0153/suivi')
    data = json.loads(response.read())
    print("WITHOUT API V1:")
    print("date_octroi:", data.get('date_octroi'))
    print("grant_date:", data.get('grant_date'))
except Exception as e:
    print("WITHOUT API V1 error:", e)
