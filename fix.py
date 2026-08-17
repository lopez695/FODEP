import sys

content = open('C:/DOSSIER TRAVAIL/DOSSIER TRAVAIL/OUTIL_FODEP/FODEP/frontend/lib/modules/risque_operationnel/widgets/ro_import_bic_dialog.dart', 'r', encoding='utf-8').read()

content = content.replace("\\'", "'")
content = content.replace("_buildModeSelector(),", "")

open('C:/DOSSIER TRAVAIL/DOSSIER TRAVAIL/OUTIL_FODEP/FODEP/frontend/lib/modules/risque_operationnel/widgets/ro_import_bic_dialog.dart', 'w', encoding='utf-8').write(content)
