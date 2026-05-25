import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import 'chat_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final PostModel post;
  const PostDetailScreen({super.key, required this.post});
  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late PostModel _post;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = await FirebaseService.getCurrentUser();
    if (mounted) setState(() => _currentUserId = u?.id);
  }

  bool get _isOwner => _currentUserId == _post.userId;

  void _openFullscreen(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullscreenImageViewer(
          images: _post.images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Future<void> _updateStatus(String status) async {
    if (status == 'resolved') {
      // Show user-picker sheet first
      await _showResolveSheet();
    } else {
      final updated = _post.copyWith(status: status);
      await FirebaseService.savePost(updated);
      if (!mounted) return;
      setState(() => _post = updated);
      _snack('Status updated to ${_statusLabel(status)}');
    }
  }

  //  Fetch chat partners for this post owner and show picker
  Future<void> _showResolveSheet() async {
    // Get all chats where current user is a participant
    final chatUsers = await FirebaseService.getChatPartners(_post.userId);

    if (!mounted) return;

    if (chatUsers.isEmpty) {
      // No chats — resolve directly without selection
      final updated = _post.copyWith(
        status: 'resolved',
        resolvedAt: DateTime.now(),
      );
      await FirebaseService.savePost(updated);
      if (!mounted) return;
      setState(() => _post = updated);
      _snack('Post resolved!');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ResolveSheet(
        chatUsers: chatUsers,
        onSelect: (user) async {
          final updated = _post.copyWith(
            status: 'resolved',
            resolvedWithUserId: user.id,
            resolvedWithUserName: user.name,
            resolvedWithUserDept: user.department,
            resolvedWithUserPhoto: user.profileImageUrl,
            resolvedAt: DateTime.now(),
          );
          await FirebaseService.savePost(updated);
          if (!mounted) return;
          setState(() => _post = updated);
          _snack('Post marked as resolved!');
        },
      ),
    );
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  Future<void> _deletePost() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('Delete', style: TextStyle(color: AppTheme.lost))),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseService.deletePost(_post.id);
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  String _statusLabel(String s) => s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final isLost = _post.type == 'lost';
    final typeColor = isLost ? AppTheme.lost : AppTheme.found;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Item Detail'),
        actions: [
          if (_isOwner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onSelected: (v) {
                if (v == 'edit') {
                  Navigator.pushNamed(context, '/create-post', arguments: _post)
                      .then((_) async {
                    final posts = await FirebaseService.getPosts();
                    final updated =
                        posts.where((p) => p.id == _post.id).firstOrNull;
                    if (updated != null && mounted) {
                      setState(() => _post = updated);
                    }
                  });
                } else if (v == 'delete') {
                  _deletePost();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Edit Post'),
                    ])),
                const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 18, color: AppTheme.lost),
                      SizedBox(width: 10),
                      Text('Delete', style: TextStyle(color: AppTheme.lost)),
                    ])),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isLost
                      ? [
                          const Color(0xFFEF4444).withOpacity(0.08),
                          const Color(0xFFFCA5A5).withOpacity(0.05),
                        ]
                      : [
                          const Color(0xFF10B981).withOpacity(0.08),
                          const Color(0xFF6EE7B7).withOpacity(0.05),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: typeColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: typeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                                isLost
                                    ? Icons.search_off_rounded
                                    : Icons.check_circle_outline_rounded,
                                color: typeColor,
                                size: 15),
                            const SizedBox(width: 5),
                            Text(
                              isLost ? 'LOST ITEM' : 'FOUND ITEM',
                              style: TextStyle(
                                  color: typeColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _StatusBadgeLarge(status: _post.status),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(_post.itemName,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.txtPri)),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('MMMM d, yyyy • h:mm a').format(_post.timestamp),
                    style:
                        const TextStyle(fontSize: 12, color: AppTheme.txtSec),
                  ),
                ],
              ),
            ),
            // ── Images section (if any) ──
            if (_post.images.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Photos',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.txtPri)),
              const SizedBox(height: 10),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _post.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    return GestureDetector(
                      onTap: () => _openFullscreen(context, i),
                      child: Hero(
                        tag: 'post_img_$i',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _post.images[i],
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color: AppTheme.border,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.broken_image_outlined,
                                  color: AppTheme.txtSec),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Details grid
            _DetailCard(children: [
              _DetailRow(
                  icon: Icons.notes_rounded,
                  label: 'Description',
                  value: _post.description,
                  multiLine: true),
              const _Divider(),
              _DetailRow(
                  icon: Icons.category_outlined,
                  label: 'Category',
                  value: _post.category),
              const _Divider(),
              _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Area',
                  value: _post.area),
              const _Divider(),
              _ColorRow(color: _post.color),
            ]),
            const SizedBox(height: 20),

            // ── Posted by
            const Text('Posted by',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.txtPri)),
            const SizedBox(height: 10),
            FutureBuilder<String>(
              // Use stored photo first; if empty, fetch from user doc
              future: _post.userPhotoUrl.isNotEmpty
                  ? Future.value(_post.userPhotoUrl)
                  : FirebaseService.getUserById(_post.userId)
                      .then((u) => u?.profileImageUrl ?? ''),
              builder: (ctx, photoSnap) {
                final photoUrl = photoSnap.data ?? '';
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.primary.withOpacity(0.12),
                        backgroundImage:
                            photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isEmpty
                            ? Text(
                                _post.userName.isNotEmpty
                                    ? _post.userName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_post.userName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: AppTheme.txtPri)),
                            const SizedBox(height: 2),
                            // ── Department (phone ki jagah) ──
                            Text(
                              _post.userDepartment.isNotEmpty
                                  ? _post.userDepartment
                                  : 'Department not set',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.txtSec),
                            ),
                          ],
                        ),
                      ),
                      // ── Chat icon — sirf doosron ke liye
                      if (!_isOwner)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  otherUserId: _post.userId,
                                  otherUserName: _post.userName,
                                  otherUserPhotoUrl: photoUrl, // fresh photo
                                  referencedPost: _post,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.chat_bubble_outline_rounded,
                                color: AppTheme.primary, size: 20),
                          ),
                        ),
                    ],
                  ),
                ); // ← FutureBuilder close
              },
            ),

            // ── Owner status actions
            if (_isOwner) ...[
              const SizedBox(height: 24),
              const Text('Update Status',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.txtPri)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatusBtn(
                      label: 'Active',
                      icon: Icons.radio_button_checked_rounded,
                      color: AppTheme.primary,
                      active: _post.status == 'active',
                      onTap: () => _updateStatus('active'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusBtn(
                      label: 'Claimed',
                      icon: Icons.handshake_outlined,
                      color: Colors.orange,
                      active: _post.status == 'claimed',
                      onTap: () => _updateStatus('claimed'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusBtn(
                      label: 'Resolved',
                      icon: Icons.check_circle_rounded,
                      color: AppTheme.found,
                      active: _post.status == 'resolved',
                      onTap: () => _updateStatus('resolved'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

//  Sub-widgets (unchanged)
class _StatusBadgeLarge extends StatelessWidget {
  final String status;
  const _StatusBadgeLarge({required this.status});
  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case 'claimed':
        c = Colors.orange;
        break;
      case 'resolved':
        c = AppTheme.found;
        break;
      default:
        c = AppTheme.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(children: children),
      );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool multiLine;
  const _DetailRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.multiLine = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: multiLine
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 18, color: AppTheme.txtSec),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.txtSec,
                        fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.txtPri, height: 1.5)),
              ),
            ])
          : Row(children: [
              Icon(icon, size: 18, color: AppTheme.txtSec),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.txtSec,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.txtPri,
                      fontWeight: FontWeight.w600)),
            ]),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final String color;
  const _ColorRow({required this.color});
  static const _map = {
    'Black': Colors.black87,
    'White': Colors.white70,
    'Red': Colors.red,
    'Blue': Colors.blue,
    'Green': Colors.green,
    'Yellow': Colors.yellow,
    'Brown': Colors.brown,
    'Grey': Colors.grey,
    'Pink': Colors.pink,
    'Orange': Colors.orange,
  };
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          const Icon(Icons.palette_outlined, size: 18, color: AppTheme.txtSec),
          const SizedBox(width: 8),
          const Text('Color',
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.txtSec,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Row(children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: _map[color] ?? Colors.blueGrey,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border),
              ),
            ),
            const SizedBox(width: 6),
            Text(color,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.txtPri,
                    fontWeight: FontWeight.w600)),
          ]),
        ]),
      );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Divider(height: 1, color: AppTheme.border),
      );
}

