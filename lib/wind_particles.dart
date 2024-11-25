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
  late Ticker _ticker;
  List<Particle> particles = [];
  Random random = Random();

  WindData windData = WindData(screenWidth / 2, screenHeight / 2, 1.0, pi / 4);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (showWindMarkers) {
      if (particles.isEmpty) {
        for (int i = 0; i < (screenHeight * screenWidth) ~/ 6000; i++) {
          particles.add(Particle(random, windData));
        }
      }
      windData.direction = ((centerWindData.heading + 720 + 90) % 360) * pi / 180;
      windData.speed = centerWindData.speed;
      setState(() {
        for (var particle in particles) {
          particle.update();
        }
      });
    } else {
      particles = [];
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: WindParticlesPainter(particles),
      child: Container(),
    );
  }
}

class WindData {
  double x, y, speed, direction;

  WindData(this.x, this.y, this.speed, this.direction);
}

class Particle {
  late double x, y, vx, vy;
  List<Offset> trail = [];
  Random random;
  WindData windData;
  int lifespan = 100; // Lifespan of the particle
  int updateCounter = 0;

  Particle(this.random, this.windData) {
    x = random.nextDouble() * screenWidth;
    y = random.nextDouble() * screenHeight;
    vx = random.nextDouble() * 2 - 1;
    vy = random.nextDouble() * 2 - 1;
  }

  void update() {
    if (updateCounter-- < 0) {
      updateCounter = (kIsWeb) ? 1 : 0;

      x += windData.speed * cos(windData.direction) / 2;
      y += windData.speed * sin(windData.direction) / 2;
      trail.add(Offset(x, y));
      if (trail.length > 15) {
        trail.removeAt(0);
      }

      // Wrap around the screen edges with random reappearance
      // first remove the trail
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
