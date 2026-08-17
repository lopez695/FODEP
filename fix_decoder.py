import os
import re

def fix_excel_dialog(filepath, expected_format_ui=None):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace package:excel/excel.dart with spreadsheet_decoder
    content = content.replace("import 'package:excel/excel.dart' hide Border;", "import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';")
    content = content.replace("import 'package:excel/excel.dart';", "import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';")
    
    # Replace Excel.decodeBytes with SpreadsheetDecoder.decodeBytes
    content = re.sub(r'final Excel excel;', 'final SpreadsheetDecoder excel;', content)
    content = re.sub(r'Excel excel;', 'SpreadsheetDecoder excel;', content)
    content = re.sub(r'Excel\.decodeBytes\(bytes\)', 'SpreadsheetDecoder.decodeBytes(bytes, update: true)', content)

    # In _cellStr, remove excel-specific types
    cell_str_replacement = """  static String _cellStr(dynamic cell) {
    if (cell == null) return '';
    return cell.toString().trim();
  }"""
    content = re.sub(r'static String _cellStr\(Data\? cell\)\s*\{[^}]*catch[^{]*\{[^}]*\}[^}]*\}', cell_str_replacement, content, flags=re.DOTALL)
    content = re.sub(r'static String _cellStr\(dynamic cell\)\s*\{[^}]*catch[^{]*\{[^}]*\}[^}]*\}', cell_str_replacement, content, flags=re.DOTALL)

    # In dashboard_fonds_propres, fix Sheet parsing
    if "Sheet? sheet;" in content:
        content = content.replace("Sheet? sheet;", "SpreadsheetTable? sheet;")
        content = re.sub(r'final candidate = excel\.tables\[key\];', r'final candidate = excel.tables[key];', content)
        
    if expected_format_ui:
        # replace the expected format section if needed
        pass

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

base_path = r"C:\DOSSIER TRAVAIL\DOSSIER TRAVAIL\OUTIL_FODEP\FODEP\frontend\lib\modules"
files = [
    os.path.join(base_path, r"dashboard\widgets\dashboard_fonds_propres_import_dialog.dart"),
    os.path.join(base_path, r"risque_operationnel\widgets\ro_import_bic_dialog.dart"),
    os.path.join(base_path, r"risque_operationnel\widgets\ro_import_pertes_dialog.dart"),
]

for file in files:
    if os.path.exists(file):
        fix_excel_dialog(file)
        print(f"Fixed {file}")
