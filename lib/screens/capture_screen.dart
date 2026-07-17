import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/food_api_service.dart';
import 'ingredient_review_screen.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _picker = ImagePicker();
  final _api = FoodApiService();
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('辨識失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mediaTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FoodSnap')),
      body: Center(
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
                      onPressed: () => _pickAndAnalyze(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('拍照'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _pickAndAnalyze(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('從相簿選取'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
