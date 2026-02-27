import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_button.dart';
import '../widgets/glassmorphic_container.dart';
import '../services/api_service.dart';

class ResultScreen extends StatefulWidget {
  final String videoPath;
  const ResultScreen({super.key, required this.videoPath});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  bool _isAnalyzing = true;
  bool _hasError = false;
  String _resultText = '';
  String _errorText = '';
  String? _avatarUrl;
  VideoPlayerController? _avatarController;
  bool _avatarReady = false;

  @override
  void initState() {
    super.initState();
    _uploadAndAnalyze();
  }

  Future<void> _uploadAndAnalyze() async {
    try {
      final response = await ApiService.uploadVideo(widget.videoPath);

      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _isAnalyzing = false;
          _resultText = response['result'] ?? '';
          _avatarUrl = response['avatar_url'];
        });
        if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
          _initAvatarVideo(_avatarUrl!);
        }
      } else {
        setState(() {
          _isAnalyzing = false;
          _hasError = true;
          _errorText = response['error'] ?? 'حدث خطأ غير متوقع';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _hasError = true;
        _errorText = 'تعذر الاتصال بالخادم، تحقق من الإنترنت';
      });
    }
  }

  Future<void> _initAvatarVideo(String url) async {
    _avatarController = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await _avatarController!.initialize();
      _avatarController!.setLooping(true);
      _avatarController!.play();
      if (mounted) setState(() => _avatarReady = true);
    } catch (_) {
      // Avatar video failed to load, just show text
    }
  }

  @override
  void dispose() {
    _avatarController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: AppColors.background,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildTopBar(),
                  const SizedBox(height: 32),
                  _buildStatusCard(),
                  const SizedBox(height: 24),
                  if (!_isAnalyzing && !_hasError && _avatarReady)
                    _buildAvatarCard(),
                  if (!_isAnalyzing && !_hasError && _avatarReady)
                    const SizedBox(height: 24),
                  if (!_isAnalyzing && !_hasError) _buildResultCard(),
                  if (!_isAnalyzing && _hasError) _buildErrorCard(),
                  const SizedBox(height: 32),
                  if (!_isAnalyzing) _buildActions(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const Expanded(
          child: Center(
            child: Text(
              'نتيجة الترجمة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 44),
      ],
    );
  }

  Widget _buildStatusCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: _isAnalyzing
              ? AppColors.primaryGradient
              : _hasError
                  ? const LinearGradient(
                      colors: [Color(0xFFFF5252), Color(0xFFFF7043)])
                  : const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)]),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: (_isAnalyzing
                      ? AppColors.primary
                      : _hasError
                          ? AppColors.error
                          : AppColors.success)
                  .withValues(alpha: 0.35),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _isAnalyzing
              ? _buildLoadingStatus()
              : _hasError
                  ? _buildErrorStatus()
                  : _buildSuccessStatus(),
        ),
      ),
    );
  }

  Widget _buildLoadingStatus() {
    return Row(
      key: const ValueKey('loading'),
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('جارٍ تحليل الفيديو...',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('قد يستغرق هذا بضع ثوانٍ',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  minHeight: 4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorStatus() {
    return Row(
      key: const ValueKey('error'),
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('فشل التحليل',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('حدث خطأ أثناء تحليل الفيديو',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessStatus() {
    return Row(
      key: const ValueKey('done'),
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تمت الترجمة بنجاح!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('تم تحليل الفيديو وترجمته',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.accessibility_new_rounded,
                      color: AppColors.secondary, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'فيديو الأفاتار',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: _avatarController!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_avatarController!),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_avatarController!.value.isPlaying) {
                              _avatarController!.pause();
                            } else {
                              _avatarController!.play();
                            }
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _avatarController!.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.translate_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'النص المترجم',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(
                _resultText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                  height: 1.8,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GlassmorphicContainer(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: Column(
        children: [
          CustomButton(
            text: 'ترجمة فيديو جديد',
            icon: Icons.videocam_rounded,
            onPressed: () => Navigator.pop(context),
          ),
          if (_hasError) ...[
            const SizedBox(height: 14),
            CustomButton(
              text: 'إعادة المحاولة',
              icon: Icons.refresh_rounded,
              isOutlined: true,
              onPressed: () {
                setState(() {
                  _isAnalyzing = true;
                  _hasError = false;
                  _errorText = '';
                  _resultText = '';
                  _avatarUrl = null;
                  _avatarReady = false;
                  _avatarController?.dispose();
                  _avatarController = null;
                });
                _uploadAndAnalyze();
              },
            ),
          ],
        ],
      ),
    );
  }
}
