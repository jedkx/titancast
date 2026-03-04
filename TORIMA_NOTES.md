# Torima & ADT-3 Projector — Geliştirme Notları

Bu dosya Torima markalı projektörler ve ADT-3 cihazıyla yapılan testlerden öğrenilen her şeyi içerir.
İlerideki chatlerde referans olarak kullan.

---

## 1. Torima Projector — Genel Bilgi

### Desteklenen Modeller
- HY300, HY320, HY350, HY350Max, T11, T12, T20
- Bunların hepsi Android tabanlı projector/mini TV

### Brand Detection (TitanCast'ta)
Torima cihazları SSDP üzerinden `MediaRenderer` serviceType ile yayın yapar, device name'de model numarası geçer.
- Layer 1 (serviceType): **Miss** — `MediaRenderer` generic, marka ayırt etmiyor
- Layer 2 (manufacturer): **Miss** — manufacturer field boş gelir (`null`)
- Layer 3 (MAC OUI): **Miss** — `arp -n` komutu Android'de çalışmıyor (`ProcessException: No such file or directory`)
- Layer 4 (heuristic name): **HIT** — `HY350Max-6282` gibi device name'i regex ile yakalar

**Brand detector regex:**
```dart
RegExp(r'\bhy3[0-9]{2}\b|\bhy350\b|hy350max|\bt1[1-9]\b|\bt20\b')
```

### Bağlantı Yöntemi: ADB over WiFi (TCP port 5555)
- `flutter_adb` paketi kullanılıyor
- İlk bağlantıda projector ekranında RSA key onay dialogu çıkıyor — kullanıcı "İzin Ver" demeli
- Onay sonrası `SharedPreferences`'a `torima_adb_auth_<ip>` key'i kaydediliyor
- Komutlar: `input keyevent <KEYCODE>` shell komutu olarak gönderiliyor

---

## 2. Torima — Bilinen Sorun: "Unreachable" (port 5555 Connection Refused)

### Semptom
```
TCP check: ✗ 192.168.0.202:5555 unreachable after 70ms (osError=111, msg=Connection refused)
```

### Kök Neden
Torima/Android projector fabrika ayarlarında **ADB over Network kapalı** geliyor.
TCP port 5555 sadece "ADB over Network" aktifken dinleniyor.

### Çözüm (Kullanıcı Tarafında)
1. Projector Ayarlar → **Hakkında** → "Derleme Numarası"na **7 kez** bas → Geliştirici Seçenekleri açılır
2. **Geliştirici Seçenekleri** → "USB Hata Ayıklama" → **Aç**
3. **Geliştirici Seçenekleri** → "ADB over Network" veya "Kablosuz ADB" → **Aç** *(listede yoksa USB debug yeterlidir)*
4. Projector'ı aynı Wi-Fi'e bağla, TitanCast'tan tekrar bağlan

### Neden Kod Tarafında Çözülemiyor?
ADB portunu remotely açmanın yolu yok — önce bir kez cihaz fiziksel erişim gerektiriyor.
Bağlandıktan sonra her şey otomatik.

---

## 3. TitanCast Receiver Projesi — Deney ve Sonuçlar

> **Karar: Proje iptal edildi.** Tüm kodlar geri alındı, `titancast-receiver/` klasörü silindi.

### Amaç
ADT-3 projektör üzerinde (Android 14) çalışan bir companion app yaparak
D-pad navigasyonunu AccessibilityService üzerinden sağlamak.
TitanCast Flutter app → WebSocket → Receiver APK → `performGlobalAction()` → D-pad

### Cihaz Bilgileri (Test Ortamı)
- **Model:** ADT-3 (Android TV reference device)
- **OS:** Android 14, HTC Lumina OS (özelleştirilmiş firmware)
- **ADB ID:** `5c000c81c8050881b8f`
- **Root:** Yok (`adbd cannot run as root in production builds`)
- **ADB:** USB bağlantıyla çalıştı, `adb root` komutu reddetti

---

## 4. D-Pad Sorunu ve Çözümü ✅

### Sorun
RemoteCommand gönderildiğinde D-pad tuşları çalışmıyordu.

### Başlangıçtaki Hata
`InputManager.injectInputEvent()` reflection yöntemi kullanılmıştı:
```kotlin
// YANLIŞ — Production build'de çalışmaz
val inputManager = context.getSystemService(Context.INPUT_SERVICE)
val method = InputManager::class.java.getDeclaredMethod(
    "injectInputEvent", InputEvent::class.java, Int::class.javaPrimitiveType)
method.invoke(inputManager, keyEvent, 0)
```
Bu yöntem `INJECT_EVENTS` permission gerektirir, sadece system app'lerde var.

