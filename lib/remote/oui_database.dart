/// OUI (Organizationally Unique Identifier) → manufacturer name mapping.
/// Only major TV/AV brands are included to keep the map small (~60 entries).
///
/// Key format: uppercase hex, no separators, 6 chars. e.g. "F4F5D8"
///
/// Sources:
///   - Home Assistant samsungtv manifest.json (Samsung OUIs confirmed)
///   - IEEE OUI registry
///   - Community-verified captures
///
/// Samsung OUIs confirmed by Home Assistant manifest.json:
///   4844F7, 606BBD, 641CB0, 8CC8CD, 8CEA48, F47B5E
const Map<String, String> ouiToManufacturer = {
  // Samsung Electronics (confirmed: HA manifest + IEEE)
  '4844F7': 'Samsung', '606BBD': 'Samsung', '641CB0': 'Samsung',
  '8CC8CD': 'Samsung', '8CEA48': 'Samsung', 'F47B5E': 'Samsung',
  'F4F5D8': 'Samsung', '8C771F': 'Samsung', 'DCA6B2': 'Samsung',
  '78BD06': 'Samsung', 'B03CF9': 'Samsung', '78F7BE': 'Samsung',
  'A8F274': 'Samsung', '000DE2': 'Samsung', '0018AF': 'Samsung',
  '002339': 'Samsung', '6C2F2C': 'Samsung',

  // LG Electronics
  'A4C3F0': 'LG', 'CC2D8C': 'LG', '7823AE': 'LG',
  '001E75': 'LG', 'B8AD28': 'LG', '5C4972': 'LG',
  'E8D8C6': 'LG', '8C3BAD': 'LG', 'F44701': 'LG',
  '34DF2A': 'LG', 'C4360C': 'LG',

  // Sony Corporation
  '0013A9': 'Sony', '001A80': 'Sony', '0024BE': 'Sony',
  'AC9B0A': 'Sony', 'F0BF97': 'Sony', '54420F': 'Sony',
  '28FD80': 'Sony', '3CEAEB': 'Sony', 'A8E063': 'Sony',
  'FCF152': 'Sony', // real Sony Bravia MAC prefix from capture

  // Philips / TP Vision
  '00178F': 'Philips', '000FDC': 'Philips', 'ACC723': 'Philips',
  'E8D4B1': 'Philips', '246078': 'Philips',

  // Hisense
  'E4B021': 'Hisense', '10F681': 'Hisense', '4CEEAD': 'Hisense',
  'C4006F': 'Hisense', '2C0E3D': 'Hisense',

  // TCL
  '500791': 'TCL', 'E04F43': 'TCL', '8CFAB5': 'TCL', '14C1EB': 'TCL',

  // Panasonic
  '00080D': 'Panasonic', '000DAE': 'Panasonic', '001B50': 'Panasonic',
  '002697': 'Panasonic', 'ACB57D': 'Panasonic', '3C2AF4': 'Panasonic',

  // Sharp
  '00166B': 'Sharp', '001AB2': 'Sharp', '6C5AB5': 'Sharp',

  // Toshiba
  '000039': 'Toshiba', '001BB1': 'Toshiba', '5CF370': 'Toshiba',

  // Google (Chromecast, Android TV dongle)
  '54609E': 'Google', 'F4F5E8': 'Google', '1C1AC0': 'Google',
  '48D705': 'Google', 'A4C138': 'Google', 'E0D55E': 'Google',

  // Amazon (Fire TV)
  'FC65DE': 'Amazon', '40B4CD': 'Amazon', '74C246': 'Amazon',
  '0C47C9': 'Amazon', 'A002DC': 'Amazon',

  // Apple (Apple TV)
  '3C0754': 'Apple', '7CD1C3': 'Apple', 'A4B197': 'Apple',
  '8C2DAA': 'Apple', 'F0DCE2': 'Apple',

  // Roku
  'B0A737': 'Roku', 'D4E26E': 'Roku', '00EE85': 'Roku',
  'C83A35': 'Roku', 'D0564C': 'Roku',
};

/// Looks up the manufacturer name for a given MAC address.
/// [mac] accepts any common format: "AA:BB:CC:DD:EE:FF", "AA-BB-CC-DD-EE-FF".
/// Returns null if the OUI is not found in the database.
String? lookupManufacturerByMac(String mac) {
  final clean = mac.toUpperCase().replaceAll(RegExp(r'[^A-F0-9]'), '');
  if (clean.length < 6) return null;
  return ouiToManufacturer[clean.substring(0, 6)];
}