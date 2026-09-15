-- Ce que le derive couvre, ou sur quoi il porte.
--
-- Un derive se pense d'abord par ce a quoi il se rattache : le credit d'un
-- client qu'il couvre, une obligation ou une action que la banque detient. La
-- contrepartie, elle, reste celui qui a SIGNE le contrat -- c'est elle que
-- l'EP11 ventile, et c'est sa notation qui fixera la ponderation. Les deux ne
-- coincident que pour la couverture d'un credit : le client qui emprunte est
-- aussi celui qui signe le swap.
--
-- `sous_jacent_type` : « credit », « obligation », « action » ou « autre » (une
-- devise, un indice, une matiere premiere sans position detenue).
-- `sous_jacent_ref` : l'identifiant de l'exposition, l'ISIN ou le ticker.
-- `sous_jacent_libelle` : recopie lisible a l'enregistrement, pour que le
-- contrat reste lisible si la position sort du portefeuille.

ALTER TABLE derives ADD COLUMN sous_jacent_type TEXT;
ALTER TABLE derives ADD COLUMN sous_jacent_ref TEXT;
ALTER TABLE derives ADD COLUMN sous_jacent_libelle TEXT;
