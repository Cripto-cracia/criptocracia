# Replace App Icon with Your Cyan "C" Logo

## Quick Setup (Automated)

1. **Save your cyan "C" logo** as: `assets/images/app_logo.png`
   - Make sure it's a square PNG image (recommended: 1024x1024px)
   - High quality PNG with transparent background works best

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Generate all app icons automatically**:
   ```bash
   flutter pub run flutter_launcher_icons
   ```

That's it! This will automatically replace ALL app icons across all platforms:
- ✅ Android (all densities)
- ✅ iOS (all sizes)
- ✅ Web (favicon and PWA icons)
- ✅ Windows
- ✅ macOS
- ✅ Linux

## What Gets Replaced
The automated tool will replace:
- Android launcher icons
- iOS app icons
- Web favicons and PWA icons
- Desktop app icons (Windows, macOS, Linux)

## Configuration
The icon generation is configured in `pubspec.yaml` with:
- **Background color**: Cyan (#00BCD4) to match your logo
- **Theme color**: Cyan (#00BCD4) for web/PWA
- **All platforms**: Enabled for complete coverage

## Manual Verification
After running the command, you can check that icons were updated in:
- `android/app/src/main/res/mipmap-*/`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- `web/icons/`
- `windows/runner/resources/`
- `macos/Runner/Assets.xcassets/AppIcon.appiconset/`

## Result
Your cyan "C" logo will now appear as the app icon when:
- Installing the app on devices
- Viewing the app in launchers/home screens
- Viewing the app in task switchers
- Accessing the web version

The icon will maintain your brand identity across all platforms!