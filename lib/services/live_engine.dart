import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper around the Agora RTC engine for live classes.
/// Handles init, join as host/audience, live role switching and teardown.
class LiveEngine {
  RtcEngine? engine;
  String appId = '';
  String channel = '';
  int uid = 0;
  bool joined = false;
  bool camOn = true;
  bool micOn = true;
  final List<int> remoteUids = [];
  void Function()? onChanged;

  Future<void> ensurePermissions() async {
    await [Permission.camera, Permission.microphone].request();
  }

  Future<void> init(String appId) async {
    this.appId = appId;
    final e = createAgoraRtcEngine();
    await e.initialize(RtcEngineContext(appId: appId));
    await e.enableVideo();
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
          onChanged?.call();
        },
      ),
    );
    engine = e;
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

  Future<void> leave() async {
    try {
      await engine?.leaveChannel();
      await engine?.release();
    } catch (_) {}
    engine = null;
    joined = false;
    remoteUids.clear();
  }
}
