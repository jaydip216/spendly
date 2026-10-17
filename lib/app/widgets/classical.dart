import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/spendly_theme.dart';

/// The building blocks of the Classical system: hairline rules, tracked-out
/// section labels, outlined buttons, pill chips and flat meters. Screens are
/// assembled from these rather than from Material's cards and filled buttons.

/// Root of a tab screen. Paints the ground and supplies the Material ancestor
/// that ink effects need, so a tab renders correctly on its own as well as
/// inside the shell.
class TabPage extends StatelessWidget {
  const TabPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SpendlyTokens.of(context).background,
      child: SafeArea(bottom: false, child: child),
    );
  }
}

/// A 1px hairline. The system uses rules where other designs use card edges.
class Rule extends StatelessWidget {
  const Rule({super.key, this.height = 1, this.color});

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: color ?? SpendlyTokens.of(context).divider,
    );
  }
}

/// Tracked-out uppercase gold label that opens a section.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final label = Text(text.toUpperCase(), style: tokens.kicker());
    if (trailing == null) return label;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: label),
        trailing!,
      ],
    );
  }
}

/// Serif section heading, optionally with a ghost action on the right.
class SectionHeading extends StatelessWidget {
  const SectionHeading(
    this.text, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.size = 19,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(text, style: tokens.heading(size))),
        if (actionLabel != null)
          ClassicalButton(
            label: actionLabel!,
            variant: ClassicalButtonVariant.ghost,
            fontSize: 11.5,
            onPressed: onAction,
          ),
      ],
    );
  }
}

enum ClassicalButtonVariant { primary, secondary, ghost }

/// Outlined buttons — the system has no filled fills; weight comes from the
/// gold stroke instead.
class ClassicalButton extends StatelessWidget {
  const ClassicalButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ClassicalButtonVariant.primary,
    this.height = 40,
    this.fontSize = 13,
    this.expand = false,
    this.foreground,
    this.borderColor,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final ClassicalButtonVariant variant;
  final double height;
  final double fontSize;
  final bool expand;
  final Color? foreground;
  final Color? borderColor;
  final Widget? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final enabled = onPressed != null && !busy;

    final (Color fg, Color? border) = switch (variant) {
      ClassicalButtonVariant.primary => (tokens.accent, tokens.accent),
      ClassicalButtonVariant.secondary => (tokens.ink, tokens.divider),
      ClassicalButtonVariant.ghost => (tokens.accent, null),
    };
    final resolvedForeground = foreground ?? fg;
    final resolvedBorder = borderColor ?? border;

