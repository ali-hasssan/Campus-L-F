import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../services/firebase_service.dart';
import 'chat_screen.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text('Messages',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.txtPri)),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseService.chatsStream(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child:
                            CircularProgressIndicator(color: AppTheme.primary));
                  }

                  final raw = snap.data?.docs ?? [];

                  // Sort by lastMessageTime desc in Dart — Firestore orderBy
                  // removed to avoid composite-index requirement
                  final docs = List.of(raw)
                    ..sort((a, b) {
                      final aTs =
                          (a.data() as Map<String, dynamic>)['lastMessageTime']
                              as Timestamp?;
                      final bTs =
                          (b.data() as Map<String, dynamic>)['lastMessageTime']
                              as Timestamp?;
                      if (aTs == null && bTs == null) return 0;
                      if (aTs == null) return 1;
                      if (bTs == null) return -1;
                      return bTs.compareTo(aTs); // newest first
                    });

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.forum_outlined,
                              size: 72,
                              color: AppTheme.txtSec.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          const Text('Koi conversation nahi abhi',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.txtPri)),
                          const SizedBox(height: 6),
                          const Text(
                              'Kisi ki post detail mein ja kar\nchat start karo',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13, color: AppTheme.txtSec)),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (_, i) {
                      final d = docs[i].data() as Map<String, dynamic>;

                      final participants =
                          List<String>.from(d['participants'] ?? []);
                      final otherUid = participants
                          .firstWhere((id) => id != myUid, orElse: () => '');
                      final names = Map<String, dynamic>.from(
                          d['participantNames'] ?? {});
                      final otherName = names[otherUid] as String? ?? 'Unknown';

                      final lastMsg = d['lastMessage'] as String? ?? '';
                      final lastSenderId = d['lastSenderId'] as String? ?? '';
                      final ts = d['lastMessageTime'] as Timestamp?;
                      final timeStr =
                          ts != null ? _formatTime(ts.toDate()) : '';
                      final isMyMsg = lastSenderId == myUid;

                      final unreadBy = d['unreadBy'] as Map<String, dynamic>?;
                      final hasUnread =
                          unreadBy != null && unreadBy[myUid] == true;

                      // ── Fetch fresh photo from user doc ──────────────────────
                      return FutureBuilder<_UserPhoto>(
                        future: FirebaseService.getUserById(otherUid)
                            .then((u) => _UserPhoto(u?.profileImageUrl ?? '')),
                        builder: (_, photoSnap) {
                          final otherPhotoUrl = photoSnap.data?.url ?? '';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 6),
                            leading: CircleAvatar(
                              radius: 26,
                              backgroundColor:
                                  AppTheme.primary.withOpacity(0.12),
                              backgroundImage: otherPhotoUrl.isNotEmpty
                                  ? NetworkImage(otherPhotoUrl)
                                  : null,
                              child: otherPhotoUrl.isEmpty
                                  ? Text(
                                      otherName.isNotEmpty
                                          ? otherName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 20),
                                    )
                                  : null,
                            ),
                            title: Text(otherName,
                                style: TextStyle(
                                    fontWeight: hasUnread
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    fontSize: 15,
                                    color: AppTheme.txtPri)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                isMyMsg ? 'You: $lastMsg' : lastMsg,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: hasUnread
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: hasUnread
                                        ? AppTheme.txtPri
                                        : AppTheme.txtSec),
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(timeStr,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: hasUnread
                                            ? AppTheme.primary
                                            : AppTheme.txtSec,
                                        fontWeight: hasUnread
                                            ? FontWeight.w600
                                            : FontWeight.normal)),
                                if (hasUnread) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  otherUserId: otherUid,
                                  otherUserName: otherName,
                                  otherUserPhotoUrl: otherPhotoUrl,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Abhi';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.day}/${dt.month}';
  }
}

// Simple wrapper so FutureBuilder has a typed result
class _UserPhoto {
  final String url;
  const _UserPhoto(this.url);
}
