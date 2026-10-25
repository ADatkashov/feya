import 'package:flutter/material.dart';

import '../theme/tokens.dart';

enum FeyaButtonKind { primary, secondary, ghost, danger }

/// Primary action button: gradient fill with soft glow. 52dp tall, full width by default.
class FeyaButton extends StatelessWidget {
  const FeyaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = FeyaButtonKind.primary,
    this.loading = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final FeyaButtonKind kind;
  final bool loading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white,
            ),
          )
        else ...[
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 16,
                color: kind == FeyaButtonKind.ghost
                    ? FeyaColors.primary
                    : _fg(enabled),
              ),
            ),
          ),
        ],
      ],
    );

    final radius = BorderRadius.circular(FeyaRadius.pill);
    final decoration = switch (kind) {
      FeyaButtonKind.primary => BoxDecoration(
        gradient: enabled ? FeyaColors.gradient : null,
        color: enabled ? null : FeyaColors.surface2,
        borderRadius: radius,
        boxShadow: enabled ? FeyaColors.softGlow : null,
      ),
      FeyaButtonKind.secondary => BoxDecoration(
        color: FeyaColors.surface,
        borderRadius: radius,
        border: Border.all(
          color: enabled ? FeyaColors.primary : FeyaColors.border,
          width: 1.4,
        ),
      ),
      FeyaButtonKind.danger => BoxDecoration(
        color: Colors.transparent,
        borderRadius: radius,
        border: Border.all(
          color: enabled ? FeyaColors.error : FeyaColors.border,
          width: 1.4,
        ),
      ),
      FeyaButtonKind.ghost => BoxDecoration(borderRadius: radius),
    };

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52, minWidth: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 12,
                ),
                child: Center(
                  widthFactor: expand ? null : 1,
                  heightFactor: 1,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _fg(bool enabled) {
    if (!enabled) return FeyaColors.textSecondary;
    return switch (kind) {
      FeyaButtonKind.primary => Colors.white,
      FeyaButtonKind.secondary => FeyaColors.text,
      FeyaButtonKind.danger => FeyaColors.error,
      FeyaButtonKind.ghost => FeyaColors.primary,
    };
  }
}