### Çözüm
`AccessibilityService.performGlobalAction()` ile Android'in kendi DPAD global action'ları kullanıldı:
```kotlin
// DOĞRU — API 33+ (Android 13+) üzerinde çalışır
private const val GLOBAL_DPAD_UP     = 16
private const val GLOBAL_DPAD_DOWN   = 17
private const val GLOBAL_DPAD_LEFT   = 18
private const val GLOBAL_DPAD_RIGHT  = 19
private const val GLOBAL_DPAD_CENTER = 20

fun dispatchKeyEvent(keycode: Int) {
    val globalAction: Int? = when (keycode) {
        KeyEvent.KEYCODE_DPAD_UP     -> GLOBAL_DPAD_UP
        KeyEvent.KEYCODE_DPAD_DOWN   -> GLOBAL_DPAD_DOWN
        KeyEvent.KEYCODE_DPAD_LEFT   -> GLOBAL_DPAD_LEFT
        KeyEvent.KEYCODE_DPAD_RIGHT  -> GLOBAL_DPAD_RIGHT
        KeyEvent.KEYCODE_DPAD_CENTER -> GLOBAL_DPAD_CENTER
        KeyEvent.KEYCODE_ENTER       -> GLOBAL_DPAD_CENTER
        KeyEvent.KEYCODE_BACK        -> GLOBAL_ACTION_BACK
        KeyEvent.KEYCODE_HOME        -> GLOBAL_ACTION_HOME
        else -> null
    }
    if (globalAction != null) {
        performGlobalAction(globalAction)
    }
}
```
**Sonuç: D-pad çalıştı ✅ (kullanıcı onayladı)**

---

## 5. Ana Sorun: AccessibilityService Kapanıyor ❌

### Semptom
Accessibility Settings'e gidip TitanCast Receiver'ı açıyorsun, geri çıkınca birkaç saniye/dakika içinde servis kapanıyor.

### Kök Neden: Android 14 "Restricted Settings" / ECM (Enhanced Confirmation Mode)

Android 14'te (API 34) sideload edilmiş APK'lar (Play Store dışından yüklenmiş) için
**Restricted Settings** özelliği devreye giriyor. Bu özellik accessibility servislerini
otomatik olarak devre dışı bırakıyor.

**Kaynak:** Android 14 `PackageInstaller` ve `EnhancedConfirmationManager` — sideloaded APK'lara
`OPSTR_ACCESS_RESTRICTED_SETTINGS` op'u `MODE_ERRORED` olarak veriliyor.

### HTC Lumina OS "Watchdog" Davranışı
ADT-3'teki HTC Lumina OS, ADB üzerinden manuel olarak verilen
`settings put secure enabled_accessibility_services` komutunu **4-5 saniye içinde** geri alıyor.
**TV arayüzünden elle açılan** servis ise daha uzun sürüyor (~3 dakika dayanıyor).

---

## 6. Denenen Yöntemler ve Sonuçları

### Yöntem 1: `adb root` ile tam erişim
```powershell
& $adb root
# → "adbd cannot run as root in production builds"
```
**Sonuç: ❌ Başarısız** — Production build, root yok.

### Yöntem 2: `pm set-installer` ile Play Store installer simülasyonu
```powershell
& $adb shell pm set-installer dev.titancast.receiver com.android.vending
# → SecurityException: caller does not hold INSTALL_PACKAGES permission
```
**Sonuç: ❌ Başarısız** — Sertifika uyuşmazlığı, system-level permission gerekiyor.

### Yöntem 3: `appops set REQUEST_INSTALL_PACKAGES allow`
```powershell
& $adb shell appops set dev.titancast.receiver REQUEST_INSTALL_PACKAGES allow
# → Exit 0 (başarılı göründü)
```
**Sonuç: ❌ Yetersiz** — Bu op sadece APK kurulum iznini etkiliyor, ECM'i bypass etmiyor.

### Yöntem 4: `appops set RUN_USER_INITIATED_JOBS allow`
```powershell
& $adb shell appops set dev.titancast.receiver RUN_USER_INITIATED_JOBS allow
```
**Sonuç: ❌ Yetersiz** — `ACCESS_RESTRICTED_SETTINGS` op'unu etkilemiyor.

### Yöntem 5: `device_config` ile ECM'i devre dışı bırakma ✅ (Kısmi)
```powershell
& $adb shell device_config put enhanced_confirmation_mode enabled false
# → (boş çıktı = başarılı)
& $adb shell device_config get enhanced_confirmation_mode enabled
# → false
```
**Sonuç: ✅ ECM devre dışı kaldı, reboot sonrası da devam etti.**

Ancak HTC Lumina OS'un kendi watchdog mekanizması **ADB ile verilen accessibility iznini**
4-5 saniye içinde geri alıyordu. ADB üzerinden verilenler güvenilir değil.

### Yöntem 6: TV Arayüzünden Manuel Açma (En İyi Sonuç)
Settings panelinden el ile TitanCast Receiver aktif edilince:
- Log: `00:23:54` → servis `connected`
- Log: `00:27:06` → `destroyed` (yaklaşık 3 dakika dayanıyor)

**Sonuç: 🟡 Kısmen çalışıyor ama kalıcı değil.**
ECM kapatıldıktan sonra TV arayüzünden açılan servisin daha uzun süre dayanıp dayanmadığı
tam test edilemedi (test bitmeden iptal edildi).

