import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'app_colors.dart';

/// Chat-optimized Markdown stylesheet — light & dark aware.
MarkdownStyleSheet chatMarkdownStyle(Brightness b) {
  final isDark = b == Brightness.dark;
  final textColor = AppColors.text(b);
  final secondaryColor = AppColors.textSecondary(b);

  return MarkdownStyleSheet.fromTheme(ThemeData(
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: textColor, fontSize: 15, height: 1.6),
    ),
  )).copyWith(
    // ── Paragraph ──
    p: TextStyle(color: textColor, fontSize: 15, height: 1.6),
    pPadding: const EdgeInsets.only(bottom: 6),

    // ── Headings ──
    h1: TextStyle(color: textColor, fontSize: 19, fontWeight: FontWeight.w700, height: 1.4),
    h1Padding: const EdgeInsets.only(top: 12, bottom: 6),
    h2: TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.w700, height: 1.4),
    h2Padding: const EdgeInsets.only(top: 10, bottom: 4),
    h3: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
    h3Padding: const EdgeInsets.only(top: 8, bottom: 4),

    // ── Bold / Italic ──
    strong: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700),
    em: TextStyle(color: textColor, fontSize: 15, fontStyle: FontStyle.italic),

    // ── Links (blue underlined, distinctive) ──
    a: TextStyle(
      color: AppColors.accentBlue,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.accentBlue.withValues(alpha: 0.5),
    ),

    // ── Inline code ──
    code: TextStyle(
      color: isDark ? const Color(0xFFF47067) : const Color(0xFFCF222E),
      fontSize: 13,
      fontFamily: 'monospace',
      backgroundColor: isDark ? const Color(0xFF1C2129) : const Color(0xFFF6F8FA),
    ),
    codeblockDecoration: BoxDecoration(
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: isDark ? const Color(0xFF21262D) : const Color(0xFFD0D7DE)),
    ),
    codeblockPadding: const EdgeInsets.all(12),

    // ── Blockquote (left accent border) ──
    blockquoteDecoration: BoxDecoration(
      color: (AppColors.accentBlue).withValues(alpha: isDark ? 0.08 : 0.04),
      borderRadius: BorderRadius.circular(6),
      border: Border(
        left: BorderSide(color: AppColors.accentBlue.withValues(alpha: 0.7), width: 3),
      ),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    blockquote: TextStyle(color: secondaryColor, fontSize: 14, height: 1.5),

    // ── Lists ──
    listBullet: TextStyle(color: secondaryColor, fontSize: 15),
    listBulletPadding: const EdgeInsets.only(left: 4, right: 8),
    listIndent: 20,

    // ── Horizontal rule ──
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.border(b).withValues(alpha: 0.05), width: 1)),
    ),

    // ── Strikethrough ──
    del: TextStyle(color: secondaryColor.withValues(alpha: 0.6), fontSize: 15, decoration: TextDecoration.lineThrough),
  );
}
