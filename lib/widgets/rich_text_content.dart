import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Reusable rich text widget with markdown support and "Read more" functionality
///
/// Supports markdown/RTF subset (bold, italic, bulleted lists, hyperlinks)
/// with premium typography styles. Includes animated collapse/expand for
/// long content with scroll anchor preservation.
class RichTextContent extends StatefulWidget {
  /// The markdown text content to render
  final String? text;

  /// Maximum height in logical pixels before collapsing (default: ~6 lines)
  final double maxCollapsedHeight;

  /// Text style for the content (defaults to bodyLarge from theme)
  final TextStyle? textStyle;

  /// Color for the "Read more"/"Read less" link
  final Color? linkColor;

  const RichTextContent({
    super.key,
    required this.text,
    this.maxCollapsedHeight = 220.0,
    this.textStyle,
    this.linkColor,
  });

  @override
  State<RichTextContent> createState() => _RichTextContentState();
}

class _RichTextContentState extends State<RichTextContent> {
  bool _isExpanded = false;
  bool _needsCollapse = false;
  final GlobalKey _contentKey = GlobalKey();
  double? _fullHeight;

  @override
  void initState() {
    super.initState();
    // Measure content after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureContent());
  }

  void _measureContent() {
    if (!mounted || _contentKey.currentContext == null) return;

    final RenderBox? renderBox =
        _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final height = renderBox.size.height;
      if (_fullHeight == null || _fullHeight != height) {
        setState(() {
          _fullHeight = height;
          _needsCollapse = height > widget.maxCollapsedHeight;
        });
      }
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = widget.textStyle ??
        theme.textTheme.bodyLarge?.copyWith(
          height: 1.6, // Premium line height for readability
        );
    final linkColor = widget.linkColor ?? theme.colorScheme.primary;

    // Handle empty or null text
    if (widget.text == null || widget.text!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Always measure the content first (without height constraint)
    final measuredContent = _MeasureWidget(
      key: _contentKey,
      onMeasure: _measureContent,
      child: _buildMarkdownContent(context, textStyle, linkColor),
    );

    // If we haven't measured yet or don't need collapse, show full content
    if (_fullHeight == null || !_needsCollapse) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          measuredContent,
        ],
      );
    }

    // Render with collapse/expand functionality
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _isExpanded
              ? _buildMarkdownContent(context, textStyle, linkColor)
              : SizedBox(
                  height: widget.maxCollapsedHeight,
                  child: ClipRect(
                    clipBehavior: Clip.hardEdge,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child:
                          _buildMarkdownContent(context, textStyle, linkColor),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _toggleExpanded,
          child: Text(
            _isExpanded ? 'Read less' : 'Read more',
            style: textStyle?.copyWith(
              color: linkColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMarkdownContent(
    BuildContext context,
    TextStyle? baseStyle,
    Color linkColor,
  ) {
    final theme = Theme.of(context);

    return MarkdownBody(
      data: widget.text!,
      styleSheet: MarkdownStyleSheet(
        // Base paragraph style
        p: baseStyle,
        // Heading styles (if markdown contains headers)
        h1: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
        h2: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
        h3: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        // List styles
        listBullet: baseStyle?.copyWith(
          color: theme.colorScheme.primary,
        ),
        // Strong/bold text
        strong: baseStyle?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        // Emphasis/italic text
        em: baseStyle?.copyWith(
          fontStyle: FontStyle.italic,
        ),
        // Link styles
        a: baseStyle?.copyWith(
          color: linkColor,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
        ),
        // Code styles
        code: baseStyle?.copyWith(
          backgroundColor: theme.colorScheme.surfaceVariant,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(4),
        ),
        // Blockquote styles
        blockquote: baseStyle?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.primary,
              width: 4,
            ),
          ),
        ),
        // Horizontal rule
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        // Spacing
        blockSpacing: 16,
        listIndent: 24,
        textScaleFactor: 1.0, // Respect system text scaling via baseStyle
      ),
      selectable: false,
      shrinkWrap: true,
      softLineBreak: true,
    );
  }
}

/// Widget that measures its child and calls onMeasure callback
class _MeasureWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onMeasure;

  const _MeasureWidget({
    super.key,
    required this.child,
    required this.onMeasure,
  });

  @override
  State<_MeasureWidget> createState() => _MeasureWidgetState();
}

class _MeasureWidgetState extends State<_MeasureWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onMeasure());
  }

  @override
  void didUpdateWidget(_MeasureWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onMeasure());
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
