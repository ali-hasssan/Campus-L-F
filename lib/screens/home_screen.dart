import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../main.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import 'my_posts_screen.dart';
import 'chats_screen.dart';
import 'profile_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _navIdx = 0;
  int _myPostsKey = 0;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final u = await FirebaseService.getCurrentUser();
    if (mounted) setState(() => _user = u);
  }

  // 0=Home  1=MyPosts  2=Chats  — simple direct mapping
  void _onNav(int idx) {
    setState(() {
      if (idx == 1) _myPostsKey++; // My Posts refresh on every tap
      _navIdx = idx;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _navIdx,          // direct — 0=Feed, 1=MyPosts, 2=Chats
        children: [
          _FeedPage(user: _user),
          MyPostsScreen(key: ValueKey(_myPostsKey), user: _user),
          const ChatsScreen(),
        ],
      ),
      // ── FABs — stacked on bottom right
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Edit Profile FAB — only on My Posts tab
          if (_navIdx == 1) ...[
            FloatingActionButton.small(
              heroTag: 'editProfile',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileSetupScreen(isEditMode: true),
                ),
              ).then((_) => _loadUser()),
              backgroundColor: AppTheme.surface,
              foregroundColor: AppTheme.primary,
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.border)),
              child: const Icon(Icons.edit_outlined, size: 18),
            ),
            const SizedBox(height: 10),
          ],
          // ── Add Post FAB — always visible
          FloatingActionButton(
            heroTag: 'addPost',
            onPressed: () => Navigator.pushNamed(context, '/create-post',
                    arguments: null)
                .then((_) => setState(() => _myPostsKey++)),
            backgroundColor: AppTheme.primary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _BottomBar(
        currentIndex: _navIdx,
        onTap: _onNav,
      ),
    );
  }
}

// ─── Bottom Nav ──────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  active: currentIndex == 0,
                  onTap: () => onTap(0)),
              _NavItem(
                  icon: Icons.bookmark_border_rounded,
                  label: 'My Posts',
                  active: currentIndex == 1,
                  onTap: () => onTap(1)),
              // Chats tab — wrapped in StreamBuilder for the unread red dot
              StreamBuilder<bool>(
                stream: FirebaseService.hasUnreadStream(),
                initialData: false,
                builder: (_, snap) => _NavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chats',
                  active: currentIndex == 2,
                  showBadge: snap.data == true && currentIndex != 2,
                  onTap: () => onTap(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool showBadge;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.primary : AppTheme.txtSec;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 24),
                // Red dot badge — only shown when showBadge is true
                if (showBadge)
                  Positioned(
                    top: -3,
                    right: -4,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

// ─── Feed Page ───────────────────────────────────────────────────────────────
class _FeedPage extends StatefulWidget {
  final UserModel? user;
  const _FeedPage({this.user});
  @override
  State<_FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<_FeedPage> {
  List<PostModel> _allPosts = [];
  List<PostModel> _filtered = [];
  String _query = '';
  String? _catFilter;
  String? _areaFilter;
  String _typeFilter = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final posts = await FirebaseService.getPosts();
    if (!mounted) return;
    setState(() {
      _allPosts = posts;
      _loading = false;
      _applyFilters();
    });
  }

  void _applyFilters() {
    var list = List<PostModel>.from(_allPosts);
    list = list.where((p) => p.status != 'resolved').toList();
    if (_typeFilter != 'all') list = list.where((p) => p.type == _typeFilter).toList();
    if (_catFilter != null) list = list.where((p) => p.category == _catFilter).toList();
    if (_areaFilter != null) list = list.where((p) => p.area == _areaFilter).toList();
    if (_query.isNotEmpty) {
      list = list
          .where((p) =>
              p.itemName.toLowerCase().contains(_query.toLowerCase()) ||
              p.description.toLowerCase().contains(_query.toLowerCase()))
          .toList();
    }
    setState(() => _filtered = list);
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        category: _catFilter,
        area: _areaFilter,
        onApply: (cat, area) => setState(() {
          _catFilter = cat;
          _areaFilter = area;
          _applyFilters();
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppTheme.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hey, ${widget.user?.name.split(' ').first ?? 'Student'} 👋',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.txtPri),
                            ),
                            const Text('Find or report items on campus',
                                style: TextStyle(
                                    fontSize: 13, color: AppTheme.txtSec)),
                          ],
                        ),
                      ),
                      _AvatarChip(
                        name: widget.user?.name ?? 'U',
                        imageUrl: widget.user?.profileImageUrl ?? '',
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() {
                            _query = v;
                            _applyFilters();
                          }),
                          decoration: InputDecoration(
                            hintText: 'Search items...',
                            prefixIcon:
                                const Icon(Icons.search_rounded, size: 22),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                            filled: true,
                            fillColor: AppTheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  const BorderSide(color: AppTheme.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  const BorderSide(color: AppTheme.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                  color: AppTheme.primary, width: 2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _showFilterSheet,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: (_catFilter != null || _areaFilter != null)
                                ? AppTheme.primary
                                : AppTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color:
                                (_catFilter != null || _areaFilter != null)
                                    ? Colors.white
                                    : AppTheme.txtSec,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      _TypeChip(
                          label: 'All',
                          value: 'all',
                          current: _typeFilter,
                          onTap: (v) => setState(() {
                                _typeFilter = v;
                                _applyFilters();
                              })),
                      const SizedBox(width: 8),
                      _TypeChip(
                          label: '🔴 Lost',
                          value: 'lost',
                          current: _typeFilter,
                          onTap: (v) => setState(() {
                                _typeFilter = v;
                                _applyFilters();
                              })),
                      const SizedBox(width: 8),
                      _TypeChip(
                          label: '🟢 Found',
                          value: 'found',
                          current: _typeFilter,
                          onTap: (v) => setState(() {
                                _typeFilter = v;
                                _applyFilters();
                              })),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text(
                    '${_filtered.length} item${_filtered.length == 1 ? '' : 's'} found',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.txtSec),
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primary)))
              else if (_filtered.isEmpty)
                SliverFillRemaining(child: _EmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: PostCard(
                          post: _filtered[i],
                          onTap: () => Navigator.pushNamed(
                              context, '/post-detail',
                              arguments: _filtered[i])
                              .then((_) => _load()),
                        ),
                      ),
                      childCount: _filtered.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;
  const _TypeChip(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: active ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppTheme.txtSec)),
      ),
    );
  }
}

