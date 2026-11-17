# FloDesk (RustDesk rebrand)
```bash
git clone --recurse-submodules -b flodesk https://github.com/<you>/rustdesk && cd rustdesk
bash ../flodesk/rebrand.sh . ../flodesk/logo.png rd.asandesk.ir 'joRoqzc0SDOHe61V9WrRORk4PqBVzBntfGtzveM3h8M='
```
Fonts: put `Vazirmatn-Regular.ttf`/`-Bold.ttf` (OFL) in `flutter/assets/fonts/`.

## Windows (cmd, x64 Native Tools)
```cmd
git clone https://github.com/microsoft/vcpkg && cd vcpkg && bootstrap-vcpkg.bat && set VCPKG_ROOT=%CD%
vcpkg install libvpx:x64-windows-static libyuv:x64-windows-static opus:x64-windows-static aom:x64-windows-static
cd ..\rustdesk && flutter pub get --directory flutter
python build.py --portable --flutter
```
Output: `flutter\build\windows\x64\runner\Release\` (rename leftover `rustdesk.exe` → `FloDesk.exe`); portable: `rustdesk-portable-packer\target\release\FloDesk.exe`.

## Android
```bash
rustup target add aarch64-linux-android armv7-linux-androideabi
cargo install cargo-ndk --version 3.1.2 --locked
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/28.2.13676358
./flutter/ndk_arm64.sh && ./flutter/ndk_arm.sh   # + jniLibs copy, see workflow
cd flutter && flutter build apk --release --target-platform android-arm,android-arm64
```
Output → `build/app/outputs/flutter-apk/app-release.apk` → `FloDesk.apk`.

Server/key can also be set at runtime: Settings → Network → ID/Relay server (the dialog stays editable).

CI: copy `flodesk-build.yml` to `.github/workflows/`, defaults to rd.asandesk.ir + its key (override with repo vars `FLODESK_SERVER`, `FLODESK_PUBKEY`); tag `v*` → Release.

## نصب APK اندروید (خارج از Play Store)
- اگر Play Protect نوشت «باید توسط گوگل تأیید شود»: **More details ← Install anyway** را بزنید، یا Play Protect را موقتاً خاموش کنید.
- برای نصب از مرورگر/فایل‌منیجر، گزینه‌ی «Install unknown apps» را برای همان برنامه فعال کنید.
- APK یکی است و روی گوشی‌های ۶۴ بیتی (arm64-v8a) و ۳۲ بیتی (armeabi-v7a) نصب می‌شود.
- امضا: keystore ثابت release (Secrets: `FLODESK_KEYSTORE_B64`, `FLODESK_KEYSTORE_PASSWORD`). همیشه با همان کلید امضا کنید تا به‌روزرسانی بدون حذف نصب ممکن بماند؛ نسخه‌های قبلی (1.1.0 با امضای debug) باید یک‌بار حذف شوند.

## آنتی‌ویروس و «تروجان» تشخیص دادن ویندوز

- علت اصلی: EXE تک‌فایلی قبلی (portable packer) خودش را در `%TEMP%` باز و اجرا می‌کرد، که الگوی کلاسیک تروجان‌دراپر است، و فایل بدون امضای دیجیتال بود. این روش حذف شد.
- اکنون: نصب‌کننده‌ی عادی `FloDesk-Setup.exe` (Inno Setup، نصب در Program Files یا پوشه‌ی کاربر + حذف‌کننده) و `FloDesk-windows-x64.zip` (پوشه‌ی بدون بسته‌بندی).
- حل ریشه‌ای فقط با **امضای Authenticode** گواهی واقعی (OV/EV) است. گواهی خودامضا فایده ندارد. Secretهای `FLODESK_CODESIGN_PFX_B64` و `FLODESK_CODESIGN_PASSWORD` را در GitHub بگذارید؛ CI خودکار `FloDesk.exe`، `librustdesk.dll` و نصب‌کننده را امضا و تأیید می‌کند.
- ابزار کنترل از راه دور ذاتاً مستعد هشدار نادرست است. برای هر آنتی‌ویروس گزارش False Positive بدهید: Microsoft Defender (https://www.microsoft.com/wdsi/filesubmission)، و سایت همان فروشنده‌ی آنتی‌ویروس، با SHA-256 فایل.
