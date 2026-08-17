import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';

import '../../dashboard/widgets/dashboard_fonds_propres_import_dialog.dart';
import '../../expositions/widgets/excel_import_dialog.dart';
import '../../risque_marche/screens/market_data_import_screen.dart';
import '../../risque_operationnel/widgets/ro_import_bic_dialog.dart';
import '../../risque_operationnel/widgets/ro_import_pertes_dialog.dart';

class ImportationsScreen extends StatefulWidget {
  const ImportationsScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<ImportationsScreen> createState() => _ImportationsScreenState();
}

class _ImportationsScreenState extends State<ImportationsScreen> {
  String? successMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppTheme.pagePadding,
              top: AppTheme.pagePadding,
              right: AppTheme.pagePadding,
              bottom: 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gestion des Importations'.tr(context),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.text,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context).dividerColor),
                const SizedBox(height: 6),
                Text(
                  'Veuillez procéder à l\'importation de vos données afin de réaliser vos analyses.'
                      .tr(context),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.muted,
                      ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.pagePadding),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight:
                          constraints.maxHeight - (AppTheme.pagePadding * 2),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(32),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accent
                                          .withValues(alpha: 0.05),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppTheme.accent
                                            .withValues(alpha: 0.1),
                                        width: 2,
                                      ),
                                    ),
                                    child: Lottie.asset(
                                      successMessage != null
                                          ? 'assets/lotties/Success.json'
                                          : 'assets/lotties/import_loader.json',
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.contain,
                                      repeat: successMessage == null,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return _ImportAnimationFallback(
                                          completed: successMessage != null,
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 48),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 16,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 180,
                                        child: _buildImportCard(
                                          context,
                                          title: 'Risque de Crédit'.tr(context),
                                          backgroundColor: AppTheme.accent,
                                          borderColor: AppTheme.accent,
                                          textColor: Colors.white,
                                          onTap: () async {
                                            final result =
                                                await showExcelImportDialog(
                                              context,
                                              api: widget.api,
                                              onImportApplied: () async {},
                                            );
                                            if (!mounted) return;
                                            if (result != null) {
                                              setState(() {
                                                successMessage = 'Données risque de crédit chargées avec succès'
                                                    .tr(context);
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        width: 180,
                                        child: _buildImportCard(
                                          context,
                                          title: 'Risque de Marché'.tr(context),
                                          backgroundColor: AppTheme.success,
                                          borderColor: AppTheme.success,
                                          textColor: Colors.white,
                                          onTap: () async {
                                            final success =
                                                await showMarketDataImportDialog(
                                                    context);
                                            if (!mounted) return;
                                            if (success) {
                                              setState(() {
                                                successMessage = 'Données risque de marché chargées avec succès'
                                                    .tr(context);
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        width: 180,
                                        child: _buildImportCard(
                                          context,
                                          title: 'Risque Opérationnel'.tr(context),
                                          backgroundColor: AppTheme.warning,
                                          borderColor: AppTheme.warning,
                                          textColor: Colors.white,
                                          onTap: () async {
                                            final choice =
                                                await _chooseRoImportType(
                                                    context);
                                            if (!context.mounted) return;
                                            if (choice == null) return;

                                            if (choice == 'ccr3') {
                                              if (!context.mounted) return;
                                              final imported =
                                                  await showRoImportBicDialog(
                                                context,
                                                api: widget.api,
                                              );
                                              if (!mounted) return;
                                              if (imported == true) {
                                                setState(() {
                                                  successMessage = 'Données BIC / CCR3 chargées avec succès'
                                                      .tr(context);
                                                });
                                              }
                                            } else {
                                              if (!context.mounted) return;
                                              final success =
                                                  await showRoImportPertesDialog(
                                                      context,
                                                      api: widget.api);
                                              if (!mounted) return;
                                              if (success == true) {
                                                setState(() {
                                                  successMessage = 'Données risque opérationnel chargées avec succès'
                                                      .tr(context);
                                                });
                                              }
                                            }
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        width: 180,
                                        child: _buildImportCard(
                                          context,
                                          title: 'Fonds Propres'.tr(context),
                                          backgroundColor: const Color(0xFF1E40AF),
                                          borderColor: const Color(0xFF1E40AF),
                                          textColor: Colors.white,
                                          onTap: () async {
                                            final success =
                                                await showFondsPropresImportDialog(
                                              context,
                                              api: widget.api,
                                            );
                                            if (!mounted) return;
                                            if (success == true) {
                                              setState(() {
                                                successMessage = 'Fonds propres réglementaires mis à jour avec succès'
                                                    .tr(context);
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (successMessage != null) ...[
                                    const SizedBox(height: 32),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.success
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: AppTheme.success
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.check_circle,
                                              color: AppTheme.success),
                                          const SizedBox(width: 8),
                                          Text(
                                            successMessage!,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: AppTheme.success,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Demande à l'utilisateur quel type de fichier "Risque Opérationnel" il
  /// souhaite importer : le registre des pertes (base prudentielle) ou le
  /// formulaire d'activité BIC/CCR3. Retourne 'prudentielle', 'ccr3' ou null
  /// si l'utilisateur annule.
  Future<String?> _chooseRoImportType(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        Widget option({
          required IconData icon,
          required String title,
          required String subtitle,
          required Color color,
          required String value,
        }) {
          return InkWell(
            onTap: () => Navigator.pop(ctx, value),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: color.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(8),
                color: color.withValues(alpha: 0.06),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(icon, color: color, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title.tr(ctx),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text(subtitle.tr(ctx),
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.muted, height: 1.3)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: color, size: 18),
                ],
              ),
            ),
          );
        }

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: Text('Quel type de fichier importer ?'.tr(ctx)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Le module Risque Opérationnel accepte deux formats de fichier.'
                      .tr(ctx),
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.muted),
                ),
                const SizedBox(height: 14),
                option(
                  icon: Icons.description_outlined,
                  title: 'Base prudentielle (pertes / incidents)',
                  subtitle:
                      'Registre des incidents et pertes opérationnelles, ligne par ligne.',
                  color: AppTheme.warning,
                  value: 'prudentielle',
                ),
                const SizedBox(height: 10),
                option(
                  icon: Icons.account_balance_outlined,
                  title: 'BIC / CCR3',
                  subtitle:
                      'Formulaire de saisie de l\'indicateur d\'activité - un onglet Excel par exercice.',
                  color: AppTheme.accent,
                  value: 'ccr3',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text('Annuler'.tr(ctx)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImportCard(
    BuildContext context, {
    required String title,
    required VoidCallback onTap,
    Color? backgroundColor,
    Color? borderColor,
    Color? textColor,
  }) {
    return Card(
      elevation: 0,
      color: backgroundColor ?? Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: borderColor ?? Theme.of(context).dividerColor,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: textColor ?? AppTheme.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportAnimationFallback extends StatelessWidget {
  const _ImportAnimationFallback({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    final color = completed ? AppTheme.success : AppTheme.accent;

    return SizedBox(
      width: 136,
      height: 136,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.2), width: 2),
        ),
        child: Center(
          child: Icon(
            completed
                ? CupertinoIcons.checkmark_alt_circle
                : CupertinoIcons.arrow_up_doc,
            color: color,
            size: 58,
          ),
        ),
      ),
    );
  }
}
