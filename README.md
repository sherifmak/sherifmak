# Whoop Tamagotchi

An iPhone home screen widget that shows a Tamagotchi character whose mood and expression reflect your WHOOP daily strain in real time.

## How It Works

Your Tamagotchi reacts to your strain score (0-21):

| Strain | Level | Tamagotchi |
|--------|-------|------------|
| 0-4 | Resting | Sleepy, snoozing with Zzz's |
| 4-8 | Light | Happy, sparkly, bouncy |
| 8-13 | Moderate | Determined, focused |
| 13-17 | High | Panting, sweating |
| 17-21 | Overreach | Exhausted, X-eyes |

The widget updates every 15 minutes and comes in **small** and **medium** sizes.

## Setup

### 1. Register a WHOOP Developer App

1. Go to [developer.whoop.com](https://developer.whoop.com)
2. Create a new application
3. Set the redirect URI to: `whooptamagotchi://oauth/callback`
4. Note your **Client ID** and **Client Secret**
5. Enable the `read:cycles` and `offline` scopes

### 2. Configure the Project

```bash
cd WhoopTamagotchi
cp Config.xcconfig.example Config.xcconfig
# Edit Config.xcconfig with your WHOOP credentials
```

### 3. Xcode Setup

1. Open Xcode and create a new iOS App project named `WhoopTamagotchi`
2. Copy the source files from this repo into the project
3. Add a Widget Extension target named `WhoopTamagotchiWidget`
4. Configure App Groups: `group.com.whooptamagotchi.shared` on both targets
5. Configure Keychain Sharing with the same access group on both targets
6. Add `Config.xcconfig` to both target build settings
7. Build and run on your device

### 4. Add the Widget

1. Open the app and tap **Connect WHOOP** to sign in
2. Long-press your home screen > tap **+**
3. Search for "Whoop Tamagotchi"
4. Choose small or medium size
5. Enjoy!

## Project Structure

```
WhoopTamagotchi/
├── Shared/
│   ├── WhoopModels.swift          # API models, strain levels, token storage
│   ├── WhoopAPIClient.swift       # WHOOP OAuth + API client
│   └── TamagotchiCharacter.swift  # Pure SwiftUI character with expressions
├── WhoopTamagotchi/
│   ├── App/
│   │   └── WhoopTamagotchiApp.swift
│   ├── Views/
│   │   └── ContentView.swift      # Main app (login + strain display)
│   └── Info.plist
├── WhoopTamagotchiWidget/
│   └── WhoopTamagotchiWidget.swift  # WidgetKit timeline + widget views
├── Config.xcconfig.example
├── Package.swift
└── .gitignore
```

## Requirements

- iOS 17.0+
- Xcode 15+
- WHOOP membership + developer account
- No external dependencies

## Tech

- **SwiftUI** for all UI (including the Tamagotchi character - no image assets needed)
- **WidgetKit** for home screen widgets
- **App Groups** for sharing data between app and widget
- **Keychain** for secure OAuth token storage
- **WHOOP API v1** for daily strain/cycle data
