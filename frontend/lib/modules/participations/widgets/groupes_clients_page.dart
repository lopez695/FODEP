import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import 'concentration_groupes_page.dart';
import 'groupes_clients_card.dart';
import 'tableau_maison.dart';

/// Tous les groupes de clients liés, sans troncature.
///
/// La carte de l'onglet Portefeuille n'en montre que cinq : elle donne le ton
/// du portefeuille, pas son inventaire. Cette page porte la liste entière,
/// avec les mêmes gestes — créer, renommer, rattacher, détacher, supprimer —
/// et sans rien qui pousse le reste de l'écran vers le bas.
///
/// Elle se distingue de la page Concentration, qui pèse les groupes les uns
/// contre les autres : ici on constitue le périmètre, là on l'apprécie.
class GroupesClientsPage extends StatelessWidget {
  const GroupesClientsPage({super.key, required this.api});

  final RwaApiService api;

  static Future<void> ouvrir(BuildContext context, RwaApiService api) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => GroupesClientsPage(api: api)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 128,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: BoutonEnTete(
            icone: Icons.arrow_back,
            libelle: 'Retour',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        title: Text(
          'Groupes de clients liés',
          style: theme.textTheme.titleMedium?.copyWith(
            color: tableauEntete,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          // Consultation, pas saisie : la pastille discrète suffit. Le bouton
          // qui crée un groupe vit dans la carte, au-dessus du tableau.
          BoutonEnTete(
            icone: Icons.bar_chart_rounded,
            libelle: 'Analyse des concentrations',
            onPressed: () => ConcentrationGroupesPage.ouvrir(context, api),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
            children: [
              Text(
                'Un groupe existe pour additionner les risques portés sur des '
                'contreparties qu\'un même contrôle ou une même dépendance '
                'économique fait tomber ensemble. Sans groupe constitué, la '
                'division des risques traite chaque contrepartie isolément et '
                'sous-estime les concentrations.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              // La carte sans plafond ni en-tête : mêmes lignes, mêmes gestes,
              // mêmes dialogues. Reprendre le tableau ici en aurait fait une
              // seconde version à tenir à jour.
              GroupesClientsCard(
                api: api,
                limiteAffichage: null,
                afficherEntete: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

