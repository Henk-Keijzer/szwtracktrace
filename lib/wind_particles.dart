// lib/wind_particles.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:szwtracktrace/default_maptileproviders.dart';
import 'dart:math';

import 'package:szwtracktrace/main_common.dart';

class WindParticles extends StatefulWidget {
  const WindParticles({super.key});

  @override
  WindParticlesState createState() => WindParticlesState();
}

class WindParticlesState extends State<WindParticles> with SingleTickerProviderStateMixin {
  late Ticker ticker;
  List<Particle> particles = [];
  Random random = Random();
  double windDirection = 0;
  double windSpeed = 0;

  @override
  void initState() {
    super.initState();
    ticker = createTicker(onTick)..start();
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: WindParticlesPainter(particles),
      child: Container(),
    );
  }

  void onTick(Duration elapsed) {
    if (showWindMarkers) {
      if (particles.isEmpty) {
        // just create a number of wind particles
        for (int i = 0; i < (screenHeight * screenWidth) ~/ 6000; i++) {
          particles.add(Particle(random)); // create a particle at a random location on the screen
        }
      }
      // get current winddirection and speed from main program
      windDirection = ((centerWindData.heading + 720 + 90) % 360) * pi / 180;
      windSpeed = centerWindData.speed;
      // and update all particles
      setState(() {
        for (var particle in particles) {
          particle.update(windDirection, windSpeed);
        }
      });
    } else {
      // no need to show anything, clear-out all particles
      particles = [];
    }
  }
}

class Particle {
  late double x, y;
  List<Offset> trail = [];
  Random random;
  int updateCounter = 0;

  Particle(this.random) {
    x = random.nextDouble() * screenWidth;
    y = random.nextDouble() * screenHeight;
  }

  void update(windDirection, windSpeed) {
    if (updateCounter-- < 0) {
      // on web update at half rate
      updateCounter = (kIsWeb) ? 1 : 0;
      x += windSpeed * cos(windDirection) / 2; // divided by 2 is a dempening factor
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
}

class WindParticlesPainter extends CustomPainter {
  List<Particle> particles;

  WindParticlesPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = markerBackgroundColor.withOpacity(1 / 2.5)
      ..strokeWidth = 1.0;
    for (var particle in particles) {
      paint.color = markerBackgroundColor.withOpacity(1 / 2.5);
      for (int i = 0; i < particle.trail.length - 1; i++) {
        paint.color = markerBackgroundColor.withOpacity(((i + 1) / particle.trail.length) / 2.5);
        canvas.drawLine(particle.trail[i], particle.trail[i + 1], paint);
      }
      canvas.drawCircle(Offset(particle.x, particle.y), 1.0, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
