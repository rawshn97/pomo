import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pomo/models/remote_session.dart';
import 'package:pomo/pages/timer/cubit/timer_cubit.dart';
import 'package:pomo/services/remote_session_service.dart';

/// Renders a live cross-device presence banner when another linked device is
/// actively running a focus timer.
class RemoteSessionPresenceBanner extends StatelessWidget {
  const RemoteSessionPresenceBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final localTimerRunning = context.select<TimerCubit, bool>(
      (c) =>
          c.state.status == TimerStatus.running ||
          c.state.duration > Duration.zero,
    );

    if (localTimerRunning) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<RemoteSession?>(
      valueListenable: RemoteSessionService().remoteSessionNotifier,
      builder: (context, remoteSession, _) {
        if (remoteSession == null || !remoteSession.isRunning) {
          return const SizedBox.shrink();
        }

        final theme = Theme.of(context);
        final tagDisplay = remoteSession.tagName != null
            ? '${remoteSession.tagIcon ?? "⏱️"} ${remoteSession.tagName}'
            : 'Focus Session';
        final taskDisplay = remoteSession.taskTitle;

        final deviceIcon =
            remoteSession.deviceName.toLowerCase().contains('mobile')
                ? Icons.phone_android
                : (remoteSession.deviceName.toLowerCase().contains('mac')
                    ? Icons.laptop_mac
                    : Icons.devices);

        return Container(
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.greenAccent.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                ),
                child: Icon(
                  deviceIcon,
                  size: 16,
                  color: Colors.greenAccent.shade400,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${remoteSession.deviceName} is focusing',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            remoteSession.formattedRemaining,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent.shade200,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      taskDisplay != null
                          ? '$tagDisplay • $taskDisplay'
                          : tagDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
