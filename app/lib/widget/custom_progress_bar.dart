import 'package:dropit_app/widget/mornye/app_glass_progress.dart';
import 'package:flutter/material.dart';

class CustomProgressBar extends StatelessWidget {
  final double? progress;
  final double borderRadius;
  final Color? color;

  const CustomProgressBar({required this.progress, this.borderRadius = 10, this.color});

  @override
  Widget build(BuildContext context) {
    return AppGlassProgress(
      progress: progress,
      borderRadius: borderRadius,
      color: color,
      height: 10,
    );
  }
}
