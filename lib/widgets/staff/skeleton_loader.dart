import 'package:flutter/material.dart';
import '../../theme.dart';

class SkeletonAppLoader extends StatefulWidget {
  final bool isMainApp;
  
  const SkeletonAppLoader({super.key, this.isMainApp = false});

  @override
  State<SkeletonAppLoader> createState() => _SkeletonAppLoaderState();
}

class _SkeletonAppLoaderState extends State<SkeletonAppLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildShimmer(double width, double height, {double borderRadius = 8.0}) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: const [0.0, 0.5, 1.0],
              colors: [
                const Color(0xFFE2E8F0),
                const Color(0xFFF1F5F9),
                const Color(0xFFE2E8F0),
              ],
              transform: _SlidingGradientTransform(slidePercent: _animation.value),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFC), Color(0xFFEEF2FF)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Header Skeletons (App Bar area)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildShimmer(40, 40, borderRadius: 20),
                      const SizedBox(width: 12),
                      _buildShimmer(150, 24, borderRadius: 8),
                    ],
                  ),
                  _buildShimmer(40, 40, borderRadius: 20),
                ],
              ),
              const SizedBox(height: 24),
              
              if (widget.isMainApp) ...[
                // Main App Layout (Tabs + List)
                // Tabs Skeleton
                _buildShimmer(double.infinity, 50, borderRadius: 16),
                const SizedBox(height: 24),
                
                // Content Title Skeleton
                Align(
                  alignment: Alignment.centerLeft,
                  child: _buildShimmer(200, 24, borderRadius: 8),
                ),
                const SizedBox(height: 16),
                
                // List Items Skeleton
                Expanded(
                  child: ListView.separated(
                    itemCount: 6,
                    separatorBuilder: (c, i) => const SizedBox(height: 12),
                    itemBuilder: (c, i) => GlassCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 12,
                      child: Row(
                        children: [
                          _buildShimmer(50, 50, borderRadius: 25),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildShimmer(double.infinity, 16),
                                const SizedBox(height: 8),
                                _buildShimmer(100, 12),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          _buildShimmer(60, 30, borderRadius: 15),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Vehicle Selector Layout (Grid)
                const SizedBox(height: 24),
                _buildShimmer(250, 40, borderRadius: 12),
                const SizedBox(height: 16),
                _buildShimmer(300, 16),
                const SizedBox(height: 48),

                Expanded(
                  child: GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
                    mainAxisSpacing: 24,
                    crossAxisSpacing: 24,
                    childAspectRatio: 3.5,
                    children: List.generate(4, (index) {
                      return GlassCard(
                        padding: const EdgeInsets.all(24),
                        borderRadius: 24,
                        child: Row(
                          children: [
                            _buildShimmer(60, 60, borderRadius: 12),
                            const SizedBox(width: 20),
                            Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildShimmer(double.infinity, 14),
                                    const SizedBox(height: 6),
                                    _buildShimmer(120, 10),
                                  ],
                                ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),

                // Footer Buttons Skeletons
                const SizedBox(height: 24),
                _buildShimmer(200, 45, borderRadius: 20),
                const SizedBox(height: 16),
                _buildShimmer(160, 45, borderRadius: 20),
                const SizedBox(height: 16),
                _buildShimmer(180, 45, borderRadius: 20),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}
