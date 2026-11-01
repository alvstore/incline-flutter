import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/models.dart';
import '../../core/routing/app_router.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/bento_card.dart';
import '../../core/widgets/dumbbell_loader.dart';

/// Material 3 Notifications and Real-time Club Bulletins Screen
/// Subscribes directly to Supabase Realtime postgres_changes on public.notifications
class NotificationsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToBookings;
  final VoidCallback? onNavigateToWorkout;

  const NotificationsScreen({
    super.key,
    this.onNavigateToBookings,
    this.onNavigateToWorkout,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<GymNotification> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _activeFilter = 'all';
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeToRealtimeNotifications();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      SupabaseService.instance.unsubscribeChannel(_realtimeChannel!);
    }
    super.dispose();
  }

  void _subscribeToRealtimeNotifications() {
    try {
      _realtimeChannel = SupabaseService.instance.subscribeToNotifications(
        onNotificationChanged: () {
          if (mounted) {
            _loadNotifications(silent: true);
          }
        },
      );
    } catch (e) {
      debugPrint('[NotificationsScreen] Realtime setup notice: $e');
    }
  }

  Future<void> _loadNotifications({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await SupabaseService.instance.fetchNotifications();
      if (mounted) {
        setState(() {
          _notifications = data;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('[NotificationsScreen] Fetch error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not retrieve club bulletins. Check your internet connection.';
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    HapticFeedback.lightImpact();
    setState(() {
      _notifications = _notifications.map((n) {
        return GymNotification(
          id: n.id,
          title: n.title,
          message: n.message,
          timestamp: n.timestamp,
          type: n.type,
          isRead: true,
          badge: n.badge,
          actionLabel: n.actionLabel,
        );
      }).toList();
    });

    await SupabaseService.instance.markAllNotificationsAsRead();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: context.cardElevated,
          content: Text(
            'All notifications marked as read',
            style: GoogleFonts.outfit(color: context.brandAccent),
          ),
        ),
      );
    }
  }

  Future<void> _markSingleAsRead(GymNotification item) async {
    if (item.isRead) return;
    HapticFeedback.selectionClick();
    setState(() {
      final idx = _notifications.indexWhere((n) => n.id == item.id);
      if (idx != -1) {
        final cur = _notifications[idx];
        _notifications[idx] = GymNotification(
          id: cur.id,
          title: cur.title,
          message: cur.message,
          timestamp: cur.timestamp,
          type: cur.type,
          isRead: true,
          badge: cur.badge,
          actionLabel: cur.actionLabel,
        );
      }
    });

    await SupabaseService.instance.markNotificationAsRead(item.id);
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutePaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _notifications.where((n) {
      if (_activeFilter == 'all') return true;
      if (_activeFilter == 'reminders') {
        return n.type == 'reminder' || n.type == 'motivation';
      }
      if (_activeFilter == 'announcements') return n.type == 'announcement' || n.type == 'info';
      if (_activeFilter == 'bookings') return n.type == 'booking' || n.type == 'reservation';
      if (_activeFilter == 'streaks') {
        return n.type == 'streak' || n.type == 'workout';
      }
      return true;
    }).toList();

    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: _handleBack,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Club Bulletins',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.emerald,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Realtime Inbox Active',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.emerald,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (unreadCount > 0)
            IconButton(
              onPressed: _markAllAsRead,
              tooltip: 'Mark all as read',
              icon: Icon(
                Icons.mark_email_read_rounded,
                color: context.brandAccent,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Pills
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _filterChip(
                      context,
                      'all',
                      unreadCount > 0 ? 'All ($unreadCount new)' : 'All Bulletins',
                      Icons.all_inbox_rounded,
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      context,
                      'announcements',
                      'Club News',
                      Icons.campaign_rounded,
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      context,
                      'bookings',
                      'Reservations',
                      Icons.event_available_rounded,
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      context,
                      'reminders',
                      'Reminders',
                      Icons.lightbulb_rounded,
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      context,
                      'streaks',
                      'Activity',
                      Icons.local_fire_department_rounded,
                    ),
                  ],
                ),
              ),
            ),

            // Content List with Loading, Empty & Error States
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadNotifications(),
                color: context.brandAccent,
                backgroundColor: context.cardElevated,
                child: _buildBodyContent(filtered),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent(List<GymNotification> filtered) {
    // 1. Loading State
    if (_isLoading) {
      return const Center(
        child: DumbbellLoader(
          text: 'Syncing Realtime Bulletins...',
          size: DumbbellLoaderSize.sm,
        ),
      );
    }

    // 2. Error State
    if (_errorMessage != null && _notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, color: context.brandAccent, size: 48),
              const SizedBox(height: 14),
              Text(
                'Could Not Load Bulletins',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => _loadNotifications(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry Connection'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.brandAccent,
                  foregroundColor: context.onBrandAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Authentic Empty State (Zero Mock Data)
    if (filtered.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.brandAccent.withValues(alpha: 0.1),
                ),
                child: Icon(
                  _activeFilter == 'all'
                      ? Icons.notifications_none_rounded
                      : Icons.filter_list_off_rounded,
                  color: context.brandAccent,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _activeFilter == 'all'
                    ? 'Your Inbox is Clear'
                    : 'No Bulletins in this Category',
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _activeFilter == 'all'
                    ? 'No notifications or club announcements right now.\nWhen personal updates, class confirmations, or club bulletins arrive, you will see them here in real-time.'
                    : 'Switch back to "All Bulletins" to view other club announcements.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Populated Notifications List
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final item = filtered[idx];
        return _buildNotificationCard(context, item);
      },
    );
  }

  Widget _buildNotificationCard(BuildContext context, GymNotification item) {
    Color iconColor;
    IconData icon;
    switch (item.type) {
      case 'reminder':
        iconColor = Colors.orange;
        icon = Icons.alarm_rounded;
        break;
      case 'motivation':
        iconColor = AppTheme.gold;
        icon = Icons.format_quote_rounded;
        break;
      case 'announcement':
      case 'info':
        iconColor = context.brandAccent;
        icon = Icons.campaign_rounded;
        break;
      case 'streak':
        iconColor = AppTheme.amber;
        icon = Icons.local_fire_department_rounded;
        break;
      case 'booking':
      case 'reservation':
        iconColor = AppTheme.emerald;
        icon = Icons.event_available_rounded;
        break;
      case 'workout':
      default:
        iconColor = AppTheme.sky;
        icon = Icons.fitness_center_rounded;
        break;
    }

    return BentoCard(
      onTap: () => _markSingleAsRead(item),
      padding: const EdgeInsets.all(16),
      backgroundColor: context.cardElevated,
      border: Border.all(
        color: !item.isRead ? iconColor.withValues(alpha: 0.5) : context.borderCol,
        width: !item.isRead ? 1.5 : 1.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (item.badge != null)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.badge!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: iconColor,
                                ),
                              ),
                            ),
                          ),
                        if (item.badge != null) const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!item.isRead) ...[
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: iconColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              _formatTimestamp(item.timestamp),
                              maxLines: 1,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: context.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: context.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.actionLabel != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: InclineScaleButton(
                onTap: () {
                  _markSingleAsRead(item);
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  if (item.type == 'announcement' || item.type == 'booking' || item.type == 'reservation') {
                    if (widget.onNavigateToBookings != null) {
                      widget.onNavigateToBookings!();
                    } else {
                      context.go(AppRoutePaths.bookings);
                    }
                  } else {
                    if (widget.onNavigateToWorkout != null) {
                      widget.onNavigateToWorkout!();
                    } else {
                      context.go(AppRoutePaths.workout);
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: iconColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.actionLabel!,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: iconColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(
      BuildContext context, String id, String label, IconData icon) {
    final isSelected = _activeFilter == id;

    return InclineScaleButton(
      onTap: () => setState(() => _activeFilter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.brandAccent : context.cardElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? context.brandAccent : context.borderCol,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.black : context.brandAccent,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.black : context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative || diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return DateFormat('dd MMM').format(dt);
    }
  }
}