class _AvatarChip extends StatelessWidget {
  final String name;
  final String imageUrl;
  const _AvatarChip({required this.name, this.imageUrl = ''});

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.isNotEmpty;
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppTheme.primary.withOpacity(0.15),
      backgroundImage: hasImage ? NetworkImage(imageUrl) : null,
      onBackgroundImageError: hasImage
          ? (_, __) {} // fallback to initials on error
          : null,
      child: hasImage
          ? null
          : Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18),
            ),
    );
  }
}

// ─── Post Card ───────────────────────────────────────────────────────────────
class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onTap;
  const PostCard({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLost = post.type == 'lost';
    final typeColor = isLost ? AppTheme.lost : AppTheme.found;
    final typeLabel = isLost ? 'LOST' : 'FOUND';
    final hasImages = post.images.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Type & category badges + date ──
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(typeLabel,
                        style: TextStyle(
                            color: typeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(post.category,
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('MMM d').format(post.timestamp),
                    style:
                        const TextStyle(fontSize: 12, color: AppTheme.txtSec),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Item name + description  (left) | thumbnail (right) ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.itemName,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.txtPri)),
                        const SizedBox(height: 4),
                        Text(
                          post.description,
                          maxLines: hasImages ? 2 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.txtSec,
                              height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  // ── Single thumbnail (first image) beside text ──
                  if (hasImages) ...[
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        post.images.first,
                        width: 72, height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: AppTheme.border,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.image_not_supported_outlined,
                              color: AppTheme.txtSec, size: 22),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),
              // ── Location, color, status ──
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 15, color: AppTheme.txtSec),
                  const SizedBox(width: 4),
                  Text(post.area,
                      style:
                          const TextStyle(fontSize: 13, color: AppTheme.txtSec)),
                  const SizedBox(width: 14),
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: _colorFromName(post.color),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.border),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(post.color,
                      style:
                          const TextStyle(fontSize: 13, color: AppTheme.txtSec)),
                  const Spacer(),
                  _StatusBadge(status: post.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _colorFromName(String name) {
  const map = {
    'Black': Colors.black87, 'White': Colors.white,
    'Red': Colors.red, 'Blue': Colors.blue, 'Green': Colors.green,
    'Yellow': Colors.yellow, 'Brown': Colors.brown, 'Grey': Colors.grey,
    'Pink': Colors.pink, 'Orange': Colors.orange,
  };
  return map[name] ?? Colors.blueGrey;
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    Color c;
    switch (status) {
      case 'claimed':  c = Colors.orange; break;
      case 'resolved': c = AppTheme.found; break;
      default:         c = AppTheme.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 72, color: AppTheme.txtSec.withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text('No items found',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.txtPri)),
            const SizedBox(height: 6),
            const Text('Try adjusting your filters',
                style: TextStyle(fontSize: 14, color: AppTheme.txtSec)),
          ],
        ),
      );
}

class _FilterSheet extends StatefulWidget {
  final String? category;
  final String? area;
  final void Function(String? cat, String? area) onApply;
  const _FilterSheet({this.category, this.area, required this.onApply});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  String? _cat;
  String? _area;

  @override
  void initState() {
    super.initState();
    _cat = widget.category;
    _area = widget.area;
  }

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
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Filter Items',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.txtPri)),
          const SizedBox(height: 20),
          const Text('Category',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.txtSec)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: AppK.categories.map((c) {
              final active = _cat == c;
              return GestureDetector(
                onTap: () => setState(() => _cat = active ? null : c),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppTheme.primary : AppTheme.bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color:
                            active ? AppTheme.primary : AppTheme.border),
                  ),
                  child: Text(c,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: active ? Colors.white : AppTheme.txtSec)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Campus Area',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.txtSec)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: AppK.areas.map((a) {
              final active = _area == a;
              return GestureDetector(
                onTap: () => setState(() => _area = active ? null : a),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? AppTheme.primary : AppTheme.bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color:
                            active ? AppTheme.primary : AppTheme.border),
                  ),
                  child: Text(a,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: active ? Colors.white : AppTheme.txtSec)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onApply(null, null);
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    side: const BorderSide(color: AppTheme.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Clear',
                      style: TextStyle(color: AppTheme.txtSec)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(_cat, _area);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 50)),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
