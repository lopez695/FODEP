/// Taux et multiplicateurs réglementaires partagés par tous les modules.
///
/// Ils vivaient en dur dans chaque écran, ce qui a laissé cohabiter deux
/// conventions : le module Risque de Marché convertissait ses exigences en
/// actifs pondérés au multiplicateur 12,5 pendant que les tuiles de capital du
/// dashboard, du moteur RWA et des expositions appliquaient 9 % aux mêmes
/// actifs. Les deux nombres ne se répondaient pas.
library;

/// Multiplicateur des exigences de fonds propres marché et opérationnel dans
/// l'assiette du ratio de solvabilité (§90) : RWA = K × 12,5.
///
/// 12,5 est l'inverse de 8 %, la convention de Bâle reprise par le dispositif
/// prudentiel — pas l'inverse du ratio de solvabilité, qui donnerait 11,11.
const double kMultiplicateurRwa = 12.5;

/// Taux de l'exigence de fonds propres : capital minimum = RWA × 8 %.
///
/// L'inverse exact de [kMultiplicateurRwa], de sorte qu'une exigence convertie
/// en actifs pondérés puis reconvertie se retrouve à l'identique.
///
/// À ne pas confondre avec [kRatioSolvabiliteMin] : celui-ci est le ratio que
/// l'établissement doit tenir sur ses actifs pondérés, un seuil de conformité
/// et non un taux de conversion.
const double kTauxExigenceFondsPropres = 0.08;

/// Ratio de solvabilité minimal UMOA, hors coussin (§91c).
///
/// Sert à juger la conformité (fonds propres / RWA ≥ 9 %), jamais à convertir
/// une exigence en actifs pondérés ni l'inverse.
const double kRatioSolvabiliteMin = 0.09;

/// Coussin de conservation (§92), au-delà des minima.
const double kCoussinConservation = 0.025;

/// Exigence globale de solvabilité, coussin inclus : 11,5 %.
const double kExigenceSolvabiliteGlobale =
    kRatioSolvabiliteMin + kCoussinConservation;

/// Capital réglementaire minimum adossé à un montant d'actifs pondérés.
double capitalMinimum(double rwa) => rwa * kTauxExigenceFondsPropres;
