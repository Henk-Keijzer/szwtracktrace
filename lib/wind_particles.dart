///
/// lib/wind_particles.dart
/// widget to paint windsimulation / windparticles on the screen
/// Assign to a variable and include the variable in your tree
///
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class WindParticles extends StatefulWidget {
  const WindParticles({super.key, this.density = 6000, this.direction = 0, this.speed = 0, this.animate = true, this.color = Colors.black});

  /// the number of windparticles on the screen as: width * heigth / density i.e. the larger the less particles
  final int density;

  /// heading in degrees (0-359)
  final int direction;

  /// speed in beaufort
  final int speed;

  /// should windparticles move yes or no
  final bool animate;

  /// color of the windparticles
  final Color color;

  @override
  WindParticlesState createState() => WindParticlesState();
}

class WindParticlesState extends State<WindParticles> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  List<Particle> _particles = [];
  Color _color = Colors.black;
  double _oldScreenSize = 0;
  double _dirRad = 0;
  int _sp = 0;
  late Ticker _windTicker;
  int _cntr = 1; // speedreduction counter (skips windTicker ticks)

  @override
  void initState() {
    // called once when the widget is inserted in the tree
    super.initState();
    WidgetsBinding.instance.addObserver(this); // needed to get the MediaQuery for screen size working
    _windTicker = createTicker(onTick);
    _windTicker.start();
  }

  @override
  void dispose() {
    // called when the widget is removed from the tree
    WidgetsBinding.instance.removeObserver(this);
    _windTicker.dispose();
    super.dispose();
  }

  void onTick(_) {
    if (widget.animate) {
      if (_cntr-- <= 0) {
        _cntr = 2; // update every second frame
        _dirRad = widget.direction * pi / 180;
        _sp = widget.speed;
        _color = widget.color;
        var screenWidth = MediaQuery.of(context).size.width;
        var screenHeight = MediaQuery.of(context).size.height;
        var screenSize = screenWidth * screenHeight;
        if (_oldScreenSize == screenSize) {
          if (_particles.isEmpty) {
            // just create a number of wind particles, the number is based on the screensize
            for (int i = 0; i < (screenSize ~/ widget.density); i++) {
              _particles.add(Particle(width: screenWidth, height: screenHeight));
            }
          }
          // and update all particles using direction and speed set in the widget
          setState(() {
            for (var particle in _particles) {
              particle.update(_dirRad, _sp);
            }
          });
        } else {
          // no need to show anything, clear-out all particles
          _particles = [];
          _oldScreenSize = screenSize;
          setState(() {});
        }
      }
    }
  }

  @override
  CustomPaint build(BuildContext context) {
    // called each time setState is called in the onTick function
    return CustomPaint(
      painter: WindParticlesPainter(_particles, _color),
    );
  }
}

class Particle {
  // creates the data for a single particle and a method for updating it
  Particle({this.width = 0, this.height = 0}) {
    // width and hight are the screen width and height. The constructor places the particle
    // initially at a random position on the screen.
    x = random.nextDouble() * width;
    y = random.nextDouble() * height;
  }

  late double x, y;
  List<Offset> trail = [];
  Random random = Random();
  double width;
  double height;

  void update(direction, speed) {
    // direction in radians, speed in Beaufort from 0 to 16
    x += speed * -sin(direction) / 2; // 2 is a dempening factor
    y += speed * cos(direction) / 2;
    trail.add(Offset(x, y));
    if (trail.length > 15) {
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
  List<Particle> particles;
  Color color;

  WindParticlesPainter(this.particles, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var particle in particles) {
      for (int i = 0; i < particle.trail.length; i++) {
        paint.color = color.withValues(alpha: ((i + 1) / particle.trail.length) / 2.5);
        canvas.drawCircle(particle.trail[i], 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(WindParticlesPainter oldDelegate) => true;
}
