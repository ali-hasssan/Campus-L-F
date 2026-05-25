import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../main.dart';
import '../models/post_model.dart';
import '../services/firebase_service.dart';

class CreatePostScreen extends StatefulWidget {
  final PostModel? post; // non-null = edit mode
  const CreatePostScreen({super.key, this.post});
  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _type = 'lost';
  String? _color;
  String? _area;
  String? _category;
  bool _loading = false;

  // Local files picked by user (max 3)
  final List<File?> _pickedImages = [null, null, null];
  // Existing URLs from Firestore (edit mode)
  List<String> _existingImageUrls = [];

  final _picker = ImagePicker();

  bool get _isEdit => widget.post != null;

  static const _colors = [
    'Black',
    'White',
    'Red',
    'Blue',
    'Green',
    'Yellow',
    'Brown',
    'Grey',
    'Pink',
    'Orange',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.post!;
      _nameCtrl.text = p.itemName;
      _descCtrl.text = p.description;
      _type = p.type;
      _color = p.color;
      _area = p.area;
      _category = p.category;
      _existingImageUrls = List<String>.from(p.images);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  //  Pick image from gallery
  Future<void> _pickImage(int slot) async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1080,
    );
    if (xFile == null) return;
    setState(() => _pickedImages[slot] = File(xFile.path));
  }

  void _removeImage(int slot) {
    setState(() => _pickedImages[slot] = null);
  }

  void _removeExisting(int idx) {
    setState(() => _existingImageUrls.removeAt(idx));
  }

  // Submit
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_color == null || _area == null || _category == null) {
      _snack('Please fill all fields before submitting.');
      return;
    }
    setState(() => _loading = true);

    final user = await FirebaseService.getCurrentUser();
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    final postId = _isEdit ? widget.post!.id : const Uuid().v4();

    // Upload newly picked images and collect download URLs
    final List<String> finalImageUrls = List<String>.from(_existingImageUrls);
    for (int i = 0; i < _pickedImages.length; i++) {
      final file = _pickedImages[i];
      if (file != null) {
        try {
          final url = await FirebaseService.uploadPostImage(
            postId: postId,
            imageFile: file,
            index: finalImageUrls.length, // append after existing
          );
          finalImageUrls.add(url);
        } catch (e) {
          _snack('Image upload failed: $e');
          setState(() => _loading = false);
          return;
        }
      }
    }

    final post = _isEdit
        ? widget.post!.copyWith(
            itemName: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            type: _type,
            color: _color,
            area: _area,
            category: _category,
            images: finalImageUrls,
          )
        : PostModel(
            id: postId,
            userId: user.id,
            userName: user.name,
            userPhone: user.phone,
            userDepartment: user.department,
            userPhotoUrl: user.profileImageUrl,
            itemName: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            color: _color!,
            area: _area!,
            category: _category!,
            type: _type,
            timestamp: DateTime.now(),
            images: finalImageUrls,
          );

    await FirebaseService.savePost(post);
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pop(context);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // Total images currently staged
  int get _totalImages =>
      _existingImageUrls.length + _pickedImages.where((f) => f != null).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Post' : 'New Post'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isEdit)
            TextButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary))
                  : const Text('Save',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Type toggle
              _SectionLabel('What happened?'),
              const SizedBox(height: 10),
              _TypeToggle(
                value: _type,
                onChanged: (v) => setState(() => _type = v),
              ),
              const SizedBox(height: 22),

              // ── Category
              _SectionLabel('Category'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppK.categories.map((c) {
                  final active = _category == c;
                  return GestureDetector(
                    onTap: () => setState(() => _category = c),
                    child: _SelectChip(label: c, active: active),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),

              //  Item name
              _SectionLabel('Item Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'e.g. Samsung A54, Black Bag',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // ── Description
              _SectionLabel('Description'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Describe the item in detail...',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.notes_rounded),
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 22),

              // Photos section
              Row(
                children: [
                  _SectionLabel('Photos'),
                  const SizedBox(width: 8),
                  Text(
                    '(optional, max 3)',
                    style:
                        const TextStyle(fontSize: 12, color: AppTheme.txtSec),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildImagePicker(),
              const SizedBox(height: 22),

              // ── Color
              _SectionLabel('Color'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colors.map((c) {
                  final active = _color == c;
                  return GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? AppTheme.primary : AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: active ? AppTheme.primary : AppTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _colorVal(c),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.black12, width: 0.5),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(c,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      active ? Colors.white : AppTheme.txtSec)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),

              // ── Area
              _SectionLabel('Campus Area'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppK.areas.map((a) {
                  final active = _area == a;
                  return GestureDetector(
                    onTap: () => setState(() => _area = a),
                    child: _SelectChip(label: a, active: active),
                  );
                }).toList(),
              ),
              const SizedBox(height: 36),

              if (!_isEdit)
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(_type == 'lost'
                                ? 'Post Lost Item'
                                : 'Post Found Item'),
                          ],
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Image picker grid
  Widget _buildImagePicker() {
    // Always show exactly 3 slots
    return Row(
      children: List.generate(3, (i) {
        // Determine what to show in this slot
        String? networkUrl;
        File? file;

        if (i < _existingImageUrls.length) {
          networkUrl = _existingImageUrls[i];
        } else {
          final newIdx = i - _existingImageUrls.length;
          if (newIdx < _pickedImages.length) {
            file = _pickedImages[newIdx];
          }
        }

        final hasImage = networkUrl != null || file != null;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
            child: _ImageSlot(
              key: ValueKey('slot_$i'),
              file: file,
              networkUrl: networkUrl,
              onPick: hasImage
                  ? null
                  : () {
                      // Find the correct _pickedImages index
                      final newIdx = i - _existingImageUrls.length;
                      if (newIdx >= 0 && newIdx < _pickedImages.length) {
                        _pickImage(newIdx);
                      }
                    },
              onRemove: hasImage
                  ? () {
                      if (networkUrl != null) {
                        _removeExisting(i);
                      } else {
                        final newIdx = i - _existingImageUrls.length;
                        _removeImage(newIdx);
                      }
                    }
                  : null,
            ),
          ),
        );
      }),
    );
  }

  Color _colorVal(String name) {
    const map = {
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
    return map[name] ?? Colors.blueGrey;
  }
}

// Image Slot Widget
class _ImageSlot extends StatelessWidget {
  final File? file;
  final String? networkUrl;
  final VoidCallback? onPick;
  final VoidCallback? onRemove;

  const _ImageSlot({
    super.key,
    this.file,
    this.networkUrl,
    this.onPick,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = file != null || networkUrl != null;

    return SizedBox(
      height: 90,
      child: Stack(
        children: [
          //  Image or placeholder
          GestureDetector(
            onTap: hasImage ? null : onPick,
            child: Container(
              width: double.infinity,
              height: 90,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasImage
                      ? AppTheme.primary.withOpacity(0.3)
                      : AppTheme.border,
                  width: hasImage ? 1.5 : 1,
                ),
              ),
              child: hasImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: file != null
                          ? Image.file(file!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity)
                          : Image.network(networkUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image_outlined,
                                        color: AppTheme.txtSec),
                                  )),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            color: AppTheme.txtSec.withOpacity(0.6), size: 24),
                        const SizedBox(height: 4),
                        const Text(
                          'Add Photo',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 11, color: AppTheme.txtSec),
                        ),
                      ],
                    ),
            ),
          ),

          //  Remove button
          if (hasImage && onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _TypeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged('lost'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              decoration: BoxDecoration(
                color: value == 'lost' ? AppTheme.lost : AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: value == 'lost' ? AppTheme.lost : AppTheme.border),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_off_rounded,
                        color: value == 'lost' ? Colors.white : AppTheme.txtSec,
                        size: 20),
                    const SizedBox(width: 6),
                    Text('Lost',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: value == 'lost'
                                ? Colors.white
                                : AppTheme.txtSec)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged('found'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 52,
              decoration: BoxDecoration(
                color: value == 'found' ? AppTheme.found : AppTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: value == 'found' ? AppTheme.found : AppTheme.border),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        color:
                            value == 'found' ? Colors.white : AppTheme.txtSec,
                        size: 20),
                    const SizedBox(width: 6),
                    Text('Found',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: value == 'found'
                                ? Colors.white
                                : AppTheme.txtSec)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectChip extends StatelessWidget {
  final String label;
  final bool active;
  const _SelectChip({required this.label, required this.active});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: active ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : AppTheme.txtSec)),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.txtPri));
}
