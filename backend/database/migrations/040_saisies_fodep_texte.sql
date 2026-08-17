-- Les saisies du FODEP ne sont pas toutes des nombres.
--
-- L'attestation ADPE demande le nom de l'établissement, ceux des deux
-- responsables, leurs fonctions, téléphones et adresses électroniques, puis
-- les codes et dates de signature. Rien de tout cela ne vient de l'outil, et
-- rien de tout cela n'est un montant.
ALTER TABLE saisies_fodep ADD COLUMN texte TEXT;
