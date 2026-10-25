import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'feya_logo.dart';

/// Network image with branded loading/failed states. Images may disappear; the UI must survive it.
class NetImage extends StatelessWidget {
  const NetImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.radius,
    this.semanticLabel,
  });
  final String? url;
  final BoxFit fit;
  final BorderRadius? radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: FeyaColors.surface2,
      alignment: Alignment.center,
      child: const Opacity(
        opacity: 0.45,
        child: FeyaLogo(size: 26, showWordmark: false),
      ),
    );
    Widget img = url == null || url!.isEmpty
        ? fallback
        : CachedNetworkImage(
            imageUrl: url!,
            fit: fit,
            fadeInDuration: const Duration(milliseconds: 180),
            placeholder: (_, _) => Container(color: FeyaColors.surface2),
            errorWidget: (_, _, _) => fallback,
          );
    if (radius != null) img = ClipRRect(borderRadius: radius!, child: img);
    return Semantics(image: true, label: semanticLabel, child: img);
  }
}