class _StatusBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _StatusBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.active,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? color : AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? color : AppTheme.border),
          ),
          child: Column(children: [
            Icon(icon, color: active ? Colors.white : color, size: 20),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : color)),
          ]),
        ),
      );
}

//  Fullscreen Image Viewer
class _FullscreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _FullscreenImageViewer(
      {required this.images, required this.initialIndex});

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: widget.images.length > 1
            ? Text(
                '${_current + 1} / ${widget.images.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              )
            : null,
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (context, i) {
          return Hero(
            tag: 'post_img_$i',
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  widget.images[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white38,
                    size: 60,
                  ),
                ),
              ),
            ),
          );
        },
      ),

      // ── Dot indicators
      bottomNavigationBar: widget.images.length > 1
          ? Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _current == i ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _current == i ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            )
          : null,
    );
  }
}

// Resolve Sheet — pick the user item was resolved with
class _ResolveSheet extends StatelessWidget {
  final List<UserModel> chatUsers;
  final ValueChanged<UserModel> onSelect;
  const _ResolveSheet({required this.chatUsers, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          const Text('Who received the item?',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.txtPri)),
          const SizedBox(height: 4),
          const Text('Select the user with whom the item was resolved.',
              style: TextStyle(fontSize: 13, color: AppTheme.txtSec)),
          const SizedBox(height: 20),

          // Users list
          ...chatUsers.map((u) => GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onSelect(u);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.primary.withOpacity(0.12),
                        backgroundImage: u.profileImageUrl.isNotEmpty
                            ? NetworkImage(u.profileImageUrl)
                            : null,
                        child: u.profileImageUrl.isEmpty
                            ? Text(
                                u.name.isNotEmpty
                                    ? u.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.name,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.txtPri)),
                            const SizedBox(height: 2),
                            Text(
                              u.department.isNotEmpty
                                  ? u.department
                                  : 'Department not set',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.txtSec),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.check_circle_outline_rounded,
                          color: AppTheme.found, size: 22),
                    ],
                  ),
                ),
              )),

          // Skip option
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onSelect(UserModel(id: '', name: '', email: '', password: ''));
            },
            child: const Center(
              child: Text('Tap me, Leave it unselected.',
                  style: TextStyle(color: AppTheme.txtSec)),
            ),
          ),
        ],
      ),
    );
  }
}
