import sqlite3
from app.core.runtime_paths import ensure_seed_data_file

db = ensure_seed_data_file('rwa_data.db')
conn = sqlite3.connect(db)
conn.execute("UPDATE expositions SET date_octroi='2024-01-01', date_echeance='2027-12-31' WHERE id='EXP-2026-0153'")
conn.commit()
print("Updated successfully.")
