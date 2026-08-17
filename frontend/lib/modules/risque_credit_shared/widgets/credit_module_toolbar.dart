import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class CreditModuleToolbar extends StatelessWidget {
  const CreditModuleToolbar({
    super.key,
    required this.searchController,
    required this.searchHint,
    required this.onSearchChanged,
    this.filters = const <Widget>[],
    this.actions = const <Widget>[],
  });

  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final List<Widget> filters;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.spacing,
      runSpacing: AppTheme.spacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: searchHint,
            ),
          ),
        ),
        ...filters,
        ...actions,
      ],
    );
  }
}
