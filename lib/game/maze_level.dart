import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'maze_theme.dart';

/// 一格迷宫的逻辑类型。
enum CellType { wall, path, start, goal }

@immutable
class MazeLevel {
  MazeLevel({
    required List<String> rows,
    this.id = 'custom',
    this.name = '自定义地图',
    this.description = '自定义迷宫',
    this.theme = MazeThemeData.tide,
    this.isRandom = false,
  }) : _rows = List<String>.unmodifiable(rows) {
    if (_rows.length < 3 || _rows.any((row) => row.isEmpty)) {
      throw ArgumentError('A maze needs at least three non-empty rows.');
    }
    final width = _rows.first.length;
    if (_rows.any((row) => row.length != width)) {
      throw ArgumentError('Maze rows must have equal width.');
    }
    final starts = <math.Point<int>>[];
    final goals = <math.Point<int>>[];
    for (var row = 0; row < _rows.length; row++) {
      for (var column = 0; column < width; column++) {
        switch (_rows[row][column]) {
          case 'S':
            starts.add(math.Point(column, row));
          case 'G':
            goals.add(math.Point(column, row));
        }
      }
    }
    if (starts.length != 1 || goals.length != 1) {
      throw ArgumentError('A maze needs exactly one start and one goal.');
    }
    startCell = starts.single;
    goalCell = goals.single;
  }

  final List<String> _rows;
  final String id;
  final String name;
  final String description;
  final MazeThemeData theme;
  final bool isRandom;
  late final math.Point<int> startCell;
  late final math.Point<int> goalCell;

  int get rows => _rows.length;
  int get columns => _rows.first.length;

  CellType cellAt(int column, int row) {
    if (row < 0 || row >= rows || column < 0 || column >= columns) {
      return CellType.wall;
    }
    switch (_rows[row][column]) {
      case '#':
        return CellType.wall;
      case 'S':
        return CellType.start;
      case 'G':
        return CellType.goal;
      default:
        return CellType.path;
    }
  }

  bool isWall(int column, int row) => cellAt(column, row) == CellType.wall;

  static MazeLevel get first {
    return MazeLevel(
      id: 'tide-corridor',
      name: '潮汐回廊',
      description: '直道和窄通道交错',
      theme: MazeThemeData.tide,
      rows: const [
        '############',
        '#S   #     #',
        '### ###### #',
        '#     #    #',
        '# ### # ## #',
        '# #   # #  #',
        '# # ### ## #',
        '# #     #  #',
        '# ##### # ##',
        '#     #    #',
        '# ### ######',
        '#          G',
        '############',
      ],
    );
  }

  static MazeLevel get ember {
    return MazeLevel(
      id: 'ember-fault',
      name: '熔岩断层',
      description: '转角密集，死路较多',
      theme: MazeThemeData.ember,
      rows: const [
        '#############',
        '#S     #    #',
        '##### ### # #',
        '#   #     # #',
        '# # ##### # #',
        '# #     #   #',
        '# ### # ### #',
        '#   # #     #',
        '### # ##### #',
        '#   #       #',
        '# ### ##### #',
        '#         G #',
        '#############',
      ],
    );
  }

  static MazeLevel get moon {
    return MazeLevel(
      id: 'moon-ice',
      name: '月面冰原',
      description: '长距离直线，节奏更快',
      theme: MazeThemeData.moon,
      rows: const [
        '#############',
        '#S   #     G#',
        '# # ### ### #',
        '# #     #   #',
        '# ##### # # #',
        '#     #   # #',
        '##### ##### #',
        '#   #       #',
        '# # # ##### #',
        '# # #     # #',
        '# ### ### # #',
        '#           #',
        '#############',
      ],
    );
  }

  static MazeLevel get crystal {
    return MazeLevel(
      id: 'crystal-circuit',
      name: '晶脉回路',
      description: '多层转角和连续死路',
      theme: MazeThemeData.aurora,
      rows: _generatedRows(width: 17, height: 17, seed: 1703),
    );
  }

  static MazeLevel get labyrinth {
    return MazeLevel(
      id: 'twilight-labyrinth',
      name: '暮色迷城',
      description: '长路线与密集岔路交错',
      theme: MazeThemeData.dusk,
      rows: _generatedRows(width: 19, height: 19, seed: 1919),
    );
  }

  static MazeLevel get reactor {
    return MazeLevel(
      id: 'oxide-reactor',
      name: '氧化反应堆',
      description: '大尺寸迷宫，回头路很少',
      theme: MazeThemeData.oxide,
      rows: _generatedRows(width: 21, height: 21, seed: 2121),
    );
  }

  static List<MazeLevel> get presets => [
        first,
        ember,
        moon,
        crystal,
        labyrinth,
        reactor,
      ];

  /// 使用深度优先回溯生成一张保证连通的完美迷宫。
  static MazeLevel random({int? seed}) {
    final actualSeed = seed ?? math.Random().nextInt(1 << 30);
    final random = math.Random(actualSeed);
    const width = 15;
    const height = 15;
    final theme =
        MazeThemeData.presets[random.nextInt(MazeThemeData.presets.length)];
    return MazeLevel(
      id: 'random-$actualSeed',
      name: '随机地图',
      description: '每次生成不同路径',
      theme: theme,
      isRandom: true,
      rows: _generatedRows(width: width, height: height, seed: actualSeed),
    );
  }

  /// 用固定种子生成可复现的复杂地图，保证每次进入关卡路径一致。
  static List<String> _generatedRows({
    required int width,
    required int height,
    required int seed,
  }) {
    final random = math.Random(seed);
    final cells = List.generate(
      height,
      (_) => List<String>.filled(width, '#'),
    );
    final stack = <math.Point<int>>[const math.Point(1, 1)];
    cells[1][1] = ' ';
    while (stack.isNotEmpty) {
      final current = stack.last;
      final candidates = <math.Point<int>>[];
      for (final direction in const [
        math.Point(2, 0),
        math.Point(-2, 0),
        math.Point(0, 2),
        math.Point(0, -2),
      ]) {
        final next = math.Point(
          current.x + direction.x,
          current.y + direction.y,
        );
        if (next.x > 0 &&
            next.x < width - 1 &&
            next.y > 0 &&
            next.y < height - 1 &&
            cells[next.y][next.x] == '#') {
          candidates.add(next);
        }
      }
      if (candidates.isEmpty) {
        stack.removeLast();
        continue;
      }
      final next = candidates[random.nextInt(candidates.length)];
      cells[current.y + (next.y - current.y) ~/ 2]
          [current.x + (next.x - current.x) ~/ 2] = ' ';
      cells[next.y][next.x] = ' ';
      stack.add(next);
    }
    cells[1][1] = 'S';
    cells[height - 2][width - 2] = 'G';
    return cells.map((row) => row.join()).toList(growable: false);
  }
}
