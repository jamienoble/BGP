import 'package:flutter/material.dart';
import 'package:walkies/screens/goal_management_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walkies/constants/app_constants.dart';
import 'package:walkies/theme/app_theme.dart';
import 'package:walkies/widgets/ui.dart';
import 'package:walkies/services/app_locker_service.dart';
import 'package:walkies/services/step_tracking_service.dart';
import 'package:walkies/services/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabaseService = SupabaseService();
  String? _preferredName;
  bool _isSavingName = false;
  bool _lockCommunity = false;

  Future<void> _loadCommunityLock() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _lockCommunity =
          prefs.getBool(AppConstants.prefCommunityLockedUntilGoal) ?? false;
    });
  }

  Future<void> _setCommunityLock(bool value) async {
    setState(() => _lockCommunity = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefCommunityLockedUntilGoal, value);
  }

  /// Sign out. Settings sits above the main app, so pop back to the root;
  /// the auth wrapper in main.dart then shows the login screen.
  Future<void> _signOut() async {
    try {
      await StepTrackingService().flushToCloud();
      // Locks belong to the account; don't leave them enforced signed out
      await AppLockerService().clearAccessibilityServiceLockedApps();
      await _supabaseService.signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account, step history, goal, '
          'app locks and community posts. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _supabaseService.deleteAccount();
      await AppLockerService().clearAccessibilityServiceLockedApps();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete your account. Please try again.'),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPreferredName();
    _loadCommunityLock();
  }

  Future<void> _loadPreferredName() async {
    try {
      await _supabaseService.ensureUserProfile();
      final name = await _supabaseService.getPreferredName();
      if (!mounted) return;
      setState(() {
        _preferredName = name;
      });
    } catch (_) {}
  }

  Future<void> _editPreferredName() async {
    final controller = TextEditingController(text: _preferredName ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Preferred name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter your preferred name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName == null) return;
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name cannot be empty.')),
      );
      return;
    }

    setState(() {
      _isSavingName = true;
    });
    try {
      await _supabaseService.upsertPreferredName(newName);
      if (!mounted) return;
      setState(() {
        _preferredName = newName;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferred name updated.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update name. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingName = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          const SectionLabel('Your goal'),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.flag_outlined,
                title: 'Daily step goal',
                subtitle: 'Changes start the next day',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const GoalManagementScreen(),
                  ),
                ),
              ),
              _SettingsRow(
                icon: Icons.lock_outline_rounded,
                iconBackground: AppPalette.terracottaSoft,
                iconColour: const Color(0xFF8A4318),
                title: 'App locks',
                subtitle: 'Apps that wait until you reach your goal',
                onTap: () => Navigator.of(context).pushNamed('/app_locks'),
              ),
              _SettingsRow(
                icon: Icons.forum_outlined,
                title: 'Lock Community',
                subtitle: 'Until you reach your goal, like a locked app',
                trailing: Switch(
                  value: _lockCommunity,
                  onChanged: _setCommunityLock,
                ),
                onTap: () => _setCommunityLock(!_lockCommunity),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SectionLabel('Profile'),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.person_outline_rounded,
                title: 'Preferred name',
                subtitle: _preferredName ?? 'Set the name we greet you with',
                trailing: _isSavingName
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _isSavingName ? null : _editPreferredName,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SectionLabel('Account'),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                onTap: _signOut,
              ),
              _SettingsRow(
                icon: Icons.delete_outline_rounded,
                iconBackground: AppPalette.dangerSoft,
                iconColour: AppPalette.danger,
                title: 'Delete account',
                titleColour: AppPalette.danger,
                subtitle: 'Permanently remove your account and data',
                onTap: _deleteAccount,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// White rounded group of rows separated by hairlines
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 70),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color iconBackground;
  final Color iconColour;
  final Color? titleColour;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconBackground = AppPalette.sage,
    this.iconColour = AppPalette.forest,
    this.titleColour,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            IconBadge(
              icon,
              size: 40,
              background: iconBackground,
              foreground: iconColour,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.titleMedium!.copyWith(color: titleColour),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: text.bodySmall),
                  ],
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right_rounded, color: AppPalette.muted),
          ],
        ),
      ),
    );
  }
}
