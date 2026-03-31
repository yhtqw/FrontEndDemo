import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class ParticleStorage {
  final int count;

  late Float32List posX;
  late Float32List posY;

  late Float32List velX;
  late Float32List velY;
  late Uint32List colors;

  late Float32List radius;

  ParticleStorage(this.count) {
    posX = Float32List(count);
    posY = Float32List(count);

    velX = Float32List(count);
    velY = Float32List(count);

    colors = Uint32List(count);

    radius = Float32List(count);
  }
}

class SpatialHashGrid {
  final double cellSize;
  final Map<int, List<int>> cells = {};

  SpatialHashGrid(this.cellSize);

  int hash(int x, int y) {
    return x * 73856093 ^ y * 19349663;
  }

  void clear() {
    cells.clear();
  }

  void insert(int id, double x, double y) {
    int cx = (x / cellSize).floor();
    int cy = (y / cellSize).floor();

    int key = hash(cx, cy);

    cells.putIfAbsent(key, () => []).add(id);
  }

  List<int> query(double x, double y) {
    int cx = (x / cellSize).floor();
    int cy = (y / cellSize).floor();

    List<int> result = [];

    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        int key = hash(cx + dx, cy + dy);

        if (cells.containsKey(key)) {
          result.addAll(cells[key]!);
        }
      }
    }

    return result;
  }
}

class PhysicsSolver {
  final ParticleStorage particles;
  final SpatialHashGrid grid;

  PhysicsSolver(this.particles, this.grid);

  void step(double width, double height) {

    grid.clear();

    int n = particles.count;

    for (int i = 0; i < n; i++) {

      particles.posX[i] += particles.velX[i];
      particles.posY[i] += particles.velY[i];

      if (particles.posX[i] < 0 || particles.posX[i] > width) {
        particles.velX[i] *= -1;
      }

      if (particles.posY[i] < 0 || particles.posY[i] > height) {
        particles.velY[i] *= -1;
      }

      grid.insert(i, particles.posX[i], particles.posY[i]);
    }

    solveCollisions();
  }

  void solveCollisions() {

    int n = particles.count;

    for (int i = 0; i < n; i++) {

      var neighbors =
      grid.query(particles.posX[i], particles.posY[i]);

      for (var j in neighbors) {

        if (i >= j) continue;

        double dx = particles.posX[j] - particles.posX[i];
        double dy = particles.posY[j] - particles.posY[i];

        double dist2 = dx * dx + dy * dy;

        double r =
            particles.radius[i] + particles.radius[j];

        if (dist2 < r * r) {

          double dist = sqrt(dist2);

          double nx = dx / dist;
          double ny = dy / dist;

          double dvx =
              particles.velX[i] - particles.velX[j];
          double dvy =
              particles.velY[i] - particles.velY[j];

          double impact = dvx * nx + dvy * ny;

          particles.velX[i] -= impact * nx;
          particles.velY[i] -= impact * ny;

          particles.velX[j] += impact * nx;
          particles.velY[j] += impact * ny;
        }
      }
    }
  }
}

class Attractor {
  double x = 0;
  double y = 0;

  double strength = 0;
}

void applyAttractor(ParticleStorage p, Attractor a) {
  if (a.strength == 0) return;

  for (int i = 0; i < p.count; i++) {
    double dx = a.x - p.posX[i];
    double dy = a.y - p.posY[i];

    double dist = sqrt(dx * dx + dy * dy) + 0.01;

    double force = a.strength / dist;

    p.velX[i] += dx * force;
    p.velY[i] += dy * force;
  }
}

ParticleStorage createParticles(int n, Size size) {
  final rand = Random();

  final p = ParticleStorage(n);

  for (int i = 0; i < n; i++) {
    p.posX[i] = rand.nextDouble() * size.width;
    p.posY[i] = rand.nextDouble() * size.height;

    p.velX[i] = rand.nextDouble() * 2 - 1;
    p.velY[i] = rand.nextDouble() * 2 - 1;

    // 随机选择一个 Material 调色板颜色
    final color = Colors.primaries[rand.nextInt(Colors.primaries.length)];
    p.colors[i] = color.toARGB32();

    p.radius[i] = 1;
  }

  return p;
}

class ParticlePainter extends CustomPainter {
  final ParticleStorage particles;
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < particles.count; i++) {
      // 从 Uint32List 构造 Color 对象（这种轻量级构造在渲染循环中是可以接受的）
      _paint.color = Color(particles.colors[i]);

      canvas.drawCircle(
        Offset(particles.posX[i], particles.posY[i]),
        particles.radius[i],
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ParticleCollisionOptimizationPage extends StatefulWidget {
  const ParticleCollisionOptimizationPage({super.key});

  static final String routePath = '/particle-collision-optimization';

  @override
  State<ParticleCollisionOptimizationPage> createState() => _ParticleCollisionOptimizationPageState();
}

class _ParticleCollisionOptimizationPageState extends State<ParticleCollisionOptimizationPage> with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late ParticleStorage particles;
  late SpatialHashGrid grid;
  late PhysicsSolver solver;

  Attractor attractor = Attractor();

  bool initialized = false;

  final int particleCount = 10000;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 100),
    )
      ..addListener(update)
      ..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // 初始化系统，用于第一次的粒子创建和划分网格
  void initSystem(Size size) {
    particles = createParticles(particleCount, size);

    grid = SpatialHashGrid(30);

    solver = PhysicsSolver(particles, grid);

    initialized = true;
  }

  void update() {
    if (!mounted) return;

    final size = MediaQuery.of(context).size;

    if (!initialized) {
      initSystem(size);
    }

    applyAttractor(particles, attractor);

    solver.step(size.width, size.height);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: initialized ? CustomPaint(
        painter: ParticlePainter(particles),
        child: Container(),
      ) : SizedBox(),
    );
  }
}
