/// Participations de l'établissement et groupes de clients liés.
///
/// Ces deux notions n'existaient pas dans l'application alors que le FODEP les
/// exige : les participations pour les états EP34 et EP35 et pour trois normes
/// de l'EP01, les groupes de clients liés pour l'EP30 et la division des
/// risques.
library;

/// Sections de l'EP34. L'ordre est celui du formulaire.
enum CategorieParticipation {
  etablissement('etablissement', 'Établissements de crédit'),
  assurance('assurance', 'Entreprises d\'assurances'),
  autreFinanciere('autre_financiere', 'Autres entités financières'),
  societeImmobiliere('societe_immobiliere', 'Sociétés immobilières'),
  entiteCommerciale('entite_commerciale', 'Entités commerciales');

  const CategorieParticipation(this.wire, this.label);

  final String wire;
  final String label;

  static CategorieParticipation fromWire(String value) =>
      CategorieParticipation.values.firstWhere(
        (categorie) => categorie.wire == value,
        orElse: () => CategorieParticipation.etablissement,
      );
}

/// Natures de lien rattachant une contrepartie à son groupe.
enum CategorieLien {
  controleDeDroit('controle_de_droit', 'Contrôle de droit'),
  controleDeFait('controle_de_fait', 'Contrôle de fait'),
  dependanceEconomique('dependance_economique', 'Dépendance économique');

  const CategorieLien(this.wire, this.label);

  final String wire;
  final String label;

  static CategorieLien? fromWire(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final lien in CategorieLien.values) {
      if (lien.wire == value) return lien;
    }
    return null;
  }
}

/// Catégories de parties liées, dans l'ordre des colonnes des états EP38 et
/// EP39. Une contrepartie sans catégorie n'est pas une partie liée.
enum CategoriePartieLiee {
  actionnaire('actionnaire', 'Actionnaire (≥ 10 %)'),
  organeDeliberant('organe_deliberant', "Membre de l'organe délibérant"),
  organeExecutif('organe_executif', "Membre de l'organe exécutif"),
  commissaireComptes('commissaire_comptes', 'Commissaire aux comptes'),
  personnelDirection('personnel_direction', 'Personnel de direction'),
  cadre('cadre', 'Cadre moyen ou supérieur'),
  personnelExecution('personnel_execution', "Personnel d'exécution"),
  autrePartieLiee('autre_partie_liee', 'Autre partie liée');

  const CategoriePartieLiee(this.wire, this.label);

  final String wire;
  final String label;

  static CategoriePartieLiee? fromWire(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final categorie in CategoriePartieLiee.values) {
      if (categorie.wire == value) return categorie;
    }
    return null;
  }
}

/// Secteurs d'activités proposés pour l'EP30.
///
/// Commodité de saisie, pas contrainte : une contrepartie dont le secteur n'y
/// figure pas se renseigne en clair, l'état n'attendant qu'un libellé. La même
/// liste alimente la colonne `Secteur_activite` du modèle d'import.
const List<String> secteursActivite = [
  'Agriculture, élevage, sylviculture',
  'Pêche et aquaculture',
  'Industries extractives',
  'Industries manufacturières',
  'Agro-industrie',
  'Électricité, gaz et eau',
  'Bâtiment et travaux publics',
  'Commerce de gros et de détail',
  'Transports et entreposage',
  'Hébergement et restauration',
  'Information et communication',
  'Activités financières et d\'assurance',
  'Activités immobilières',
  'Activités spécialisées, scientifiques et techniques',
  'Services administratifs et de soutien',
  'Administration publique',
  'Enseignement',
  'Santé humaine et action sociale',
  'Arts, spectacles et loisirs',
  'Autres services',
  'Ménages et particuliers',
];

/// Propose le prochain numéro Centrale des risques d'un groupe.
///
/// Le numéro est attribué par la Centrale des risques de la BCEAO : cette
/// suggestion ne fait que prolonger la série déjà saisie dans le groupe, en
/// reprenant son préfixe et sa longueur. Elle épargne une frappe, elle ne
/// dispense pas de vérifier le numéro réel.
///
/// Retourne une chaîne vide si le groupe ne porte encore aucun numéro
/// exploitable — mieux vaut ne rien proposer qu'inventer une série.
String suggererNumeroCentraleRisques(Iterable<String?> numerosExistants) {
  final motif = RegExp(r'^(.*?)(\d+)$');
  String prefixe = '';
  int plusGrand = 0;
  int largeur = 0;
  var trouve = false;

  for (final numero in numerosExistants) {
    final valeur = (numero ?? '').trim();
    if (valeur.isEmpty) continue;
    final correspondance = motif.firstMatch(valeur);
    if (correspondance == null) continue;
    final chiffres = correspondance.group(2)!;
    final valeurNumerique = int.parse(chiffres);
    if (!trouve || valeurNumerique > plusGrand) {
      prefixe = correspondance.group(1)!;
      plusGrand = valeurNumerique;
      largeur = chiffres.length;
    }
    trouve = true;
  }

  if (!trouve) return '';
  return '$prefixe${(plusGrand + 1).toString().padLeft(largeur, '0')}';
}

