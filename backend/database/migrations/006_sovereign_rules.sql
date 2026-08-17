ALTER TABLE exposures ADD COLUMN sovereign_preferential_zero_weight INTEGER NOT NULL DEFAULT 0;
ALTER TABLE exposures ADD COLUMN sovereign_oce_established INTEGER NOT NULL DEFAULT 0;
ALTER TABLE exposures ADD COLUMN sovereign_oce_note TEXT NOT NULL DEFAULT '';
