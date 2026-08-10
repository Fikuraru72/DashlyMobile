import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../theme/dashly_theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _emergencyPhoneCtrl = TextEditingController();

  String? _selectedBloodType;
  String? _selectedEmergencyRelation;

  static const _bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  static const _relations = [
    'Teman',
    'Saudara',
    'Orang Tua',
    'Suami/Istri',
    'Anak',
  ];

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _phoneCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleComplete() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final healthInfo = HealthInfo(
      bloodType: _selectedBloodType,
      weight: double.tryParse(_weightCtrl.text.trim()),
      height: double.tryParse(_heightCtrl.text.trim()),
      emergencyName: _emergencyNameCtrl.text.trim().isEmpty
          ? null
          : _emergencyNameCtrl.text.trim(),
      emergencyPhone: _emergencyPhoneCtrl.text.trim().isEmpty
          ? null
          : _emergencyPhoneCtrl.text.trim(),
      emergencyRelation: _selectedEmergencyRelation,
    );

    final success = await auth.completeProfile(
      phone: _phoneCtrl.text.trim(),
      healthInfo: healthInfo,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Failed to save profile'),
          backgroundColor: context.dashlyColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: const SizedBox.shrink(), // No back button during onboarding
        title: Text('Complete Your Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Subtitle ──────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: context.dashlyColors.cardGradient,
                        borderRadius: DashlyTheme.radiusMd,
                        border: Border.all(
                          color: context.dashlyColors.accent.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: context.dashlyColors.accent.withOpacity(0.15),
                              borderRadius: DashlyTheme.radiusSm,
                            ),
                            child: Icon(
                              Icons.health_and_safety_outlined,
                              color: context.dashlyColors.accent,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Health & Safety Info',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: context.dashlyColors.textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'This data helps event organizers ensure your safety during races.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: context.dashlyColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Section: Contact ──────────────────────────
                    _sectionLabel('Contact Information'),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: context.dashlyColors.textPrimary),
                      decoration: DashlyTheme.inputDecoration(context, 
                        label: 'Phone Number',
                        hint: '+62 812 3456 7890',
                        prefixIcon: Icons.phone_outlined,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Phone number is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _emergencyNameCtrl,
                      style: TextStyle(color: context.dashlyColors.textPrimary),
                      decoration: DashlyTheme.inputDecoration(context, 
                        label: 'Nama Kontak Darurat',
                        hint: 'Nama lengkap kontak darurat',
                        prefixIcon: Icons.emergency_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedEmergencyRelation,
                            dropdownColor: context.dashlyColors.surfaceLight,
                            style: TextStyle(color: context.dashlyColors.textPrimary),
                            decoration: DashlyTheme.inputDecoration(context, 
                              label: 'Hubungan',
                            ),
                            items: _relations
                                .map((r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(r),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedEmergencyRelation = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _emergencyPhoneCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: context.dashlyColors.textPrimary),
                            decoration: DashlyTheme.inputDecoration(context, 
                              label: 'No. HP Darurat',
                              hint: '0812...',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Section: Health ───────────────────────────
                    _sectionLabel('Health Information'),
                    const SizedBox(height: 12),

                    // Blood Type Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedBloodType,
                      dropdownColor: context.dashlyColors.surfaceLight,
                      style: TextStyle(color: context.dashlyColors.textPrimary),
                      decoration: DashlyTheme.inputDecoration(context, 
                        label: 'Blood Type',
                        prefixIcon: Icons.bloodtype_outlined,
                      ),
                      items: _bloodTypes
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedBloodType = v),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please select your blood type';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Weight & Height side by side
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _weightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: TextStyle(
                                color: context.dashlyColors.textPrimary),
                            decoration: DashlyTheme.inputDecoration(context, 
                              label: 'Weight',
                              hint: 'kg',
                              prefixIcon: Icons.monitor_weight_outlined,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(v) == null) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _heightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: TextStyle(
                                color: context.dashlyColors.textPrimary),
                            decoration: DashlyTheme.inputDecoration(context, 
                              label: 'Height',
                              hint: 'cm',
                              prefixIcon: Icons.height_rounded,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              if (double.tryParse(v) == null) {
                                return 'Invalid';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // ── Complete Button ───────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _handleComplete,
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.black,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.check_circle_outline_rounded,
                                      size: 20),
                                  SizedBox(width: 8),
                                  Text('COMPLETE SETUP'),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Skip Button ──────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed('/home');
                        },
                        child: Text(
                          'Skip for now',
                          style: TextStyle(color: context.dashlyColors.textHint),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
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
          decoration: BoxDecoration(
            color: context.dashlyColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
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
