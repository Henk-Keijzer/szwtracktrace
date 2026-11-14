//
// lib/widgets/wind_particles.dart
// widget to paint wind simulation / wind particles on the screen
// Assign to a variable and include the variable in your tree
//

import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';

class WindParticles extends StatefulWidget {
  const WindParticles(
      {super.key,
      this.density = 6000,
      this.trailLength = 15,
      this.direction = 0,
      this.speed = 3.0,
      this.animate = true,
      this.color = Colors.black54});

  /// the number of wind particles on the screen as: screen width * screen height / density i.e. the larger the less particles
  final int density;

  /// the length of the particle trail
  final int trailLength;

  /// heading in degrees (0-359)
  final int direction;

  /// speed
  final double speed;

  /// should wind particles move yes or no
  final bool animate;

  /// color of the wind particles
  final Color color;

  @override
  WindParticlesState createState() => WindParticlesState();
}

class WindParticlesState extends State<WindParticles> with SingleTickerProviderStateMixin {
  List<Particle> _particles = [];
  double _oldScreenSize = 0;
  double _screenWidth = 0;
  double _screenHeight = 0;
  late Ticker _windTicker;
  int _cntr = 1; // speed reduction counter (skips windTicker ticks)

  @override
  void initState() {
    // called once when the widget is inserted in the tree
    super.initState();
    _windTicker = createTicker(onTick);
    _windTicker.start();
  }

  @override
  void dispose() {
    _windTicker.dispose();
    super.dispose();
  }

  void onTick(Duration _) {
    if (widget.animate && _cntr-- <= 0) {
      _cntr = 3; // update only every third frame (i.e. at 20 frames / second, is fast enough)
      double dirRad = widget.direction * pi / 180; // direction in radians
      var screenSize = _screenWidth * _screenHeight;
      if (_oldScreenSize == screenSize) {
        if (_particles.isEmpty) {
          // just create a number of wind particles, the number is based on the screen size
          for (int i = 0; i < (screenSize ~/ widget.density); i++) {
            _particles.add(Particle(width: _screenWidth, height: _screenHeight, trailLength: widget.trailLength));
          }
        }
        // and update all particles using direction and speed set in the widget
        setState(() {
          for (var particle in _particles) {
            particle.update(dirRad, widget.speed, widget.trailLength);
          }
        });
      } else {
        // no need to show anything, clear-out all particles, they will be redrawn next cycle
        _particles = [];
        _oldScreenSize = screenSize;
        setState(() {});
      }
    }
  }

  @override
  LayoutBuilder build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
      _screenWidth = constraints.maxWidth;
      _screenHeight = constraints.maxHeight;
      return CustomPaint(
        painter: WindParticlesPainter(_particles, widget.color),
      );
    });
  }
}

class Particle {
  // creates the data for a single particle and a method for updating it
  Particle({this.width = 0, this.height = 0, this.trailLength = 15}) {
    // width and height are the screen width and height. The constructor places the particle initially at a random position on the screen.
    x = random.nextDouble() * width;
    y = random.nextDouble() * height;
  }

  final int trailLength;
  final double width;
  final double height;
  List<Offset> trail = [];
  late double x, y;
  Random random = Random();

  void update(double direction, speed, trailLength) {
    x += speed * -sin(direction);
    y += speed * cos(direction);
    trail.add(Offset(x, y));
    if (trail.length > trailLength) {
      trail.removeAt(0);
    }
    // First remove the trail if we are outside of the screen
    if (x < 0 || x > width || y < 0 || y > height) {
      trail = [];
    }
    // than wrap around the screen edges with random reappearance at the other side of the screen
    if (x < 0 || x > width) {
      x = (x < 0) ? width : 0;
      y = random.nextDouble() * height;
    } else if (y < 0 || y > height) {
      y = (y < 0) ? height : 0;
      x = random.nextDouble() * width;
    }
  }
}

class WindParticlesPainter extends CustomPainter {
  final List<Particle> particles;
  final Color color;

  WindParticlesPainter(this.particles, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final intensity = color.a; // this is the intensity of the tip of the trail
    final paint = Paint();
    for (var particle in particles) {
      for (int i = 0; i < particle.trail.length; i++) {
        paint.color = color.withValues(alpha: ((i + 1) / particle.trail.length) * intensity); // factor defines color intensity, 1 = max
        canvas.drawCircle(particle.trail[i], 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(WindParticlesPainter oldDelegate) => true;
}
