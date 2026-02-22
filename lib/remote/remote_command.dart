/// Canonical set of remote commands sent to any TV brand.
/// Each protocol adapter maps these to its own wire format.
enum RemoteCommand {
  // Power
  power,
  powerOn,
  powerOff,

  // Volume
  volumeUp,
  volumeDown,
  mute,

  // Channel
  channelUp,
  channelDown,

  // Navigation
  up,
  down,
  left,
  right,
  ok,
  back,
  home,
  menu,

  // Playback
  play,
  pause,
  stop,
  rewind,
  fastForward,

  // Input / Source
  source,

  // Smart buttons
  netflix,
  youtube,

  // Number keys
  key0,
  key1,
  key2,
  key3,
  key4,
  key5,
  key6,
  key7,
  key8,
  key9,
}