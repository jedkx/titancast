# TitanCast — Proje Genel Notları

Bu dosya projeyle ilgili her şeyi kapsar. İlerideki chatlerde bağlam olarak kullan.

---

## 1. Proje Özeti

**TitanCast** — Flutter ile yazılmış çapraz platform evrensel TV uzaktan kumanda uygulaması.
Aynı ağdaki akıllı TV'leri otomatik keşfeder ve brand'e göre doğru protokolü seçip bağlanır.

- **Platform:** Flutter (Dart), `sdk: ^3.11.0`
- **Hedef platformlar:** Android, iOS, Windows, macOS, Linux, Web
- **Paket adı:** `titancast`
- **Versiyon:** `1.0.0+1`

---

## 2. Proje Klasör Yapısı

```
lib/
├── main.dart                     # Uygulama girişi, SystemChrome ayarları
├── core/                         # Yardımcı altyapı
│   ├── app_logger.dart           # AppLogger (I/D/V/W/E seviyeleri)
│   ├── constants.dart
│   ├── enhanced_logging.dart
│   ├── exceptions.dart
│   ├── result.dart
│   ├── security.dart
│   └── validation.dart
├── data/                         # Kalıcı veri katmanı
│   ├── active_device.dart        # Global ValueNotifier'lar (seçili cihaz, bağlantı durumu)
│   ├── device_repository.dart    # SharedPreferences tabanlı cihaz persistansı
│   └── seed_devices.dart
├── discovery/                    # Ağ keşif motoru
│   ├── discovery_manager.dart    # SSDP + mDNS + NetworkProbe koordinatörü
│   ├── discovery_model.dart      # DiscoveredDevice, DiscoveryMethod, DeviceType enum'ları
│   ├── ip/
│   │   └── ip_discovery.dart     # Manuel IP adresi girişi
│   ├── network/
│   │   ├── ssdp_discovery.dart
│   │   ├── mdns_discovery.dart
│   │   └── network_probe_discovery.dart  # Port probe (1925,1926,8008,8080)
│   └── scanner/
│       └── qr_scanner_discovery.dart     # QR kod tarama (mobile_scanner)
├── remote/                       # Protokol ve brand yönetimi
│   ├── tv_brand.dart             # TvBrand enum
│   ├── remote_command.dart       # RemoteCommand enum (tüm tuşlar/komutlar)
│   ├── remote_controller.dart    # ChangeNotifier facade — bağlantı lifecycle yöneticisi
│   ├── brand_detector.dart       # 4 katmanlı brand tespit motoru
│   ├── oui_database.dart         # MAC OUI → üretici eşleme
│   └── protocol/
│       ├── tv_protocol.dart      # Abstract base: connect/sendCommand/sendText/disconnect
│       ├── samsung_protocol.dart
│       ├── lg_protocol.dart
│       ├── sony_protocol.dart
│       ├── philips_protocol.dart
│       ├── android_tv_protocol.dart
│       ├── torima_protocol.dart
│       ├── unknown_protocol.dart
│       └── adb_key_store.dart    # RSA keypair kalıcı depolama (flutter_adb için)
└── ui/
    ├── app_shell.dart            # 3 sekme: Devices / Remote / Logs
    ├── devices/
    │   ├── devices_screen.dart
    │   ├── device_list_item.dart
    │   ├── device_filter_chips.dart
    │   └── device_menu_sheet.dart  # Cihaz menüsü (bağlan/sil/yeniden adlandır/marka seç)
    ├── remote/
    │   ├── remote_screen.dart      # Ana kumanda ekranı
    │   ├── brand_menu_sheet.dart   # Marka-özel ek özellikler (Ambilight vb.)
    │   ├── philips_remote_state.dart
    │   ├── brands/
    │   │   └── philips/
    │   │       └── ambilight_tab.dart
    │   └── widgets/               # Remote UI bileşenleri
    ├── find_tv/
    │   └── find_tv_screen.dart    # QR / Manuel IP ile cihaz ekleme
    ├── logs/
    │   └── logs_screen.dart       # In-app log ekranı
    └── shared/                    # Paylaşılan UI bileşenleri
```

