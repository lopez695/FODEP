ALTER TABLE exposures ADD COLUMN sovereign_special_case TEXT NOT NULL DEFAULT '';

UPDATE exposures
SET sovereign_special_case = 'Cas préférentiel 0 % (historique)'
WHERE COALESCE(sovereign_preferential_zero_weight, 0) = 1
  AND COALESCE(TRIM(sovereign_special_case), '') = '';
