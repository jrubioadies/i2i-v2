# Scripts Directory

Utility scripts for building and distributing the i2i app.

## distribute.sh

Builds and distributes the i2i app to Firebase App Distribution.

### Prerequisites

Before using this script, complete the setup in [`FIREBASE_SETUP.md`](../FIREBASE_SETUP.md):
- Create Firebase project
- Create Ad-Hoc provisioning profile
- Set `FIREBASE_APP_ID` environment variable
- Authenticate with `firebase login`

### Usage

```bash
# With default release notes
./scripts/distribute.sh

# With custom release notes
./scripts/distribute.sh "v3.1 — Conversaciones independientes"
```

### What It Does

1. Checks prerequisites (xcodebuild, firebase, FIREBASE_APP_ID)
2. Installs missing tools (xcodegen, firebase-tools)
3. Generates Xcode project using xcodegen
4. Compiles Release build archive
5. Exports as Ad-Hoc .ipa
6. Uploads to Firebase App Distribution
7. Notifies testers via email

### Environment Variables

Required:
- `FIREBASE_APP_ID` — Your Firebase App ID (format: `1:XXXX:ios:YYYY`)

Optional:
- `FIREBASE_TOKEN` — For CI/CD (GitHub Actions) authentication

### Troubleshooting

**Error: FIREBASE_APP_ID not set**
```bash
export FIREBASE_APP_ID="1:XXXX:ios:YYYY"
./scripts/distribute.sh
```

**Error: firebase command not found**
```bash
npm install -g firebase-tools
firebase login
./scripts/distribute.sh
```

**Error: Code signing issue**
- Verify Ad-Hoc provisioning profile is installed
- Verify all test devices are in the profile
- Run: `rm -rf ~/Library/Developer/Xcode/DerivedData/i2i-*`
- Retry

## ExportOptions.plist

Xcode configuration for exporting as Ad-Hoc .ipa.

Used by `distribute.sh` during export phase.

Contains:
- `method: ad-hoc` — Export as Ad-Hoc build (not App Store)
- `teamID: 4GH5R96VHF` — Apple Developer Team ID
- `provisioningProfiles` — Mapping to Ad-Hoc provisioning profile

---

## GitHub Actions

Automated distribution via `.github/workflows/firebase-distribution.yml`

**Triggers on:**
- Push to `main` or `master` branch
- Any tag matching `v*` or `release-*`
- Manual trigger via GitHub UI

**Setup:**
1. Create secrets in repository:
   - `FIREBASE_APP_ID`
   - `FIREBASE_TOKEN` (from `firebase login:ci`)
2. Push a tag or commit to main
3. GitHub Actions automatically distributes to testers

---

## Manual Distribution (Without Script)

If you prefer to build and distribute manually:

```bash
cd ios
xcodegen generate
xcodebuild archive -scheme i2i -archivePath ../build/i2i.xcarchive -configuration Release
xcodebuild -exportArchive -archivePath ../build/i2i.xcarchive \
  -exportOptionsPlist ../scripts/ExportOptions.plist -exportPath ../build/
firebase appdistribution:distribute build/i2i.ipa --app $FIREBASE_APP_ID --groups "beta-testers"
```

---

## Files

| File | Purpose |
|------|---------|
| `distribute.sh` | Main distribution script |
| `ExportOptions.plist` | Xcode export configuration |
| `.github/workflows/firebase-distribution.yml` | GitHub Actions workflow |
| `FIREBASE_SETUP.md` | Complete setup guide |

---

**Documentation**: See `FIREBASE_SETUP.md` for complete setup instructions.
