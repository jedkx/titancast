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

  // Color / teletext keys (Philips, Android TV)
  colorRed,
  colorGreen,
  colorYellow,
  colorBlue,

  // Info / Guide / Subtitle
  info,
  guide,
  subtitle,
  teletext,

  // Extended media
  record,
  nextTrack,
  prevTrack,

  // Navigation extras
  exit,
  tv,

  // Philips-specific
  ambilight,

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