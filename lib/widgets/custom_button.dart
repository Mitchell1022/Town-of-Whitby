import 'package:flutter/material.dart';

enum ButtonVariant { primary, secondary, outline, danger }
enum ButtonSize { small, medium, large }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool isLoading;
  final bool fullWidth;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color backgroundColor;
    Color foregroundColor;
    double elevation;
    BorderSide? borderSide;

    switch (variant) {
      case ButtonVariant.primary:
        backgroundColor = const Color(0xFF003366);
        foregroundColor = Colors.white;
        elevation = 2;
        borderSide = null;
        break;
      case ButtonVariant.secondary:
        backgroundColor = colorScheme.secondary;
        foregroundColor = Colors.white;
        elevation = 1;
        borderSide = null;
        break;
      case ButtonVariant.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = const Color(0xFF003366);
        elevation = 0;
        borderSide = const BorderSide(color: Color(0xFF003366));
        break;
      case ButtonVariant.danger:
        backgroundColor = Colors.red[600]!;
        foregroundColor = Colors.white;
        elevation = 2;
        borderSide = null;
        break;
    }

    double height;
    double fontSize;
    EdgeInsets padding;

    switch (size) {
      case ButtonSize.small:
        height = 36;
        fontSize = 14;
        padding = const EdgeInsets.symmetric(horizontal: 16);
        break;
      case ButtonSize.medium:
        height = 48;
        fontSize = 16;
        padding = const EdgeInsets.symmetric(horizontal: 24);
        break;
      case ButtonSize.large:
        height = 56;
        fontSize = 18;
        padding = const EdgeInsets.symmetric(horizontal: 32);
        break;
    }

    Widget buttonChild;
    if (isLoading) {
      buttonChild = SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    } else if (icon != null) {
      buttonChild = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 2),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } else {
      buttonChild = Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: elevation,
          shadowColor: backgroundColor.withOpacity(0.3),
          side: borderSide,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: buttonChild,
      ),
    );
  }
}