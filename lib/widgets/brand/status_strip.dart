import 'package:flutter/material.dart';
import 'package:pomo/theme/rawshn_brand.dart';

/// Terminal-style brand strip: `pomo@focus: ~/path $`
class StatusStrip extends StatelessWidget {
  const StatusStrip({
    required this.path,
    super.key,
  });

  final String path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: scheme.outline.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            fontFamily: RawshnBrand.fontMono,
            fontSize: 11,
            height: 1.3,
            color: scheme.onSurfaceVariant,
          ),
          children: [
            TextSpan(
              text: 'pomo@focus',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: ': $path \$'),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
