import 'package:flutter/material.dart';
import 'package:walkies/services/community_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _service = CommunityService();
  Map<String, String>? _blocked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final blocked = await _service.getBlockedUsers();
      if (mounted) setState(() => _blocked = blocked);
    } catch (_) {
      if (mounted) setState(() => _blocked = {});
    }
  }

  Future<void> _unblock(String userId) async {
    try {
      await _service.unblockUser(userId);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not unblock. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _blocked;
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked people')),
      body: blocked == null
          ? const Center(child: CircularProgressIndicator())
          : blocked.isEmpty
              ? const Center(child: Text('You haven\'t blocked anyone.'))
              : ListView(
                  children: [
                    for (final entry in blocked.entries)
                      ListTile(
                        title: Text(entry.value),
                        trailing: TextButton(
                          onPressed: () => _unblock(entry.key),
                          child: const Text('Unblock'),
                        ),
                      ),
                  ],
                ),
    );
  }
}
