import 'package:flutter/material.dart';

import 'widgets/animate_point.dart';

/// 抽取奖励位移效果
class RewardMoveEffect {
  static void show({
    required BuildContext context,
    // 顶部奖励组件的 Key
    required GlobalKey targetKey,
    // 点击按钮的坐标
    required Offset startOffset,
    // 奖励数量
    required int rewardCount,
  }) {
    final OverlayState overlayState = Overlay.of(context);
    final Offset endOffset = _getTargetOffset(targetKey);

    // 根据奖励数量，循环创建飞行的金币
    for (int i = 0; i < rewardCount; i++) {
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (context) => Stack(
          children: [
            // 一个占满全屏的遮罩层
            const ModalBarrier(
              dismissible: false, // 是否点击背景关闭
              color: Colors.transparent, // 如果需要背景变暗，可以设置 rgba(0,0,0,0.5)
            ),
            // 你的动画层
            AnimatePoint(
              key: ValueKey('$i'),
              startPoint: startOffset,
              endPoint: endOffset,
              animateTime: 3000 + i * 100,
              delay: Duration(milliseconds: i * 100),
              onCompleted: () => entry.remove(),
            ),
          ],
        ),
      );
      overlayState.insert(entry);
    }
  }

  /// 获取奖励展示组件的位置信息
  static Offset _getTargetOffset(GlobalKey key) {
    final RenderBox? box = key.currentContext?.findRenderObject() as RenderBox?;
    return box?.localToGlobal(Offset.zero) ?? Offset.zero;
  }
}

class PointMoveAnimatePage extends StatefulWidget {
  const PointMoveAnimatePage({super.key});

  static final String routePath = '/point-move-animate';

  @override
  State<PointMoveAnimatePage> createState() => _PointMoveAnimatePageState();
}

class _PointMoveAnimatePageState extends State<PointMoveAnimatePage> {
  final GlobalKey _rewardKey = GlobalKey();

  /// 完成任务，获取奖励
  void _onTaskComplete(BuildContext btnContext, int rewardCount) {
    final RenderBox box = btnContext.findRenderObject() as RenderBox;
    final startOffset = box.localToGlobal(Offset.zero) + Offset(box.size.width / 2, box.size.height / 2) - Offset(10, 10);

    RewardMoveEffect.show(
      context: context,
      targetKey: _rewardKey,
      startOffset: startOffset,
      rewardCount: rewardCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('点移动动画'),
      ),
      body: Column(
        children: [
          SizedBox(height: 10,),
          Row(
            children: [
              Container(
                margin: EdgeInsets.only(left: 20),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.blueAccent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      key: _rewardKey,
                      margin: EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.blueAccent,
                      ),
                    ),
                    Text(
                      '111',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10,),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 40),
              itemBuilder: (_, index) {
                return Container(
                  margin: EdgeInsets.only(bottom: 20),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('任务名称: ${index + 1}'),
                      ),
                      Builder(
                        builder: (btnContext) => ElevatedButton(
                          onPressed: () => _onTaskComplete(btnContext, index + 1),
                          child: Text('完成'),
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
