import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';

class FirebaseService {
  static final _auth    = FirebaseAuth.instance;
  static final _db      = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  static CollectionReference get _users => _db.collection('users');
  static CollectionReference get _posts => _db.collection('posts');
  static CollectionReference get _chats => _db.collection('chats');

  // ─── Auth ────────────────────────────────────────────────────────────────────

  static Future<UserModel> signUp(UserModel user, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: user.email, password: password,
    );
    final uid = cred.user!.uid;
    final newUser = UserModel(
      id: uid, name: user.name, email: user.email, password: '',
      department: user.department, semester: user.semester,
      phone: user.phone, profileComplete: user.profileComplete,
    );
    await _users.doc(uid).set(_toFirestore(newUser));
    return newUser;
  }

  static Future<UserModel?> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(), password: password,
      );
      return _fetchUserById(cred.user!.uid);
    } on FirebaseAuthException {
      return null;
    }
  }

  static Future<bool> emailExists(String email) async {
    final snap = await _users
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1).get();
    return snap.docs.isNotEmpty;
  }

  static Future<void> setSession(String userId) async {}

  static Future<void> clearSession() async => await _auth.signOut();

  static Future<UserModel?> getCurrentUser() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return null;
    return _fetchUserById(fbUser.uid);
  }

  // ─── User ────────────────────────────────────────────────────────────────────

  static Future<void> saveUser(UserModel user) async {
    await _users.doc(user.id).set(_toFirestore(user), SetOptions(merge: true));
  }

  static Future<UserModel?> getUserByEmail(String email) async {
    final snap = await _users
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1).get();
    if (snap.docs.isEmpty) return null;
    return _fromFirestore(snap.docs.first);
  }

  static Future<UserModel?> getUserById(String uid) => _fetchUserById(uid);

  // ─── Image Upload ─────────────────────────────────────────────────────────────

  /// Upload profile image and return download URL.
  static Future<String> uploadProfileImage({
    required String userId,
    required File imageFile,
  }) async {
    final ref = _storage
        .ref()
        .child('profile_images')
        .child('$userId.jpg');

    final task = await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
  }

  /// Upload a local image file to Firebase Storage and return its download URL.
  /// [postId]  — used as folder name so images are grouped per post.
  /// [index]   — 0, 1, or 2 (position slot).
  static Future<String> uploadPostImage({
    required String postId,
    required File imageFile,
    required int index,
  }) async {
    final ref = _storage
        .ref()
        .child('post_images')
        .child(postId)
        .child('img_$index.jpg');

    final task = await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
  }

  /// Delete all images stored for a post (call when deleting the post).
  static Future<void> deletePostImages(String postId) async {
    try {
      final listResult =
          await _storage.ref().child('post_images').child(postId).listAll();
      for (final item in listResult.items) {
        await item.delete();
      }
    } catch (_) {
      // Folder may not exist — safe to ignore
    }
  }

  // ─── Posts ───────────────────────────────────────────────────────────────────

  static Future<List<PostModel>> getPosts() async {
    final snap = await _posts.orderBy('timestamp', descending: true).get();
    return snap.docs.map((d) => _postFromFirestore(d)).toList();
  }

  static Future<void> savePost(PostModel post) async {
    await _posts.doc(post.id).set(_postToFirestore(post));
  }

  static Future<void> deletePost(String postId) async {
    await _posts.doc(postId).delete();
    await deletePostImages(postId); // also remove images from Storage
  }

  static Future<List<PostModel>> getPostsByUser(String userId) async {
    final snap = await _posts
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true).get();
    return snap.docs.map((d) => _postFromFirestore(d)).toList();
  }

  // ─── Chat ────────────────────────────────────────────────────────────────────

  static String chatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return ids.join('_');
  }

  static Future<void> sendMessage({
    required String toUserId,
    required String toUserName,
    required String message,
    String toUserPhotoUrl = '',
  }) async {
    final me = _auth.currentUser;
    if (me == null) return;

    final myProfile = await _fetchUserById(me.uid);
    final cid = chatId(me.uid, toUserId);
    final now = Timestamp.now();

    final msgData = {
      'senderId': me.uid,
      'senderName': myProfile?.name ?? me.email ?? 'User',
      'senderPhotoUrl': myProfile?.profileImageUrl ?? '',  // ← profile image
      'text': message.trim(),
      'timestamp': now,
    };

    final chatMeta = {
      'participants': [me.uid, toUserId],
      'participantNames': {
        me.uid: myProfile?.name ?? '',
        toUserId: toUserName,
      },
      'participantPhotoUrls': {
        me.uid: myProfile?.profileImageUrl ?? '',          // ← my photo
        toUserId: toUserPhotoUrl,                          // ← other's photo
      },
      'lastMessage': message.trim(),
      'lastMessageTime': now,
      'lastSenderId': me.uid,
      'unreadBy': {toUserId: true},
    };

    final chatRef = _chats.doc(cid);
    await chatRef.set(chatMeta, SetOptions(merge: true));
    await chatRef.collection('messages').add(msgData);
  }

  static Future<void> markChatAsRead(String otherUserId) async {
    final me = _auth.currentUser;
    if (me == null) return;
    final cid = chatId(me.uid, otherUserId);
    try {
      await _chats.doc(cid).update({'unreadBy.${me.uid}': FieldValue.delete()});
    } catch (_) {}
  }

  static Stream<QuerySnapshot> messagesStream(String otherUserId) {
    final me = _auth.currentUser;
    if (me == null) return const Stream.empty();
    final cid = chatId(me.uid, otherUserId);
    return _chats.doc(cid).collection('messages').snapshots();
  }

  static Stream<QuerySnapshot> chatsStream() {
    final me = _auth.currentUser;
    if (me == null) return const Stream.empty();
    return _chats.where('participants', arrayContains: me.uid).snapshots();
  }

  static Stream<bool> hasUnreadStream() {
    final me = _auth.currentUser;
    if (me == null) return Stream.value(false);
    return chatsStream().map((snap) {
      return snap.docs.any((doc) {
        final d = doc.data() as Map<String, dynamic>;
        final unreadBy = d['unreadBy'] as Map<String, dynamic>?;
        return unreadBy != null && unreadBy[me.uid] == true;
      });
    });
  }

  /// Chat kar chuke saare users return karta hai [userId] ke liye
  static Future<List<UserModel>> getChatPartners(String userId) async {
    try {
      final snap = await _chats
          .where('participants', arrayContains: userId)
          .get();

      final partnerIds = <String>{};
      for (final doc in snap.docs) {
        final d = doc.data() as Map<String, dynamic>;
        final participants = List<String>.from(d['participants'] ?? []);
        for (final id in participants) {
          if (id != userId) partnerIds.add(id);
        }
      }

      final users = <UserModel>[];
      for (final id in partnerIds) {
        final u = await _fetchUserById(id);
        if (u != null) users.add(u);
      }
      return users;
    } catch (_) {
      return [];
    }
  }

  // ─── Private helpers ─────────────────────────────────────────────────────────

  static Future<UserModel?> _fetchUserById(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return _fromFirestore(doc);
  }

  static Map<String, dynamic> _toFirestore(UserModel u) => {
        'id': u.id, 'name': u.name, 'email': u.email,
        'department': u.department, 'semester': u.semester,
        'phone': u.phone, 'profileComplete': u.profileComplete,
        'profileImageUrl': u.profileImageUrl, // ← NEW
      };

  static UserModel _fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: d['id'] as String? ?? doc.id,
      name: d['name'] as String? ?? '',
      email: d['email'] as String? ?? '',
      password: '',
      department: d['department'] as String? ?? '',
      semester: d['semester'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      profileComplete: d['profileComplete'] as bool? ?? false,
      profileImageUrl: d['profileImageUrl'] as String? ?? '', // ← NEW
    );
  }

  static Map<String, dynamic> _postToFirestore(PostModel p) => {
        'id': p.id,
        'userId': p.userId,
        'userName': p.userName,
        'userPhone': p.userPhone,
        'userDepartment': p.userDepartment,
        'userPhotoUrl': p.userPhotoUrl,
        'itemName': p.itemName,
        'description': p.description,
        'color': p.color,
        'area': p.area,
        'category': p.category,
        'type': p.type,
        'status': p.status,
        'timestamp': Timestamp.fromDate(p.timestamp),
        'images': p.images,
      };

  static PostModel _postFromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final ts = d['timestamp'];
    final DateTime dateTime =
        ts is Timestamp ? ts.toDate() : DateTime.parse(ts as String);
    return PostModel(
      id: d['id'] as String? ?? doc.id,
      userId: d['userId'] as String,
      userName: d['userName'] as String,
      userPhone: d['userPhone'] as String? ?? '',
      userDepartment: d['userDepartment'] as String? ?? '',
      userPhotoUrl: d['userPhotoUrl'] as String? ?? '',
      itemName: d['itemName'] as String,
      description: d['description'] as String,
      color: d['color'] as String,
      area: d['area'] as String,
      category: d['category'] as String,
      type: d['type'] as String,
      status: d['status'] as String? ?? 'active',
      timestamp: dateTime,
      images: List<String>.from(d['images'] ?? []), // ← NEW
    );
  }
}
