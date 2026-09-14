import 'package:flutter/material.dart';
import 'package:pomo/theme/rawshn_brand.dart';

class MonoTime extends StatelessWidget {
  const MonoTime({
    required this.duration,
    this.style,
    super.key,
  });

  final String duration;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      duration,
      style: (style ?? Theme.of(context).textTheme.displayLarge)!.copyWith(
        fontFamily: RawshnBrand.fontMono,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
