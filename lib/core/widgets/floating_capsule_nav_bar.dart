import 'package:flutter/material.dart';
import 'curved_notch_nav_bar.dart';

export 'curved_notch_nav_bar.dart';

/// Legacy alias forwarder for CurvedNotchNavBar to guarantee full backward compatibility
/// with existing routes and test suites.
class FloatingCapsuleNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final List<CapsuleNavItem> items;

  const FloatingCapsuleNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return CurvedNotchNavBar(
      selectedIndex: selectedIndex,
      onItemSelected: onItemSelected,
      items: items,
    );
  }
}
