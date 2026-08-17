import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

/// Style de formulaire standard pour Dispositif UEMOA : reprend l'habillage
/// de la modale "Modifier les Fonds Propres" (bandeau coloré en tête de
/// carte, titre + sous-titre, puis champs en boîtes grisées).
///
/// Deux briques :
/// - [UemoiFormCard] : conteneur avec bandeau coloré + titre/sous-titre.
/// - [UemoiFormField] / [UemoiFormDropdown] : ligne libellé + valeur en
///   boîte grisée compacte.

class UemoiFormCard extends StatelessWidget {
  const UemoiFormCard({
    super.key,
    required this.title,
    this.subtitle,
    this.color = AppTheme.accent,
    required this.children,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Color color;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: color),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark ? const Color(0x1F94A3B8) : const Color(0x1F64748B),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class UemoiFormField extends StatelessWidget {
  const UemoiFormField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.suffixText,
    this.keyboardType,
    this.validator,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.numeric = true,
    this.multiline = false,
    this.required = false,
    this.suffixIcon,
    this.labelFlex = 6,
    this.fieldFlex = 7,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? suffixText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool numeric;
  final bool multiline;
  final bool required;
  final Widget? suffixIcon;
  final int labelFlex;
  final int fieldFlex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final valueColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final fillColor = enabled
        ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
        : (isDark ? const Color(0xFF0B1220) : const Color(0xFFE9EDF3));

    final field = TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: multiline ? 3 : 1,
      textAlign: multiline ? TextAlign.left : TextAlign.right,
      keyboardType: keyboardType ??
          (numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text),
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\s]'))]
          : null,
      validator: validator ?? (required ? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null : null),
      style: TextStyle(
        fontSize: 12.5,
        fontFeatures: numeric ? const [FontFeature.tabularFigures()] : const [],
        fontWeight: FontWeight.w600,
        color: valueColor,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        hintText: hint ?? (numeric ? '0' : null),
        suffixText: suffixText,
        suffixIcon: suffixIcon,
        suffixStyle: TextStyle(
          color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
          fontSize: 9.5,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.2),
        ),
        filled: true,
        fillColor: fillColor,
      ),
    );

    final labelWidget = Text(
      required ? '$label *' : label,
      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: labelColor),
    );

    if (multiline) {
      // Champs longs : libellé au-dessus, boîte grisée pleine largeur.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            labelWidget,
            const SizedBox(height: 6),
            field,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x1F94A3B8) : const Color(0x1F64748B),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(flex: labelFlex, child: labelWidget),
          const SizedBox(width: 8),
          Expanded(flex: fieldFlex, child: SizedBox(height: 32, child: field)),
        ],
      ),
    );
  }
}

/// Ligne libellé + valeur en boîte grisée, en lecture seule (pas de champ
/// éditable) - même habillage que [UemoiFormField] pour afficher des
/// données déjà saisies (ex. cartes par exercice de la saisie AIB).
class UemoiInfoRow extends StatelessWidget {
  const UemoiInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.labelFlex = 6,
    this.fieldFlex = 7,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final int labelFlex;
  final int fieldFlex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final defaultValueColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final fillColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x1F94A3B8) : const Color(0x1F64748B),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: labelFlex,
            child: Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: labelColor)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: fieldFlex,
            child: Container(
              height: 32,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(4)),
              child: Text(
                value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? defaultValueColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UemoiFormDropdown<T> extends StatelessWidget {
  const UemoiFormDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
    this.required = false,
    this.labelFlex = 6,
    this.fieldFlex = 7,
  });

  final String label;
  final T? value;
  final List<T> items;
  final void Function(T?) onChanged;
  final String Function(T)? itemLabel;
  final bool required;
  final int labelFlex;
  final int fieldFlex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final valueColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final fillColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x1F94A3B8) : const Color(0x1F64748B),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: labelFlex,
            child: Text(
              required ? '$label *' : label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: labelColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: fieldFlex,
            child: SizedBox(
              height: 32,
              child: DropdownButtonFormField<T>(
                initialValue: value,
                isDense: true,
                isExpanded: true,
                icon: Icon(Icons.expand_more_rounded, size: 16, color: labelColor),
                validator: required ? (v) => v == null ? 'Champ requis' : null : null,
                items: items
                    .map((v) => DropdownMenuItem<T>(
                          value: v,
                          child: Text(
                            itemLabel != null ? itemLabel!(v) : v.toString(),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: valueColor),
                          ),
                        ))
                    .toList(),
                onChanged: onChanged,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: AppTheme.accent, width: 1.2),
                  ),
                  filled: true,
                  fillColor: fillColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
