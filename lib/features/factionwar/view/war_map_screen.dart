import 'dart:async' as async;

import 'package:eoxrpg_client/data/master/master_repository.dart';
import 'package:eoxrpg_client/game/node_component.dart';
import 'package:flame/components.dart' hide Timer;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/war_map_bloc.dart';

class WarMapGame extends FlameGame
    with ScaleDetector, MultiTouchTapDetector, ScrollDetector {
  static const worldScale = 60.0;
  static const regionMinSize = 200.0;
  static const regionPadding = 60.0;
  static const zonePadding = 30.0;

  List<RegionModel> _regions = [];
  List<NodeModel> _nodes = [];
  Map<String, Color> _factionColors = {};
  final Map<String, NodeComponent> _nodeComponents = {};

  double _baseZoom = 1.0;
  bool _built = false;

  void Function(NodeModel)? onNodeTap;

  Vector2 toWorld(double x, double y) =>
      Vector2(x * worldScale, y * worldScale);

  void loadMapData(
    List<RegionModel> regions,
    List<NodeModel> nodes,
    Map<String, Color> factionColors,
  ) {
    _regions = regions;
    _nodes = nodes;
    _factionColors = factionColors;

    if (!_built) {
      _buildMap();
      _built = true;
    } else {
      _updateNodes();
    }
  }

  void _buildMap() {
    for (final region in _regions) {
      final color = _factionColors[region.factionOwner] ?? Colors.grey;
      final bounds = _computeRegionBounds(region);

      world.add(RectangleComponent(
        position: Vector2(bounds.left, bounds.top),
        size: Vector2(bounds.width, bounds.height),
        paint: Paint()..color = color.withValues(alpha: 0.12),
      ));

      world.add(RectangleComponent(
        position: Vector2(bounds.left, bounds.top),
        size: Vector2(bounds.width, bounds.height),
        paint: Paint()
          ..color = color.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      ));

      world.add(TextComponent(
        text: region.nameKey.isNotEmpty ? region.nameKey : region.regionId,
        textRenderer: TextPaint(
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        anchor: Anchor.center,
        position: Vector2(bounds.center.dx.toDouble(),
            bounds.center.dy.toDouble() < bounds.top + 18
                ? bounds.top + 18
                : bounds.center.dy.toDouble()),
      ));

      for (final zone in region.zones) {
        final zBounds = _computeZoneBounds(zone, bounds);
        world.add(RectangleComponent(
          position: Vector2(zBounds.left, zBounds.top),
          size: Vector2(zBounds.width, zBounds.height),
          paint: Paint()
            ..color = color.withValues(alpha: 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        ));
      }

      for (final node in region.allNodes) {
        final pos = toWorld(node.x, node.y);
        final nodeColor = _factionColors[node.ownerFaction] ?? Colors.grey;
        final comp = NodeComponent(
          nodeId: node.id,
          tier: node.tier,
          ownerFaction: node.ownerFaction,
          influence: node.influence,
          aiControlled: node.aiControlled,
          factionColor: nodeColor,
          position: pos,
        );
        _nodeComponents[node.id] = comp;
        world.add(comp);
      }
    }

    final total = _computeTotalBounds();
    if (total != Rect.zero) {
      final vpSize = camera.viewport.size;
      camera.viewfinder.position =
          Vector2(total.center.dx, total.center.dy);
      final fitZoomX = vpSize.x / total.width;
      final fitZoomY = vpSize.y / total.height;
      camera.viewfinder.zoom =
          (fitZoomX < fitZoomY ? fitZoomX : fitZoomY).clamp(0.3, 2.0);
    }
  }

  void _updateNodes() {
    for (final node in _nodes) {
      final comp = _nodeComponents[node.id];
      if (comp == null) continue;
      final newColor = _factionColors[node.ownerFaction] ?? Colors.grey;
      comp.animateToColor(newColor);
    }
  }

  Rect _computeRegionBounds(RegionModel region) {
    final nodes = region.allNodes;
    if (nodes.isEmpty) {
      return const Rect.fromLTWH(0, 0, regionMinSize, regionMinSize);
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final n in nodes) {
      final pos = toWorld(n.x, n.y);
      if (pos.x < minX) minX = pos.x;
      if (pos.y < minY) minY = pos.y;
      if (pos.x > maxX) maxX = pos.x;
      if (pos.y > maxY) maxY = pos.y;
    }

    return Rect.fromLTRB(
      minX - regionPadding,
      minY - regionPadding,
      (maxX + regionPadding).clamp(
          minX + regionMinSize - regionPadding * 2, double.infinity),
      (maxY + regionPadding).clamp(
          minY + regionMinSize - regionPadding * 2, double.infinity),
    );
  }

  Rect _computeZoneBounds(ZoneModel zone, Rect regionBounds) {
    final nodes = zone.nodes;
    if (nodes.isEmpty) {
      return Rect.fromLTWH(
        regionBounds.left + zonePadding,
        regionBounds.top + 30 + zonePadding,
        regionBounds.width - zonePadding * 2,
        regionBounds.height - 30 - zonePadding * 2,
      );
    }

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final n in nodes) {
      final pos = toWorld(n.x, n.y);
      if (pos.x < minX) minX = pos.x;
      if (pos.y < minY) minY = pos.y;
      if (pos.x > maxX) maxX = pos.x;
      if (pos.y > maxY) maxY = pos.y;
    }

    return Rect.fromLTRB(
      minX - zonePadding,
      minY - zonePadding,
      maxX + zonePadding,
      maxY + zonePadding,
    );
  }

  Rect _computeTotalBounds() {
    if (_regions.isEmpty) return Rect.zero;
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final region in _regions) {
      final b = _computeRegionBounds(region);
      if (b.left < minX) minX = b.left;
      if (b.top < minY) minY = b.top;
      if (b.right > maxX) maxX = b.right;
      if (b.bottom > maxY) maxY = b.bottom;
    }

    return Rect.fromLTRB(minX - 40, minY - 40, maxX + 40, maxY + 40);
  }

  Vector2 _screenToWorld(Vector2 widgetPosition) {
    final canvasCenter = canvasSize / 2;
    final zoom = camera.viewfinder.zoom;
    final viewfinderPos = camera.viewfinder.position;
    return (widgetPosition - canvasCenter) / zoom + viewfinderPos;
  }

  @override
  void onScaleStart(ScaleStartInfo info) {
    _baseZoom = camera.viewfinder.zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final zoom = camera.viewfinder.zoom;
    camera.viewfinder.position -= info.delta.global / zoom;
    camera.viewfinder.zoom =
        (_baseZoom * info.scale.global.x).clamp(0.3, 3.0);
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final delta = info.scrollDelta.global.y;
    camera.viewfinder.zoom =
        (camera.viewfinder.zoom - delta * 0.001).clamp(0.3, 3.0);
  }

  @override
  void onTapUp(int pointerId, TapUpInfo info) {
    final worldPos = _screenToWorld(info.eventPosition.widget);
    for (final entry in _nodeComponents.entries) {
      if (entry.value.containsWorldPoint(worldPos)) {
        final model = _nodes.firstWhere((n) => n.id == entry.key);
        onNodeTap?.call(model);
        return;
      }
    }
  }

  @override
  void onRemove() {
    _nodeComponents.clear();
    super.onRemove();
  }
}

