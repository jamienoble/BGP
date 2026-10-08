import 'package:flutter/material.dart';
import 'package:walkies/models/community.dart';
import 'package:walkies/services/community_service.dart';

/// Write a post in [topic]. Pops with true once posted.
class NewPostScreen extends StatefulWidget {
  final CommunityTopic topic;

  const NewPostScreen({super.key, required this.topic});

  @override
  State<NewPostScreen> createState() => _NewPostScreenState();
}

class _NewPostScreenState extends State<NewPostScreen> {
  final _controller = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _isPosting = true);
    try {
      await CommunityService().createPost(widget.topic.id, text);
      if (mounted) Navigator.of(context).pop(true);
    } on CommunityRateLimitException {
      _snack('You\'re posting very quickly. Please wait a while and try again.');
    } catch (e) {
      _snack('Could not post. Please try again.');
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Post in ${widget.topic.name}'),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _post,
            child: const Text('Post'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: true,
                expands: true,
                maxLines: null,
                maxLength: 5000,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Share something with the community',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Posts are public to other members under your display name. '
              'Please don\'t share personal details or medical advice.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