    final child = busy
        ? SizedBox(
            width: fontSize + 4,
            height: fontSize + 4,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: resolvedForeground,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                IconTheme(
                  data: IconThemeData(
                    color: resolvedForeground,
                    size: fontSize + 3,
                  ),
                  child: icon!,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.heading(
                    fontSize,
                    weight: FontWeight.w600,
                    color: resolvedForeground,
                    height: 1.2,
                    letterSpacingEm: 0,
                  ),
                ),
              ),
            ],
          );

    final hitHeight = math.max(height, 48.0);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: hitHeight,
            width: expand ? double.infinity : null,
            child: Center(
              child: Container(
                height: height,
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(
                  horizontal: variant == ClassicalButtonVariant.ghost ? 5 : 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: resolvedBorder == null
                      ? null
                      : Border.all(color: resolvedBorder),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Borderless icon button with a 48×48 minimum touch target.
class IconAction extends StatelessWidget {
  const IconAction({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 34,
    this.iconSize = 19,
    this.showDot = false,
    this.dotColor,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final bool showDot;
  final Color? dotColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final hitSize = math.max(size, 48.0);
    Widget button = InkResponse(
      onTap: onPressed,
      radius: hitSize / 2,
      child: SizedBox(
        width: hitSize,
        height: hitSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: iconSize, color: color ?? tokens.ink),
            if (showDot)
              Positioned(
                top: (hitSize - size) / 2 + size * 0.18,
                right: (hitSize - size) / 2 + size * 0.18,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor ?? tokens.accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Pill chip used for every filter and picker in the app.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.swatch,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    return Material(
      color: selected ? tokens.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? tokens.accent : tokens.divider,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (swatch != null) ...[
                    Container(width: 8, height: 8, color: swatch),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    label,
                    style: tokens.body(
                      12,
                      height: 1.3,
                      color: selected ? tokens.accentInk : tokens.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small rounded tag — status only, never interactive.
class StatusTag extends StatelessWidget {
  const StatusTag(this.label, {super.key, this.outlined = false});

  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: outlined ? null : tokens.accentSoft,
        border: outlined ? Border.all(color: tokens.accent) : null,
      ),
      child: Text(
        label,
        style: tokens.body(
          11,
          height: 1.3,
          color: outlined ? tokens.accent : tokens.accentInk,
        ),
      ),
    );
  }
}

/// A row of figures separated by vertical hairlines, ruled above and below.
class MetricStrip extends StatelessWidget {
  const MetricStrip({super.key, required this.metrics, this.valueSize = 22});

  final List<({String value, String label})> metrics;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final children = <Widget>[];
    for (var i = 0; i < metrics.length; i++) {
      if (i > 0) {
        children.add(Container(width: 1, color: tokens.divider));
      }
      children.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Column(
              children: [
                Text(
                  metrics[i].value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.figure(valueSize),
                ),
                const SizedBox(height: 3),
                Text(
                  metrics[i].label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.metricLabel(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: tokens.divider),
          bottom: BorderSide(color: tokens.divider),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Label, amount, optional share, and a flat 5px meter underneath.
class MeterRow extends StatelessWidget {
  const MeterRow({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    this.trailingNote,
    this.labelNote,
    this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final double fraction;
  final String? trailingNote;
  final String? labelNote;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.body(13.5, height: 1.3),
              ),
            ),
            if (labelNote != null) ...[
              const SizedBox(width: 8),
              Text(
                labelNote!,
                style: tokens.body(
                  11.5,
                  color: tokens.muted(0.45),
                  height: 1.3,
                ),
              ),
            ],
            const Spacer(),
            Text(value, style: tokens.body(13.5, height: 1.3, tabular: true)),
            if (trailingNote != null) ...[
              const SizedBox(width: 7),
              Text(
                trailingNote!,
                style: tokens.body(
                  11.5,
                  color: tokens.muted(0.45),
                  height: 1.3,
                  tabular: true,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 5,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: tokens.track)),
              FractionallySizedBox(
                widthFactor: fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0,
                child: ColoredBox(color: color ?? tokens.accentStrong),
              ),
            ],
          ),
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: content,
        ),
      ),
    );
  }
}

/// Circled initial that opens every spend row.
class InitialAvatar extends StatelessWidget {
  const InitialAvatar(this.initial, {super.key, this.size = 34});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: tokens.divider),
      ),
      child: Text(
        initial,
        style: tokens.heading(
          size * 0.41,
          color: tokens.accentDeep,
          letterSpacingEm: 0,
        ),
      ),
    );
  }
}

/// 44×25 pill toggle inside a 48×48 touch target.
class ClassicalSwitch extends StatelessWidget {
  const ClassicalSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    return InkResponse(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      radius: 24,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            width: 44,
            height: 25,
            padding: const EdgeInsets.all(2),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: value ? tokens.accentSoft : Colors.transparent,
              border: Border.all(color: value ? tokens.accent : tokens.divider),
            ),
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? tokens.accent : tokens.muted(0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings-style row: title, subtitle, chevron or trailing control.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.topRule = true,
    this.bottomRule = false,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool topRule;
  final bool bottomRule;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    final row = Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        border: Border(
          top: topRule ? BorderSide(color: tokens.divider) : BorderSide.none,
          bottom: bottomRule
              ? BorderSide(color: tokens.divider)
              : BorderSide.none,
        ),
      ),
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 19, color: tokens.accent),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tokens.body(14.5, height: 1.3)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: tokens.body(
                      11.5,
                      color: tokens.muted(0.52),
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          if (showChevron) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: tokens.muted(0.4),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// Centred serif message used for empty and error states.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.action,
    this.titleSize = 22,
  });

  final String title;
  final String? message;
  final Widget? action;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: tokens.heading(titleSize),
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: tokens.body(13.5, color: tokens.muted(0.58)),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Tinted block with a gold edge — warnings and "worth knowing" copy.
class Callout extends StatelessWidget {
  const Callout({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: tokens.accentSoft,
        border: Border.all(color: tokens.accentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tokens.heading(
              16,
              color: tokens.accentInk,
              letterSpacingEm: 0,
            ),
          ),
          const SizedBox(height: 5),
          Text(body, style: tokens.body(12.5, color: tokens.accentInk)),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

/// The 38×3 grab handle at the top of every sheet.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    return Container(
      width: 38,
      height: 3,
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      decoration: BoxDecoration(
        color: tokens.divider,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Bottom sheet with the system's border-radius, ground and scrim.
Future<T?> showClassicalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool expand = false,
}) {
  final tokens = SpendlyTokens.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: tokens.background,
    barrierColor: const Color(0xFF201F1D).withValues(alpha: 0.46),
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      side: BorderSide(color: tokens.divider),
    ),
    constraints: expand
        ? const BoxConstraints(maxHeight: double.infinity)
        : null,
    builder: builder,
  );
}

/// Ring chart drawn as gapped strokes — the Insights donut.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    required this.centerTop,
    required this.centerBottom,
    this.size = 132,
  });

  /// (share of the whole 0..1, colour), largest first.
  final List<({double fraction, Color color})> slices;
  final String centerTop;
  final String centerBottom;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = SpendlyTokens.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(
              slices: slices,
              guide: tokens.divider,
              stroke: size * 0.114,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(centerTop, style: tokens.figure(size * 0.144)),
              Text(
                centerBottom.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.metricLabel(size: size * 0.072),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.guide,
    required this.stroke,
  });

  final List<({double fraction, Color color})> slices;
  final Color guide;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = size.width * 0.348;

    canvas.drawCircle(
      center,
      size.width * 0.394,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = guide,
    );

    var start = -math.pi / 2;
    const gap = 0.02;
    for (final slice in slices) {
      final sweep = slice.fraction * 2 * math.pi;
      if (sweep <= gap) continue;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        start,
        sweep - gap,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = slice.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.slices != slices ||
      oldDelegate.guide != guide ||
      oldDelegate.stroke != stroke;
}
