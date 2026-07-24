import 'package:flutter/material.dart';

import '../theme/app_brand.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 36,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppBrand.logoAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class DevelopedByLabel extends StatelessWidget {
  const DevelopedByLabel({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppBrand.developedBy,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: compact ? 11 : 12,
          ),
    );
  }
}
