import 'package:flutter/material.dart';
import 'package:pomo/theme/rawshn_brand.dart';

class BoldMonoTime extends StatelessWidget {
  const BoldMonoTime({
    required this.duration,
    this.style,
    super.key,
  });

  final String duration;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseStyle =
        (style ?? Theme.of(context).textTheme.displayLarge)!.copyWith(
      fontFamily: RawshnBrand.fontMono,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: scheme.onSurface,
      letterSpacing: -1.5,
    );

    return Text(
      duration,
      style: baseStyle,
    );
  }
}
