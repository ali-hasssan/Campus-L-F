import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import 'home_screen.dart';

class MyPostsScreen extends StatefulWidget {
  final UserModel? user;
  const MyPostsScreen({super.key, this.user});
  @override
  State<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends State<MyPostsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<PostModel> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = await FirebaseService.getCurrentUser();
    if (user == null) return;
    final posts = await FirebaseService.getPostsByUser(user.id);
    if (mounted) setState(() { _posts = posts; _loading = false; });
  }

  List<PostModel> _byStatus(String status) =>
      _posts.where((p) => p.status == status).toList();

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout',
                  style: TextStyle(color: AppTheme.lost))),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseService.clearSession();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
          context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('My Posts',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.txtPri)),
                        if (user != null)
                          Text(
                            '${user.department} • ${user.semester} Sem',
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.txtSec),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.lost.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: AppTheme.lost, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            // ── Profile summary
            if (user != null) ...[
              const SizedBox(height: 16),
              _ProfileCard(user: user, postCount: _posts.length),
            ],
            const SizedBox(height: 16),
            // ── Tab bar
            Container(
              margin:
                  const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: TabBar(
                controller: _tab,
                padding: const EdgeInsets.all(4),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.txtSec,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                tabs: [
                  _tab_item('Active', _byStatus('active').length),
                  _tab_item('Claimed', _byStatus('claimed').length),
                  _tab_item('History', _byStatus('resolved').length),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── Content
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary))
                  : TabBarView(
                      controller: _tab,
                      children: [
                        _PostList(
                            posts: _byStatus('active'),
                            emptyMsg: 'No active posts yet',
                            onAction: _load),
                        _PostList(
                            posts: _byStatus('claimed'),
                            emptyMsg: 'No claimed posts',
                            onAction: _load),
                        _PostList(
                            posts: _byStatus('resolved'),
                            emptyMsg: 'No resolved posts',
                            onAction: _load,
                            isResolvedTab: true),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Tab _tab_item(String label, int count) => Tab(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$count',
                    style: const TextStyle(fontSize: 11)),
              ),
            ],
          ],
        ),
      );
}

// ─── Profile Card ─────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final UserModel user;
  final int postCount;
  const _ProfileCard({required this.user, required this.postCount});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5B4FE9), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withOpacity(0.2),
              backgroundImage: user.profileImageUrl.isNotEmpty
                  ? NetworkImage(user.profileImageUrl)
                  : null,
              onBackgroundImageError: user.profileImageUrl.isNotEmpty
                  ? (_, __) {}
                  : null,
              child: user.profileImageUrl.isNotEmpty
                  ? null
                  : Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(user.email,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(user.phone,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text('$postCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700)),
                  const Text('Posts',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
}

// ─── Post List per Tab ────────────────────────────────────────────────────────
class _PostList extends StatelessWidget {
  final List<PostModel> posts;
  final String emptyMsg;
  final VoidCallback onAction;
  final bool isResolvedTab;
  const _PostList({
    required this.posts,
    required this.emptyMsg,
    required this.onAction,
    this.isResolvedTab = false,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 60, color: AppTheme.txtSec.withOpacity(0.4)),
            const SizedBox(height: 12),
            Text(emptyMsg,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.txtPri)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onAction(),
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        itemCount: posts.length,
        itemBuilder: (ctx, i) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: isResolvedTab
              ? _ResolvedPostCard(post: posts[i])
              : PostCard(
                  post: posts[i],
                  onTap: () => Navigator.pushNamed(ctx, '/post-detail',
                          arguments: posts[i])
                      .then((_) => onAction()),
                ),
        ),
      ),
    );
  }
}

// ─── Resolved Post Card — full details + resolved user ────────────────────────
class _ResolvedPostCard extends StatelessWidget {
  final PostModel post;
  const _ResolvedPostCard({required this.post});

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Post Delete Karo?'),
        content: const Text('Ye post permanently delete ho jayegi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppTheme.lost))),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseService.deletePost(post.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLost = post.type == 'lost';
    final typeColor = isLost ? AppTheme.lost : AppTheme.found;
    final hasImage = post.images.isNotEmpty;
    final hasResolvedUser = post.resolvedWithUserName.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.found.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.found.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Post image — tappable full screen
          if (hasImage)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      _FullScreenImage(imageUrl: post.images.first),
                ),
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(18)),
                child: Image.network(
                  post.images.first,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Badges + delete button row
                Row(
                  children: [
                    _Badge(label: isLost ? 'LOST' : 'FOUND', color: typeColor),
                    const SizedBox(width: 8),
                    _Badge(label: post.category, color: AppTheme.primary),
                    const SizedBox(width: 8),
                    _Badge(label: '✓ RESOLVED', color: AppTheme.found),
                    const Spacer(),
                    // ── Delete button — top right
                    GestureDetector(
                      onTap: () => _confirmDelete(context),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.lost.withOpacity(0.09),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: AppTheme.lost, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Resolved date
                if (post.resolvedAt != null)
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 12, color: AppTheme.txtSec),
                      const SizedBox(width: 4),
                      Text(
                        'Resolved on ${DateFormat('MMM d, yyyy').format(post.resolvedAt!)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.txtSec),
                      ),
                    ],
                  ),
                const SizedBox(height: 10),

                // ── Item name
                Text(post.itemName,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.txtPri)),
                const SizedBox(height: 6),

                // ── Description
                Text(post.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.txtSec,
                        height: 1.5)),
                const SizedBox(height: 12),

                // ── Area + Color
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppTheme.txtSec),
                    const SizedBox(width: 4),
                    Text(post.area,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.txtSec)),
                    const SizedBox(width: 16),
                    Container(
                      width: 11, height: 11,
                      decoration: BoxDecoration(
                        color: _colorFromName(post.color),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.border),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(post.color,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.txtSec)),
                  ],
                ),

                // ── Resolved user box
                if (hasResolvedUser) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppTheme.border),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.found.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.found.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              AppTheme.primary.withOpacity(0.12),
                          backgroundImage:
                              post.resolvedWithUserPhoto.isNotEmpty
                                  ? NetworkImage(post.resolvedWithUserPhoto)
                                  : null,
                          child: post.resolvedWithUserPhoto.isEmpty
                              ? Text(
                                  post.resolvedWithUserName[0].toUpperCase(),
                                  style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Resolved with',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.txtSec)),
                              const SizedBox(height: 3),
                              Text(post.resolvedWithUserName,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.txtPri)),
                              if (post.resolvedWithUserDept.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(children: [
                                  const Icon(Icons.school_outlined,
                                      size: 12, color: AppTheme.txtSec),
                                  const SizedBox(width: 4),
                                  Text(post.resolvedWithUserDept,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.txtSec)),
                                ]),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.handshake_rounded,
                            color: AppTheme.found, size: 26),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorFromName(String name) {
    const map = {
      'Black': Colors.black87, 'White': Colors.white70,
      'Red': Colors.red, 'Blue': Colors.blue, 'Green': Colors.green,
      'Yellow': Colors.yellow, 'Brown': Colors.brown, 'Grey': Colors.grey,
      'Pink': Colors.pink, 'Orange': Colors.orange,
    };
    return map[name] ?? Colors.blueGrey;
  }
}

// ─── Full Screen Image Viewer ─────────────────────────────────────────────────
class _FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const _FullScreenImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
            errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 64),
          ),
        ),
      ),
    );
  }
}


// ─── Small badge widget ───────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
      );
}
