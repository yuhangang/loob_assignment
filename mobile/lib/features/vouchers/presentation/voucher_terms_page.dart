import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/tokens/colors.dart';
import '../../../core/theme/tokens/spacing.dart';
import '../../../core/utils/extensions.dart';
import '../data/models/voucher_model.dart';

class VoucherTermsPage extends StatefulWidget {
  final VoucherModel voucher;

  const VoucherTermsPage({super.key, required this.voucher});

  @override
  State<VoucherTermsPage> createState() => _VoucherTermsPageState();
}

class _VoucherTermsPageState extends State<VoucherTermsPage> with SingleTickerProviderStateMixin {
  bool _isCopied = false;
  late AnimationController _copyAnimationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _copyAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _copyAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _copyAnimationController.dispose();
    super.dispose();
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.voucher.code));
    setState(() {
      _isCopied = true;
    });
    _copyAnimationController.forward().then((_) => _copyAnimationController.reverse());
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text('Voucher code "${widget.voucher.code}" copied to clipboard!'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
        backgroundColor: AppColors.success,
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAvailable = widget.voucher.status == 'AVAILABLE';
    final discountLabel = widget.voucher.discountType == 'PERCENTAGE'
        ? '${widget.voucher.discountValue}% OFF'
        : '${widget.voucher.discountValue.toDisplayPrice('MYR')} OFF';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.primary.withValues(alpha: 0.05),
              theme.scaffoldBackgroundColor,
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Custom styled silver app bar
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: CircleAvatar(
                    backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.9),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                centerTitle: true,
                title: Text(
                  'Voucher Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              // Page contents
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageHorizontal,
                  vertical: AppSpacing.md,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // 1. Voucher Premium Visual Card Header
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Graphic decorative circle
                          Positioned(
                            right: -30,
                            top: -30,
                            child: CircleAvatar(
                              radius: 80,
                              backgroundColor: Colors.white.withValues(alpha: 0.07),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.xs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                                      ),
                                      child: Text(
                                        widget.voucher.voucherType.replaceAll('_', ' '),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: AppSpacing.xs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isAvailable
                                            ? Colors.white.withValues(alpha: 0.25)
                                            : Colors.black.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                                      ),
                                      child: Text(
                                        widget.voucher.status,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Text(
                                  discountLabel,
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  widget.voucher.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  widget.voucher.description,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 2. Voucher Code Copy Section
                    Text(
                      'VOUCHER CODE',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: GestureDetector(
                        onTap: _copyCode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.15),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.voucher.code,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.primary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    _isCopied ? 'COPIED' : 'COPY',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: _isCopied ? AppColors.success : theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Icon(
                                    _isCopied ? Icons.check_circle_rounded : Icons.copy_rounded,
                                    size: 16,
                                    color: _isCopied ? AppColors.success : theme.colorScheme.primary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 3. Terms and Conditions Title
                    Text(
                      'TERMS & CONDITIONS',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    
                    // 4. HTML Terms list using Custom SimpleHtmlRenderer
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: widget.voucher.termsAndConditionsHtml.isNotEmpty
                          ? SimpleHtmlRenderer(html: widget.voucher.termsAndConditionsHtml)
                          : Text(
                              widget.voucher.termsAndConditionsText.isNotEmpty
                                  ? widget.voucher.termsAndConditionsText
                                  : 'No specific terms and conditions apply.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                height: 1.4,
                              ),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Simple HTML Renderer Widget ──────────────────────────────────────────────

class SimpleHtmlRenderer extends StatelessWidget {
  final String html;
  final TextStyle? style;

  const SimpleHtmlRenderer({super.key, required this.html, this.style});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = style ?? theme.textTheme.bodyMedium?.copyWith(
      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
      height: 1.4,
    );

    // Basic cleaning: Strip <ul> and </ul>
    var cleanedHtml = html.replaceAll('<ul>', '').replaceAll('</ul>', '');
    
    // Split by <li> tags
    final blocks = cleanedHtml.split(RegExp(r'<(p|li)>'));
    
    final List<Widget> children = [];
    
    for (var block in blocks) {
      // Clean up closing tags </p>, </li>, and br tags
      var content = block
          .replaceAll('</p>', '')
          .replaceAll('</li>', '')
          .replaceAll('<br>', '\n')
          .replaceAll('<br/>', '\n')
          .replaceAll('<br />', '\n')
          .trim();
          
      if (content.isEmpty) continue;
      
      final isBullet = block.contains('</li>') || html.contains('<li>');
      
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isBullet) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, right: AppSpacing.sm),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
              Expanded(
                child: RichText(
                  text: _parseInlineHtml(content, textStyle),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    if (children.isEmpty && html.isNotEmpty) {
      // Fallback if no <li> tags found
      return RichText(
        text: _parseInlineHtml(html, textStyle),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  TextSpan _parseInlineHtml(String text, TextStyle? baseStyle) {
    final List<InlineSpan> spans = [];
    // Parses simple tags: <b>, <strong>, <i>, <em>
    final regExp = RegExp(r'<(b|strong|i|em)>(.*?)</\1>|([^<]+)');
    final matches = regExp.allMatches(text);
    
    for (final match in matches) {
      if (match.group(3) != null) {
        // Plain text
        spans.add(TextSpan(text: match.group(3)));
      } else {
        // Styled text
        final tag = match.group(1);
        final innerText = match.group(2) ?? '';
        final isBold = tag == 'b' || tag == 'strong';
        final isItalic = tag == 'i' || tag == 'em';
        
        spans.add(
          TextSpan(
            text: innerText,
            style: baseStyle?.copyWith(
              fontWeight: isBold ? FontWeight.w900 : null,
              fontStyle: isItalic ? FontStyle.italic : null,
            ),
          ),
        );
      }
    }
    
    return TextSpan(children: spans, style: baseStyle);
  }
}
