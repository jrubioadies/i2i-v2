# i2i v3 — Independent Conversations

This is the v3 branch of the i2i project, focused on **independent conversations and group messaging**.

## 🎯 Current Version: v3.1

✅ **Status**: Production Ready  
✅ **Tested**: 3 devices (2 real iPhones + 1 simulator)  
✅ **Feature Complete**: Independent 1:1 conversations

### What's v3.1?

**Independent Conversations**: Each peer relationship gets its own separate conversation thread. No message mixing, clean inbox organization, foundation for group chats.

- ✅ Conversation list (inbox) sorted by last message
- ✅ Separate message history per peer
- ✅ E2E encrypted messages
- ✅ Both local (MultipeerConnectivity) and relay transports
- ✅ Backwards compatible with v2

## 📁 Repository Structure

```
i2i-v3/
├── ios/
│   ├── i2i/
│   │   ├── Core/
│   │   │   ├── Models/
│   │   │   │   ├── Conversation.swift (NEW)
│   │   │   │   ├── Message.swift (updated)
│   │   │   │   └── ...
│   │   │   └── Storage/
│   │   │       ├── ConversationRepository.swift (NEW)
│   │   │       ├── LocalConversationRepository.swift (NEW)
│   │   │       └── ...
│   │   ├── Features/
│   │   │   ├── Conversations/
│   │   │   │   └── ConversationListView.swift (NEW)
│   │   │   └── ...
│   │   └── App/AppEnvironment.swift (updated)
│   ├── project.yml
│   └── i2i.xcodeproj
├── INSTALLATION.md
├── V3_1_SUMMARY.md
├── V3_1_TESTING_REPORT.md
├── V3_1_WHATS_NEW.md
└── README.md (this file)
```

## 🚀 Quick Start

### Clone This Repo
```bash
git clone https://github.com/jrubioadies/i2i-v3.git
cd i2i-v3
```

### Install on Simulator
```bash
cd ios
open i2i.xcodeproj
# Cmd + R to build and run
```

### Install on Real iPhones
See `INSTALLATION.md` for detailed steps.

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| `V3_1_SUMMARY.md` | Overview and status |
| `V3_1_WHATS_NEW.md` | Feature guide for users |
| `V3_1_TESTING_REPORT.md` | Detailed test results |
| `INSTALLATION.md` | Setup instructions |

## 🧪 Testing

**Tested on**:
- iPhone Real A + iPhone Real B + iOS Simulator
- All transport modes (local + relay)
- All 9 core test cases passed
- 12 edge cases validated

## 🔐 Security

- ✅ **E2E Encrypted**: ChaCha20-Poly1305 + Curve25519
- ✅ **Device Authentication**: Ed25519 signing
- ✅ **QR Pairing**: Secure key exchange
- ✅ **Trust-on-First-Use**: Relay pinning

## 🎯 Roadmap

### v3.1 (Current) ✅
- [x] Independent conversations
- [x] Conversation list UI
- [x] Message persistence
- [x] Transport modes (local + relay)

### v3.2 (Next)
- [ ] Group chats
- [ ] Fan-out encryption
- [ ] Group creation UI
- [ ] Group invitations

### v3.3+
- [ ] Read receipts
- [ ] Typing indicators
- [ ] Message reactions
- [ ] Voice/video calls

## 📞 Support

### For Users
- Read `V3_1_WHATS_NEW.md` for features
- Read `INSTALLATION.md` for setup
- Check `V3_1_TESTING_REPORT.md` for what's been tested

### For Developers
- Check commits for implementation details
- Read code in `ios/i2i/` for architecture
- Review `CLAUDE.md` for project guidelines

## 🤝 Related Repositories

- **i2i-v2**: Previous version (local communication only)
  - GitHub: https://github.com/jrubioadies/i2i-v2

- **i2i**: Original prototype
  - GitHub: https://github.com/jrubioadies/i2i

- **ws-relay**: Internet relay server (standalone)
  - GitHub: https://github.com/jrubioadies/ws-relay

## 📝 Releases

### v3.1 (2026-04-11)
- Independent conversations with separate message threads
- Conversation inbox sorted by last message
- Full E2E encryption
- Tested on 3 devices
- Production ready

See [Releases](https://github.com/jrubioadies/i2i-v3/releases) for downloads.

## 📄 License

Same as parent project (check LICENSE file in main repo).

## 🙏 Credits

Built with:
- SwiftUI 5.9+
- iOS 16+ (16.0 deployment target)
- MultipeerConnectivity framework
- WebSocket (URLSession)
- Cryptography (Ed25519 + Curve25519)

---

**Current Status**: ✅ Production Ready  
**Next Release**: v3.2 (Group Chats)  
**Maintained**: Active development

For details, see `V3_1_SUMMARY.md`.
