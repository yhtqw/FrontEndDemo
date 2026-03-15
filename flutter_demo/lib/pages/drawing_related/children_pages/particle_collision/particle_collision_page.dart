import 'dart:math';

import 'package:flutter/material.dart';

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (var p in particles) {
      paint.color = p.color;
      canvas.drawCircle(
        p.position,
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Particle {
  Offset position;
  Offset velocity;
  Color color;
  double size;

  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
  });
}

class ParticleCollisionPage extends StatefulWidget {
  const ParticleCollisionPage({super.key});

  static final String routePath = '/particle-collision';

  @override
  State<ParticleCollisionPage> createState() => _ParticleCollisionPageState();
}

class _ParticleCollisionPageState extends State<ParticleCollisionPage> with SingleTickerProviderStateMixin {
  late AnimationController controller;
  // 网格 col 数
  late int gridCols;
  // 网格 row 数
  late int gridRows;
  late List<List<List<Particle>>> grid;

  // 初始化粒子个数
  final int particleCount = 5000;
  // 网格大小
  final double gridSize = 60;

  List<Particle> particles = [];
  // 是否完成初始化，没有如果为false，则执行初始化
  bool initialized = false;

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
    initParticles(size);
    initGrid(size);
    initialized = true;
  }

  // 初始化粒子
  void initParticles(Size size) {
    final rand = Random();

    for (int i = 0; i < particleCount; i++) {
      particles.add(
        Particle(
          position: Offset(
            rand.nextDouble() * size.width,
            rand.nextDouble() * size.height,
          ),
          velocity: Offset(
            rand.nextDouble() * 2 - 1,
            rand.nextDouble() * 2 - 1,
          ),
          color: Colors.primaries[rand.nextInt(Colors.primaries.length)],
          size: rand.nextDouble() + 1,
        ),
      );
    }
  }

  // 初始化网格
  void initGrid(Size size) {
    gridCols = (size.width / gridSize).ceil();
    gridRows = (size.height / gridSize).ceil();

    grid = List.generate(
      gridCols,
          (_) => List.generate(
        gridRows,
            (_) => <Particle>[],
      ),
    );
  }

  // 清空网格中的元素
  void clearGrid() {
    for (int i = 0; i < gridCols; i++) {
      for (int j = 0; j < gridRows; j++) {
        grid[i][j].clear();
      }
    }
  }

  // 将粒子加入对应的网格
  void insertParticlesToGrid() {
    for (var p in particles) {
      int col = (p.position.dx / gridSize).floor()
          .clamp(0, gridCols - 1);

      int row = (p.position.dy / gridSize).floor()
          .clamp(0, gridRows - 1);

      grid[col][row].add(p);
    }
  }

  // 更新位置信息
  void updateParticles(Size size) {
    for (var p in particles) {
      // 1 更新位置
      p.position += p.velocity;

      // 2 左右边界反弹
      if (p.position.dx - p.size < 0) {
        p.position = Offset(p.size, p.position.dy);
        p.velocity = Offset(-p.velocity.dx, p.velocity.dy);
      }

      if (p.position.dx + p.size > size.width) {
        p.position = Offset(size.width - p.size, p.position.dy);
        p.velocity = Offset(-p.velocity.dx, p.velocity.dy);
      }

      // 3 上下边界反弹
      if (p.position.dy - p.size < 0) {
        p.position = Offset(p.position.dx, p.size);
        p.velocity = Offset(p.velocity.dx, -p.velocity.dy);
      }

      if (p.position.dy + p.size > size.height) {
        p.position = Offset(p.position.dx, size.height - p.size);
        p.velocity = Offset(p.velocity.dx, -p.velocity.dy);
      }
    }
  }

  // 粒子碰撞检测
  void collideParticles(Particle p1, Particle p2) {
    final dx = p2.position.dx - p1.position.dx;
    final dy = p2.position.dy - p1.position.dy;
    final dist = sqrt(dx * dx + dy * dy);
    final minDist = p1.size + p2.size;

    if (dist < minDist && dist > 0) {
      // 法向单位向量
      final nx = dx / dist;
      final ny = dy / dist;

      // 相对速度
      final pVel =
          (p1.velocity.dx - p2.velocity.dx) * nx +
              (p1.velocity.dy - p2.velocity.dy) * ny;

      // 更新速度
      p1.velocity = Offset(
        p1.velocity.dx - pVel * nx,
        p1.velocity.dy - pVel * ny,
      );

      p2.velocity = Offset(
        p2.velocity.dx + pVel * nx,
        p2.velocity.dy + pVel * ny,
      );

      // 修正重叠
      final overlap = 0.5 * (minDist - dist);

      p1.position = p1.position - Offset(nx * overlap, ny * overlap);
      p2.position = p2.position + Offset(nx * overlap, ny * overlap);
    }
  }

  // 检测相邻网格的粒子是否碰撞
  void detectCollisions() {
    for (int i = 0; i < gridCols; i++) {
      for (int j = 0; j < gridRows; j++) {
        List<Particle> nearby = [];

        // 检测相邻网格，将相邻网格的粒子加入到上面相邻列表中
        for (int dx = -1; dx <= 1; dx++) {
          for (int dy = -1; dy <= 1; dy++) {
            int nx = i + dx;
            int ny = j + dy;

            if (nx >= 0 &&
                nx < gridCols &&
                ny >= 0 &&
                ny < gridRows
            ) {
              nearby.addAll(grid[nx][ny]);
            }
          }
        }

        // 检测粒子是否发生碰撞
        // 遍历当前网格的粒子和相邻网格中的粒子是否发生碰撞
        for (var p1 in grid[i][j]) {
          for (var p2 in nearby) {
            if (p1 != p2) {
              collideParticles(p1, p2);
            }
          }
        }
      }
    }
  }

  // 启动方法
  void step(Size size) {
    updateParticles(size);
    clearGrid();
    insertParticlesToGrid();
    detectCollisions();
  }

  // 新的更新方法封装
  void update() {
    if (!mounted) return;

    final size = MediaQuery.of(context).size;

    if (!initialized) {
      initSystem(size);
    }

    step(size);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomPaint(
        painter: ParticlePainter(particles),
        child: Container(),
      ),
    );
  }
}
