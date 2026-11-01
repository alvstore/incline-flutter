import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// M3 Home Greeting Header
/// Displays a personalized time-aware greeting, member status, consistency streak count,
/// and an interactive notification icon with an M3 Badge counter.
///
/// Material 3 Design Choices:
/// - Uses [ColorScheme.surface] and [ColorScheme.surfaceContainerLow] for surface layering.
/// - Adheres strictly to [TextTheme] typography scale (titleMedium, labelSmall, bodySmall).
/// - Implements the Material 3 [Badge] component with tonal error/primary styling.
/// - Micro-interactions leverage [HapticFeedback.lightImpact] for tactile feedback.
class HomeGreetingHeader extends StatelessWidget {
  final String memberName;
  final String? avatarUrl;
  final String membershipStatus;
  final int streakDays;
  final int unreadNotifications;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onStreakTap;

  const HomeGreetingHeader({
    super.key,
    required this.memberName,
    this.avatarUrl,
    this.membershipStatus = 'ACTIVE',
    this.streakDays = 0,
    this.unreadNotifications = 0,
    this.onNotificationTap,
    this.onProfileTap,
    this.onStreakTap,
  });

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'M';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  Widget _buildInitialsAvatar(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      width: 44,
      height: 44,
      color: colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        _getInitials(memberName),
        style: textTheme.titleSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final hasNetworkAvatar = avatarUrl != null && avatarUrl!.startsWith('http');
    debugPrint('[HomeGreetingHeader] memberName: $memberName, avatarUrl: $avatarUrl, hasNetworkAvatar: $hasNetworkAvatar');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Profile Avatar with Subtle M3 Tonal Ring
          Semantics(
            button: true,
            label: 'Open Member Profile',
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onProfileTap?.call();
                },
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: hasNetworkAvatar
                          ? Image.network(
                              avatarUrl!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildInitialsAvatar(colorScheme, textTheme),
                            )
                          : (avatarUrl != null && avatarUrl!.startsWith('assets/'))
                              ? Image.asset(
                                  avatarUrl!,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildInitialsAvatar(colorScheme, textTheme),
                                )
                              : _buildInitialsAvatar(colorScheme, textTheme),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Greeting & Member Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getTimeGreeting().toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        memberName,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        membershipStatus,
                        style: textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Consistency Streak Pill Chip
          Semantics(
            button: true,
            label: '$streakDays day streak active',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onStreakTap?.call();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.35),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        color: colorScheme.primary,
                        size: 18,
                      )
                          .animate(onPlay: (controller) => controller.repeat(reverse: true))
                          .scale(
                            begin: const Offset(1.0, 1.0),
                            end: const Offset(1.18, 1.18),
                            duration: 900.ms,
                            curve: Curves.easeInOut,
                          )
                          .shimmer(
                            duration: 1800.ms,
                            color: colorScheme.primary.withValues(alpha: 0.5),
                          ),
                      const SizedBox(width: 4),
                      Text(
                        '$streakDays',
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // M3 Notification Badge Button
          Semantics(
            button: true,
            label: unreadNotifications > 0
                ? '$unreadNotifications unread notifications'
                : 'Notifications',
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onNotificationTap?.call();
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Badge(
                    isLabelVisible: unreadNotifications > 0,
                    backgroundColor: colorScheme.error,
                    textColor: colorScheme.onError,
                    label: Text(
                      '$unreadNotifications',
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onError,
                      ),
                    ),
                    child: Icon(
                      Icons.notifications_outlined,
                      size: 24,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
