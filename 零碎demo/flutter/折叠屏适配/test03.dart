import 'package:flutter/material.dart';

void main() {
  runApp(const ScrollAnchorApp());
}

class ScrollAnchorApp extends StatelessWidget {
  const ScrollAnchorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const ProductCommentsPage(),
    );
  }
}

class ProductCommentsPage extends StatefulWidget {
  const ProductCommentsPage({super.key});

  @override
  State<ProductCommentsPage> createState() => _ProductCommentsPageState();
}

class _ProductCommentsPageState extends State<ProductCommentsPage> {
  final _readerKey = GlobalKey<CommentReaderState>();
  bool _isDualPane = false;

  void _toggleLayout() {
    final anchor = _readerKey.currentState?.captureAnchor();

    setState(() => _isDualPane = !_isDualPane);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _readerKey.currentState?.restoreAnchor(anchor);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('评论滚动锚点'),
        actions: [
          Row(
            children: [
              Text(_isDualPane ? '双栏' : '单栏'),
              Switch(
                value: _isDualPane,
                onChanged: (_) => _toggleLayout(),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final isDualPane = _isDualPane && width >= 500;

          final summaryRect = isDualPane
              ? Rect.fromLTWH(16, 16, width * 0.36 - 24, height - 32)
              : Rect.fromLTWH(16, 16, width - 32, 180);

          final readerRect = isDualPane
              ? Rect.fromLTWH(
                width * 0.36 + 8,
                16,
                width * 0.64 - 24,
                height - 32,
              ) : Rect.fromLTWH(16, 212, width - 32, height - 228);

          return Stack(
            children: [
              Positioned.fromRect(
                rect: summaryRect,
                child: const ProductSummaryCard(),
              ),
              Positioned.fromRect(
                rect: readerRect,
                child: CommentReader(key: _readerKey),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ProductSummaryCard extends StatelessWidget {
  const ProductSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(
              Icons.phone_android_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(height: 16),
            Text(
              'Fold X Pro',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              '切换单双栏时，评论文字会因宽度变化重新换行。'
                  '右侧列表会用内容锚点，而不是旧 offset，恢复阅读位置。',
            ),
          ],
        ),
      ),
    );
  }
}

class CommentReader extends StatefulWidget {
  const CommentReader({super.key});

  @override
  State<CommentReader> createState() => CommentReaderState();
}

class CommentReaderState extends State<CommentReader> {
  final _controller = ScrollController();
  final _viewportKey = GlobalKey();
  late final List<GlobalKey> _commentKeys;
  late final List<Comment> _comments;

  @override
  void initState() {
    super.initState();
    _comments = List.generate(
      40,
      (index) => Comment(
        id: 'comment_${1000 + index}',
        author: '小伙伴 ${index + 1}',
        content: _commentText(index),
      ),
    );
    _commentKeys = List.generate(_comments.length, (_) => GlobalKey());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ScrollAnchor? captureAnchor() {
    if (!_controller.hasClients) {
      return null;
    }

    final viewportContext = _viewportKey.currentContext;
    if (viewportContext == null) {
      return null;
    }

    final viewportBox = viewportContext.findRenderObject()! as RenderBox;
    final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
    final viewportBottom = viewportTop + viewportBox.size.height;

    ScrollAnchor? result;

    for (var index = 0; index < _commentKeys.length; index++) {
      final itemContext = _commentKeys[index].currentContext;
      if (itemContext == null) {
        continue;
      }

      final itemBox = itemContext.findRenderObject()! as RenderBox;
      final itemTop = itemBox.localToGlobal(Offset.zero).dy;
      final itemBottom = itemTop + itemBox.size.height;

      final isVisible = itemBottom > viewportTop && itemTop < viewportBottom;
      if (!isVisible) {
        continue;
      }

      if (result == null || itemTop < result.itemScreenTop) {
        result = ScrollAnchor(
          commentIndex: index,
          viewportDy: itemTop - viewportTop,
          itemScreenTop: itemTop,
        );
      }
    }

    return result;
  }

  Future<void> restoreAnchor(ScrollAnchor? anchor) async {
    if (anchor == null || !mounted) {
      return;
    }

    final itemContext = _commentKeys[anchor.commentIndex].currentContext;
    if (itemContext == null || !_controller.hasClients) {
      return;
    }

    await Scrollable.ensureVisible(
      itemContext,
      alignment: 0,
      duration: Duration.zero,
    );

    if (!mounted || !_controller.hasClients) {
      return;
    }

    final position = _controller.position;
    if (!position.hasContentDimensions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        restoreAnchor(anchor);
      });
      return;
    }

    final target = (_controller.offset - anchor.viewportDy).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    _controller.jumpTo(target.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        key: _viewportKey,
        controller: _controller,
        padding: const EdgeInsets.all(16),
        itemCount: _comments.length,
        separatorBuilder: (_, _) => const Divider(height: 24),
        itemBuilder: (context, index) {
          final comment = _comments[index];

          return Container(
            key: _commentKeys[index],
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.author,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(comment.content),
              ],
            ),
          );
        },
      ),
    );
  }

  String _commentText(int index) {
    const texts = [
      '展开屏幕以后看商品图确实更舒服，不过我更在意评论列表不要突然跳走。正在读一半的时候，内容位置保持住会让整个体验自然很多。',
      '这台设备的外屏尺寸刚刚好，单手回消息不会费劲。展开后查参数、看长图和对比规格又非常方便，适合需要经常切换任务的用户。',
      '我一开始以为折叠屏适配就是多摆一列内容，实际用下来发现滚动位置、输入框和弹层这些细节处理好了，才是真的省心。',
      '商品已经用了两周，续航和屏幕表现都不错。希望后续评论区能支持按图片筛选，这样看真实使用体验会更快一些。',
    ];

    return texts[index % texts.length];
  }
}

class Comment {
  const Comment({
    required this.id,
    required this.author,
    required this.content,
  });

  final String id;
  final String author;
  final String content;
}

class ScrollAnchor {
  const ScrollAnchor({
    required this.commentIndex,
    required this.viewportDy,
    required this.itemScreenTop,
  });

  final int commentIndex;
  final double viewportDy;
  final double itemScreenTop;
}
