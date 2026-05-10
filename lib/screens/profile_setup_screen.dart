import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isEditMode;
  const ProfileSetupScreen({super.key, this.isEditMode = false});
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  String? _dept;
  String? _sem;
  bool _loading = false;
  bool _prefilled = false;          // guard so we only pre-fill once

  File? _profileImage;
  String _existingPhotoUrl = '';   // show existing photo in edit mode
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode) _prefillExistingData();
  }

  Future<void> _prefillExistingData() async {
    final user = await FirebaseService.getCurrentUser();
    if (user == null || !mounted) return;
    setState(() {
      _phoneCtrl.text = user.phone;
      _dept = user.department.isNotEmpty ? user.department : null;
      _sem  = user.semester.isNotEmpty  ? user.semester  : null;
      _existingPhotoUrl = user.profileImageUrl;
      _prefilled = true;
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
    );
    if (xFile != null) setState(() => _profileImage = File(xFile.path));
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_dept == null || _sem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select department & semester')),
      );
      return;
    }
    setState(() => _loading = true);

    final user = await FirebaseService.getCurrentUser();
    if (user == null) { setState(() => _loading = false); return; }

    // Upload profile image if picked
    String profileImageUrl = user.profileImageUrl;
    if (_profileImage != null) {
      try {
        profileImageUrl = await FirebaseService.uploadProfileImage(
          userId: user.id,
          imageFile: _profileImage!,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image upload failed: $e')),
          );
        }
        setState(() => _loading = false);
        return;
      }
    }

    await FirebaseService.saveUser(user.copyWith(
      department: _dept,
      semester: _sem,
      phone: _phoneCtrl.text.trim(),
      profileComplete: true,
      profileImageUrl: profileImageUrl,
    ));

    if (!mounted) return;
    setState(() => _loading = false);
    if (widget.isEditMode) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.isEditMode
          ? AppBar(title: const Text('Edit Profile'))
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: widget.isEditMode ? 20 : 48),

              // ── Profile image picker ──────────────────────────────────────
              Center(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: _pickProfileImage,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: (_profileImage == null && _existingPhotoUrl.isEmpty)
                              ? const LinearGradient(
                                  colors: [Color(0xFF5B4FE9), Color(0xFF7C3AED)],
                                )
                              : null,
                          border: Border.all(
                            color: AppTheme.primary.withOpacity(0.3),
                            width: 2.5,
                          ),
                        ),
                        child: _profileImage != null
                            // newly picked local file
                            ? ClipOval(
                                child: Image.file(
                                  _profileImage!,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                ),
                              )
                            : _existingPhotoUrl.isNotEmpty
                                // existing photo from Firestore
                                ? ClipOval(
                                    child: Image.network(
                                      _existingPhotoUrl,
                                      fit: BoxFit.cover,
                                      width: 100,
                                      height: 100,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.person_rounded,
                                              color: Colors.white, size: 48),
                                    ),
                                  )
                                : const Icon(Icons.person_rounded,
                                    color: Colors.white, size: 48),
                      ),
                    ),
                    // Camera badge
                    Positioned(
                      bottom: 0, right: 0,
                      child: GestureDetector(
                        onTap: _pickProfileImage,
                        child: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _profileImage == null ? 'Add profile photo' : 'Tap to change',
                  style: const TextStyle(fontSize: 12, color: AppTheme.txtSec),
                ),
              ),

              const SizedBox(height: 28),
              const Center(
                child: Text('Set up your profile',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.txtPri)),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                    'This helps others identify you when\nyou post about lost or found items.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppTheme.txtSec)),
              ),
              const SizedBox(height: 36),

              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionLabel('Department'),
                    const SizedBox(height: 8),
                    _StyledDropdown<String>(
                      hint: 'Select your department',
                      value: _dept,
                      items: AppK.departments,
                      onChanged: (v) => setState(() => _dept = v),
                      icon: Icons.account_balance_outlined,
                    ),
                    const SizedBox(height: 18),
                    const _SectionLabel('Semester'),
                    const SizedBox(height: 8),
                    _StyledDropdown<String>(
                      hint: 'Select semester',
                      value: _sem,
                      items: AppK.semesters,
                      onChanged: (v) => setState(() => _sem = v),
                      icon: Icons.calendar_today_outlined,
                    ),
                    const SizedBox(height: 18),
                    const _SectionLabel('Phone Number'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: '03XX-XXXXXXX',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length < 10) {
                          return 'Enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 36),
                    ElevatedButton(
                      onPressed: _loading ? null : _save,
                      child: _loading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(widget.isEditMode
                                ? 'Save Changes'
                                : 'Complete Profile'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.txtPri),
      );
}

class _StyledDropdown<T> extends StatelessWidget {
  final String hint;
  final T? value;
  final List<String> items;
  final ValueChanged<T?> onChanged;
  final IconData icon;

  const _StyledDropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Row(children: [
            Icon(icon, size: 20, color: AppTheme.txtSec),
            const SizedBox(width: 10),
            Text(hint,
                style: const TextStyle(color: AppTheme.txtSec, fontSize: 14)),
          ]),
          items: items
              .map((e) => DropdownMenuItem<T>(
                    value: e as T,
                    child: Text(e,
                        style: const TextStyle(
                            fontSize: 14, color: AppTheme.txtPri)),
                  ))
              .toList(),
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppTheme.txtSec),
        ),
      ),
    );
  }
}
