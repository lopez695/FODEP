ALTER TABLE counterparties ADD COLUMN country_rating TEXT NOT NULL DEFAULT 'Non noté';

UPDATE counterparties
SET country_rating = 'Non noté'
WHERE country_rating IS NULL OR TRIM(country_rating) = '';
