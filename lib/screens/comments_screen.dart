import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../services/comment_service.dart';

class CommentsScreen extends StatefulWidget {
  final String videoId;
  final String userId;

  const CommentsScreen({
    super.key,
    required this.videoId,
    required this.userId,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final _commentService = CommentService();
  final _commentController = TextEditingController();
  Comment? _replyingTo;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      await _commentService.addComment(
        videoId: widget.videoId,
        userId: widget.userId,
        text: _commentController.text.trim(),
        parentId: _replyingTo?.id,
      );

      if (mounted) {
        _commentController.clear();
        if (_replyingTo != null) {
          setState(() => _replyingTo = null);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            height: 4,
            width: 40,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Comments list
          Expanded(
            child: StreamBuilder<List<Comment>>(
              stream: _commentService.getVideoComments(widget.videoId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final comments = snapshot.data!;
                if (comments.isEmpty) {
                  return const Center(
                    child: Text('No comments yet. Be the first to comment!'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    return CommentTile(
                      comment: comments[index],
                      userId: widget.userId,
                      onReply: (comment) {
                        setState(() => _replyingTo = comment);
                        _commentController.text = '@${comment.userId} ';
                        _commentController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _commentController.text.length),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Reply indicator
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[200],
              child: Row(
                children: [
                  Text(
                    'Replying to @${_replyingTo!.userId}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _replyingTo = null),
                  ),
                ],
              ),
            ),

          // Comment input
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              8 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _addComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommentTile extends StatefulWidget {
  final Comment comment;
  final String userId;
  final Function(Comment) onReply;

  const CommentTile({
    super.key,
    required this.comment,
    required this.userId,
    required this.onReply,
  });

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  final _commentService = CommentService();
  bool _showReplies = false;
  bool _isEditing = false;
  final _editController = TextEditingController();

  void _showReactionPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'React to comment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              children: CommentService.defaultEmojis.map((emoji) {
                final hasReacted = widget.comment.hasReacted(emoji, widget.userId);
                final count = widget.comment.getReactionCount(emoji);
                
                return InkWell(
                  onTap: () {
                    _commentService.toggleReaction(
                      widget.comment.id,
                      emoji,
                      widget.userId,
                    );
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: hasReacted ? Colors.blue.withOpacity(0.1) : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      if (count > 0)
                        Text(
                          count.toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditMenu() {
    if (widget.comment.userId != widget.userId) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit comment'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _isEditing = true;
                  _editController.text = widget.comment.text;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete comment'),
              onTap: () {
                Navigator.pop(context);
                _commentService.deleteComment(widget.comment.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.grey[300],
                      child: Text(
                        widget.comment.userId[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '@${widget.comment.userId}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.comment.editedAt != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '(edited)',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (widget.comment.userId == widget.userId)
                                IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: _showEditMenu,
                                ),
                            ],
                          ),
                          if (_isEditing)
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _editController,
                                    autofocus: true,
                                    decoration: const InputDecoration(
                                      hintText: 'Edit your comment...',
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() => _isEditing = false);
                                  },
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    if (_editController.text.trim().isNotEmpty) {
                                      await _commentService.editComment(
                                        widget.comment.id,
                                        _editController.text.trim(),
                                      );
                                      if (mounted) {
                                        setState(() => _isEditing = false);
                                      }
                                    }
                                  },
                                  child: const Text('Save'),
                                ),
                              ],
                            )
                          else
                            Text(
                              widget.comment.text,
                              style: const TextStyle(fontSize: 16),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.comment.reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 8,
                      children: widget.comment.reactions.entries.map((entry) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: entry.value.contains(widget.userId)
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(entry.key),
                              const SizedBox(width: 4),
                              Text(
                                entry.value.length.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _getTimeAgo(widget.comment.createdAt),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined),
                      onPressed: _showReactionPicker,
                    ),
                    IconButton(
                      icon: Icon(
                        widget.comment.isLikedBy(widget.userId)
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: widget.comment.isLikedBy(widget.userId)
                            ? Colors.red
                            : null,
                      ),
                      onPressed: () => _commentService.toggleLike(
                        widget.comment.id,
                        widget.userId,
                      ),
                    ),
                    Text(
                      widget.comment.likedBy.length.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      icon: const Icon(Icons.reply),
                      label: const Text('Reply'),
                      onPressed: () => widget.onReply(widget.comment),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Show replies button
        if (widget.comment.replyCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: TextButton.icon(
              icon: Icon(_showReplies
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down),
              label: Text(
                _showReplies
                    ? 'Hide replies'
                    : '${widget.comment.replyCount} replies',
              ),
              onPressed: () => setState(() => _showReplies = !_showReplies),
            ),
          ),
        // Replies
        if (_showReplies)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: StreamBuilder<List<Comment>>(
              stream: _commentService.getCommentReplies(widget.comment.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Column(
                  children: snapshot.data!.map((reply) {
                    return CommentTile(
                      comment: reply,
                      userId: widget.userId,
                      onReply: widget.onReply,
                    );
                  }).toList(),
                );
              },
            ),
          ),
      ],
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
} 