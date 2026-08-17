// Ce fichier affiche le module rapports.
import 'package:flutter/material.dart';

import '../../../core/services/rwa_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/page_header.dart';
import '../../../shared/widgets/section_card.dart';
import '../models/report_models.dart';
import '../widgets/report_filter_card.dart';
import '../widgets/report_table.dart';

/// Ecran de génération et d'historique des rapports.
class RapportsScreen extends StatefulWidget {
  const RapportsScreen({
    super.key,
    required this.api,
  });

  final RwaApiService api;

  @override
  State<RapportsScreen> createState() => _RapportsScreenState();
}

/// Etat interne de l'écran rapports et de ses actions.
class _RapportsScreenState extends State<RapportsScreen> {
  late Future<ReportsModuleData> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchReports();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReportsModuleData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        final data = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Rapports',
                subtitle:
                    'Generation de rapports de synthese et detail avec filtres metier et exports.',
              ),
              const SizedBox(height: AppTheme.pageGap),
              ReportFilterCard(onGenerate: _handleGenerate),
              const SizedBox(height: AppTheme.pageGap),
              SectionCard(
                title: 'Rapports Recents',
                child: ReportTable(reports: data.reports),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleGenerate(ReportDraft draft) async {
    try {
      await widget.api.generateReport(draft);
      if (!mounted) {
        return;
      }
      setState(() => _future = widget.api.fetchReports());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rapport genere.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.danger,
          content: Text('Échec de la génération du rapport : $error'),
        ),
      );
    }
  }
}
