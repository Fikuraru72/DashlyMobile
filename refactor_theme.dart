import 'dart:io';

void main() {
  final dir = Directory('lib');
  for (final file in dir.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart') || file.path.contains('dashly_theme.dart') || file.path.contains('theme_provider.dart')) continue;
    String content = file.readAsStringSync();
    
    // Replace DashlyTheme. with context.dashlyColors.
    content = content.replaceAll('DashlyTheme.background', 'context.dashlyColors.background');
    content = content.replaceAll('DashlyTheme.surface', 'context.dashlyColors.surface');
    content = content.replaceAll('DashlyTheme.surfaceLight', 'context.dashlyColors.surfaceLight');
    content = content.replaceAll('DashlyTheme.accent', 'context.dashlyColors.accent');
    content = content.replaceAll('DashlyTheme.accentDim', 'context.dashlyColors.accentDim');
    content = content.replaceAll('DashlyTheme.textPrimary', 'context.dashlyColors.textPrimary');
    content = content.replaceAll('DashlyTheme.textSecondary', 'context.dashlyColors.textSecondary');
    content = content.replaceAll('DashlyTheme.textHint', 'context.dashlyColors.textHint');
    content = content.replaceAll('DashlyTheme.error', 'context.dashlyColors.error');
    content = content.replaceAll('DashlyTheme.divider', 'context.dashlyColors.divider');
    content = content.replaceAll('DashlyTheme.accentGradient', 'context.dashlyColors.accentGradient');
    content = content.replaceAll('DashlyTheme.cardGradient', 'context.dashlyColors.cardGradient');
    
    // Replace DashlyTheme.inputDecoration( to DashlyTheme.inputDecoration(context, 
    content = content.replaceAll('DashlyTheme.inputDecoration(', 'DashlyTheme.inputDecoration(context, ');
    
    // Strip const keywords that became invalid
    content = content.replaceAll('const TextStyle(', 'TextStyle(');
    content = content.replaceAll('const BoxDecoration(', 'BoxDecoration(');
    content = content.replaceAll('const Divider(', 'Divider(');
    content = content.replaceAll('const Expanded(', 'Expanded(');
    content = content.replaceAll('const Text(', 'Text(');
    content = content.replaceAll('const Icon(', 'Icon(');
    content = content.replaceAll('const BorderSide(', 'BorderSide(');
    content = content.replaceAll('const LinearGradient(', 'LinearGradient(');
    content = content.replaceAll('const Color(', 'Color(');
    
    file.writeAsStringSync(content);
  }
}
