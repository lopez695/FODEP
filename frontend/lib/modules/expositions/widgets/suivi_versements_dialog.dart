// Panneau de suivi mensuel des versements et du cycle de vie prudentiel d'une
// exposition : marquage versé/impayé par mois, jours d'impayés dérivés,
// déclassement en créance douteuse (motif obligatoire) et levée conditionnée.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/services/api_client.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/state/portfolio_amount_unit_scope.dart';
import '../../../core/utils/currency_conversion.dart';
import '../models/suivi_versements_models.dart';

String _formatDateStr(String dateStr) {
  if (dateStr.isEmpty) return '-';
  try {
    final parts = dateStr.split('-');
    if (parts.length >= 3) {
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return dateStr;
  } catch (_) {
    return dateStr;
  }
}

class SuiviVersementsDialog extends StatefulWidget {
  const SuiviVersementsDialog({
    super.key,
    required this.api,
    required this.exposureId,
    required this.counterpartyName,
  });

  final RwaApiService api;
  final String exposureId;
  final String counterpartyName;

  @override
  State<SuiviVersementsDialog> createState() => _SuiviVersementsDialogState();
}

class _SuiviVersementsDialogState extends State<SuiviVersementsDialog> {
  static const List<String> _moisAbreges = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

  ExpositionSuivi? _suivi;
  bool _isLoading = true;
  bool _isBusy = false;
  bool _dirty = false;
  String? _error;

  ThemeData get _theme => Theme.of(context);
  bool get _isDark => _theme.brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _loadSuivi();
  }

  Future<void> _loadSuivi() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final suivi = await widget.api.fetchExpositionSuivi(widget.exposureId);
      if (!mounted) return;
      setState(() {
        _suivi = suivi;
        _isLoading = false;
      });
    } catch (exc) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _humanizeError(exc);
      });
    }
  }

  String _humanizeError(Object exc) {
    if (exc is ApiException) {
      final detail = exc.detail;
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }
    }
    return 'Une erreur est survenue. Vérifiez que le service est démarré.';
  }



  Future<void> _runAction(
    Future<ExpositionSuivi> Function() action,
  ) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      final suivi = await action();
      if (!mounted) return;
      setState(() {
        _suivi = suivi;
        _isBusy = false;
        _dirty = true;
      });
    } catch (exc) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(_humanizeError(exc), style: const TextStyle(color: Colors.white)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _declasser() async {
    final motif = await _promptMotif(
      title: 'Déclasser en créance douteuse',
      message:
          'Cette exposition sera pondérée comme une créance en souffrance. '
          'Indiquez le motif de la décision (jugement expert, procédure '
          'collective, information de gestion…).',
      confirmLabel: 'Déclasser',
      confirmColor: AppTheme.danger,
    );
    if (motif == null) return;
    await _runAction(
      () => widget.api.declasserExposition(widget.exposureId, motif: motif),
    );
  }

  Future<void> _lever() async {
    final motif = await _promptMotif(
      title: 'Lever le déclassement',
      message: 'Le retour au statut sain exige que les arriérés soient apurés. '
          'Indiquez le motif de la régularisation.',
      confirmLabel: 'Lever',
      confirmColor: AppTheme.success,
    );
    if (motif == null) return;
    await _runAction(
      () => widget.api.leverDeclassement(widget.exposureId, motif: motif),
    );
  }

  Future<String?> _promptMotif({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final controller = TextEditingController();
    final motif = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _isDark ? AppTheme.darkCard : AppTheme.card,
          title: Text(title, style: TextStyle(color: _textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message,
                  style: TextStyle(color: _mutedColor, fontSize: 12.5)),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                style: TextStyle(color: _textColor, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Motif (obligatoire)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: confirmColor),
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) return;
                Navigator.of(dialogContext).pop(value);
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return motif;
  }

  Future<void> _promptMontant(String periode, SuiviVersement? existing) async {
    final controller = TextEditingController(text: existing?.montantVerse?.toString() ?? '');
    final encours = _suivi?.encours ?? 0.0;
    final oldAmount = existing?.montantVerse ?? 0.0;
    final maxAllowed = encours + oldAmount;

    final double? amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final value = controller.text.trim().replaceAll(',', '.');
            final parsed = double.tryParse(value);
            final bool isOverLimit = parsed != null && parsed > maxAllowed + 0.01;
            final bool isInvalid = value.isNotEmpty && (parsed == null || parsed < 0);
            
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(1)),
              backgroundColor: _isDark ? AppTheme.darkCard : AppTheme.card,
              title: Text('Saisir le montant', style: TextStyle(color: _textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 400,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Entrez le montant versé pour le mois de ${_monthOnlyLabel(periode)}.',
                      style: TextStyle(color: _mutedColor, fontSize: 13)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: _textColor, fontSize: 14),
                    onChanged: (_) => setStateDialog(() {}),
                    decoration: InputDecoration(
                      labelText: 'Montant versé',
                      suffixText: _suivi?.devise ?? '',
                      suffixStyle: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(1)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(1),
                        borderSide: BorderSide(color: (isOverLimit || isInvalid) ? Colors.red : AppTheme.accent, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(1),
                        borderSide: BorderSide(color: (isOverLimit || isInvalid) ? Colors.red : Colors.grey.withValues(alpha: 0.5), width: 1.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    ),
                  ),
                  if (isOverLimit) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Le cumul des versements ne peut pas dépasser l'encours d'origine du prêt.",
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (isInvalid) ...[
                    const SizedBox(height: 8),
                    const Text('Le montant doit être un nombre valide positif.', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ],
              ),
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(1))),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(1)),
                  ),
                  onPressed: (value.isEmpty || parsed == null || isInvalid || isOverLimit) ? null : () {
                    Navigator.of(dialogContext).pop(parsed);
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          }
        );
      },
    );
    controller.dispose();
    if (amount == null) return;
    await _runAction(
      () => widget.api.recordVersement(
        widget.exposureId,
        periode: periode,
        statut: amount > 0 ? 'verse' : 'impaye', // We consider that entering an amount > 0 means it's paid, otherwise unpaid.
        montantVerse: amount > 0 ? amount : null,
      ),
    );
  }

  Color get _textColor => _isDark ? AppTheme.darkText : AppTheme.text;
  Color get _mutedColor => _isDark ? AppTheme.darkMuted : AppTheme.muted;
  Color get _cardColor => _isDark ? Colors.indigo.shade900 : Colors.indigo.shade50;
  Color get _softColor =>
      _isDark ? const Color(0xFF14233D) : const Color(0xFFF6F9FF);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: Container(
        width: 760,
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: _isLoading
              ? const SizedBox(
                  height: 260,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final suivi = _suivi;

    // Échec du chargement initial : on ne laisse pas un panneau vide. On
    // affiche l'erreur avec un bouton « Réessayer » plutôt que de forcer la
    // fermeture / réouverture du panneau.
    if (suivi == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(suivi),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(CupertinoIcons.exclamationmark_circle, size: 16, color: AppTheme.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error ?? 'Le suivi de cette exposition est indisponible.',
                    style: const TextStyle(color: AppTheme.danger, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _loadSuivi,
                icon: const Icon(CupertinoIcons.arrow_clockwise, size: 15),
                label: const Text('Réessayer'),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_dirty),
                style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(suivi),
        const SizedBox(height: 14),
        _buildStatusBanner(suivi),
        const SizedBox(height: 12),
        _buildReconciliation(suivi),
        const SizedBox(height: 16),
        Text(
          'Historique des versements',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '* Cliquez sur un mois pour modifier son statut.',
          style: TextStyle(
            color: Colors.amber[700],
            fontSize: 10,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: SingleChildScrollView(
            child: _buildMonthGrid(suivi),
          ),
        ),
        const SizedBox(height: 16),
        _buildFooter(suivi),
      ],
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Widget _buildHeader(ExpositionSuivi? suivi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF001F4E), // Solid dark blue
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _getInitials(widget.counterpartyName),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.counterpartyName,
                    style: TextStyle(
                      color: _textColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF001F4E).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.exposureId,
                          style: const TextStyle(
                            color: Color(0xFF001F4E),
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Suivi & classement',
                        style: TextStyle(
                          color: _mutedColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(CupertinoIcons.clear_circled_solid, size: 24, color: _mutedColor.withValues(alpha: 0.5)),
              onPressed: () => Navigator.of(context).pop(_dirty),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Fermer',
            ),
          ],
        ),
        if (suivi != null && (suivi.dateOctroi != null || suivi.dateEcheance != null)) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              if (suivi.dateOctroi != null)
                _infoTile('Octroi', _formatDateStr(suivi.dateOctroi!)),
              if (suivi.dateEcheance != null)
                _infoTile('Échéance', _formatDateStr(suivi.dateEcheance!)),
              if (suivi.maturite != null)
                _infoTile('Maturité', '${suivi.maturite!.toStringAsFixed(1)} an(s)'),
              if (suivi.maturiteResiduelle != null)
                _infoTile(
                  'Maturité résiduelle',
                  '${(suivi.maturiteResiduelle! * 12).toStringAsFixed(1).replaceAll('.0', '')} mois',
                ),
              if (suivi.notation != null && suivi.notation!.isNotEmpty)
                _infoTile('Notation', suivi.notation!),
            ],
          ),
        ],
      ],
    );
  }

  /// Étiquette + valeur, le motif répété de l'en-tête.
  Widget _infoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _isDark ? Colors.blue[300] : const Color(0xFF1E40AF),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: _isDark ? Colors.white : const Color(0xFF001F4E),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner(ExpositionSuivi suivi) {
    late final Color bg;
    late final Color fg;
    late final IconData icon;
    switch (suivi.statutPrudentiel) {
      case 'douteuse':
        bg = _isDark ? const Color(0xFF3E1A1E) : const Color(0xFFFBE7E7);
        fg = _isDark ? const Color(0xFFFF9B9B) : const Color(0xFFB3261E);
        icon = CupertinoIcons.exclamationmark_triangle_fill;
        break;
      case 'impayee':
        bg = _isDark ? const Color(0xFF43370F) : const Color(0xFFFBF1D9);
        fg = _isDark ? const Color(0xFFF0C368) : const Color(0xFF8A6100);
        icon = CupertinoIcons.clock_fill;
        break;
      default:
        bg = _isDark ? const Color(0xFF13301C) : const Color(0xFFE4F3E8);
        fg = _isDark ? const Color(0xFF7FD79A) : const Color(0xFF1B7A3D);
        icon = CupertinoIcons.checkmark_shield_fill;
        break;
    }

    final surfaceColor = _isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = _isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bg.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Icon(icon, size: 24, color: fg),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Text(
                      suivi.statutLabel,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (suivi.declassementManuel) ...[
                      const SizedBox(width: 8),
                      Icon(CupertinoIcons.lock_fill, size: 12, color: _mutedColor),
                      const SizedBox(width: 4),
                      Text(
                        'déclassement manuel',
                        style: TextStyle(
                            color: _mutedColor,
                            fontSize: 10,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (suivi.joursImpayes > 0) ...[
                  Text(
                    "${suivi.joursImpayes} jour(s) d'impayés",
                    style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Seuil de souffrance : ${suivi.seuilJoursSouffrance} jours',
                    style: TextStyle(color: _mutedColor, fontSize: 11),
                  ),
                ] else ...[
                  Text(
                    'Aucun impayé en cours',
                    style: TextStyle(color: _textColor, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
                if (suivi.declassementManuel &&
                    (suivi.declassementMotif ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Motif : ${suivi.declassementMotif}',
                    style: TextStyle(color: _mutedColor, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }


  /// Chaîne de calcul menant de l'encours au RWA.
  ///
  /// Le panneau juxtaposait un encours (bilan seul) et un RWA calculé sur une
  /// assiette plus large : le rapprochement était impossible à l'œil. Chaque
  /// terme est désormais posé, opérateur compris, pour que le montant pondéré
  /// se vérifie sans quitter l'écran.
  Widget _buildReconciliation(ExpositionSuivi suivi) {
    final encours = suivi.encours;
    if (encours == null) return const SizedBox.shrink();

    final unit = PortfolioAmountUnitScope.maybeOf(context);
    final devise = suivi.devise ?? 'XOF';
    String money(double value) => formatCurrencyInDisplayUnit(
          value,
          toCurrency: devise,
          amountUnit: unit,
          maxDecimals: 1,
        );

    final totalVerse = suivi.totalVerse ?? 0;
    final horsBilan = suivi.montantHorsBilan ?? 0;
    final ead = suivi.ead;

    // L'assiette pondérée ne vaut « encours + hors bilan » que sans facteur de
    // conversion ni garantie financée. Quand une ARC ou un FCEC intervient, la
    // somme est fausse : on pose alors l'assiette sans la présenter comme un
    // total, plutôt que d'afficher une égalité qui ne tient pas.
    final bool assietteAdditive =
        ead != null && (encours + horsBilan - ead).abs() <= 1.0;

    final terms = <Widget>[];
    if (totalVerse > 0 && suivi.montantInitial != null) {
      terms
        ..add(_reconTerm('Encours initial', money(suivi.montantInitial!)))
        ..add(_reconOperator('−'))
        ..add(_reconTerm('Total versé', money(totalVerse)))
        ..add(_reconOperator('='));
    }
    terms.add(_reconTerm('Encours actuel', money(encours), highlight: true));
    if (horsBilan > 0) {
      terms
        ..add(_reconOperator(assietteAdditive ? '+' : '·'))
        ..add(_reconTerm('Hors bilan', money(horsBilan)));
    }
    if (ead != null) {
      terms
        ..add(_reconOperator(assietteAdditive ? '=' : '→'))
        ..add(_reconTerm('Assiette pondérée', money(ead)));
    }
    if (suivi.ponderation != null) {
      terms
        ..add(_reconOperator('×'))
        ..add(_reconTerm(
          'Pondération',
          '${(suivi.ponderation! * 100).toStringAsFixed(0)} %',
        ));
    }
    if (suivi.rwa != null) {
      terms
        ..add(_reconOperator('='))
        ..add(_reconTerm('RWA', money(suivi.rwa!), highlight: true));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: _isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: terms),
          ),
          if (horsBilan > 0 && !assietteAdditive) ...[
            const SizedBox(height: 8),
            Text(
              "L'assiette pondérée tient compte du facteur de conversion du "
              'hors bilan et des garanties : elle ne se lit pas comme la somme '
              'des deux montants.',
              style: TextStyle(color: _mutedColor, fontSize: 10.5, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reconTerm(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _isDark ? Colors.blue[300] : const Color(0xFF1E40AF),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: highlight
                  ? (_isDark ? Colors.white : const Color(0xFF001F4E))
                  : _textColor,
              fontSize: highlight ? 13.5 : 12.5,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reconOperator(String symbol) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 10, bottom: 1),
      child: Text(
        symbol,
        style: TextStyle(
          color: _mutedColor,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildMonthGrid(ExpositionSuivi suivi) {
    int startYear = DateTime.now().year - 1;
    int endYear = DateTime.now().year;
    int startMonth = 1;
    int endMonth = 12;

    if (suivi.dateOctroi != null && suivi.dateOctroi!.length >= 7) {
      startYear = int.tryParse(suivi.dateOctroi!.substring(0, 4)) ?? startYear;
      startMonth = int.tryParse(suivi.dateOctroi!.substring(5, 7)) ?? 1;
    }
    if (suivi.dateEcheance != null && suivi.dateEcheance!.length >= 7) {
      endYear = int.tryParse(suivi.dateEcheance!.substring(0, 4)) ?? endYear;
      endMonth = int.tryParse(suivi.dateEcheance!.substring(5, 7)) ?? 12;
    }

    final years = <String>[];
    for (int y = startYear; y <= endYear; y++) {
      years.add(y.toString());
    }

    if (years.isEmpty) {
      years.add(DateTime.now().year.toString());
    }

    final Map<String, List<String>> byYear = {};
    for (final yearStr in years) {
      byYear[yearStr] = [];
      int y = int.parse(yearStr);
      int mStart = (y == startYear) ? startMonth : 1;
      int mEnd = (y == endYear) ? endMonth : 12;

      for (int m = mStart; m <= mEnd; m++) {
        byYear[yearStr]!.add('$y-${m.toString().padLeft(2, '0')}');
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(years.length, (index) {
        final year = years[index];
        final isLast = index == years.length - 1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  year,
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Builder(
                    builder: (context) {
                      final periods = byYear[year]!;
                      final List<TableRow> rows = [];
                      for (int i = 0; i < periods.length; i += 6) {
                        final List<Widget> rowChildren = [];
                        for (int j = 0; j < 6; j++) {
                          if (i + j < periods.length) {
                            rowChildren.add(
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                child: _buildMonthChip(periods[i + j], suivi.entryForPeriode(periods[i + j])),
                              ),
                            );
                          } else {
                            rowChildren.add(const SizedBox());
                          }
                        }
                        rows.add(TableRow(children: rowChildren));
                      }
                      return Table(
                        defaultColumnWidth: const FixedColumnWidth(94),
                        children: rows,
                      );
                    },
                  ),
                ),
              ],
            ),
            if (!isLast)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: _mutedColor.withValues(alpha: 0.3), height: 1, thickness: 1),
              )
            else
              const SizedBox(height: 16),
          ],
        );
      }),
    );
  }

  String _monthOnlyLabel(String periode) {
    final parts = periode.split('-');
    if (parts.length != 2) return periode;
    final month = int.tryParse(parts[1]) ?? 1;
    return (month >= 1 && month <= 12) ? _moisAbreges[month - 1] : parts[1];
  }

  String _formatAmount(double amount) {
    if (amount >= 1e9) return '${(amount / 1e9).toStringAsFixed(1).replaceAll('.0', '')}Md';
    if (amount >= 1e6) return '${(amount / 1e6).toStringAsFixed(1).replaceAll('.0', '')}M';
    if (amount >= 1e3) return '${(amount / 1e3).toStringAsFixed(1).replaceAll('.0', '')}k';
    return amount.toStringAsFixed(0);
  }

  Widget _buildMonthChip(String periode, SuiviVersement? entry) {
    final now = DateTime.now();
    final currentMonthStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
    final isFuture = periode.compareTo(currentMonthStr) > 0;
    
    final bool? verse = entry?.estVerse;
    late final Color bg;
    late final Color fg;
    String statusText;

    if (isFuture) {
      bg = _softColor;
      fg = _mutedColor.withValues(alpha: 0.6);
      statusText = 'À venir';
    } else if (verse == true) {
      bg = const Color(0xFF00B050); // Vivid Green
      fg = Colors.white;
      if (entry?.montantVerse != null) {
        statusText = '${_formatAmount(entry!.montantVerse!)} ${_suivi?.devise ?? ''}'.trim();
      } else {
        statusText = 'Versé';
      }
    } else if (verse == false) {
      bg = const Color(0xFFE53935); // Vivid Red
      fg = Colors.white;
      statusText = 'Impayé';
    } else {
      bg = _softColor;
      fg = _mutedColor;
      statusText = 'À saisir';
    }

    return Material(
      elevation: 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(1),
        side: BorderSide(color: fg.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Container(
        width: 82,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(1),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: InkWell(
                onTap: (_isBusy || isFuture) ? null : () => _promptMontant(periode, entry),
                borderRadius: BorderRadius.circular(1),
                child: Padding(
                  padding: const EdgeInsets.only(left: 6, top: 2, bottom: 2, right: 18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _monthOnlyLabel(periode),
                        style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.8),
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isFuture)
              Positioned(
                top: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(CupertinoIcons.lock_fill, size: 10, color: fg.withValues(alpha: 0.5)),
                ),
              )
            else
              Positioned(
                top: 0,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isBusy ? null : () => _promptMontant(periode, entry),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(CupertinoIcons.pencil, size: 10, color: fg.withValues(alpha: 0.7)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ExpositionSuivi? suivi) {
    final canLever = suivi?.declassementManuel ?? false;
    return Row(
      children: [
        if (_isBusy)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        const Spacer(),
        if (canLever)
          OutlinedButton.icon(
            onPressed: _isBusy ? null : _lever,
            icon: const Icon(CupertinoIcons.lock_open, size: 15),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.success,
              side: BorderSide(color: AppTheme.success.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
            ),
            label: const Text('Lever le déclassement'),
          )
        else
          OutlinedButton.icon(
            onPressed: _isBusy ? null : _declasser,
            icon: const Icon(CupertinoIcons.exclamationmark_triangle, size: 15),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.danger,
              side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.6)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
            ),
            label: const Text('Déclasser en douteuse'),
          ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_dirty),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF001F4E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
          ),
          child: const Text('Terminé'),
        ),
      ],
    );
  }
}
