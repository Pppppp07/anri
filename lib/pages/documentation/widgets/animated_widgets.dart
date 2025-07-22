import 'package:flutter/material.dart';

/// Sebuah ListView yang menganimasikan turun setiap child-nya secara berurutan.
class StaggeredListView extends StatefulWidget {
  final List<Widget> children;
  const StaggeredListView({super.key, required this.children});

  @override
  State<StaggeredListView> createState() => _StaggeredListViewState();
}

class _StaggeredListViewState extends State<StaggeredListView> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.children.length,
      itemBuilder: (context, index) {
        return _StaggeredListItem(
          index: index,
          child: widget.children[index],
        );
      },
    );
  }
}

class _StaggeredListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _StaggeredListItem({required this.index, required this.child});

  @override
  State<_StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<_StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(curve);

    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: _animation.drive(
          Tween<Offset>(
            begin: const Offset(0, 0.1),
            end: Offset.zero,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

// --- WIDGET ANIMASI BARU DITAMBAHKAN DI SINI ---

/// Menganimasikan anak-anaknya dengan efek fade dan slide secara berurutan.
/// Digunakan untuk konten di dalam ExpansionTile.
class AnimatedChildren extends StatelessWidget {
  final List<Widget> children;
  const AnimatedChildren({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        children.length,
        (index) => _FadeInAndSlideUp(
          delay: Duration(milliseconds: 100 * index),
          child: children[index],
        ),
      ),
    );
  }
}

/// Widget helper yang memberikan efek fade dan slide-up pada satu child.
class _FadeInAndSlideUp extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;

  const _FadeInAndSlideUp({
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.delay = const Duration(milliseconds: 0),
  });

  @override
  State<_FadeInAndSlideUp> createState() => _FadeInAndSlideUpState();
}

class _FadeInAndSlideUpState extends State<_FadeInAndSlideUp>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}