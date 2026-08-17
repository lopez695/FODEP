CREATE TABLE IF NOT EXISTS reports (
    id TEXT PRIMARY KEY,
    created_at TEXT NOT NULL,
    period TEXT NOT NULL,
    report_type TEXT NOT NULL,
    currency TEXT NOT NULL,
    exposure_scope TEXT NOT NULL,
    include_category_chart INTEGER NOT NULL DEFAULT 1,
    include_rating_chart INTEGER NOT NULL DEFAULT 1,
    export_pdf_path TEXT NOT NULL,
    export_excel_path TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS report_lines (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    report_id TEXT NOT NULL,
    line_order INTEGER NOT NULL,
    source TEXT NOT NULL,
    item_id TEXT NOT NULL,
    counterparty TEXT NOT NULL,
    amount REAL NOT NULL,
    ead REAL NOT NULL,
    rwa REAL NOT NULL,
    capital REAL NOT NULL,
    FOREIGN KEY(report_id) REFERENCES reports(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_report_lines_report ON report_lines(report_id, line_order);
