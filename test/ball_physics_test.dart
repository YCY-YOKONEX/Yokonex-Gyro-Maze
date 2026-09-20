import 'package:flutter_test/flutter_test.dart';

import 'package:gyro_maze/game/ball_physics.dart';
import 'package:gyro_maze/game/maze_level.dart';

void main() {
  final level = MazeLevel(
    rows: const [
      '#######',
      '#S   G#',
      '#######',
    ],
  );

  test('ball starts at the center of the start cell', () {
    final physics = BallPhysics(level: level);
    expect(physics.position, const Offset(1.5, 1.5));
    expect(physics.velocity, Offset.zero);
  });

  test('ball moves in an open corridor and reaches the goal', () {
    final physics = BallPhysics(level: level);
    for (var i = 0; i < 120; i++) {
      physics.update(const Duration(milliseconds: 16), const Offset(1, 0));
    }
    expect(physics.position.dx, greaterThan(4.5));
    expect(physics.reachedGoal(), isTrue);
  });

  test('wall collision prevents leaving the corridor', () {
    final physics = BallPhysics(level: level);
    for (var i = 0; i < 180; i++) {
      physics.update(const Duration(milliseconds: 16), const Offset(0, -1));
    }
    expect(physics.position.dy, greaterThan(1.2));
  });

  test('tilt magnitude maps to ball speed and releases quickly', () {
    final physics = BallPhysics(level: level);
    physics.update(const Duration(milliseconds: 16), const Offset(0.2, 0));
    final lowSpeed = physics.velocity.dx;

    physics.reset();
    physics.update(const Duration(milliseconds: 16), const Offset(1, 0));
    final highSpeed = physics.velocity.dx;
    expect(highSpeed, greaterThan(lowSpeed));

    physics.update(const Duration(milliseconds: 200), Offset.zero);
    expect(physics.velocity.dx, lessThan(highSpeed));
  });

  test('reset returns the ball to the start', () {
    final physics = BallPhysics(level: level);
    physics.update(const Duration(seconds: 1), const Offset(1, 0));
    physics.reset();
    expect(physics.position, const Offset(1.5, 1.5));
    expect(physics.velocity, Offset.zero);
  });

  test('stays touching the wall after movement is stopped', () {
    final physics = BallPhysics(level: level);
    for (var i = 0; i < 120; i++) {
      physics.update(const Duration(milliseconds: 16), const Offset(0, -1));
    }
    final firstContactDuration = physics.wallContactDuration;
    expect(physics.touchingWall, isTrue);
    expect(firstContactDuration, greaterThan(Duration.zero));

    for (var i = 0; i < 20; i++) {
      physics.update(const Duration(milliseconds: 16), Offset.zero);
    }
    expect(physics.touchingWall, isTrue);
    expect(physics.wallContactDuration, greaterThan(firstContactDuration));

    for (var i = 0; i < 4; i++) {
      physics.update(const Duration(milliseconds: 16), const Offset(0, 1));
    }
    expect(physics.touchingWall, isFalse);
    expect(physics.wallContactDuration, Duration.zero);
  });
}
