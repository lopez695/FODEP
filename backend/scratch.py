import sqlite3
import json

conn = sqlite3.connect('C:/DOSSIER TRAVAIL/DOSSIER TRAVAIL/OUTIL_FODEP/FODEP/backend/data/rwa_data.db')
c = conn.cursor()

c.execute('SELECT capital_ordinaire, reserves, resultats_report, resultat_eligible, deductions_prud_cet1, instruments_at1, primes_emission_at1, deductions_prud_at1 FROM fonds_propres ORDER BY date_analyse DESC LIMIT 1')
fp = c.fetchone()
cet1 = fp[0] + fp[1] + fp[2] + fp[3] - fp[4]
at1 = fp[5] + fp[6] - fp[7]
tier1 = cet1 + at1

c.execute('SELECT gross_amount FROM exposures')
rows = c.fetchall()
gross_total = sum(r[0] for r in rows)
print(f'CET1: {cet1}')
print(f'AT1: {at1}')
print(f'Tier 1: {tier1}')
print(f'Gross Total (Exposition): {gross_total}')
print(f'Leverage Ratio: {(tier1 / gross_total) * 100}%')
