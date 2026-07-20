import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/food_api_service.dart';
import 'achievements_screen.dart';
import 'history_screen.dart';
import 'ingredient_review_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _picker = ImagePicker();
  final _api = FoodApiService();
  final _authService = AuthService();
  bool _loading = false;

  Future<void> _pickAndAnalyze(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1568, // keep well within vision token limits
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;

    setState(() => _loading = true);
    try {
      final bytes = await picked.readAsBytes();
      final mediaType = _mediaTypeFor(picked.path);
      final result = await _api.analyzeFood(
        imageBytes: bytes,
        mediaType: mediaType,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => IngredientReviewScreen(
            initialResult: result,
            imageBytes: bytes,
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      _showApiError(e);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('辨識失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showApiError(FirebaseFunctionsException e) {
    final isQuotaError = e.code == 'resource-exhausted';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.message ?? (isQuotaError ? '今日免費次數已用完。' : '辨識失敗，請稍後再試。'),
        ),
        duration: const Duration(seconds: 5),
        action: isQuotaError && _authService.isAnonymous
            ? SnackBarAction(label: '登入', onPressed: _showSignInSheet)
            : null,
      ),
    );
  }

  Future<void> _showSignInSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '登入解鎖每日更多次數',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.g_mobiledata),
                label: const Text('使用 Google 登入'),
                onPressed: () => _handleSignIn(
                  sheetContext,
                  _authService.linkWithGoogle,
                ),
              ),
              if (Platform.isIOS) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  icon: const Icon(Icons.apple),
                  label: const Text('使用 Apple 登入'),
                  onPressed: () => _handleSignIn(
                    sheetContext,
                    _authService.linkWithApple,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignIn(
    BuildContext sheetContext,
    Future<void> Function() signIn,
  ) async {
    try {
      await signIn();
      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登入成功！')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('登入失敗：$e')),
      );
    }
  }

  Future<void> _openManualEntry() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const IngredientReviewScreen()),
    );
  }

  String _mediaTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('登出'),
        content: const Text('登出後將以訪客身分繼續使用，每日次數會恢復成訪客額度。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('登出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _authService.signOut();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已登出')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodSnap'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '我的紀錄',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => HistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: '成就',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => AchievementsScreen()),
            ),
          ),
          if (!_authService.isAnonymous)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: '登出',
              onPressed: _handleSignOut,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_authService.isAnonymous) _buildSignInBanner(context),
          Expanded(
            child: Center(
              child: _loading
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('辨識食材中…'),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.restaurant, size: 72),
                          const SizedBox(height: 16),
                          const Text(
                            '拍下食材照片，自動翻譯、估算熱量、生成食譜',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            onPressed: () =>
                                _pickAndAnalyze(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('拍照'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _pickAndAnalyze(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('從相簿選取'),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _openManualEntry,
                            icon: const Icon(Icons.edit_note),
                            label: const Text('手動輸入食材'),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInBanner(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: InkWell(
        onTap: _showSignInSheet,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.lock_open, size: 20),
              const SizedBox(width: 12),
              const Expanded(child: Text('登入解鎖每日更多次數')),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
