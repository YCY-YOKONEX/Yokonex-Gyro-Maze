import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:gyro_maze/game/maze_level.dart';

void main() {
  test('first level has one start, one goal, and a solid border', () {
    final level = MazeLevel.first;

    expect(level.startCell.x, 1);
    expect(level.startCell.y, 1);
    expect(level.goalCell.x, 11);
    expect(level.goalCell.y, 11);
    expect(level.isWall(0, 0), isTrue);
    expect(level.isWall(level.columns - 1, level.rows - 1), isTrue);
    expect(level.cellAt(1, 1), CellType.start);
    expect(level.cellAt(11, 11), CellType.goal);
  });

  test('invalid levels are rejected', () {
    expect(
      () => MazeLevel(rows: const ['###', '#S#', '###']),
      throwsArgumentError,
    );
    expect(
      () => MazeLevel(rows: const ['####', '#SG#', '###']),
      throwsArgumentError,
    );
  });

  test('preset maps expose different visual themes', () {
    final levels = MazeLevel.presets;

    expect(levels.length, 6);
    expect(levels.map((level) => level.theme.id).toSet().length, 6);
    expect(levels.map((level) => level.name).toSet().length, 6);
    expect(levels.where((level) => level.columns >= 17).length, 3);
  });

  test('random map has a valid border, start, and goal', () {
    final level = MazeLevel.random(seed: 42);

    expect(level.isRandom, isTrue);
    expect(level.rows, 15);
    expect(level.columns, 15);
    expect(level.startCell, const math.Point(1, 1));
    expect(level.goalCell, const math.Point(13, 13));
    expect(level.isWall(0, 0), isTrue);
    expect(level.isWall(level.columns - 1, level.rows - 1), isTrue);
  });
}
