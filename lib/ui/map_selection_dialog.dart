import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/maze_level.dart';
import '../l10n/app_localizations.dart';

/// A 方案：大图预览 + 底部横向地图卡片。
class MapSelectionDialog extends StatefulWidget {
  const MapSelectionDialog({super.key, required this.currentLevel});

  final MazeLevel currentLevel;

  @override
  State<MapSelectionDialog> createState() => _MapSelectionDialogState();
}

class _MapSelectionDialogState extends State<MapSelectionDialog> {
  late List<MazeLevel> _levels;
  late MazeLevel _selected;

  @override
  void initState() {
    super.initState();
    final randomLevel =
        widget.currentLevel.isRandom ? widget.currentLevel : MazeLevel.random();
    _levels = [...MazeLevel.presets, randomLevel];
    _selected = _levels.firstWhere(
      (level) => level.id == widget.currentLevel.id,
      orElse: () => widget.currentLevel,
    );
  }

  void _select(MazeLevel level) {
    setState(() => _selected = level);
  }

  void _regenerateRandom() {
    final random = MazeLevel.random();
    setState(() {
      _levels = [
        ..._levels.where((level) => !level.isRandom),
        random,
      ];
      _selected = random;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = _selected.theme;
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: theme.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.border.withValues(alpha: 0.8)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(compact ? 18 : 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.text('mapSelect'),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: theme.text,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.text('close'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close_rounded, color: theme.muted),
                      ),
                    ],
                  ),
                  Text(
                    l10n.text('mapHint'),
                    style: TextStyle(color: theme.muted),
                  ),
                  const SizedBox(height: 18),
                  AspectRatio(
                    aspectRatio: compact ? 1.15 : 1.55,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.board.withValues(alpha: 0.66),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.border.withValues(alpha: 0.8),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: MazePreview(level: _selected),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.mapName(_selected.id, _selected.name),
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.mapDescription(_selected.id, _selected.description),
                    style: TextStyle(color: theme.muted),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 152,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _levels.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final level = _levels[index];
                        return _MapCard(
                          level: level,
                          selected: level.id == _selected.id,
                          onTap: () => _select(level),
                          onRegenerate:
                              level.isRandom ? _regenerateRandom : null,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.text('cancel')),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(_selected),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(l10n.text('useMap')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.level,
    required this.selected,
    required this.onTap,
    this.onRegenerate,
  });

  final MazeLevel level;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onRegenerate;

  @override
  Widget build(BuildContext context) {
    final theme = level.theme;
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 164,
      child: Material(
        color: theme.board,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? theme.primary : theme.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ColoredBox(
                      color: theme.background.withValues(alpha: 0.78),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: MazePreview(level: level),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  l10n.mapName(level.id, level.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        level.isRandom
                            ? l10n.text('randomEachTime')
                            : '${level.columns} × ${level.rows}',
                        style: TextStyle(color: theme.muted, fontSize: 11),
                      ),
                    ),
                    if (onRegenerate != null)
                      IconButton(
                        tooltip: l10n.text('regenerate'),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        onPressed: onRegenerate,
                        icon: Icon(Icons.shuffle_rounded,
                            size: 17, color: theme.primary),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MazePreview extends StatelessWidget {
  const MazePreview({super.key, required this.level});

  final MazeLevel level;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: MazePreviewPainter(level),
      child: const SizedBox.expand(),
    );
  }
}

class MazePreviewPainter extends CustomPainter {
  const MazePreviewPainter(this.level);

  final MazeLevel level;

  @override
  void paint(Canvas canvas, Size size) {
    final theme = level.theme;
    final tile = math.min(size.width / level.columns, size.height / level.rows);
    final boardWidth = tile * level.columns;
    final boardHeight = tile * level.rows;
    final left = (size.width - boardWidth) / 2;
    final top = (size.height - boardHeight) / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, boardWidth, boardHeight),
        Radius.circular(tile * .08),
      ),
      Paint()..color = theme.board,
    );
    for (var row = 0; row < level.rows; row++) {
      for (var column = 0; column < level.columns; column++) {
        final cell = level.cellAt(column, row);
        final rect = Rect.fromLTWH(
          left + column * tile + tile * .035,
          top + row * tile + tile * .035,
          tile * .93,
          tile * .93,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(tile * .04)),
          Paint()..color = cell == CellType.wall ? theme.wall : theme.path,
        );
        if (cell == CellType.start || cell == CellType.goal) {
          canvas.drawCircle(
            rect.center,
            tile * .23,
            Paint()
              ..color =
                  cell == CellType.start ? theme.ballDark : theme.secondary,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant MazePreviewPainter oldDelegate) {
    return oldDelegate.level.id != level.id ||
        oldDelegate.level.theme.id != level.theme.id;
  }
}
