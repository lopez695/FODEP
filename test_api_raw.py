import urllib.request, json
response = urllib.request.urlopen('http://127.0.0.1:8000/expositions/EXP-2026-0153/suivi')
data = json.loads(response.read())
print(data)
