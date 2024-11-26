// lib/wind_particles.dart

import 'package:flutter/material.dart';
import 'package:szwtracktrace/default_maptileproviders.dart';
import 'dart:math';

import 'package:szwtracktrace/main_common.dart';

class WindParticles extends StatefulWidget {
  const WindParticles({super.key});

  @override
  WindParticlesState createState() => WindParticlesState();
}

class WindParticlesState extends State<WindParticles> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  List<Particle> particles = [];
  double oldScreenSize = 0;

  @override
  void initState() {
    super.initState();
    windTicker = createTicker(onTick);
    windTicker.start();
  }

  @override
  void dispose() {
    windTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: WindParticlesPainter(particles),
    );
  }

  void onTick(Duration elapsed) {
    var screenSize = screenHeight * screenWidth;
    if (showWindMarkers && oldScreenSize == screenSize) {
      if (particles.isEmpty) {
        // just create a number of wind particles, the number is based on the screensize
        for (int i = 0; i < (screenSize) ~/ 6000; i++) {
          particles.add(Particle());
        }
      }
      // and update all particles using data prepared by the rotateWindTo(time) routine in main_common
      setState(() {
        for (var particle in particles) {
          particle.update(particleWindDirection, particleWindSpeed);
        }
      });
    } else {
      // no need to show anything, clear-out all particles
      particles = [];
      oldScreenSize = screenHeight * screenWidth;
      setState(() {});
    }
  }
}

class Particle {
  late double x, y;
  List<Offset> trail = [];
  Random random = Random();

  Particle() {
    x = random.nextDouble() * screenWidth;
    y = random.nextDouble() * screenHeight;
  }

  void update(windDirection, windSpeed) {
    x += windSpeed * cos(windDirection) / 2; // 2 is a dempening factor
    y += windSpeed * sin(windDirection) / 2;
    trail.add(Offset(x, y));
    if (trail.length > 15) {
      trail.removeAt(0);
    }
    // Wrap around the screen edges with random reappearance at the other side of the screen
    // first remove the trail if we are outside of the screen
    if (x < 0 || x > screenWidth || y < 0 || y > screenHeight) trail = [];
    if (x < 0) {
      x = screenWidth;
      y = random.nextDouble() * screenHeight;
    }
    if (x > screenWidth) {
      x = 0;
      y = random.nextDouble() * screenHeight;
    }
    if (y < 0) {
      y = screenHeight;
      x = random.nextDouble() * screenWidth;
    }
    if (y > screenHeight) {
      y = 0;
      x = random.nextDouble() * screenWidth;
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