---

## 7. Genel Android AccessibilityService Bilgileri

### Sideload APK + Accessibility Hiyerarşisi (Android 14)
1. **System app** (platform imzalı) → Her şeyi yapabilir
2. **Play Store app** (Google's installer) → Restricted Settings yok
3. **Sideload APK** (ADB / başka kaynak) → **Restricted Settings ENGEL**, ECM devreye giriyor
4. **ADB shell ile zorla açılan** servis → OS watchdog 4-5s içinde geri alıyor (Lumina OS özelliği)

### `accessibility_service.xml` Gerekli Flag'ler (D-pad için)
```xml
<accessibility-service
    android:accessibilityFlags="flagRetrieveInteractiveWindows"
    android:canRetrieveWindowContent="true"
    android:canPerformGestures="true" />
```

### `GLOBAL_ACTION_*` Sabitleri (AccessibilityService API)
| Sabit | Değer | Açıklama |
|-------|-------|----------|
| `GLOBAL_ACTION_BACK` | 1 | Geri tuşu |
| `GLOBAL_ACTION_HOME` | 2 | Home tuşu |
| `GLOBAL_ACTION_RECENTS` | 3 | Son uygulamalar |
| `GLOBAL_ACTION_DPAD_UP` | 16 | D-pad yukarı (API 33+) |
| `GLOBAL_ACTION_DPAD_DOWN` | 17 | D-pad aşağı (API 33+) |
| `GLOBAL_ACTION_DPAD_LEFT` | 18 | D-pad sol (API 33+) |
| `GLOBAL_ACTION_DPAD_RIGHT` | 19 | D-pad sağ (API 33+) |
| `GLOBAL_ACTION_DPAD_CENTER` | 20 | D-pad merkez/OK (API 33+) |

> DPAD global action'ları **API 33 (Android 13)** ile eklendi. Daha eski cihazlarda `performGlobalAction(16)` çağrısı `false` döner ve hiçbir şey olmaz.

---

## 8. Gelecekte Denenebilecek Yaklaşımlar

Eğer ileride bu konu tekrar gündeme gelirse:

### Opsiyon A: Cihaz Üreticisiyle İletişim
ADT-3 gibi projector üreticilerine ulaşıp APK'yı sistema-level sign ettirmek.
Pratikte imkansız/zor.

### Opsiyon B: Companion App'i Play Store'a Yüklemek
Play Store üzerinden dağıtılan APK'lar Restricted Settings sorununu yaşamıyor.
Ama Play Store TV app politikaları var.

### Opsiyon C: ADB Direkt Kontrol (Torima yöntemi gibi)
Accessibility service yerine ADB üzerinden `input keyevent` shell komutları göndermek.
Şu an TorimaProtocol bunu yapıyor. Receiver'a gerek kalmaz, doğrudan ADB yeterli.
**Sorun:** Kullanıcının ADB over Network'ü açması gerekiyor (Torima'daki aynı soruna bak → Bölüm 2).

### Opsiyon D: Android TV Input Method Service
Remote app olarak `InputMethodService` kullanmak — text input için çalışıyor ama navigasyon için yetersiz.

### Opsiyon E: `USE_INPUT_MONITORING` + Companion Device
Sadece paired companion cihaz olarak konfigüre edilince bazı özeller unlock olabilir.
Araştırılmadı.

---

## 9. TitanCast Flutter App'te Receiver İzleri (Temizlendi)

Projeye eklenen receiver kodları geri alındı:

| Dosya | Yapılan Değişiklik (geri alındı) |
|-------|----------------------------------|
| `lib/remote/tv_brand.dart` | `TvBrand.receiver` enum değeri eklenmişti |
| `lib/remote/brand_detector.dart` | `_titancast._tcp` mDNS tespiti eklenmişti |
| `lib/remote/remote_controller.dart` | port 7676, ReceiverProtocol import ve case'i eklenmişti |
| `lib/remote/protocol/receiver_protocol.dart` | Yeni dosya — WebSocket client eklenmişti |
| `lib/ui/devices/device_menu_sheet.dart` | Brand picker'a `TvBrand.receiver` eklenmişti |
| `lib/ui/devices/device_list_item.dart` | Brand label map'e `TvBrand.receiver` eklenmişti |

---

## 10. Özet

| Konu | Durum | Not |
|------|-------|-----|
| Torima ADB bağlantısı | ✅ Çalışıyor | Kullanıcı ADB over Network açmalı |
| Torima D-pad / keyevent | ✅ Çalışıyor | `input keyevent` shell |
| ADT-3 D-pad (receiver) | ✅ Fix bulundu | `performGlobalAction(GLOBAL_DPAD_*)` |
| ADT-3 Accessibility kalıcılık | ❌ Çözülemedi | Android 14 ECM + HTC Lumina OS watchdog |
| TitanCast Receiver projesi | ❌ İptal | Accessibility sorunu aşılamadı |
