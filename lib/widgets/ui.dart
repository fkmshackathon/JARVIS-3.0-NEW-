import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Small shared pieces so every screen states the same thing the same way.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.overline,
    this.trailing,
    this.padding = const EdgeInsets.all(SynchroSpacing.gutter),
  });

  final String title;
  final Widget child;
  final String? overline;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(SynchroRadius.card),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (overline != null) ...[
                      Text(
                        overline!.toUpperCase(),
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: SynchroSpacing.xs),
                    ],
                    Text(title, style: theme.textTheme.titleMedium),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: SynchroSpacing.md),
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    );
  }
}

enum Tone { neutral, good, warn, bad }

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = Tone.neutral,
    this.icon,
  });

  final String label;
  final Tone tone;
  final IconData? icon;

  static Color color(Tone tone, Brightness brightness) => switch (tone) {
    Tone.neutral =>
      brightness == Brightness.dark
          ? SynchroColors.onNavyMuted
          : SynchroColors.inkMuted,
    Tone.good =>
      brightness == Brightness.dark ? SynchroColors.okOnNavy : SynchroColors.ok,
    Tone.warn =>
      brightness == Brightness.dark
          ? SynchroColors.warnOnNavy
          : SynchroColors.warn,
    Tone.bad =>
      brightness == Brightness.dark
          ? SynchroColors.dangerOnNavy
          : SynchroColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    final ink = StatusChip.color(tone, Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SynchroSpacing.md,
        vertical: SynchroSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(SynchroRadius.pill),
        border: Border.all(color: ink.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: ink),
            const SizedBox(width: SynchroSpacing.sm),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: SynchroType.micro,
              fontWeight: FontWeight.w700,
              letterSpacing: SynchroType.overlineTracking * 0.6,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

class Stat extends StatelessWidget {
  const Stat({
    super.key,
    required this.value,
    required this.caption,
    this.tone = Tone.neutral,
  });

  final String value;
  final String caption;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: StatusChip.color(tone, theme.brightness),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(caption.toUpperCase(), style: theme.textTheme.labelSmall),
      ],
    );
  }
}

/// A labelled `value / total` bar used for demand against supply and per-faculty load.
class MeterRow extends StatelessWidget {
  const MeterRow({
    super.key,
    required this.label,
    required this.value,
    required this.limit,
    this.detail,
    this.overIsBad = true,
  });

  final String label;
  final int value;
  final int limit;
  final String? detail;
  final bool overIsBad;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = limit <= 0 ? 0.0 : (value / limit).clamp(0.0, 1.0);
    final over = limit > 0 && value > limit;
    final ink = over && overIsBad
        ? StatusChip.color(Tone.bad, theme.brightness)
        : over
        ? StatusChip.color(Tone.good, theme.brightness)
        : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SynchroSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$value${limit > 0 ? ' / $limit' : ''}',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: over ? ink : theme.colorScheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: SynchroSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: ratio),
              duration: SynchroMotion.standard,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: theme.colorScheme.outlineVariant,
                valueColor: AlwaysStoppedAnimation(ink),
              ),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: SynchroSpacing.xs),
            Text(detail!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class Notice extends StatelessWidget {
  const Notice({
    super.key,
    required this.text,
    this.tone = Tone.warn,
    this.icon,
    this.action,
  });

  final String text;
  final Tone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ink = StatusChip.color(tone, Theme.of(context).brightness);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: SynchroSpacing.md),
      padding: const EdgeInsets.all(SynchroSpacing.md),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SynchroRadius.chip),
        border: Border.all(color: ink.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? Icons.info_outline, size: 18, color: ink),
          const SizedBox(width: SynchroSpacing.md),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: ink),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.calendar_month_outlined,
    this.action,
  });

  final String title;
  final String body;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SynchroSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: SynchroSpacing.lg),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: SynchroSpacing.sm),
            Text(
              body,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: SynchroSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
