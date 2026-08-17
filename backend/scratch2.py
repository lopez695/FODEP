import sys
sys.path.append('C:/DOSSIER TRAVAIL/DOSSIER TRAVAIL/OUTIL_FODEP/FODEP/backend')
import json
from app.dashboard.services import get_dashboard_snapshot

snapshot = get_dashboard_snapshot()
for m in snapshot.metrics:
    if "levier" in m.key or "cet1" in m.key or "tier1" in m.key or "solvabilite" in m.key:
        print(f"{m.key} -> {m.value}")
