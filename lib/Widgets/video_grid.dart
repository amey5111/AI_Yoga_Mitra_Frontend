import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// One person's video in a live class.
class VideoTileData {
  /// Agora uid. 0 means the local camera.
  final int uid;
  final String name;
  final bool isLocal;
  final bool isInstructor;
  final bool cameraOff;
  final bool muted;
  final bool speaking;

  const VideoTileData({
    required this.uid,
    required this.name,
    this.isLocal = false,
    this.isInstructor = false,
    this.cameraOff = false,
    this.muted = false,
    this.speaking = false,
  });

  String get initial {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }
}

/// A Meet-style grid of everyone on camera.
///
/// The tile count decides the shape: one person fills the space, two split it,
/// and beyond that it settles into columns. Past [maxTiles] the extra people
/// are counted in a "+N" chip rather than shrinking everyone into stamps.
class VideoGrid extends StatelessWidget {
  final RtcEngine engine;
  final String channelId;
  final List<VideoTileData> tiles;

  /// Tapping a tile — used to spotlight that person.
  final void Function(VideoTileData tile)? onTapTile;

  final int maxTiles;
  final EdgeInsets padding;

  const VideoGrid({
    super.key,
    required this.engine,
    required this.channelId,
    required this.tiles,
    this.onTapTile,
    this.maxTiles = 12,
    this.padding = const EdgeInsets.all(6),
  });

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) {
      return const _EmptyStage();
    }

    final shown = tiles.take(maxTiles).toList();
    final overflow = tiles.length - shown.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(shown.length, constraints);
        return Padding(
          padding: padding,
          child: GridView.builder(
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: _aspectFor(shown.length, columns, constraints),
            ),
            itemCount: shown.length + (overflow > 0 ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= shown.length) {
                return _OverflowTile(count: overflow);
              }
              final tile = shown[index];
              return VideoTile(
                engine: engine,
                channelId: channelId,
                tile: tile,
                onTap: onTapTile == null ? null : () => onTapTile!(tile),
              );
            },
          ),
        );
      },
    );
  }

  int _columnsFor(int count, BoxConstraints c) {
    final wide = c.maxWidth > c.maxHeight;
    if (count <= 1) return 1;
    if (count == 2) return wide ? 2 : 1;
    if (count <= 4) return 2;
    if (count <= 9) return wide ? 4 : 3;
    return wide ? 4 : 3;
  }

  double _aspectFor(int count, int columns, BoxConstraints c) {
    final rows = (count / columns).ceil();
    if (rows == 0) return 16 / 9;
    final width = (c.maxWidth - padding.horizontal) / columns;
    final height = (c.maxHeight - padding.vertical) / rows;
    if (height <= 0 || width <= 0) return 3 / 4;
    return width / height;
  }
}

/// A single participant's video, or their initial when the camera is off.
class VideoTile extends StatelessWidget {
  final RtcEngine engine;
  final String channelId;
  final VideoTileData tile;
  final VoidCallback? onTap;

  /// Renders larger type and a bigger avatar — used for the spotlight.
  final bool large;

  const VideoTile({
    super.key,
    required this.engine,
    required this.channelId,
    required this.tile,
    this.onTap,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF141428),
          borderRadius: BorderRadius.circular(large ? 0 : 14),
          border: Border.all(
            color: tile.speaking
                ? const Color(0xFF6C63FF)
                : Colors.white.withValues(alpha: 0.10),
            width: tile.speaking ? 2.4 : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (tile.cameraOff)
              _CameraOff(tile: tile, large: large)
            else if (tile.isLocal)
              AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: engine,
                  canvas: const VideoCanvas(uid: 0),
                ),
              )
            else
              AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: engine,
                  canvas: VideoCanvas(uid: tile.uid),
                  connection: RtcConnection(channelId: channelId),
                ),
              ),

            // Name plate.
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (tile.isInstructor) ...[
                            const Icon(Icons.school_rounded,
                                size: 11, color: Color(0xFFB8B2FF)),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              tile.isLocal ? 'You' : tile.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: large ? 13 : 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (tile.muted) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.mic_off_rounded,
                                size: 12, color: Color(0xFFFF8A80)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraOff extends StatelessWidget {
  final VideoTileData tile;
  final bool large;

  const _CameraOff({required this.tile, required this.large});

  @override
  Widget build(BuildContext context) {
    final size = large ? 92.0 : 46.0;
    return Container(
      color: const Color(0xFF141428),
      alignment: Alignment.center,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFF2E2A5E),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          tile.initial,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _OverflowTile extends StatelessWidget {
  final int count;

  const _OverflowTile({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141428),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '+$count',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'more',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _EmptyStage extends StatelessWidget {
  const _EmptyStage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_rounded,
              color: Colors.white24, size: 44),
          const SizedBox(height: 10),
          Text(
            'Nobody is on camera yet',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
