import urllib.request, re

req = urllib.request.Request('https://www.umoatitres.org/fr/ressources-2/courbe-des-taux/', headers={'User-Agent': 'Mozilla/5.0 (compatible; FODEP/1.0)'})
html = urllib.request.urlopen(req).read().decode('utf-8', 'ignore')
liens = re.findall(r'https://[^\'\"\s]+[Cc]ourbe[s]?-?[- ]?[Dd]e-?[- ]?[Tt]aux[^\'\"\s]+\.xlsx', html)
print('\n'.join(set(liens)))
