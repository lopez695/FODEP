-- Les fonds propres n'avaient pas d'exercice : `update_fonds_propres` relisait
-- la ligne la plus récente et l'écrasait, si bien que la table n'a jamais porté
-- plus d'un enregistrement. `date_analyse` n'y suffisait pas — c'est un
-- horodatage de saisie, pas le millésime déclaré : deux corrections du même
-- exercice y créaient deux dates sans jamais désigner l'exercice.
--
-- L'absence d'historique se paie ailleurs : les limites des EP36, EP37 et EP38
-- se mesurent, dit le formulaire, sur les fonds propres de l'EXERCICE
-- PRÉCÉDENT. Faute de les conserver, l'export les rapporte à ceux de
-- l'exercice déclaré et le signale en réserve. C'est aussi ce qui empêche de
-- déduire du CET1 l'excédent des limites franchies : mesurer sur les fonds
-- propres de l'année en cours rendrait la déduction circulaire — elle baisse
-- le CET1, qui relève le ratio, qui augmente l'excédent.

ALTER TABLE fonds_propres ADD COLUMN exercice INTEGER;

-- Reprise de l'existant : le millésime se déduit de l'horodatage de saisie,
-- seule information disponible. Une saisie faite en janvier pour l'exercice
-- clos l'année précédente sera donc rattachée à la mauvaise année — l'écran
-- permet de la corriger, et il n'y a qu'une ligne à reprendre.
UPDATE fonds_propres
   SET exercice = CAST(strftime('%Y', date_analyse) AS INTEGER)
 WHERE exercice IS NULL
   AND date_analyse IS NOT NULL;

-- Filet pour une ligne sans date exploitable.
UPDATE fonds_propres
   SET exercice = CAST(strftime('%Y', 'now') AS INTEGER)
 WHERE exercice IS NULL;

-- Un exercice, un enregistrement : c'est ce qui fait de la table un historique
-- plutôt qu'une pile de corrections. L'index rend l'unicité opposable, la
-- couche applicative se contentant sinon de faire confiance à son propre
-- upsert.
CREATE UNIQUE INDEX IF NOT EXISTS idx_fonds_propres_exercice
    ON fonds_propres (exercice);