class WarMapScreen extends StatefulWidget {
  const WarMapScreen({super.key});

  @override
  State<WarMapScreen> createState() => _WarMapScreenState();
}

class _WarMapScreenState extends State<WarMapScreen> {
  late final WarMapBloc _bloc;
  late final WarMapGame _game;
  async.Timer? _pollTimer;
  Map<String, Color> _factionColors = {};

  @override
  void initState() {
    super.initState();

    final repo = MasterRepository();

    _bloc = WarMapBloc(repo);
    _game = WarMapGame();
    _game.onNodeTap = _showNodeDetail;
    _bloc.add(const LoadWarMap());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _bloc.close();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = async.Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_bloc.isClosed) {
        _bloc.add(const RefreshWarMap());
      }
    });
  }

  void _showNodeDetail(NodeModel node) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _NodeDetailSheet(
        node: node,
        factionColors: _factionColors,
        allNodes: (_bloc.state is WarMapLoaded)
            ? (_bloc.state as WarMapLoaded).nodes
            : [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: BlocConsumer<WarMapBloc, WarMapState>(
        bloc: _bloc,
        listener: (context, state) {
          if (state is WarMapLoaded) {
            _factionColors = state.factionColors;
            _game.loadMapData(
                state.regions, state.nodes, state.factionColors);
            _startPolling();
          }
        },
        builder: (context, state) {
          if (state is WarMapLoading) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white70),
                  SizedBox(height: 16),
                  Text(
                    'Loading War Map...',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                ],
              ),
            );
          }
          if (state is WarMapError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      state.message,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _bloc.add(const LoadWarMap()),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          return Stack(
            children: [
              GameWidget<WarMapGame>(game: _game),
              Positioned(
                top: 8,
                left: 8,
                child: _LegendBar(factionColors: _factionColors),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LegendBar extends StatelessWidget {
  final Map<String, Color> factionColors;

  const _LegendBar({required this.factionColors});

  @override
  Widget build(BuildContext context) {
    if (factionColors.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FACTIONS',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...factionColors.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: e.value,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      e.key,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 10),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _NodeDetailSheet extends StatelessWidget {
  final NodeModel node;
  final Map<String, Color> factionColors;
  final List<NodeModel> allNodes;

  const _NodeDetailSheet({
    required this.node,
    required this.factionColors,
    required this.allNodes,
  });

  @override
  Widget build(BuildContext context) {
    final factionColor = factionColors[node.ownerFaction] ?? Colors.grey;
    final tierLabel =
        node.tier[0].toUpperCase() + node.tier.substring(1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: factionColor,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.white38, width: 1.5),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  node.id,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (node.aiControlled)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blueAccent),
                  ),
                  child: const Text('AI',
                      style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _detailRow('Tier', tierLabel),
          _detailRow('Owner', node.ownerFaction),
          _detailRow('Influence',
              '${(node.influence * 100).toStringAsFixed(0)}%'),
          if (node.adjacency.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Adjacent Nodes',
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: node.adjacency.map((adj) {
                final adjNode =
                    allNodes.where((n) => n.id == adj).firstOrNull;
                final adjColor = adjNode != null
                    ? (factionColors[adjNode.ownerFaction] ??
                        Colors.grey)
                    : Colors.grey;
                return Chip(
                  backgroundColor: adjColor.withValues(alpha: 0.2),
                  side: BorderSide(
                      color: adjColor.withValues(alpha: 0.5)),
                  label: Text(adj,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white70)),
                  materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.shield, size: 18),
              label: const Text('Declare Siege'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                disabledForegroundColor:
                    Colors.redAccent.withValues(alpha: 0.4),
                side: BorderSide(
                    color: Colors.redAccent.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
