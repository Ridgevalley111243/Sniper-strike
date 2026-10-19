import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// Integration point for a real rewarded-ad network (e.g. Google Mobile Ads
/// on Android/iOS). Implement this and pass it to `AppServices` — nothing else
/// in the app needs to change.
abstract class RewardedAdProvider {
  String get name;

  /// Demo providers never show a real advertisement and are labeled as such.
  bool get isDemo;

  /// Shows the ad. Completes with true only when the reward was earned.
  Future<bool> showRewarded(BuildContext context);
}

/// Used when no ad network is configured. It does not pretend to be an ad:
/// it shows an explicit "demo ad slot" with a short countdown so the locked →
/// unlocked lyrics flow can be tested end to end.
class DemoRewardedAdProvider implements RewardedAdProvider {
  const DemoRewardedAdProvider({this.length = const Duration(seconds: 5)});
  final Duration length;

  @override
  String get name => 'Demo ad slot';

  @override
  bool get isDemo => true;

  @override
  Future<bool> showRewarded(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DemoAdDialog(length: length),
    );
    return ok ?? false;
  }
}

class _DemoAdDialog extends StatefulWidget {
  const _DemoAdDialog({required this.length});
  final Duration length;
  @override
  State<_DemoAdDialog> createState() => _DemoAdDialogState();
}

class _DemoAdDialogState extends State<_DemoAdDialog> {
  late int _left = widget.length.inSeconds;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _left <= 0;
    return AlertDialog(
      title: const Text('Demo ad slot'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 140,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfacePrimary,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Text(done ? 'Reward earned' : '$_left',
              textAlign: TextAlign.center, style: (done ? AppText.h2 : AppText.display).secondaryColor),
        ),
        const SizedBox(height: Space.md),
        Text(
          'No ad network is connected, so this placeholder stands in for a rewarded ad. '
          'Production builds plug a real provider into RewardedAdProvider.',
          style: AppText.secondary.muted,
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Close')),
        FilledButton(onPressed: done ? () => Navigator.pop(context, true) : null, child: const Text('Unlock lyrics')),
      ],
    );
  }
}
