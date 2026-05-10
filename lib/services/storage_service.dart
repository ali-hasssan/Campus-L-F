import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';

class StorageService {
  static const _usersKey = 'clf_users';
  static const _postsKey = 'clf_posts';
  static const _sessionKey = 'clf_session';

  // ─── User helpers ───────────────────────────────────────────────────────────
  static Future<List<UserModel>> _readUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_usersKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => UserModel.fromJson(e)).toList();
  }

  static Future<void> _writeUsers(List<UserModel> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _usersKey, jsonEncode(users.map((u) => u.toJson()).toList()));
  }

  static Future<void> saveUser(UserModel user) async {
    final users = await _readUsers();
    final idx = users.indexWhere((u) => u.id == user.id);
    if (idx >= 0) {
      users[idx] = user;
    } else {
      users.add(user);
    }
    await _writeUsers(users);
  }

  static Future<UserModel?> getUserByEmail(String email) async {
    final users = await _readUsers();
    try {
      return users.firstWhere(
          (u) => u.email.toLowerCase() == email.trim().toLowerCase());
    } catch (_) {
      return null;
    }
  }

  // ─── Session ────────────────────────────────────────────────────────────────
  static Future<void> setSession(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, userId);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  static Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_sessionKey);
    if (id == null) return null;
    final users = await _readUsers();
    try {
      return users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── Post helpers ───────────────────────────────────────────────────────────
  static Future<List<PostModel>> getPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_postsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => PostModel.fromJson(e)).toList();
  }

  static Future<void> _writePosts(List<PostModel> posts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _postsKey, jsonEncode(posts.map((p) => p.toJson()).toList()));
  }

  static Future<void> savePost(PostModel post) async {
    final posts = await getPosts();
    final idx = posts.indexWhere((p) => p.id == post.id);
    if (idx >= 0) {
      posts[idx] = post;
    } else {
      posts.insert(0, post); // newest first
    }
    await _writePosts(posts);
  }

  static Future<void> deletePost(String postId) async {
    final posts = await getPosts();
    posts.removeWhere((p) => p.id == postId);
    await _writePosts(posts);
  }

  static Future<List<PostModel>> getPostsByUser(String userId) async {
    final posts = await getPosts();
    return posts.where((p) => p.userId == userId).toList();
  }
}
