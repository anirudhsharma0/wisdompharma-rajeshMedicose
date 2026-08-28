import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';

class AppLoadingOverlay {
  static bool _isShowing = false;

  /// Show non-dismissible loading overlay HUD dialog
  static void show(BuildContext context, {String message = 'Processing, please wait...'}) {
    if (_isShowing) return;
    _isShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            backgroundColor: Colors.teal.shade50,
                          ),
                        ),
                        const Icon(
                          Icons.sync_rounded,
                          size: 22,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.slate800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Please wait a moment...',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isShowing = false;
    });
  }

  /// Hide the loading overlay HUD
  static void hide(BuildContext context) {
    if (_isShowing) {
      _isShowing = false;
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  /// Wrap any async function call automatically with the sleek loading overlay
  static Future<T?> runWithLoading<T>(
    BuildContext context, {
    String message = 'Processing, please wait...',
    required Future<T> Function() task,
  }) async {
    show(context, message: message);
    try {
      final result = await task();
      return result;
    } catch (e) {
      rethrow;
    } finally {
      if (context.mounted) {
        hide(context);
      }
    }
  }
}
