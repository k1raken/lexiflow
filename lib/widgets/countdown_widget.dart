import 'dart:async';
import 'package:flutter/material.dart';
import '../services/daily_word_service.dart';

class CountdownWidget extends StatefulWidget {
  final TextStyle? style;
  final Color? iconColor;
  final bool showIcon;

  const CountdownWidget({
    super.key,
    this.style,
    this.iconColor,
    this.showIcon = true,
  });

  @override
  State<CountdownWidget> createState() => _CountdownWidgetState();
}

class _CountdownWidgetState extends State<CountdownWidget> {
  Timer? _timer;
  Duration _timeUntilReset = Duration.zero;
  final DailyWordService _dailyWordService = DailyWordService();

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final newTime = _dailyWordService.getTimeUntilReset();
    if (newTime.inSeconds != _timeUntilReset.inSeconds) {
      if (mounted) {
        setState(() {
          _timeUntilReset = newTime;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _timeUntilReset.inHours;
    final minutes = _timeUntilReset.inMinutes % 60;
    final seconds = _timeUntilReset.inSeconds % 60;

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Theme-aware colors for high contrast
    final backgroundColor = isDark
        ? Colors.white.withOpacity(0.15)
        : colorScheme.primary.withOpacity(0.1);
    
    final borderColor = isDark
        ? Colors.white.withOpacity(0.3)
        : colorScheme.primary.withOpacity(0.3);
    
    final textColor = isDark
        ? Colors.white.withOpacity(0.9)
        : colorScheme.primary;
    
    final iconColorResolved = widget.iconColor ?? textColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showIcon) ...[
            Icon(
              Icons.timer_outlined,
              color: iconColorResolved,
              size: 16,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            '${hours}s ${minutes}d ${seconds}sn',
            style: widget.style ??
                TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
        ],
      ),
    );
  }
}
