import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../services/face_embedding_service.dart';

/// One-time face registration.
///
/// Three photographs are taken and averaged into a single template, and the
/// captures are checked against each other before anything is sent — if they do
/// not agree, they are not all the same face, and registering the average would
/// produce a template matching nobody in particular.
class FaceEnrollmentScreen extends StatefulWidget {
  const FaceEnrollmentScreen({super.key});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  static const int _requiredCaptures = 3;

  /// Captures of one person score far higher than this against each other;
  /// two different people score nowhere near it.
  static const double _consistencyFloor = 0.75;

  final List<List<double>> _samples = [];
  final List<String> _samplePaths = [];

  bool _loading = true;
  bool _busy = false;
  bool _alreadyEnrolled = false;
  bool _modelMissing = false;
  String? _enrolledAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final ready = await FaceEmbeddingService.instance.initialise();
      final response = await ApiService().getFaceStatus();
      if (!mounted) return;

      final data = response['data'] as Map<String, dynamic>?;
      setState(() {
        _modelMissing = !ready;
        _alreadyEnrolled = data?['enrolled'] == true;
        _enrolledAt = data?['enrolled_at'] as String?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not check your face registration. $e';
        _loading = false;
      });
    }
  }

  Future<void> _capture() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90, // higher than attendance: this is the reference
      );
      if (photo == null) {
        setState(() => _busy = false);
        return;
      }

      final result = await FaceEmbeddingService.instance
          .embedFromFile(File(photo.path), strict: true);

      if (!mounted) return;

      if (!result.ok) {
        setState(() {
          _error = result.message;
          _busy = false;
        });
        return;
      }

      // Compare against what has already been captured, so a photo of someone
      // else cannot be slipped into the set.
      if (_samples.isNotEmpty) {
        final score = FaceEmbeddingService.instance
            .similarity(_samples.first, result.embedding!);
        if (score != null && score < _consistencyFloor) {
          setState(() {
            _error = 'That does not look like the same face as the first photo. '
                'Please start again.';
            _samples.clear();
            _samplePaths.clear();
            _busy = false;
          });
          return;
        }
      }

      setState(() {
        _samples.add(result.embedding!);
        _samplePaths.add(photo.path);
        _busy = false;
      });

      if (_samples.length >= _requiredCaptures) await _submit();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong while capturing. $e';
        _busy = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _busy = true);

    final template = FaceEmbeddingService.instance.averageEmbeddings(_samples);
    if (template == null) {
      setState(() {
        _error = 'Could not combine the photos. Please start again.';
        _samples.clear();
        _samplePaths.clear();
        _busy = false;
      });
      return;
    }

    try {
      final response = await ApiService()
          .enrollFace(template, FaceEmbeddingService.instance.modelVersion);
      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _alreadyEnrolled = true;
          _busy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Face registered.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _alreadyEnrolled = response['already_enrolled'] == true;
          _error = response['message'] ?? 'Could not register your face.';
          _samples.clear();
          _samplePaths.clear();
          _busy = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach the server. $e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Face Registration'),
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_modelMissing) _card(_unavailableBody())
                  else if (_alreadyEnrolled) _card(_enrolledBody())
                  else ...[
                    _card(_instructionsBody()),
                    const SizedBox(height: 16),
                    _card(_captureBody()),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _errorBanner(_error!),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _unavailableBody() {
    // A model that was bundled but rejected says why, which is what whoever is
    // setting this up needs; an employee who simply has an older build sees
    // the plain message and nothing confusing.
    final problem = FaceEmbeddingService.instance.loadProblem;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFF1E3A5F), size: 32),
        const SizedBox(height: 12),
        const Text('Not available yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Face registration is not included in this version of the app. '
          'Please update to the latest version and try again.',
          style: TextStyle(color: Colors.black54, height: 1.4),
        ),
        if (problem != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Text(problem,
                style: const TextStyle(fontSize: 12.5, height: 1.35, color: Colors.black87)),
          ),
        ],
      ],
    );
  }

  Widget _enrolledBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.verified_user_rounded,
                  color: Colors.green, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text('Your face is registered',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        if (_enrolledAt != null) ...[
          const SizedBox(height: 12),
          Text('Registered on $_enrolledAt',
              style: const TextStyle(color: Colors.black54)),
        ],
        const SizedBox(height: 12),
        const Text(
          'Your selfie is checked against this when you clock in and out. '
          'This is a one-time setup — if you need to register again, ask your '
          'administrator to reset it.',
          style: TextStyle(color: Colors.black54, height: 1.4),
        ),
      ],
    );
  }

  Widget _instructionsBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Register your face',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text(
          'Take $_requiredCaptures photos of yourself. They are used to confirm '
          'it is really you when you clock in and out.',
          style: TextStyle(color: Colors.black54, height: 1.4),
        ),
        const SizedBox(height: 16),
        ...[
          'Stand in good, even light — avoid a window behind you',
          'Hold the phone at eye level and look straight at it',
          'Keep both eyes open, and remove sunglasses or a cap',
          'Make sure nobody else is in the picture',
        ].map(
          (tip) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    size: 18, color: Color(0xFF2A5298)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(tip,
                        style: const TextStyle(color: Colors.black87, height: 1.3))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F).withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF1E3A5F)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Only a mathematical summary of your face is stored — not the '
                  'photographs. It cannot be turned back into a picture.',
                  style: TextStyle(fontSize: 12.5, color: Colors.black54, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _captureBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_requiredCaptures, (i) {
            final done = i < _samples.length;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? Colors.green.withOpacity(0.12)
                          : Colors.grey.withOpacity(0.10),
                      border: Border.all(
                        color: done ? Colors.green : Colors.grey.shade300,
                        width: 2,
                      ),
                      image: done
                          ? DecorationImage(
                              image: FileImage(File(_samplePaths[i])),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: done
                        ? null
                        : Icon(Icons.person_outline_rounded,
                            color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 6),
                  Text('Photo ${i + 1}',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: done ? Colors.green.shade700 : Colors.black45,
                          fontWeight: done ? FontWeight.w600 : FontWeight.normal)),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _busy ? null : _capture,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.photo_camera_rounded),
          label: Text(_busy
              ? 'Please wait...'
              : _samples.isEmpty
                  ? 'Take first photo'
                  : 'Take photo ${_samples.length + 1} of $_requiredCaptures'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A5F),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (_samples.isNotEmpty && !_busy) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _samples.clear();
              _samplePaths.clear();
              _error = null;
            }),
            child: const Text('Start again'),
          ),
        ],
      ],
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.red, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
