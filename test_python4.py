import xlsxwriter
from io import BytesIO

def build_fonds_propres_import_template() -> bytes:
    out = BytesIO()
    workbook = xlsxwriter.Workbook(out)
    worksheet = workbook.add_worksheet('Fonds propres')
    
    worksheet.write('A1', 'Test')
    
    workbook.close()
    return out.getvalue()

if __name__ == "__main__":
    with open("test_python4.xlsx", "wb") as f:
        f.write(build_fonds_propres_import_template())
