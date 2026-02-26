
# TitanCast

TitanCast is a cross-platform Flutter application designed to discover and interact with streaming devices on your local network. It supports Google Cast, AirPlay, Spotify Connect, and DLNA devices, making it easy to find and connect to your favorite media receivers.

## Features

- Fast device discovery using mDNS and SSDP
- Supports Google Cast, AirPlay, Spotify Connect, DLNA
- Simple and intuitive user interface
- Cross-platform: Android, iOS, Windows, macOS, Linux, Web

## Getting Started

To run TitanCast locally:
1. Clone this repository.
2. Run `flutter pub get` to install dependencies.
3. Use `flutter run` to launch the app on your device or emulator.

## Project Structure

- `lib/` — Main application code
- `lib/datasource/` — Device discovery logic
- `android/`, `ios/`, `windows/`, `macos/`, `linux/`, `web/` — Platform-specific files

## Contributing

Pull requests and suggestions are welcome! Please open an issue for bugs or feature requests.

## License

This project is licensed under the MIT License.

---

For more information about Flutter, check out:
- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the [online documentation](https://docs.flutter.dev/), which offers tutorials, samples, guidance on mobile development, and a full API reference.


## TO DO

---
- uygulama geneli kalite standarti testi yapilacak gereksiz yorum satirlari kaldirilacak kalacak yorum satirlari ingilizce olacak. senior dev quality engineer gozuyle proje mimarisi kodlar teker teker incelenecek
- kullanilan yontemler apiler protocoller veriler nerden bulundugu ilgili yerin bir yerine ingilizvce yorum satiriyle belirtilecek kullanilan her bilgi dogru olmali
- mobil uygulama standartlari cercevesinde ui incelemesi ve testi yapilacak.
- dosya mimarisi ve genel mimari incelenecek endustri standartlarina ulasmasi icin yapilmasi gerekenler yapilacak (ornegin touchpad gibi ozellikler bence ayrilmali) moduler bir yapi olmali
- devices kisminda routerlari da sayiyar count olarak saymamasi lazim.
- loglar detaylandirilacak kalitesi artirilacak ve 500 satidan fazlasi kopyalanabilir olcak
- devices kisminda hangi cihazin hangi wifidan geldigni gormeliyiz suan bu islev calismiyor bunun icin ust baslik gibi wifi ssid ismine gore siralanmali eger 1 den fazla ise

## Torima to do
- Baglanti saglayamiyorum unreachable diyo
- Log:[19:28:38.147] I/AppShell: TitanCast started
  [19:28:39.622] I/DeviceRepository: loadFromPrefs: loaded 1 device(s) — Internet Home Gateway Device(192.168.1.254)
  [19:29:10.800] I/DeviceRepository: loadFromPrefs: loaded 1 device(s) — Internet Home Gateway Device(192.168.1.254)
  [19:29:11.815] I/DeviceRepository: loadFromPrefs: loaded 1 device(s) — Internet Home Gateway Device(192.168.1.254)
  [19:29:13.914] I/DiscoveryManager: ── startDiscovery() ────────────────────────────
  [19:29:13.915] I/DiscoveryManager: mode=network timeout=15s targetIp=n/a
  [19:29:13.915] D/DiscoveryManager: device cache cleared
  [19:29:13.918] D/DiscoveryManager: starting network discovery (SSDP + mDNS + port-probe)
  [19:29:13.918] D/DiscoveryManager: network discovery: starting SSDP and mDNS sources (activeSources=2, probe delayed 200ms)
  [19:29:13.936] D/DiscoveryManager: timeout timer set for 15s
  [19:29:14.217] D/DiscoveryManager: starting port-probe (ports: 1925, 1926, 8008, 8080)
  [19:29:14.408] I/DiscoveryManager: processDevice: NEW device 192.168.0.1 "Archer C6 AC1200 MU-MIMO Wi-Fi Router" brand=? method=ssdp
  [19:29:14.408] D/DiscoveryManager: emit: 192.168.0.1 "Archer C6 AC1200 MU-MIMO Wi-Fi Router" brand=? manufacturer="TP-Link" method=ssdp cache size=1
  [19:29:14.843] D/DeviceRepository: save: "Archer C6 AC1200 MU-MIMO Wi-Fi Router" ip=192.168.0.1 incomingBrand=null manufacturer=TP-Link
  [19:29:14.843] D/DeviceRepository: save: brand unknown, running BrandDetector for 192.168.0.1
  [19:29:14.844] D/BrandDetector: ── detect() start ─────────────────────────────────────
  [19:29:14.844] D/BrandDetector: device: "Archer C6 AC1200 MU-MIMO Wi-Fi Router" ip=192.168.0.1 manufacturer=TP-Link serviceType=InternetGatewayDevice currentBrand=null
  [19:29:14.845] V/BrandDetector: layer 1: serviceType probe (st=InternetGatewayDevice, rawHeaders=CACHE-CONTROL,DATE,EXT,LOCATION,SERVER,ST,USN)
  [19:29:14.845] V/BrandDetector: layer 1 miss
  [19:29:14.846] V/BrandDetector: layer 2: manufacturer string probe ("TP-Link")
  [19:29:14.846] V/BrandDetector: layer 2 miss ("TP-Link" not recognized)
  [19:29:14.846] V/BrandDetector: layer 3: MAC OUI lookup for ip=192.168.0.1
  [19:29:15.332] E/BrandDetector: MAC lookup failed for 192.168.0.1: ProcessException: No such file or directory
  Command: arp -n 192.168.0.1
  [19:29:15.333] V/BrandDetector: layer 3 miss (no OUI match)
  [19:29:15.334] V/BrandDetector: layer 4: heuristic probe (name="Archer C6 AC1200 MU-MIMO Wi-Fi Router")
  [19:29:15.337] W/BrandDetector: all 4 layers missed — brand=unknown for 192.168.0.1 ("Archer C6 AC1200 MU-MIMO Wi-Fi Router")
  [19:29:15.338] I/DeviceRepository: save: BrandDetector result → unknown for 192.168.0.1
  [19:29:15.338] I/DeviceRepository: save: NEW device added — "Archer C6 AC1200 MU-MIMO Wi-Fi Router" ip=192.168.0.1 brand=unknown manufacturer=TP-Link
  [19:29:15.375] V/DeviceRepository: save: persisted — total 2 device(s)
  [19:29:16.366] I/DiscoveryManager: processDevice: NEW device 192.168.0.202 "HY350Max-6282" brand=? method=ssdp
  [19:29:16.366] D/DiscoveryManager: emit: 192.168.0.202 "HY350Max-6282" brand=? manufacturer="?" method=ssdp cache size=2
  [19:29:16.625] D/DiscoveryManager: port-probe finished
  [19:29:16.767] D/DeviceRepository: save: "HY350Max-6282" ip=192.168.0.202 incomingBrand=null manufacturer=null
  [19:29:16.769] D/DeviceRepository: save: brand unknown, running BrandDetector for 192.168.0.202
  [19:29:16.770] D/BrandDetector: ── detect() start ─────────────────────────────────────
  [19:29:16.770] D/BrandDetector: device: "HY350Max-6282" ip=192.168.0.202 manufacturer=null serviceType=MediaRenderer currentBrand=null
  [19:29:16.771] V/BrandDetector: layer 1: serviceType probe (st=MediaRenderer, rawHeaders=CACHE-CONTROL,LOCATION,EXT,ST,USN,SERVER)
  [19:29:16.771] V/BrandDetector: layer 1 miss
  [19:29:16.771] V/BrandDetector: layer 2 skipped — manufacturer is null
  [19:29:16.771] V/BrandDetector: layer 3: MAC OUI lookup for ip=192.168.0.202
  [19:29:16.901] E/BrandDetector: MAC lookup failed for 192.168.0.202: ProcessException: No such file or directory
  Command: arp -n 192.168.0.202
  [19:29:16.903] V/BrandDetector: layer 3 miss (no OUI match)
  [19:29:16.906] V/BrandDetector: layer 4: heuristic probe (name="HY350Max-6282")
  [19:29:16.908] I/BrandDetector: layer 4 HIT → torima (heuristic on friendlyName)
  [19:29:16.908] I/DeviceRepository: save: BrandDetector result → torima for 192.168.0.202
  [19:29:16.908] I/DeviceRepository: save: NEW device added — "HY350Max-6282" ip=192.168.0.202 brand=torima manufacturer=none
  [19:29:16.973] V/DeviceRepository: save: persisted — total 3 device(s)
  [19:29:18.636] I/RemoteController: ── connect() start ──────────────────────────────────
  [19:29:18.637] I/RemoteController: device: "HY350Max-6282" ip=192.168.0.202 port=null brand=torima method=ssdp
  [19:29:18.638] D/RemoteController: state: RemoteConnectionState.disconnected → RemoteConnectionState.connecting
  [19:29:18.639] D/AppShell: connection state changed: connecting
  [19:29:18.640] D/RemoteController: step 1: resolving brand (detectedBrand=torima)
  [19:29:18.640] V/RemoteController: brand already known: torima, skipping probe
  [19:29:18.641] I/RemoteController: step 1 done: effectiveBrand=torima
  [19:29:18.641] D/RemoteController: step 2: TCP reachability check for 192.168.0.202 (brand=torima)
  [19:29:18.642] D/RemoteController: TCP check: connecting to 192.168.0.202:5555 (brand=torima, timeout=4s)
  [19:29:18.711] W/RemoteController: TCP check: ✗ 192.168.0.202:5555 unreachable after 68ms (osError=111, msg=Connection refused)
  [19:29:18.711] E/RemoteController: step 2 failed: Device unreachable (192.168.0.202:5555). Make sure the TV is on and on the same network. (Connection refused)
  [19:29:18.712] D/RemoteController: state: RemoteConnectionState.connecting → RemoteConnectionState.error
  [19:29:18.712] D/AppShell: connection state changed: error
  [19:29:19.080] V/DiscoveryManager: processDevice: UPDATE candidate for 192.168.0.202 existing.method=ssdp incoming.method=mdns
  [19:29:19.081] V/DiscoveryManager: processDevice: SSDP master already has good name "HY350Max-6282", ignoring mdns update
  [19:29:23.156] D/RemoteController: dispose() — disconnecting protocol if active
  [19:29:23.156] D/AppShell: connection state changed: disconnected
  [19:29:24.594] I/RemoteController: ── connect() start ──────────────────────────────────
  [19:29:24.594] I/RemoteController: device: "HY350Max-6282" ip=192.168.0.202 port=null brand=torima method=ssdp
  [19:29:24.594] D/RemoteController: state: RemoteConnectionState.disconnected → RemoteConnectionState.connecting
  [19:29:24.594] D/AppShell: connection state changed: connecting
  [19:29:24.594] D/RemoteController: step 1: resolving brand (detectedBrand=torima)
  [19:29:24.594] V/RemoteController: brand already known: torima, skipping probe
  [19:29:24.594] I/RemoteController: step 1 done: effectiveBrand=torima
  [19:29:24.595] D/RemoteController: step 2: TCP reachability check for 192.168.0.202 (brand=torima)
  [19:29:24.595] D/RemoteController: TCP check: connecting to 192.168.0.202:5555 (brand=torima, timeout=4s)
  [19:29:24.665] W/RemoteController: TCP check: ✗ 192.168.0.202:5555 unreachable after 70ms (osError=111, msg=Connection refused)
  [19:29:24.665] E/RemoteController: step 2 failed: Device unreachable (192.168.0.202:5555). Make sure the TV is on and on the same network. (Connection refused)
  [19:29:24.666] D/RemoteController: state: RemoteConnectionState.connecting → RemoteConnectionState.error
  [19:29:24.666] D/AppShell: connection state changed: error
  [19:29:28.937] I/DiscoveryManager: discovery timeout reached (15s) — stopping
  [19:29:28.938] I/DiscoveryManager: stopDiscovery(): stopping all sources
  [19:29:28.945] D/DiscoveryManager: closing main stream controller (total unique devices found: 2)
  [19:29:28.947] I/DiscoveryManager: stopDiscovery(): all sources stopped, 2 devices in cache
  [19:29:28.948] D/DiscoveryManager: SSDP finished (activeSources remaining=1)
  [19:29:28.949] D/DiscoveryManager: mDNS finished (activeSources remaining=0)
  [19:29:28.949] I/DiscoveryManager: all primary sources done — closing stream
  [19:29:31.937] D/RemoteController: dispose() — disconnecting protocol if active
  [19:29:31.938] D/AppShell: connection state changed: disconnected
  [19:29:33.624] I/RemoteController: ── connect() start ──────────────────────────────────
  [19:29:33.624] I/RemoteController: device: "HY350Max-6282" ip=192.168.0.202 port=null brand=torima method=ssdp
  [19:29:33.624] D/RemoteController: state: RemoteConnectionState.disconnected → RemoteConnectionState.connecting
  [19:29:33.625] D/AppShell: connection state changed: connecting
  [19:29:33.625] D/RemoteController: step 1: resolving brand (detectedBrand=torima)
  [19:29:33.625] V/RemoteController: brand already known: torima, skipping probe
  [19:29:33.625] I/RemoteController: step 1 done: effectiveBrand=torima
  [19:29:33.625] D/RemoteController: step 2: TCP reachability check for 192.168.0.202 (brand=torima)
  [19:29:33.626] D/RemoteController: TCP check: connecting to 192.168.0.202:5555 (brand=torima, timeout=4s)
  [19:29:33.704] W/RemoteController: TCP check: ✗ 192.168.0.202:5555 unreachable after 77ms (osError=111, msg=Connection refused)
  [19:29:33.704] E/RemoteController: step 2 failed: Device unreachable (192.168.0.202:5555). Make sure the TV is on and on the same network. (Connection refused)
  [19:29:33.704] D/RemoteController: state: RemoteConnectionState.connecting → RemoteConnectionState.error
  [19:29:33.704] D/AppShell: connection state changed: error

## Philips to do
- ambligiht genel olarak dogru ama sabit renk durumlarinda renk secimi calismiyo ve ambligiht kapanmiyo
- klavye calismiyor arastirma yapilacak en kotu klavye kismini klavye takilmis gibi algilatiriz (arastir) bu hatadan dolayi sesli komut da calismiyor
- touchpad ozellikleri su olacak tv ye kendini bir mouse gibi tanitacak ve ekranda imlec ciktigi durumlarda laptop touchpadi gibi islev gorucek. sunu istiyorum o kisim normal bir bilgisayar toucpadi gibi calisacak buna dikkat et. en bastan duzenle islevini
- apps dogru calismiyor arastirma yapilacak, appsler bulunamiyor ve mevcuttta gozukenlere de gidilemiyor. apiv6 neyse
