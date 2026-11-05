import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// Grouped settings rows (docs/plans/settings-polish.md): a quiet label, then
/// one bordered surface holding the rows, with dividers inset to the text.
class SettingsGroup extends StatelessWidget {
  final String? label;
  final List<Widget> children;

  /// Where the dividers start: past the leading icon by default.
  final double dividerIndent;

  const SettingsGroup({super.key, this.label, required this.children, this.dividerIndent = _textInset});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, 0, Space.xs, Space.sm),
            child: Semantics(
              header: true,
              child: Text(label!, style: context.text.labelLarge?.copyWith(color: colors.onSurfaceVariant)),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: settingsGroupColor(context),
            borderRadius: Radii.controlAll,
            border: Border.all(color: colors.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.control - 1),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) Divider(indent: dividerIndent, height: 1),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The groups' surface: the lightest one in light mode; in dark mode one
/// step above the background, since the darkest one looks sunk in.
Color settingsGroupColor(BuildContext context) {
  final colors = context.colors;
  return context.theme.brightness == Brightness.dark ? colors.surfaceContainerLow : colors.surfaceContainerLowest;
}

/// 16 padding + 20 icon + 16 gap: where row text starts.
const double _textInset = Space.lg + 20 + Space.lg;

/// One tappable settings row: optional icon, a title, an optional subtitle
/// line, an optional value on the right and a chevron when it navigates.
/// Shrinks slightly while pressed (none under reduced motion).
class SettingsRow extends StatefulWidget {
  final IconData? icon;
  final String title;

  /// A line under the title, styled muted; a widget so it can hold a [StatusDot].
  final Widget? subtitle;

  /// Shown on the right, muted; [valueFigures] sets it in Geist Mono.
  final String? value;
  final bool valueFigures;

  /// The value's color, when muted isn't right (a balance on Home).
  final Color? valueColor;

  /// Replaces the default chevron (shown when [onTap] is set).
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Error color, for actions that remove something.
  final bool destructive;

  /// False dims the row and ignores taps (say why in [subtitle]).
  final bool enabled;

  const SettingsRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.valueFigures = false,
    this.valueColor,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.enabled = true,
  });

  @override
  State<SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<SettingsRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final onTap = widget.enabled ? widget.onTap : null;
    final enabled = onTap != null;
    final muted = colors.onSurfaceVariant;
    final accent = widget.destructive ? colors.error : null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final trailing =
        widget.trailing ??
        (enabled && !widget.destructive ? Icon(Icons.chevron_right_rounded, size: 20, color: colors.outline) : null);
    final valueStyle = context.text.bodyMedium?.copyWith(color: widget.valueColor ?? muted);

    final content = Row(
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 20, color: accent ?? muted),
          const SizedBox(width: Space.lg),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500, color: accent),
              ),
              if (widget.subtitle != null)
                DefaultTextStyle.merge(
                  style: context.text.bodyMedium?.copyWith(color: muted),
                  child: widget.subtitle!,
                ),
            ],
          ),
        ),
        if (widget.value != null) ...[
          const SizedBox(width: Space.md),
          Text(widget.value!, style: widget.valueFigures ? figures(valueStyle) : valueStyle),
        ],
        if (trailing != null) ...[const SizedBox(width: Space.sm), trailing],
      ],
    );

    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: widget.subtitle == null ? 56 : 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 10),
            child: Opacity(
              opacity: widget.enabled ? 1 : 0.5,
              child: AnimatedScale(
                scale: _pressed && !reduceMotion ? Motion.pressScale : 1,
                duration: reduceMotion ? Duration.zero : Motion.press,
                curve: Motion.easeOut,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row that toggles a setting; the whole row is the hit target.
class SettingsSwitchRow extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SettingsSwitchRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  void _set(bool next) {
    HapticFeedback.selectionClick();
    onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MergeSemantics(
      child: InkWell(
        onTap: onChanged == null ? null : () => _set(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 14, Space.md, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 20, color: colors.onSurfaceVariant),
                ),
                const SizedBox(width: Space.lg),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: context.text.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              Switch(value: value, onChanged: onChanged == null ? null : _set),
            ],
          ),
        ),
      ),
    );
  }
}

enum SettingsStatus {
  /// Connected and working.
  ok,

  /// Not set up yet (a hollow dot).
  off,

  /// Set up but failing.
  failing,

  /// Being checked.
  busy,
}

/// A status dot with its label (and an optional value, in Geist Mono), so
/// the meaning never rests on color alone: "off" is also hollow. The dot
/// crossfades and the label swaps with a short fade when the status changes.
class StatusDot extends StatelessWidget {
  final SettingsStatus status;
  final String label;
  final String? value;

  const StatusDot({super.key, required this.status, required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (fill, ring) = switch (status) {
      SettingsStatus.ok => (colors.primary, colors.primary),
      SettingsStatus.off => (Colors.transparent, colors.onSurfaceVariant),
      SettingsStatus.failing => (colors.error, colors.error),
      SettingsStatus.busy => (colors.outline, colors.outline),
    };
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final style = DefaultTextStyle.of(context).style;
    final text = value == null ? label : '$label · ';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: Motion.small,
          curve: Motion.easeOut,
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: 1.5),
          ),
        ),
        const SizedBox(width: Space.sm),
        Flexible(
          child: AnimatedSwitcher(
            duration: reduceMotion ? const Duration(milliseconds: 120) : Motion.small,
            switchInCurve: Motion.easeOut,
            switchOutCurve: Motion.easeOut,
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: reduceMotion
                  ? child
                  : SlideTransition(
                      position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(animation),
                      child: child,
                    ),
            ),
            child: Text.rich(
              key: ValueKey('$status$label${value ?? ''}'),
              TextSpan(
                text: text,
                children: [if (value != null) TextSpan(text: value, style: figures(style))],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
