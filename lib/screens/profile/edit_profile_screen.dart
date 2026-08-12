import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../theme/dashly_theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _emergencyNameCtrl;
  late TextEditingController _emergencyPhoneCtrl;
  late TextEditingController _medicalHistoryCtrl;
  late TextEditingController _passwordCtrl;

  String? _selectedBloodType;
  String? _selectedEmergencyRelation;
  String? _avatarBase64;
  
  static const _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  static const _relations = ['Teman', 'Saudara', 'Orang Tua', 'Suami/Istri', 'Anak'];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _weightCtrl = TextEditingController(text: user?.healthInfo?.weight?.toString() ?? '');
    _heightCtrl = TextEditingController(text: user?.healthInfo?.height?.toString() ?? '');
    _emergencyNameCtrl = TextEditingController(text: user?.healthInfo?.emergencyName ?? '');
    _emergencyPhoneCtrl = TextEditingController(text: user?.healthInfo?.emergencyPhone ?? user?.healthInfo?.emergencyContact ?? '');
    _medicalHistoryCtrl = TextEditingController(text: user?.healthInfo?.medicalHistory ?? '');
    _passwordCtrl = TextEditingController();
    _selectedBloodType = user?.healthInfo?.bloodType;
    final rel = user?.healthInfo?.emergencyRelation;
    _selectedEmergencyRelation = (rel != null && _relations.contains(rel)) ? rel : null;
    _avatarBase64 = user?.avatar;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _medicalHistoryCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 70, // compress slightly
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          // Convert to base64
          _avatarBase64 = 'data:image/jpeg;base64,' + base64Encode(bytes);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image'), backgroundColor: context.dashlyColors.error),
      );
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    
    final auth = context.read<AuthProvider>();
    
    final healthInfo = HealthInfo(
      bloodType: _selectedBloodType,
      weight: double.tryParse(_weightCtrl.text.trim()),
      height: double.tryParse(_heightCtrl.text.trim()),
      emergencyName: _emergencyNameCtrl.text.trim().isEmpty ? null : _emergencyNameCtrl.text.trim(),
      emergencyPhone: _emergencyPhoneCtrl.text.trim().isEmpty ? null : _emergencyPhoneCtrl.text.trim(),
      emergencyRelation: _selectedEmergencyRelation,
      medicalHistory: _medicalHistoryCtrl.text.trim().isEmpty ? null : _medicalHistoryCtrl.text.trim(),
    );

    final success = await auth.updateProfile(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passwordCtrl.text.isNotEmpty ? _passwordCtrl.text : null,
      avatar: _avatarBase64,
      healthInfo: healthInfo,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Profile updated successfully!'), backgroundColor: context.dashlyColors.accent),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Failed to update profile'), backgroundColor: context.dashlyColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Section
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: context.dashlyColors.accent, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: context.dashlyColors.surfaceLight,
                          backgroundImage: _avatarBase64 != null && _avatarBase64!.isNotEmpty
                              ? MemoryImage(const Base64Decoder().convert(_avatarBase64!.split(',').last))
                              : null,
                          child: _avatarBase64 == null || _avatarBase64!.isEmpty
                              ? Icon(Icons.person_rounded, size: 40, color: context.dashlyColors.accent)
                              : null,
                        ),
                      ),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.dashlyColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.dashlyColors.surface, width: 3),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Name & Phone
                _sectionLabel("PERSONAL INFO"),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  style: TextStyle(color: context.dashlyColors.textPrimary),
                  decoration: DashlyTheme.inputDecoration(context, label: 'Full Name', prefixIcon: Icons.person_outline),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: context.dashlyColors.textPrimary),
                  decoration: DashlyTheme.inputDecoration(context, label: 'Phone Number', prefixIcon: Icons.phone_outlined),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Phone number is required';
                    }
                    final cleanV = v.trim().replaceAll(' ', '');
                    if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(cleanV)) {
                      return 'Enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),


                // Health Info
                _sectionLabel("HEALTH DATA"),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedBloodType,
                        dropdownColor: context.dashlyColors.surface,
                        style: TextStyle(color: context.dashlyColors.textPrimary),
                        decoration: DashlyTheme.inputDecoration(context, label: 'Blood Type'),
                        items: _bloodTypes.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                        onChanged: (v) => setState(() => _selectedBloodType = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _weightCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: context.dashlyColors.textPrimary),
                        decoration: DashlyTheme.inputDecoration(context, label: 'Weight (kg)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _heightCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: context.dashlyColors.textPrimary),
                  decoration: DashlyTheme.inputDecoration(context, label: 'Height (cm)'),
                ),
                const SizedBox(height: 16),
                // Emergency Contact
                const SizedBox(height: 24),
                _sectionLabel("EMERGENCY CONTACT"),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emergencyNameCtrl,
                  style: TextStyle(color: context.dashlyColors.textPrimary),
                  decoration: DashlyTheme.inputDecoration(context, label: 'Nama Kontak Darurat', prefixIcon: Icons.person_search_outlined),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedEmergencyRelation,
                        dropdownColor: context.dashlyColors.surface,
                        style: TextStyle(color: context.dashlyColors.textPrimary),
                        decoration: DashlyTheme.inputDecoration(context, label: 'Hubungan'),
                        items: _relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (v) => setState(() => _selectedEmergencyRelation = v),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _emergencyPhoneCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: context.dashlyColors.textPrimary),
                        decoration: DashlyTheme.inputDecoration(context, label: 'No. HP Darurat'),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            final cleanV = v.trim().replaceAll(' ', '');
                            if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(cleanV)) {
                              return 'Enter a valid phone number';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _medicalHistoryCtrl,
                  maxLines: 3,
                  style: TextStyle(color: context.dashlyColors.textPrimary),
                  decoration: DashlyTheme.inputDecoration(context, label: 'Medical History (Optional)').copyWith(
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 40),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.dashlyColors.accent,
                      foregroundColor: Colors.white,
                    ),
                    child: auth.isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(color: context.dashlyColors.accent, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.dashlyColors.textPrimary,
                letterSpacing: 0.5,
              ),
        ),
      ],
    );
  }
}