---

## 3. Bağımlılıklar (pubspec.yaml)

| Paket | Versiyon | Kullanım |
|-------|----------|----------|
| `flutter_adb` | ^0.1.1 | ADB over WiFi (Torima + AndroidTV protokolleri) |
| `web_socket_channel` | ^3.0.1 | Samsung, LG, WebSocket bağlantıları |
| `http` | ^1.2.0 | Philips (JointSpace), Sony (IRCC-IP) HTTP istekleri |
| `crypto` | ^3.0.3 | Philips Android TV Digest Auth (MD5 hesaplama) |
| `shared_preferences` | ^2.3.0 | Cihaz listesi + ADB RSA key + LG client-key persistansı |
| `multicast_dns` | ^0.3.2+4 | mDNS keşif servisi |
| `network_info_plus` | ^7.0.0 | Wi-Fi SSID bilgisi |
| `connectivity_plus` | ^7.0.0 | Ağ durumu izleme |
| `mobile_scanner` | ^7.2.0 | QR kod tarama |
| `speech_to_text` | ^7.0.0 | Sesli arama / tuşlama |
| `permission_handler` | ^12.0.1 | Android/iOS izin yönetimi |
| `xml` | ^6.3.0 | SSDP/UPnP XML parse |

---

## 4. Keşif Motoru (Discovery)

### Modlar
| Mod | Açıklama |
|-----|----------|
| `network` | SSDP + mDNS eş zamanlı + 200ms sonra port probe |
| `manualIp` | Tek IP'ye direkt bağlantı dener |
| `qrScan` | QR kodundan IP/port okur |

### Network Modu Akışı
1. `SsdpDiscoveryService` — UDP multicast 239.255.255.250:1900 (`M-SEARCH`)
2. `MdnsDiscoveryService` — `_googlecast._tcp`, `_airplay._tcp` vb. mDNS kayıtları
3. `NetworkProbeDiscoveryService` — port 1925, 1926, 8008, 8080 probe
4. Tüm kaynaklar `DiscoveryManager`'a stream eder
5. Her cihaz `DeviceRepository.save()` üzerinden `BrandDetector.detect()` çalıştırır
6. `DeviceRepository` markayı bulunca SharedPreferences'a yazar (sonraki açılışta tekrar detection çalışmaz)

### Timeout: 15 saniye (varsayılan)

### `DiscoveredDevice` Modeli
```dart
String ip
String friendlyName
DiscoveryMethod method      // ssdp | mdns | networkProbe | manualIp | qr
String? location            // SSDP LOCATION header (UPnP XML URL)
String? serviceType         // SSDP ST header
String? manufacturer        // UPnP XML'den
String? modelName
int? port
Map<String, dynamic> rawHeaders
String? ssid                // Hangi Wi-Fi'dan keşfedildi
String? customName          // Kullanıcının verdiği takma ad
DateTime addedAt
TvBrand? detectedBrand      // BrandDetector sonucu
```

---

## 5. Brand Detector — 4 Katmanlı Waterfall

`lib/remote/brand_detector.dart`

### Katman 1 — SSDP Service Type Stringleri (en güvenilir)
Gerçek SSDP paket yakalamalarından + Home Assistant manifestlerinden çıkarıldı.
| Eşleşme | Marka |
|---------|-------|
| `urn:samsung.com:device:*` | Samsung |
| `urn:lge-com:*` veya `urn:lge-com:service:*` | LG |
| `urn:schemas-sony-com:*` | Sony |
| `urn:philips-com:*` veya `jointspace` | Philips |
| `_googlecast._tcp` | Android TV / Google TV |