double _asDouble(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0.0;

class Participation {
  const Participation({
    required this.id,
    required this.denomination,
    required this.categorie,
    required this.capitalEntreprise,
    required this.montantBrut,
    required this.montantNet,
    this.commentaire,
  });

  final int id;
  final String denomination;
  final CategorieParticipation categorie;

  /// Capital social de l'entreprise émettrice : dénominateur de la limite
  /// individuelle de 25 % (EP35, colonne d = b / a).
  final double capitalEntreprise;

  /// Souscriptions.
  final double montantBrut;

  /// Montants libérés, nets des provisions.
  final double montantNet;

  final String? commentaire;

  /// Part du capital de l'émetteur détenue. Le plafond réglementaire est de
  /// 25 %, mais la valeur n'est pas bornée : un dépassement doit se voir.
  double get partDuCapital =>
      capitalEntreprise > 0 ? montantBrut / capitalEntreprise : 0;

  factory Participation.fromJson(Map<String, dynamic> json) => Participation(
        id: (json['id'] as num).toInt(),
        denomination: json['denomination'] as String? ?? '',
        categorie:
            CategorieParticipation.fromWire(json['categorie'] as String? ?? ''),
        capitalEntreprise: _asDouble(json['capital_entreprise']),
        montantBrut: _asDouble(json['montant_brut']),
        montantNet: _asDouble(json['montant_net']),
        commentaire: json['commentaire'] as String?,
      );

  Map<String, dynamic> toPayload() => {
        'denomination': denomination,
        'categorie': categorie.wire,
        'capital_entreprise': capitalEntreprise,
        'montant_brut': montantBrut,
        'montant_net': montantNet,
        if (commentaire != null && commentaire!.isNotEmpty)
          'commentaire': commentaire,
      };
}

/// Une des limites prudentielles qui encadrent les participations.
///
/// Le ratio seul ne se vérifie pas : la limite porte donc aussi son numérateur,
/// son dénominateur et l'état qui les déclare. Quand le dénominateur manque —
/// pas de fonds propres saisis, capital de l'émetteur non renseigné — la limite
/// n'est pas respectée, elle n'est pas mesurable.
class LimitePrudentielle {
  const LimitePrudentielle({
    required this.code,
    required this.libelle,
    required this.etat,
    required this.numerateur,
    required this.numerateurLibelle,
    required this.denominateur,
    required this.denominateurLibelle,
    required this.observe,
    required this.limite,
    required this.mesurable,
    required this.respectee,
    required this.excedent,
    this.concerne,
  });

  /// Code de la norme à l'EP01, de RA006 à RA010.
  final String code;
  final String libelle;

  /// État du FODEP qui porte le calcul : EP35, EP36 ou EP37.
  final String etat;

  final double numerateur;
  final String numerateurLibelle;
  final double denominateur;
  final String denominateurLibelle;

  /// Niveau observé, en part du dénominateur.
  final double observe;

  /// Plafond réglementaire.
  final double limite;

  final bool mesurable;
  final bool respectee;

  /// Montant au-delà du plafond, nul tant qu'il est respecté.
  final double excedent;

  /// Participation qui porte la limite, quand elle est individuelle.
  final String? concerne;

  /// Où en est le ratio par rapport à son plafond, borné à 1 pour la jauge.
  double get remplissage =>
      limite > 0 ? (observe / limite).clamp(0.0, 1.0) : 0.0;

  factory LimitePrudentielle.fromJson(Map<String, dynamic> json) =>
      LimitePrudentielle(
        code: json['code'] as String? ?? '',
        libelle: json['libelle'] as String? ?? '',
        etat: json['etat'] as String? ?? '',
        numerateur: _asDouble(json['numerateur']),
        numerateurLibelle: json['numerateur_libelle'] as String? ?? '',
        denominateur: _asDouble(json['denominateur']),
        denominateurLibelle: json['denominateur_libelle'] as String? ?? '',
        observe: _asDouble(json['observe']),
        limite: _asDouble(json['limite']),
        mesurable: json['mesurable'] == true,
        respectee: json['respectee'] == true,
        excedent: _asDouble(json['excedent']),
        concerne: json['concerne'] as String?,
      );
}

/// Synthèse des participations et de ce qu'elles doivent aux autres données.
///
/// Les fonds propres sont le dénominateur de quatre limites sur cinq, et les
/// immobilisations s'additionnent aux participations dans les deux dernières :
/// cette synthèse les rassemble pour que l'écran n'ait pas à les rapprocher
/// lui-même.
class SyntheseParticipations {
  const SyntheseParticipations({
    required this.nombre,
    required this.nombreEntitesCommerciales,
    required this.totalGeneral,
    required this.totalEntitesCommerciales,
    required this.totauxParCategorie,
    required this.fondsPropresT1,
    required this.fondsPropresEffectifs,
    required this.dateFondsPropres,
    required this.immobilisationsNettes,
    required this.immobilisationsHorsExploitationNettes,
    required this.limites,
    required this.alertes,
  });

  final int nombre;
  final int nombreEntitesCommerciales;
  final double totalGeneral;
  final double totalEntitesCommerciales;
  final Map<String, double> totauxParCategorie;

  final double fondsPropresT1;
  final double fondsPropresEffectifs;

  /// Date de l'assiette de fonds propres retenue, pour savoir de quand
  /// datent les ratios.
  final String? dateFondsPropres;

  final double immobilisationsNettes;
  final double immobilisationsHorsExploitationNettes;

  final List<LimitePrudentielle> limites;
  final List<String> alertes;

  /// Limites dépassées, celles qui appellent une décision.
  List<LimitePrudentielle> get depassements =>
      limites.where((limite) => limite.mesurable && !limite.respectee).toList();

  /// Limites qu'aucune donnée ne permet de mesurer.
  List<LimitePrudentielle> get nonMesurables =>
      limites.where((limite) => !limite.mesurable).toList();

  factory SyntheseParticipations.fromJson(Map<String, dynamic> json) =>
      SyntheseParticipations(
        nombre: (json['nombre'] as num?)?.toInt() ?? 0,
        nombreEntitesCommerciales:
            (json['nombre_entites_commerciales'] as num?)?.toInt() ?? 0,
        totalGeneral: _asDouble(json['total_general']),
        totalEntitesCommerciales: _asDouble(json['total_entites_commerciales']),
        totauxParCategorie: {
          for (final entree
              in ((json['totaux_par_categorie'] as Map<dynamic, dynamic>?) ??
                      const {})
                  .entries)
            '${entree.key}': _asDouble(entree.value),
        },
        fondsPropresT1: _asDouble(json['fonds_propres_t1']),
        fondsPropresEffectifs: _asDouble(json['fonds_propres_effectifs']),
        dateFondsPropres: json['date_fonds_propres'] as String?,
        immobilisationsNettes: _asDouble(json['immobilisations_nettes']),
        immobilisationsHorsExploitationNettes:
            _asDouble(json['immobilisations_hors_exploitation_nettes']),
        limites: ((json['limites'] as List<dynamic>?) ?? const [])
            .map((item) =>
                LimitePrudentielle.fromJson(item as Map<String, dynamic>))
            .toList(),
        alertes: ((json['alertes'] as List<dynamic>?) ?? const [])
            .map((item) => '$item')
            .toList(),
      );
}

class MembreGroupe {
  const MembreGroupe({
    required this.id,
    required this.nom,
    this.pays,
    this.categorieLien,
    this.numeroCentraleRisques,
    this.secteurActivite,
    this.categoriePartieLiee,
  });

  final String id;
  final String nom;
  final String? pays;
  final CategorieLien? categorieLien;
  final String? numeroCentraleRisques;
  final String? secteurActivite;

  /// Renseignée, elle range la contrepartie dans les états EP38 et EP39.
  final CategoriePartieLiee? categoriePartieLiee;

  /// L'EP30 exige le numéro Centrale des risques et la nature du lien :
  /// aucun zéro ne remplace ces colonnes d'identification.
  bool get identificationComplete =>
      (numeroCentraleRisques ?? '').isNotEmpty && categorieLien != null;

  factory MembreGroupe.fromJson(Map<String, dynamic> json) => MembreGroupe(
        id: '${json['id']}',
        nom: json['nom'] as String? ?? '',
        pays: json['pays'] as String?,
        categorieLien: CategorieLien.fromWire(json['categorie_lien'] as String?),
        numeroCentraleRisques: json['numero_centrale_risques'] as String?,
        secteurActivite: json['secteur_activite'] as String?,
        categoriePartieLiee: CategoriePartieLiee.fromWire(
            json['categorie_partie_liee'] as String?),
      );
}

class GroupeClients {
  const GroupeClients({
    required this.id,
    required this.nom,
    this.numeroCentraleRisques,
    this.membres = const [],
  });

  final int id;
  final String nom;
  final String? numeroCentraleRisques;
  final List<MembreGroupe> membres;

  factory GroupeClients.fromJson(Map<String, dynamic> json) => GroupeClients(
        id: (json['id'] as num).toInt(),
        nom: json['nom'] as String? ?? '',
        numeroCentraleRisques: json['numero_centrale_risques'] as String?,
        membres: ((json['membres'] as List<dynamic>?) ?? const [])
            .map((item) => MembreGroupe.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class ContrepartieRattachement extends MembreGroupe {
  const ContrepartieRattachement({
    required super.id,
    required super.nom,
    super.pays,
    super.categorieLien,
    super.numeroCentraleRisques,
    super.secteurActivite,
    super.categoriePartieLiee,
    this.groupeId,
    this.groupeNom,
  });

  final int? groupeId;
  final String? groupeNom;

  factory ContrepartieRattachement.fromJson(Map<String, dynamic> json) =>
      ContrepartieRattachement(
        id: '${json['id']}',
        nom: json['nom'] as String? ?? '',
        pays: json['pays'] as String?,
        categorieLien: CategorieLien.fromWire(json['categorie_lien'] as String?),
        numeroCentraleRisques: json['numero_centrale_risques'] as String?,
        secteurActivite: json['secteur_activite'] as String?,
        categoriePartieLiee: CategoriePartieLiee.fromWire(
            json['categorie_partie_liee'] as String?),
        groupeId: (json['groupe_id'] as num?)?.toInt(),
        groupeNom: json['groupe_nom'] as String?,
      );
}


/// Concentration d'un groupe de clients liés.
class ConcentrationGroupe {
  const ConcentrationGroupe({
    required this.id,
    required this.nom,
    required this.numeroCentraleRisques,
    required this.expositionTotale,
    required this.partFondsPropres,
    required this.depasseLeSeuil,
    required this.partDuPlusGrosMembre,
    required this.herfindahl,
    required this.membres,
  });

  final int id;
  final String nom;

  /// Identifiant du groupe à la centrale des risques, tel que déclaré à l'EP30.
  final String? numeroCentraleRisques;

  final double expositionTotale;

  /// Exposition rapportée aux fonds propres de base T1.
  final double partFondsPropres;

  /// Au-delà de 25 % des fonds propres, le risque est un « grand risque ».
  final bool depasseLeSeuil;

  final double partDuPlusGrosMembre;

  /// Indice de Herfindahl : 1 quand un seul membre porte tout le groupe,
  /// tend vers 1/n quand le risque est également réparti.
  final double herfindahl;

  final List<MembreConcentration> membres;

  factory ConcentrationGroupe.fromJson(Map<String, dynamic> json) =>
      ConcentrationGroupe(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nom: json['nom'] as String? ?? '',
        numeroCentraleRisques: json['numero_centrale_risques'] as String?,
        expositionTotale: _asDouble(json['exposition_totale']),
        partFondsPropres: _asDouble(json['part_fonds_propres']),
        depasseLeSeuil: json['depasse_le_seuil'] == true,
        partDuPlusGrosMembre: _asDouble(json['part_du_plus_gros_membre']),
        herfindahl: _asDouble(json['herfindahl']),
        membres: ((json['membres'] as List<dynamic>?) ?? const [])
            .map((item) =>
                MembreConcentration.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class MembreConcentration {
  const MembreConcentration({
    required this.nom,
    required this.exposition,
    required this.partDuGroupe,
  });

  final String nom;
  final double exposition;
  final double partDuGroupe;

  factory MembreConcentration.fromJson(Map<String, dynamic> json) =>
      MembreConcentration(
        nom: json['nom'] as String? ?? '',
        exposition: _asDouble(json['exposition']),
        partDuGroupe: _asDouble(json['part_du_groupe']),
      );
}

class ConcentrationGroupes {
  const ConcentrationGroupes({
    required this.fondsPropresT1,
    required this.seuilGrandRisque,
    required this.expositionPortefeuille,
    required this.groupes,
  });

  final double fondsPropresT1;
  final double seuilGrandRisque;
  final double expositionPortefeuille;

  /// Groupes triés par exposition décroissante.
  final List<ConcentrationGroupe> groupes;

  factory ConcentrationGroupes.fromJson(Map<String, dynamic> json) =>
      ConcentrationGroupes(
        fondsPropresT1: _asDouble(json['fonds_propres_t1']),
        seuilGrandRisque: _asDouble(json['seuil_grand_risque']),
        expositionPortefeuille: _asDouble(json['exposition_portefeuille']),
        groupes: ((json['groupes'] as List<dynamic>?) ?? const [])
            .map((item) =>
                ConcentrationGroupe.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}
