import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/post_model.dart';
import '../services/firebase_service.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhotoUrl;
  final PostModel? referencedPost;
  const ChatScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhotoUrl = '',
    this.referencedPost,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // UID synchronously from FirebaseAuth — no async needed
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

  String _otherPhotoUrl = '';
  String _otherDept = '';
  bool _sending = false;
  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();
    _otherPhotoUrl = widget.otherUserPhotoUrl;

    FirebaseService.getUserById(widget.otherUserId).then((u) {
      if (!mounted || u == null) return;
      setState(() {
        if (u.profileImageUrl.isNotEmpty) _otherPhotoUrl = u.profileImageUrl;
        _otherDept = u.department;
      });
    });

    FirebaseService.markChatAsRead(widget.otherUserId);

    if (widget.referencedPost != null) {
      _ctrl.text =
          'Can I get more info about your "${widget.referencedPost!.itemName}"?';
      _ctrl.selection =
          TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (animated) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    await FirebaseService.sendMessage(
      toUserId: widget.otherUserId,
      toUserName: widget.otherUserName,
      toUserPhotoUrl: _otherPhotoUrl,
      message: text,
    );
    _scrollToBottom();
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.primary.withOpacity(0.15),
              backgroundImage: _otherPhotoUrl.isNotEmpty
                  ? NetworkImage(_otherPhotoUrl)
                  : null,
              child: _otherPhotoUrl.isEmpty
                  ? Text(
                      widget.otherUserName.isNotEmpty
                          ? widget.otherUserName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Text(
                  _otherDept.isNotEmpty ? _otherDept : 'Campus L&F',
                  style: const TextStyle(fontSize: 11, color: AppTheme.txtSec),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseService.messagesStream(widget.otherUserId),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppTheme.primary));
                }

                final raw = snap.data?.docs ?? [];
                final docs = List.of(raw)
                  ..sort((a, b) {
                    final aTs = (a.data() as Map<String, dynamic>)['timestamp']
                        as Timestamp?;
                    final bTs = (b.data() as Map<String, dynamic>)['timestamp']
                        as Timestamp?;
                    if (aTs == null && bTs == null) return 0;
                    if (aTs == null) return -1;
                    if (bTs == null) return 1;
                    return aTs.compareTo(bTs);
                  });

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 60, color: AppTheme.txtSec.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        const Text('No Message Yet',
                            style: TextStyle(
                                color: AppTheme.txtSec, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('Send message to start conversation!',
                            style: TextStyle(
                                color: AppTheme.txtSec, fontSize: 13)),
                      ],
                    ),
                  );
                }

                if (!_initialScrollDone) {
                  _initialScrollDone = true;
                  _scrollToBottom(animated: false);
                } else {
                  _scrollToBottom();
                }

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final isMe = d['senderId'] == _myUid;
                    final ts = d['timestamp'] as Timestamp?;
                    return _MessageBubble(
                      text: d['text'] ?? '',
                      isMe: isMe,
                      senderName: d['senderName'] ?? '',
                      time: ts != null ? _formatTime(ts.toDate()) : '',
                    );
                  },
                );
              },
            ),
          ),

          //  Input bar
          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  )
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Message',
                        filled: true,
                        fillColor: AppTheme.bg,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _send,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  //  Date and Time format
  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // 12-hour AM/PM
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    final timeStr = '$hour:$minute $period';

    if (msgDay == today) return timeStr;
    if (msgDay == yesterday) return 'Yesterday';
    // Older: show short date
    return '${dt.day}/${dt.month}/${dt.year % 100}';
  }
}

//  Message Bubble
class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String senderName;
  final String time;
  const _MessageBubble({
    required this.text,
    required this.isMe,
    required this.senderName,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          border: isMe ? null : Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  senderName,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary),
                ),
              ),
            Text(
              text,
              style: TextStyle(
                  fontSize: 14,
                  color: isMe ? Colors.white : AppTheme.txtPri,
                  height: 1.4),
            ),
            const SizedBox(height: 3),
            Text(
              time,
              style: TextStyle(
                  fontSize: 10,
                  color:
                      isMe ? Colors.white.withOpacity(0.7) : AppTheme.txtSec),
            ),
          ],
        ),
      ),
    );
  }
}
