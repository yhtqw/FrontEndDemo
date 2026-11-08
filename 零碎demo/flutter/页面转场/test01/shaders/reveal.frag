#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uProgress;
uniform float uEffect;
uniform vec2 uOrigin;
uniform float uCellSize;
uniform float uFeather;

out vec4 fragColor;

float hashCell(vec2 cell) {
  // 同一格始终取同一个值，返回时不会重新随机。
  vec3 p = fract(vec3(cell.xyx) * 0.1031);
  p += dot(p, p.yzx + 33.33);
  return fract((p.x + p.y) * p.z);
}

float iris(vec2 position, vec2 size, float progress) {
  vec2 center = clamp(uOrigin, 0.0, 1.0) * size;
  float feather = max(uFeather, 0.001);
  // 每个轴取较远的一侧，组合后就是最远角点。
  float farthest = length(max(center, size - center));
  float radius = mix(-feather, farthest + feather, progress);
  return 1.0 - smoothstep(
    radius - feather,
    radius + feather,
    length(position - center)
  );
}

float diamond(vec2 position, vec2 size, float progress) {
  float cellSize = max(uCellSize, 1.0);
  vec2 cell = floor(position / cellSize);
  vec2 local = fract(position / cellSize) - 0.5;
  float distance = abs(local.x) + abs(local.y);
  vec2 lastCell = floor(max(size - 0.001, 0.0) / cellSize);
  float span = lastCell.x + lastCell.y;
  // 单元沿左上到右下依次启动，每个单元各自长出一个菱形。
  float sweep = (cell.x + cell.y) / max(span, 1.0);
  float localProgress = span < 0.5
    ? progress
    : clamp((progress - 0.65 * sweep) / 0.35, 0.0, 1.0);
  float feather = max(uFeather / cellSize, 0.001);
  float radius = mix(-feather, 1.0 + feather, localProgress);
  return 1.0 - smoothstep(radius - feather, radius + feather, distance);
}

float dissolve(vec2 position, float progress) {
  float cellSize = max(uCellSize, 1.0);
  float noise = hashCell(floor(position / cellSize));
  // 将柔化参数换算到 0～1 的噪声阈值范围。
  float feather = clamp(uFeather / cellSize, 0.001, 0.25);
  float threshold = mix(-feather, 1.0 + feather, progress);
  return 1.0 - smoothstep(threshold - feather, threshold + feather, noise);
}

void main() {
  // 显式处理端点，柔边和噪声不会留下半透明残像。
  if (uProgress <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }
  if (uProgress >= 1.0) {
    fragColor = vec4(1.0);
    return;
  }

  vec2 position = FlutterFragCoord().xy;
  vec2 size = max(uSize, vec2(1.0));
  float alpha;
  if (uEffect < 0.5) {
    alpha = iris(position, size, uProgress);
  } else if (uEffect < 1.5) {
    alpha = diamond(position, size, uProgress);
  } else {
    alpha = dissolve(position, uProgress);
  }
  // 预乘 Alpha 的白色，dstIn 只使用其中的 Alpha。
  fragColor = vec4(clamp(alpha, 0.0, 1.0));
}