### Katman 2 — UPnP Manufacturer String
UPnP XML `<manufacturer>` alanı: "Samsung Electronics", "LG Electronics", "Sony Corporation", "Philips", "TP Vision", vb.

### Katman 3 — MAC OUI ARP Lookup (sadece Android, native)
```bash
arp -n <ip>
```
**Not:** Android'de `arp` komutu mevcut değil → her zaman `ProcessException: No such file or directory` hatası alır. Bu katman pratikte hiç çalışmıyor.

### Katman 4 — Heuristic (friendlyName regex)
```dart
// Torima projector modelleri
RegExp(r'\bhy3[0-9]{2}\b|\bhy350\b|hy350max|\bt1[1-9]\b|\bt20\b')
```

### `TvBrand` Enum Değerleri
```
samsung, lg, sony, philips, hisense, tcl, panasonic, sharp, toshiba,
google, amazon, apple, roku, torima, androidTv, unknown
```

---

## 6. RemoteController — Bağlantı Lifecycle

`lib/remote/remote_controller.dart` — `ChangeNotifier`

### connect() Adımları
1. **Step 1 — Brand belirleme:**
   - Zaten biliyorsa (detectedBrand ≠ null) atla
   - Bilinmiyorsa: port probe ile brand tespit et (4s timeout)
2. **Step 2 — TCP reachability check:**
   Markaya göre belirlenen porta `Socket.connect` (timeout: 4s)
3. **Step 3 — Protocol build + connect:**
   `_buildProtocolForBrand()` ile doğru TvProtocol instance'ı oluştur, `protocol.connect()` çağır

### TCP Port Haritası
| Marka | Port |
|-------|------|
| Samsung | 8001 |
| LG | 3000 |
| Sony | 80 |
| Torima | 5555 |
| AndroidTV / Hisense / TCL / Sharp / Toshiba / Google | 5555 |
| Philips | (port probe — 1925 veya 1926) |

### RemoteConnectionState
`disconnected → connecting → connected | error`

---

## 7. Protokoller

### Samsung — `SamsungProtocol`
- **Protokol:** Samsung Remote WebSocket API (Tizen 2016+)
- **Endpoint:** `ws://<ip>:8001/api/v2/channels/samsung.remote.control`
- **Auth:** İlk bağlantıda TV pairing promptu çıkar, kullanıcı "Allow" der
- **Komut:** `{"method":"ms.remote.control","params":{"Cmd":"Click","DataOfCmd":"KEY_UP"}}`
- **Referans:** https://github.com/xchwarze/samsung-tv-ws-api

### LG — `LgProtocol`
- **Protokol:** SSAP (Second Screen Application Protocol, webOS 2014+)
- **Endpoint:** `ws://<ip>:3000`
- **Auth:** İlk bağlantı pairing → `client-key` alır ve `SharedPreferences`'a yazar (`lg_client_key_<ip>`)
- **Komut:** `ssap://com.webos.service.ime/sendEnterKey` gibi ssap:// URI'lar
- **Referans:** https://github.com/hobbyquaker/lgtv2 | https://github.com/klattimer/LGWebOSRemote

