///
/// lib/wind_particles.dart
/// widget to paint windsimulation / windparticles on the screen
/// Assign to a variable and include the variable in your tree
///
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:szwtracktrace/default_maptileproviders.dart';

//ignore: must_be_immutable
class WindParticles extends StatefulWidget {
  WindParticles({super.key, this.density = 6000, this.direction = 0, this.speed = 0});

  /// the number of windparticles on the screen as: width * heigth / density i.e. the larger the less particles
  int density;

  /// heading in degrees
  int direction;

  /// speed in beaufort
  int speed;

  @override
  WindParticlesState createState() => WindParticlesState();
}

class WindParticlesState extends State<WindParticles> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  List<Particle> _particles = [];
  double _oldScreenSize = 0;
  double _dir = 0;
  int _sp = 0;
  late Ticker _windTicker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // needed to get the MediaQuery for screen size working
    _windTicker = createTicker(onTick);
    _windTicker.start();
  }

  ///
  /// call pause and resume to temporarily stop moving the particles, for example when the app goes to the background
  /// 1. create the widget with a key:
  ///   WindParticles windParticleWidget = WindParticles(key: wpKey);
  /// 2. insert the widget in the tree, for example as a child of flutter_map)
  /// 3. then use the key to get the currentstate
  ///   dynamic wpState = wpKey.currentState;
  /// 4. call pause/resume as a method of this state  dynamic state = wpKey.currentState;
  ///   wpState?.pause();    or    state?.resume();     // note ?. as wpState may be null
  ///
  void pause() {
    if (_windTicker.isTicking) _windTicker.stop();
  }

  void resume() {
    if (!_windTicker.isTicking) _windTicker.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _windTicker.dispose();
    super.dispose();
  }

  @override
  CustomPaint build(BuildContext context) {
    return CustomPaint(
      painter: WindParticlesPainter(_particles),
    );
  }

  void onTick(Duration elapsed) {
    _dir = (((widget.direction + 90 + 720) % 360) * pi / 180);
    _sp = widget.speed;
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
      // and update all particles using data prepared by the rotateWindTo(time) routine in main_common
      setState(() {
        for (var particle in _particles) {
          particle.update(_dir, _sp);
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

class Particle {
  late double x, y;
  List<Offset> trail = [];
  Random random = Random();
  double width;
  double height;

  Particle({this.width = 0, this.height = 0}) {
    x = random.nextDouble() * width;
    y = random.nextDouble() * height;
  }

  void update(direction, speed) {
    x += speed * cos(direction) / 2; // 2 is a dempening factor
    y += speed * sin(direction) / 2;
    trail.add(Offset(x, y));
    if (trail.length > 15) {
      trail.removeAt(0);
    }
    // first remove the trail if we are outside of the screen
    if (x < 0 || x > width || y < 0 || y > height) trail = [];
    // then wrap around the screen edges with random reappearance at the other side of the screen
    if (x < 0) {
      x = width;
      y = random.nextDouble() * height;
    }
    if (x > width) {
      x = 0;
      y = random.nextDouble() * height;
    }
    if (y < 0) {
      y = height;
      x = random.nextDouble() * width;
    }
    if (y > height) {
      y = 0;
      x = random.nextDouble() * width;
    }
  }
}

class WindParticlesPainter extends CustomPainter {
  List<Particle> particles;

  WindParticlesPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var particle in particles) {
      for (int i = 0; i < particle.trail.length; i++) {
        paint.color = markerBackgroundColor.withOpacity(((i + 1) / particle.trail.length) / 2.5);
        canvas.drawCircle(particle.trail[i], 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(WindParticlesPainter oldDelegate) => true;
}
