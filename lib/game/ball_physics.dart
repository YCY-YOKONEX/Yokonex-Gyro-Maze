import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'maze_level.dart';

@immutable
class BallSnapshot {
  const BallSnapshot({required this.position, required this.velocity});

  final Offset position;
  final Offset velocity;
}

/// 以“格子”为单位计算滚珠运动，避免跟屏幕像素耦合。
class BallPhysics {
  BallPhysics({required this.level, this.radius = 0.24}) {
    reset();
  }

  final MazeLevel level;
  final double radius;

  Offset position = Offset.zero;
  Offset velocity = Offset.zero;
  bool touchingWall = false;
  Duration wallContactDuration = Duration.zero;

  static const double maxSpeed = 5.8;
  // 倾斜输入直接映射到目标速度，响应值越大，球越快跟手。
  static const double speedResponse = 12;

  BallSnapshot get snapshot =>
      BallSnapshot(position: position, velocity: velocity);

  void reset() {
    position = Offset(
      level.startCell.x + 0.5,
      level.startCell.y + 0.5,
    );
    velocity = Offset.zero;
    touchingWall = false;
    wallContactDuration = Duration.zero;
  }

  void update(Duration delta, Offset input) {
    final dt = math
        .min(delta.inMicroseconds / Duration.microsecondsPerSecond, 0.05)
        .toDouble();
    if (dt <= 0) return;

    final targetVelocity = Offset(
      input.dx * maxSpeed,
      input.dy * maxSpeed,
    );
    final response = math.min(1.0, speedResponse * dt).toDouble();
    velocity += (targetVelocity - velocity) * response;
    if (velocity.distance > maxSpeed) {
      velocity = velocity / velocity.distance * maxSpeed;
    }

    // 分轴移动，碰墙后保留另一轴速度，自然形成贴墙滑行。
    var collided = false;
    final nextX = Offset(position.dx + velocity.dx * dt, position.dy);
    if (_collides(nextX)) {
      collided = true;
      velocity = Offset(0, velocity.dy);
    } else {
      position = nextX;
    }

    final nextY = Offset(position.dx, position.dy + velocity.dy * dt);
    if (_collides(nextY)) {
      collided = true;
      velocity = Offset(velocity.dx, 0);
    } else {
      position = nextY;
    }
    // 球被墙顶住后速度会变成 0，下一帧不一定还会产生新的碰撞尝试。
    // 用当前位置做一次带微小容差的检测，保持“贴墙”状态和持续计时。
    touchingWall = collided || _isTouchingWall(position);
    wallContactDuration = touchingWall
        ? wallContactDuration +
            Duration(
                microseconds: (dt * Duration.microsecondsPerSecond).round())
        : Duration.zero;
  }

  bool reachedGoal() {
    final goal = Offset(level.goalCell.x + 0.5, level.goalCell.y + 0.5);
    return (position - goal).distance <= 0.42;
  }

  bool _collides(Offset center) {
    return _overlapsWall(center, radius);
  }

  bool _isTouchingWall(Offset center) {
    const contactEpsilon = 0.035;
    return _overlapsWall(center, radius + contactEpsilon);
  }

  bool _overlapsWall(Offset center, double collisionRadius) {
    final minColumn =
        math.max(0, (center.dx - collisionRadius).floor()).toInt();
    final maxColumn = math
        .min(level.columns - 1, (center.dx + collisionRadius).floor())
        .toInt();
    final minRow = math.max(0, (center.dy - collisionRadius).floor()).toInt();
    final maxRow =
        math.min(level.rows - 1, (center.dy + collisionRadius).floor()).toInt();

    for (var row = minRow; row <= maxRow; row++) {
      for (var column = minColumn; column <= maxColumn; column++) {
        if (!level.isWall(column, row)) continue;
        final closestX =
            center.dx.clamp(column.toDouble(), column + 1.0).toDouble();
        final closestY = center.dy.clamp(row.toDouble(), row + 1.0).toDouble();
        final dx = center.dx - closestX;
        final dy = center.dy - closestY;
        if (dx * dx + dy * dy < collisionRadius * collisionRadius) {
          return true;
        }
      }
    }
    return false;
  }
}
