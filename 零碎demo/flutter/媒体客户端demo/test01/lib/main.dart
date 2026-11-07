import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'playback_session.dart';
import 'player_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const MediaApp());
}

class MediaApp extends StatelessWidget {
  const MediaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: '映间',
    theme: ThemeData(
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffb7d9c3),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xff101513),
      useMaterial3: true,
    ),
    home: const MediaHome(),
  );
}

class MediaHome extends StatefulWidget {
  const MediaHome({super.key});

  @override
  State<MediaHome> createState() => _MediaHomeState();
}

class _MediaHomeState extends State<MediaHome> with WidgetsBindingObserver {
  final _session = PlaybackSession();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _session.pause(); // 只做前台播放，恢复时由用户决定是否继续。
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlayerShell(
    session: _session,
    child: MediaLibrary(onPlay: _session.open),
  );
}

class MediaLibrary extends StatelessWidget {
  const MediaLibrary({super.key, required this.onPlay});
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    key: const PageStorageKey('library'),
    slivers: [
      SliverAppBar(
        pinned: true,
        expandedHeight: 480,
        backgroundColor: const Color(0xff101513),
        title: const Text('映间', style: TextStyle(letterSpacing: 5)),
        actions: const [Padding(padding: EdgeInsets.all(16), child: Icon(Icons.search))],
        flexibleSpace: FlexibleSpaceBar(
          collapseMode: CollapseMode.parallax,
          background: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/cover.png', fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x44000000), Color(0x00101513), Color(0xff101513)],
                    stops: [0, .35, 1],
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('本周精选  /  原创视觉短片', style: TextStyle(color: Color(0xffc8ded0))),
                    const SizedBox(height: 12),
                    const Text(
                      '山海之间',
                      style: TextStyle(fontSize: 42, fontWeight: FontWeight.w700, letterSpacing: 4),
                    ),
                    const SizedBox(height: 8),
                    const Text('2026  ·  自然  ·  静音演示片', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      key: const ValueKey('open-player'),
                      onPressed: onPlay,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('开始播放'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SliverPadding(
        padding: EdgeInsets.fromLTRB(24, 20, 24, 14),
        sliver: SliverToBoxAdapter(
          child: Text('留一点时间，看远一点。', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverToBoxAdapter(
          child: Text(
            '沿着山脊与海岸慢慢向前。光线经过森林，也经过我们偶尔停下来的日常。',
            style: TextStyle(height: 1.8, color: Colors.white.withValues(alpha: .62)),
          ),
        ),
      ),
      const SliverPadding(
        padding: EdgeInsets.fromLTRB(24, 30, 24, 16),
        sliver: SliverToBoxAdapter(
          child: Text('继续探索', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 140),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) => SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.crossAxisExtent > 700 ? 4 : 2,
              mainAxisSpacing: 20,
              crossAxisSpacing: 16,
              childAspectRatio: .72,
            ),
            itemCount: 8,
            itemBuilder: (context, i) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/poster_${i % 3 + 1}.png',
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  ['风起的地方', '海岸来信', '森林慢行'][i % 3],
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 3),
                const Text('视觉短片', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