### Sony — `SonyProtocol`
- **Protokol:** IRCC-IP over HTTP (Bravia 2013+)
- **Endpoint:** `POST http://<ip>/sony/IRCC`
- **Auth:** `X-Auth-PSK` header (kullanıcı TV Ayarlar > IP Control'dan PSK set eder)
- **Payload:** SOAP envelope + base64-encoded IRCC command code
- **Referans:** https://pro-bravia.sony.net/develop/integrate/ircc-ip/

### Philips — `PhilipsProtocol` (~1006 satır, en karmaşık)
- **Protokol:** JointSpace JSON API
  - Eski (2011-2015) : `http://<ip>:1925/<ver>/input/key` — auth yok
  - Android TV (2016+) : `https://<ip>:1926/<ver>/input/key` — Digest Auth
- **Auth:** Android TV modeller için önce PIN pairing gerekiyor (TV ekranında PIN gösterir)
  - `PhilipsPairingRequiredException` fırlar → UI PIN dialog açar → `philipsPair(pin)` çağrılır
  - `SharedPreferences`'ta `philips_user_<ip>`, `philips_pass_<ip>`, `philips_devid_<ip>` saklanır
- **Keyboard polling:** `Timer` ile TV'nin on-screen keyboard durumu poll edilir → `onKeyboardAppeared` callback
- **Ambilight:** `BrandMenuSheet`'te ayrı tab var

### Android TV / Google TV — `AndroidTvProtocol`
- **Protokol:** ADB over WiFi (TCP 5555)
- **Kütüphane:** `flutter_adb`
- **Auth:** RSA keypair → `AdbKeyStore.loadOrCreate()` ile SharedPreferences'ta kalıcı
- **Komut:** `input keyevent <KEYCODE>` shell
- **İlk bağlantı:** TV ekranında RSA fingerprint onayı → `androidtv_adb_auth_<ip>` kaydedilir
- **Kapsanan markalar:** androidTv, hisense, tcl, sharp, toshiba, google

### Torima — `TorimaProtocol`
- **Cihazlar:** HY300, HY320, HY350, HY350Max, T11, T12, T20 projektörler
- **Protokol:** ADB over WiFi (TCP 5555), `flutter_adb` kütüphanesi
- **Komut:** `input keyevent <KEYCODE>` + `am start` (uygulama açma)
- **Ön koşul (tek seferlik):** Ayarlar → Hakkında → Derleme No. 7x tap → Geliştirici Seçenekleri → USB Hata Ayıklama + ADB over Network
- **Auth:** SharedPreferences'ta `torima_adb_auth_<ip>`
- **Bilinen sorun:** Port 5555 kapalıyken `osError=111 Connection refused` → kullanıcı ADB over Network açmalı

---

## 8. RemoteCommand Enum — Desteklenen Komutlar

```
power, powerOn, powerOff
volumeUp, volumeDown, mute
channelUp, channelDown
up, down, left, right, ok, back, home, menu
play, pause, stop, rewind, fastForward
source
netflix, youtube, spotify, prime, disney, twitch
colorRed, colorGreen, colorYellow, colorBlue
info, guide, subtitle, teletext
record, nextTrack, prevTrack
exit, tv
ambilight                          (Philips-specific)
key0–key9
```

---

## 9. State Yönetimi

Basit, ViewModel yok, `ChangeNotifier` + global `ValueNotifier`:

```dart
// lib/data/active_device.dart
final activeDeviceNotifier = ValueNotifier<DiscoveredDevice?>(null);
final activeConnectionStateNotifier = ValueNotifier<RemoteConnectionState>(...);
```

- `DevicesScreen` → `activeDeviceNotifier.value = device` (kullanıcı seçince)
- `RemoteScreen` → `RemoteController` oluşturur, `addListener` ile dinler
- `AppShell` → bağlantı kurulunca otomatik Remote tab'ına geçer

---

## 10. UI Akışı

### AppShell (3 sekme → `IndexedStack`)
1. **DevicesScreen** — keşfedilen cihazlar, filter chips (All / TV / Speaker / Other)
2. **RemoteScreen** — aktif cihaza kumanda, touchpad, ses kontrolü
3. **LogsScreen** — `AppLogger` çıktıları (in-app debug)

### DevicesScreen önemli davranışlar
- Discovery başlangıçta otomatik çalışır (15s)
- `device_filter_chips.dart` ile DeviceType filtresi
- Router/modem'ler `DeviceType.modem` olarak sınıflandırılır (Archer C6 gibi isimler)
- **Bilinen sorun:** Cihaz sayısı sayarken modem'leri de sayıyor
- **Bilinen sorun:** Wi-Fi SSID'ye göre gruplandırma yapılmıyor (ssid field var ama UI'da kullanılmıyor)

