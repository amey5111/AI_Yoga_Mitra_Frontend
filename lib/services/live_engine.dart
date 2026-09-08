import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper around the Agora RTC engine for live classes.
///
/// Handles init, join as host/audience, live role switching and teardown, and
/// keeps just enough per-participant state for the video grid to draw itself:
/// who is publishing, who has their camera off, who is muted and who is
/// currently talking.
class LiveEngine {
  RtcEngine? engine;
  String appId = '';
  String channel = '';
  int uid = 0;
  bool joined = false;
  bool camOn = true;
  bool micOn = true;

  /// Everyone else publishing into the channel, in the order they arrived.
  final List<int> remoteUids = [];

  /// Remote uids whose camera is currently off — their tile shows an avatar
  /// rather than a frozen or black video surface.
  final Set<int> videoOff = {};

  /// Remote uids whose microphone is muted.
  final Set<int> mutedAudio = {};

  /// Whoever is loudest right now (0 when nobody is). The local user reports
  /// as uid 0 in Agora's volume callback; [localIsSpeaking] covers that case.
  int activeSpeakerUid = 0;
  bool localIsSpeaking = false;

  void Function()? onChanged;

  /// Called when the class we are in has ended from the engine's point of view
  /// (token expired, kicked, connection lost for good).
  void Function(String reason)? onFatal;

  Future<void> ensurePermissions() async {
    await [Permission.camera, Permission.microphone].request();
  }

  Future<void> init(String appId) async {
    this.appId = appId;
    final e = createAgoraRtcEngine();
    await e.initialize(RtcEngineContext(appId: appId));
    await e.enableVideo();
    // Drives the "who is talking" ring on the tiles.
    await e.enableAudioVolumeIndication(
      interval: 400,
      smooth: 3,
      reportVad: true,
    );
    e.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          joined = true;
          onChanged?.call();
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (!remoteUids.contains(remoteUid)) {
            remoteUids.add(remoteUid);
            onChanged?.call();
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          remoteUids.remove(remoteUid);
          // Forget their state too, so a rejoin does not inherit a stale
          // "camera off" badge from the last time they were here.
          videoOff.remove(remoteUid);
          mutedAudio.remove(remoteUid);
          if (activeSpeakerUid == remoteUid) activeSpeakerUid = 0;
          onChanged?.call();
        },
        onUserMuteVideo:
            (RtcConnection connection, int remoteUid, bool muted) {
          if (muted) {
            videoOff.add(remoteUid);
          } else {
            videoOff.remove(remoteUid);
          }
          onChanged?.call();
        },
        onUserMuteAudio:
            (RtcConnection connection, int remoteUid, bool muted) {
          if (muted) {
            mutedAudio.add(remoteUid);
          } else {
            mutedAudio.remove(remoteUid);
          }
          onChanged?.call();
        },
        onUserEnableLocalVideo:
            (RtcConnection connection, int remoteUid, bool enabled) {
          if (enabled) {
            videoOff.remove(remoteUid);
          } else {
            videoOff.add(remoteUid);
          }
          onChanged?.call();
        },
        onAudioVolumeIndication: (
          RtcConnection connection,
          List<AudioVolumeInfo> speakers,
          int speakerNumber,
          int totalVolume,
        ) {
          _updateActiveSpeaker(speakers);
        },
        onConnectionLost: (RtcConnection connection) {
          onFatal?.call('Lost connection to the class.');
        },
      ),
    );
    engine = e;
  }

  /// Agora reports every audible participant each interval; the loudest one
  /// above a floor gets the ring. Below the floor nobody is highlighted, so a
  /// quiet room does not flicker between people breathing.
  void _updateActiveSpeaker(List<AudioVolumeInfo> speakers) {
    const floor = 15;
    int bestUid = 0;
    int bestVolume = 0;
    bool localLoudest = false;

    for (final s in speakers) {
      final volume = s.volume ?? 0;
      if (volume < floor || volume <= bestVolume) continue;
      bestVolume = volume;
      // uid 0 in this callback means "me".
      final speakerUid = s.uid ?? 0;
      localLoudest = speakerUid == 0;
      bestUid = speakerUid;
    }

    final changed =
        bestUid != activeSpeakerUid || localLoudest != localIsSpeaking;
    activeSpeakerUid = bestUid;
    localIsSpeaking = localLoudest;
    if (changed) onChanged?.call();
  }

  Future<void> join({
    required String token,
    required String channel,
    required int uid,
    required bool asHost,
  }) async {
    this.channel = channel;
    this.uid = uid;
    final role = asHost
        ? ClientRoleType.clientRoleBroadcaster
        : ClientRoleType.clientRoleAudience;
    if (asHost) await engine?.startPreview();
    camOn = asHost;
    micOn = asHost;
    await engine?.joinChannel(
      token: token,
      channelId: channel,
      uid: uid,
      options: ChannelMediaOptions(
        clientRoleType: role,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        publishCameraTrack: asHost,
        publishMicrophoneTrack: asHost,
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
      ),
    );
  }

  /// Promote (audience -> host) or demote (host -> audience) mid-class.
  Future<void> setHost(bool asHost) async {
    final role = asHost
        ? ClientRoleType.clientRoleBroadcaster
        : ClientRoleType.clientRoleAudience;
    await engine?.setClientRole(role: role);
    if (asHost) {
      await engine?.startPreview();
    } else {
      await engine?.stopPreview();
    }
    await engine?.updateChannelMediaOptions(
      ChannelMediaOptions(
        clientRoleType: role,
        publishCameraTrack: asHost,
        publishMicrophoneTrack: asHost,
      ),
    );
    camOn = asHost;
    micOn = asHost;
    onChanged?.call();
  }

  Future<void> toggleCam() async {
    camOn = !camOn;
    await engine?.enableLocalVideo(camOn);
    await engine?.muteLocalVideoStream(!camOn);
    onChanged?.call();
  }

  Future<void> toggleMic() async {
    micOn = !micOn;
    await engine?.muteLocalAudioStream(!micOn);
    onChanged?.call();
  }

  Future<void> switchCamera() async {
    await engine?.switchCamera();
  }

  bool isVideoOff(int remoteUid) => videoOff.contains(remoteUid);

  bool isMuted(int remoteUid) => mutedAudio.contains(remoteUid);

  Future<void> leave() async {
    try {
      await engine?.leaveChannel();
      await engine?.release();
    } catch (_) {}
    engine = null;
    joined = false;
    remoteUids.clear();
    videoOff.clear();
    mutedAudio.clear();
    activeSpeakerUid = 0;
    localIsSpeaking = false;
  }
}
