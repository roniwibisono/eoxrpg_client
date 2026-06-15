import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'package:eoxrpg_client/data/master/master_repository.dart';

sealed class WarMapEvent extends Equatable {
  const WarMapEvent();
}

class LoadWarMap extends WarMapEvent {
  const LoadWarMap();

  @override
  List<Object?> get props => [];
}

class RefreshWarMap extends WarMapEvent {
  const RefreshWarMap();

  @override
  List<Object?> get props => [];
}

class NodeModel extends Equatable {
  final String id;
  final String tier;
  final String ownerFaction;
  final double influence;
  final bool aiControlled;
  final double x;
  final double y;
  final List<String> adjacency;

  const NodeModel({
    required this.id,
    required this.tier,
    required this.ownerFaction,
    required this.influence,
    required this.aiControlled,
    required this.x,
    required this.y,
    required this.adjacency,
  });

  @override
  List<Object?> get props => [
        id,
        tier,
        ownerFaction,
        influence,
        aiControlled,
        x,
        y,
        adjacency,
      ];
}

class ZoneModel extends Equatable {
  final String zoneId;
  final List<NodeModel> nodes;

  const ZoneModel({required this.zoneId, required this.nodes});

  @override
  List<Object?> get props => [zoneId, nodes];
}

class RegionModel extends Equatable {
  final String regionId;
  final String nameKey;
  final String factionOwner;
  final String biome;
  final List<ZoneModel> zones;

  const RegionModel({
    required this.regionId,
    required this.nameKey,
    required this.factionOwner,
    required this.biome,
    required this.zones,
  });

  List<NodeModel> get allNodes => zones.expand((z) => z.nodes).toList();

  @override
  List<Object?> get props => [regionId, nameKey, factionOwner, biome, zones];
}

sealed class WarMapState extends Equatable {
  const WarMapState();
}

class WarMapLoading extends WarMapState {
  const WarMapLoading();

  @override
  List<Object?> get props => [];
}

class WarMapLoaded extends WarMapState {
  final List<RegionModel> regions;
  final List<NodeModel> nodes;
  final Map<String, Color> factionColors;

  const WarMapLoaded({
    required this.regions,
    required this.nodes,
    required this.factionColors,
  });

  @override
  List<Object?> get props => [regions, nodes, factionColors];
}

class WarMapError extends WarMapState {
  final String message;

  const WarMapError(this.message);

  @override
  List<Object?> get props => [message];
}

class WarMapBloc extends Bloc<WarMapEvent, WarMapState> {
  final MasterRepository _repo;

  WarMapBloc(this._repo) : super(const WarMapLoading()) {
    on<LoadWarMap>(_onLoad);
    on<RefreshWarMap>(_onRefresh);
  }

  Future<void> _onLoad(
      LoadWarMap event, Emitter<WarMapState> emit) async {
    try {
      emit(const WarMapLoading());

      final factionsData = await _repo.getFactions();
      final worldMapData = await _repo.getWorldMap();

      final factionColors = <String, Color>{};
      final factionsList = factionsData['factions'] as List<dynamic>;
      for (final f in factionsList) {
        final map = f as Map<String, dynamic>;
        final id = map['id'] as String;
        final hex = map['color_hex'] as String? ?? '#888888';
        factionColors[id] = _parseHexColor(hex);
      }

      final regions = <RegionModel>[];
      final allNodes = <NodeModel>[];

      final regionsList = worldMapData['regions'] as List<dynamic>;
      for (final r in regionsList) {
        final rMap = r as Map<String, dynamic>;
        final regionId = rMap['region_id'] as String;
        final nameKey = rMap['name_key'] as String? ?? '';
        final factionOwner = rMap['faction_owner'] as String? ?? '';
        final biome = rMap['biome'] as String? ?? '';

        final zones = <ZoneModel>[];
        final zonesList = rMap['zones'] as List<dynamic>;
        for (final z in zonesList) {
          final zMap = z as Map<String, dynamic>;
          final zoneId = zMap['zone_id'] as String;

          final nodes = <NodeModel>[];
          final nodesList = zMap['nodes'] as List<dynamic>? ?? [];
          for (final n in nodesList) {
            final nMap = n as Map<String, dynamic>;
            final posMap = nMap['position'] as Map<String, dynamic>;
            final adjacency = (nMap['adjacency'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];

            final node = NodeModel(
              id: nMap['id'] as String,
              tier: nMap['tier'] as String? ?? 'outer',
              ownerFaction: factionOwner,
              influence: (nMap['income'] as num?)?.toDouble() ?? 0.0,
              aiControlled: nMap['ai_controlled'] as bool? ?? false,
              x: (posMap['x'] as num).toDouble(),
              y: (posMap['y'] as num).toDouble(),
              adjacency: adjacency,
            );
            nodes.add(node);
            allNodes.add(node);
          }

          zones.add(ZoneModel(zoneId: zoneId, nodes: nodes));
        }

        regions.add(RegionModel(
          regionId: regionId,
          nameKey: nameKey,
          factionOwner: factionOwner,
          biome: biome,
          zones: zones,
        ));
      }

      emit(WarMapLoaded(
        regions: regions,
        nodes: allNodes,
        factionColors: factionColors,
      ));
    } catch (e) {
      emit(WarMapError(e.toString()));
    }
  }

  Future<void> _onRefresh(
      RefreshWarMap event, Emitter<WarMapState> emit) async {
    add(const LoadWarMap());
  }

  Color _parseHexColor(String hex) {
    final stripped = hex.replaceFirst('#', '');
    return Color(int.parse('FF$stripped', radix: 16));
  }
}
