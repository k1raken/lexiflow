import 'package:flutter/material.dart';

/// Skeleton loader widget for loading states
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((e) => e.clamp(0.0, 1.0)).toList(),
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton loader for word cards
class WordCardSkeleton extends StatelessWidget {
  const WordCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonLoader(
                width: 40,
                height: 40,
                borderRadius: BorderRadius.circular(20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonLoader(
                      width: double.infinity,
                      height: 20,
                    ),
                    const SizedBox(height: 8),
                    const SkeletonLoader(
                      width: 150,
                      height: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonLoader(
            width: double.infinity,
            height: 14,
          ),
          const SizedBox(height: 8),
          const SkeletonLoader(
            width: 200,
            height: 14,
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for dashboard
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Header skeleton
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SkeletonLoader(
                      width: 120,
                      height: 32,
                    ),
                    Row(
                      children: [
                        SkeletonLoader(
                          width: 60,
                          height: 40,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        const SizedBox(width: 8),
                        SkeletonLoader(
                          width: 40,
                          height: 40,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const SkeletonLoader(
                  width: 200,
                  height: 28,
                ),
                const SizedBox(height: 8),
                const SkeletonLoader(
                  width: 150,
                  height: 20,
                ),
                const SizedBox(height: 24),
                SkeletonLoader(
                  width: double.infinity,
                  height: 80,
                  borderRadius: BorderRadius.circular(16),
                ),
              ],
            ),
          ),
        ),
        // Word cards skeleton
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => const WordCardSkeleton(),
              childCount: 5,
            ),
          ),
        ),
      ],
    );
  }
}
