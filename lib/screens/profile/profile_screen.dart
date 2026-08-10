import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/dashly_theme.dart';
import '../../models/user_model.dart';
import '../auth/login_screen.dart';
import '../../providers/theme_provider.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("PROFILE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            // Header Section
            _buildHeader(context, user),
            const SizedBox(height: 32),

            // Personal Info Section
            _buildSectionHeader(context, "PERSONAL INFORMATION"),
            const SizedBox(height: 12),
            _buildInfoCard(context, [
              _buildListTile(context, Icons.phone_android_rounded, "Phone Number", user.phone ?? "Not set"),
              _buildListTile(context, Icons.email_outlined, "Email Address", user.email),
            ]),
            const SizedBox(height: 24),

            // Health Info Section (Req #14)
            _buildSectionHeader(context, "ATHLETE HEALTH INFO"),
            const SizedBox(height: 12),
            _buildHealthGrid(context, user.healthInfo),
            const SizedBox(height: 24),

            // Account Actions
            _buildSectionHeader(context, "APPEARANCE"),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: context.dashlyColors.surface,
                borderRadius: DashlyTheme.radiusMd,
                border: Border.all(color: context.dashlyColors.divider, width: 1),
              ),
              child: SwitchListTile(
                title: Text("Dark Mode", style: TextStyle(color: context.dashlyColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text("Use dark colors", style: TextStyle(color: context.dashlyColors.textHint, fontSize: 12)),
                activeColor: context.dashlyColors.accent,
                value: themeProvider.isDarkMode,
                onChanged: (val) => themeProvider.toggleTheme(val),
              ),
            ),
            const SizedBox(height: 24),

            _buildSectionHeader(context, "ACCOUNT SETTINGS"),
            const SizedBox(height: 12),
            _buildInfoCard(context, [
              _buildListTile(context, Icons.edit_note_rounded, "Edit Profile", "Update your data", isAction: true, onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
              }),
              _buildListTile(context, Icons.lock_outline_rounded, "Change Password", "Security settings", isAction: true, onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
              }),
              _buildListTile(
                context,
                Icons.logout_rounded,
                "Logout",
                "Sign out of Dashly",
                isAction: true,
                color: context.dashlyColors.error,
                onTap: () => _handleLogout(context, authProvider),
              ),
            ]),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, User user) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.dashlyColors.accent,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundColor: context.dashlyColors.surface,
                backgroundImage: user.avatar != null && user.avatar!.isNotEmpty
                    ? MemoryImage(const Base64Decoder().convert(user.avatar!.split(',').last))
                    : null,
                child: user.avatar == null || user.avatar!.isEmpty
                    ? Icon(Icons.person_rounded, size: 50, color: context.dashlyColors.textHint)
                    : null,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: context.dashlyColors.accent, shape: BoxShape.circle),
              child: Icon(Icons.camera_alt_rounded, size: 16, color: Colors.black),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          user.name,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.dashlyColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          user.role?.toUpperCase() ?? "ATHLETE",
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.dashlyColors.accent, letterSpacing: 1.5),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.dashlyColors.textHint, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: context.dashlyColors.surface,
        borderRadius: DashlyTheme.radiusMd,
        border: Border.all(color: context.dashlyColors.divider, width: 1),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile(BuildContext context, IconData icon, String title, String subtitle, {bool isAction = false, Color? color, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color ?? context.dashlyColors.accent, size: 22),
      title: Text(title, style: TextStyle(color: color ?? context.dashlyColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: context.dashlyColors.textHint, fontSize: 12)),
      trailing: isAction ? Icon(Icons.chevron_right_rounded, color: context.dashlyColors.textHint, size: 20) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildHealthGrid(BuildContext context, HealthInfo? info) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.dashlyColors.surface,
        borderRadius: DashlyTheme.radiusMd,
        border: Border.all(color: context.dashlyColors.divider, width: 1),
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _buildHealthItem(context, "BLOOD TYPE", info?.bloodType ?? "Not set"),
          _buildHealthItem(context, "WEIGHT", info?.weight != null ? "${info!.weight} kg" : "Not set"),
          _buildHealthItem(context, "HEIGHT", info?.height != null ? "${info!.height} cm" : "Not set"),
          _buildHealthItem(context, "EMERGENCY", info?.formattedEmergencyContact ?? "Not set"),
        ],
      ),
    );
  }

  Widget _buildHealthItem(BuildContext context, String label, String value) {
    final bool isNotSet = value == "Not set";
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.dashlyColors.textHint, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: isNotSet ? context.dashlyColors.textHint.withValues(alpha: 0.5) : context.dashlyColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  void _handleLogout(BuildContext context, AuthProvider auth) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.dashlyColors.surface,
        title: Text("LOGOUT?"),
        content: Text("Are you sure you want to sign out of Dashly?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text("CANCEL")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: context.dashlyColors.error),
            child: Text("LOGOUT"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await auth.logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
