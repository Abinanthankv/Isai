import 'package:flutter/material.dart';

class InteractiveControls extends StatefulWidget {
  final bool isM3;
  final bool playing;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;
  final ColorScheme colorScheme;

  const InteractiveControls({
    super.key,
    required this.isM3,
    required this.playing,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
    required this.colorScheme,
  });

  @override
  State<InteractiveControls> createState() => _InteractiveControlsState();
}

class _InteractiveControlsState extends State<InteractiveControls> with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _prevOffsetAnim;
  late final Animation<double> _nextOffsetAnim;
  late final Animation<double> _centerScaleAnim;
  late final Animation<double> _outerScaleAnim;

  bool _isCenterPressed = false;

  @override
  void initState() {
    super.initState();
    // 350ms duration for a springy, rubbery look
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // Bouncing curves using ElasticOut/ElasticIn for natural bounce back
    final Curve forwardCurve = Curves.easeOutCubic;
    final Curve reverseCurve = const ElasticOutCurve(0.6);

    final CurvedAnimation curvedAnimation = CurvedAnimation(
      parent: _animController,
      curve: forwardCurve,
      reverseCurve: reverseCurve,
    );

    // How much the previous/next buttons move towards the play/pause button (e.g. 24px)
    _prevOffsetAnim = Tween<double>(begin: 0.0, end: 24.0).animate(curvedAnimation);
    _nextOffsetAnim = Tween<double>(begin: 0.0, end: -24.0).animate(curvedAnimation);
    
    // Scale down the play button slightly during the squeeze/pull state
    _centerScaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(curvedAnimation);
    
    // Scale down previous/next buttons slightly when sucked in
    _outerScaleAnim = Tween<double>(begin: 1.0, end: 0.9).animate(curvedAnimation);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onPressDown() {
    setState(() => _isCenterPressed = true);
    _animController.forward();
  }

  void _onPressUp() {
    setState(() => _isCenterPressed = false);
    _animController.reverse();
    widget.onPlayPause();
  }

  void _onPressCancel() {
    setState(() => _isCenterPressed = false);
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isM3) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Previous Button
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_prevOffsetAnim.value, 0),
                child: Transform.scale(
                  scale: _outerScaleAnim.value,
                  child: child,
                ),
              );
            },
            child: InteractiveControlItem(
              onTap: widget.onPrevious,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.skip_previous_rounded, size: 32, color: widget.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          
          // Play/Pause Button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _onPressDown(),
            onTapUp: (_) => _onPressUp(),
            onTapCancel: () => _onPressCancel(),
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _centerScaleAnim.value,
                  child: child,
                );
              },
              child: Container(
                width: 140,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  color: widget.colorScheme.primary,
                  boxShadow: [
                    BoxShadow(
                      color: widget.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      widget.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 32,
                      color: widget.colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.playing ? "PAUSE" : "PLAY",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: widget.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Next Button
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_nextOffsetAnim.value, 0),
                child: Transform.scale(
                  scale: _outerScaleAnim.value,
                  child: child,
                ),
              );
            },
            child: InteractiveControlItem(
              onTap: widget.onNext,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.skip_next_rounded, size: 32, color: widget.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      );
    }

    // Default/Apple style
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Previous Button
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_prevOffsetAnim.value, 0),
              child: Transform.scale(
                scale: _outerScaleAnim.value,
                child: child,
              ),
            );
          },
          child: InteractiveControlItem(
            onTap: widget.onPrevious,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
            ),
          ),
        ),

        // Play/Pause Button
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _onPressDown(),
          onTapUp: (_) => _onPressUp(),
          onTapCancel: () => _onPressCancel(),
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Transform.scale(
                scale: _centerScaleAnim.value,
                child: child,
              );
            },
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                widget.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 40,
                color: Colors.black,
              ),
            ),
          ),
        ),

        // Next Button
        AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_nextOffsetAnim.value, 0),
              child: Transform.scale(
                scale: _outerScaleAnim.value,
                child: child,
              ),
            );
          },
          child: InteractiveControlItem(
            onTap: widget.onNext,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
            ),
          ),
        ),
      ],
    );
  }
}

class InteractiveControlItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const InteractiveControlItem({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<InteractiveControlItem> createState() => _InteractiveControlItemState();
}

class _InteractiveControlItemState extends State<InteractiveControlItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