### DeviceMenuSheet
Cihaza long press / menü butonu:
- Bağlan / Bağlantıyı kes
- Yeniden adlandır
- Sil
- **Marka seç** (Brand picker) — yanlış tespit durumunda kullanıcı override edebilir
  Listede: philips, samsung, lg, sony, androidTv, hisense, tcl, panasonic, sharp, toshiba, torima

### BrandMenuSheet
Marka-özel ek özellikler (RemoteScreen'de menü ikonuyla açılır):
- Tüm markalar: temel navigasyon, renk tuşları, uygulama kısayolları
- Philips'e özel: **Ambilight** tab (stil seçimi, renk, kapatma)

---

## 11. Logging Sistemi

`lib/core/app_logger.dart`

Seviyeler: `V` (verbose) / `D` (debug) / `I` (info) / `W` (warning) / `E` (error)

Format: `[HH:mm:ss.mmm] LEVEL/TAG: message`

Log hem Flutter debug console'a hem de in-app `LogsScreen`'e yazılır.

---

## 12. Veri Kalıcılığı (SharedPreferences Keys)

| Key | İçerik |
|-----|--------|
| `titancast_devices` | JSON — tüm cihaz listesi |
| `torima_adb_auth_<ip>` | bool — Torima ADB kabul edildi mi |
| `androidtv_adb_auth_<ip>` | bool — AndroidTV ADB kabul edildi mi |
| `lg_client_key_<ip>` | string — LG webOS client key |
| `philips_user_<ip>` | string — Philips Digest Auth kullanıcı adı |
| `philips_pass_<ip>` | string — Philips Digest Auth şifre |
| `philips_devid_<ip>` | string — Philips device ID |
| `adb_rsa_private_key` | string — ADB RSA private key (flutter_adb) |
| `adb_rsa_public_key` | string — ADB RSA public key |

---

## 13. Bilinen Açık Sorunlar / TODO

### Genel
- [ ] Cihaz count'unda router/modem'ler hariç tutulmalı
- [ ] Wi-Fi SSID'ye göre cihaz gruplama (field var, UI yok)
- [ ] MAC OUI (layer 3) pratikte çalışmıyor, optimize edilmeli veya kaldırılmalı
- [ ] Log ekranı: 500+ satır kopyalanabilir olmalı
- [ ] Genel kod kalitesi: gereksiz yorum satırları temizlenmeli, ingilizce yorumlar standartlaştırılmalı
- [ ] Mimari: Touchpad gibi özellikler ayrı modüle alınmalı

### Philips
- [ ] Ambilight sabit renk durumunda renk seçimi çalışmıyor
- [ ] Ambilight kapatma çalışmıyor

### Torima
- [ ] Kullanıcı ADB over Network'ü açmadıysa `Connection refused` alıyor
  - Daha iyi hata mesajı + adım adım yönlendirme gerekli (zaten kısmen var)

---

## 14. Geliştirme Ortamı

- **Flutter SDK:** ^3.11.0
- **Android SDK:** `C:\Users\ccosk\AppData\Local\Android\Sdk`
- **ADB yolu:** `C:\Users\ccosk\AppData\Local\Android\Sdk\platform-tools\adb.exe`
- **Java (Android Studio JBR):** `C:\Program Files\Android\Android Studio\jbr`
  - Build için: `$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"`
- **Android local.properties:** `C:\1-Extra\titancast\android\local.properties`

---

## 15. İlgili Diğer Not Dosyaları

- [TORIMA_NOTES.md](TORIMA_NOTES.md) — Torima + ADT-3 aksesuar deneylerinin detaylı notu
  (ADB bağlantı sorunu, TitanCast Receiver deney/iptal geçmişi, Android 14 ECM bilgisi)
