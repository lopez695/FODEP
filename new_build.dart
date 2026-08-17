  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _CarteVar(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        \'Méthode de la VaR historique\',
                        style: TextStyle(
                          color: _varNavy,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        \'Aucune loi de probabilité n\\\'est supposée. On observe ce \'
                        \'que le portefeuille a réellement perdu, séance après \'
                        \'séance, puis on lit directement dans cette série le seuil \'
                        \'qui n\\\'a été dépassé que dans 1 % des cas.\',
                        style: TextStyle(
                          color: _varMuted,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 16),
                      _EtapeMethodologie(
                        numero: 1,
                        titre: \'Reconstituer la série des variations\',
                        texte: \'Pour chaque séance de la fenêtre, on revalorise le \'
                            \'portefeuille ACTUEL avec les prix de la veille, puis \'
                            \'avec ceux du jour. La différence est le gain ou la \'
                            \'perte qu\\\'il aurait subi ce jour-là. La composition ne \'
                            \'change jamais : seuls les prix bougent.\',
                      ),
                      _EtapeMethodologie(
                        numero: 2,
                        titre: \'Classer les pertes, de la plus lourde à la plus \'
                            \'légère\',
                        texte: \'Les gains restent dans la série mais se retrouvent \'
                            \'en fin de classement : ils ne jouent aucun rôle dans \'
                            \'le seuil de perte.\',
                      ),
                      _EtapeMethodologie(
                        numero: 3,
                        titre: \'Lire la perte au rang correspondant au seuil\',
                        texte: \'À 99 % sur 250 séances, le rang vaut \'
                            \'250 × (1 − 0,99) = 2,5, arrondi à 3. La VaR est la \'
                            \'troisième perte du classement. Arrondir vers le haut \'
                            \'est le choix prudent : il retient une perte plus \'
                            \'lourde, jamais plus légère.\',
                      ),
                      SizedBox(height: 4),
                      _EncadreFormule(
                        formule: \'VaR = perte de rang ⌈n × (1 − c)⌉\',
                        legende: \'n = nombre de séances observées, \'
                            \'c = niveau de confiance\',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const _CarteVar(
                  padding: EdgeInsets.all(18),
                  color: _varSurfaceSoft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        \'Ce que la méthode exige, et pourquoi elle est inactive ici\',
                        style: TextStyle(
                          color: _varNavy,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 10),
                      _PointExigence(
                        texte: \'Une série de prix observés, une valeur par séance et \'
                            \'par titre. Les titres publics de la zone étant émis par \'
                            \'adjudication et non cotés en continu, cette série \'
                            \'n\\\'existe pas dans les fichiers dont nous disposons.\',
                      ),
                      _PointExigence(
                        texte: \'Une profondeur suffisante : 250 séances au minimum. \'
                            \'En deçà, le rang du quantile tombe sur les toutes \'
                            \'premières observations et la VaR se confond avec la \'
                            \'perte maximale de l\\\'échantillon.\',
                      ),
                      _PointExigence(
                        texte: \'Une composition figée sur toute la fenêtre. Une \'
                            \'ligne entrée en portefeuille il y a trois mois n\\\'a pas \'
                            \'d\\\'historique sur les neuf précédents : elle doit être \'
                            \'reconstituée à partir d\\\'un titre de référence, ou \'
                            \'écartée.\',
                      ),
                      SizedBox(height: 12),
                      Text(
                        \'Tant que ces conditions ne sont pas réunies, l\\\'onglet \'
                        \'reste inactif. Publier un quantile calculé sur une série \'
                        \'reconstituée reviendrait à présenter comme observé un \'
                        \'chiffre qui ne l\\\'est pas. Les VaR paramétrique et \'
                        \'Monte-Carlo, elles, n\\\'ont pas besoin d\\\'historique : elles \'
                        \'partent d\\\'une volatilité et d\\\'une hypothèse de \'
                        \'distribution, et restent disponibles.\',
                        style: TextStyle(
                          color: _varMuted,
                          fontSize: 12.5,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SingleChildScrollView(
            child: _CarteVar(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(
                        child: Text(
                          \'Cas chiffré, de bout en bout\',
                          style: TextStyle(
                            color: _varNavy,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _varOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          \'Données d\\\'illustration\',
                          style: TextStyle(
                            color: Color(0xFFB45309),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    \'Portefeuille de 12,4 Md FCFA, fenêtre de 250 séances, \'
                    \'niveau de confiance 99 %. Voici les dix pires séances de \'
                    \'la fenêtre, en millions de FCFA :\',
                    style: TextStyle(
                      color: _varMuted,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TableauPertesClassees(
                    pertes: _pertesTriees,
                    rangRetenu: _rang,
                  ),
                  const SizedBox(height: 14),
                  const _EncadreFormule(
                    formule: \'Rang = ⌈250 × (1 − 0,99)⌉ = ⌈2,5⌉ = 3\',
                    legende: \'La VaR est donc la 3ᵉ perte du classement\',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ResultatCas(
                          libelle: \'VaR 99 % à 1 jour\',
                          valeur: \'\ M FCFA\',
                          note: \'3ᵉ perte du classement\',
                          couleur: _varDanger,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ResultatCas(
                          libelle: \'Perte moyenne au-delà du seuil\',
                          valeur:
                              \'\ M FCFA\',
                          note: \'Moyenne des rangs 1 à 3\',
                          couleur: _varOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    \'Lecture : sur les 250 séances observées, deux seulement ont \'
                    \'coûté plus de \ M FCFA. Un jour de \'
                    \'marché sur cent, la perte dépasse ce seuil ; ces jours-là, \'
                    \'elle s\\\'est élevée à \'
                    \'\ M FCFA en \'
                    \'moyenne. La VaR dit à partir de quel montant on entre dans \'
                    \'le 1 % défavorable, jamais jusqu\\\'où la perte peut aller : \'
                    \'c\\\'est le rôle de la seconde mesure.\',
                    style: const TextStyle(
                      color: _varNavy,
                      fontSize: 12.5,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }