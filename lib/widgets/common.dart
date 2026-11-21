import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 白底圆角卡片，带柔和投影
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: softShadow(),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// 渐变主视觉卡（首页信号区）
class GradientCard extends StatelessWidget {
  const GradientCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.circular(AppRadius.sheet),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 小节标题：左侧短竖条 + 标题 + 可选右侧操作
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 15,
            decoration: BoxDecoration(
              gradient: AppColors.gradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8),
            Text(subtitle!,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 指标块：label + 大数值 + 单位
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.unit = '',
    this.color = AppColors.textPrimary,
    this.onDark = false,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        onDark ? Colors.white.withOpacity(0.72) : AppColors.textMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11.5,
                color: labelColor,
                letterSpacing: 0.3)),
        const SizedBox(height: 5),
        RichText(
          text: TextSpan(children: [
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.05,
              ),
            ),
            if (unit.isNotEmpty)
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: onDark
                      ? Colors.white.withOpacity(0.7)
                      : AppColors.textMuted,
                ),
              ),
          ]),
        ),
      ],
    );
  }
}

/// 状态胶囊
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.text,
    this.color = AppColors.primary,
    this.bg,
    this.icon,
  });

  final String text;
  final Color color;
  final Color? bg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg ?? color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

/// 信息行：左标签右值
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor = AppColors.textSecondary,
    this.mono = false,
    this.onDark = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool mono;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    color: onDark
                        ? Colors.white.withOpacity(0.72)
                        : AppColors.textMuted)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '--' : value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: onDark ? Colors.white : valueColor,
                fontFeatures: mono
                    ? const [FontFeature.tabularFigures()]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 信号强度：5 格电平条
class SignalBars extends StatelessWidget {
  const SignalBars({
    super.key,
    required this.level,
    this.color = Colors.white,
    this.height = 22,
  });

  /// 0..5
  final int level;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (i) {
        final active = i < level;
        final h = height * (0.34 + i * 0.165);
        return Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Container(
            width: 5,
            height: h,
            decoration: BoxDecoration(
              color: active ? color : color.withOpacity(0.22),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

/// 自绘信号环：渐变弧 + 中心数值
class SignalRing extends StatelessWidget {
  const SignalRing({
    super.key,
    required this.progress,
    required this.center,
    this.subLabel,
    this.size = 132,
    this.colors = const [Color(0xFF3EDC86), Color(0xFF3B82F6)],
    this.trackColor,
  });

  /// 0..1
  final double progress;
  final String center;
  final String? subLabel;
  final double size;
  final List<Color> colors;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress,
          colors: colors,
          track: trackColor ?? Colors.white.withOpacity(0.22),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(center,
                  style: const TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.0)),
              if (subLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(subLabel!,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.78))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.colors,
    required this.track,
  });

  final double progress;
  final List<Color> colors;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, math.pi * 0.75, math.pi * 1.5, false, trackPaint);

    if (progress <= 0) return;
    final value = progress.clamp(0.0, 1.0);
    final sweep = math.pi * 1.5 * value;
    final shader = SweepGradient(
      startAngle: math.pi * 0.75,
      endAngle: math.pi * 0.75 + math.pi * 1.5,
      colors: colors,
    ).createShader(rect);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = shader;

    // 用自绘 path 保证圆头与渐变方向正确
    canvas.save();
    final path = Path()
      ..addArc(rect, math.pi * 0.75, sweep);
    canvas.drawPath(path, arcPaint);
    final tip = Offset(
      rect.center.dx + rect.width / 2 * math.cos(math.pi * 0.75 + sweep),
      rect.center.dy + rect.height / 2 * math.sin(math.pi * 0.75 + sweep),
    );
    canvas.drawCircle(
      tip,
      stroke / 2,
      Paint()..color = colors.last,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.colors != colors;
}

/// 底部导航图标
class NavItem {
  const NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}
