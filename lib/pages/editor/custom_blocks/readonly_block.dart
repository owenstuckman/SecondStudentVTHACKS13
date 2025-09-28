// lib/pages/editor/custom_blocks/readonly_block.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// This block renders a non-editable card of content.
/// You can store either plain text or a nested delta; here we keep it simple with plain text + optional title.
class ReadonlyBlockEmbed extends CustomBlockEmbed {
  ReadonlyBlockEmbed({
    String? title,
    required String body,
    String variant = 'note', // note|warning|info|success...
  }) : super(
          kType,
          jsonEncode({
            'title': title,
            'body': body,
            'variant': variant,
          }),
        );

  static const String kType = 'readonly';

  static ReadonlyBlockEmbed fromRaw(dynamic raw) {
    Map<String, dynamic> m;
    if (raw is String) {
      m = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } else if (raw is Map<String, dynamic>) {
      m = raw;
    } else {
      m = const {};
    }
    return ReadonlyBlockEmbed(
      title: (m['title'] as String?)?.toString(),
      body: (m['body'] ?? '').toString(),
      variant: (m['variant'] ?? 'note').toString(),
    );
  }

  Map<String, dynamic> get dataMap {
    try {
      if (data is String) return jsonDecode(data) as Map<String, dynamic>;
      if (data is Map<String, dynamic>) return data as Map<String, dynamic>;
    } catch (_) {}
    return const {'title': null, 'body': '', 'variant': 'note'};
  }

  String? get title => (dataMap['title'] as String?)?.toString();
  String get body => (dataMap['body'] ?? '').toString();
  String get variant => (dataMap['variant'] ?? 'note').toString();
}

class ReadonlyEmbedBuilder implements EmbedBuilder {
  const ReadonlyEmbedBuilder();

  @override
  String get key => ReadonlyBlockEmbed.kType;

  @override
  bool get expanded => false;

  @override
  WidgetSpan buildWidgetSpan(Widget child) => WidgetSpan(child: child);

  @override
  String toPlainText(Embed node) {
    final m = ReadonlyBlockEmbed.fromRaw(node.value.data);
    return '[readonly ${m.title ?? ''}] ${m.body}';
  }

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final m = ReadonlyBlockEmbed.fromRaw(embedContext.node.value.data);

    final colors = _variantColors(context, m.variant);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((m.title ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                m.title!,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.fg,
                    ),
              ),
            ),
          Text(
            m.body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.fg),
          ),
        ],
      ),
    );
  }

  _VariantColors _variantColors(BuildContext ctx, String v) {
    final theme = Theme.of(ctx).colorScheme;
    switch (v) {
      case 'warning':
        return _VariantColors(
          bg: theme.errorContainer.withValues(alpha: 0.18),
          border: theme.error.withValues(alpha: 0.5),
          fg: theme.onErrorContainer,
        );
      case 'info':
        return _VariantColors(
          bg: theme.secondaryContainer.withValues(alpha: 0.2),
          border: theme.secondary.withValues(alpha: 0.5),
          fg: theme.onSecondaryContainer,
        );
      case 'success':
        return _VariantColors(
          bg: theme.tertiaryContainer.withValues(alpha: 0.2),
          border: theme.tertiary.withValues(alpha: 0.5),
          fg: theme.onTertiaryContainer,
        );
      default:
        return _VariantColors(
          bg: theme.surfaceContainerHighest,
          border: theme.outlineVariant,
          fg: theme.onSurface,
        );
    }
  }
}

class _VariantColors {
  const _VariantColors({required this.bg, required this.border, required this.fg});
  final Color bg;
  final Color border;
  final Color fg;
}
