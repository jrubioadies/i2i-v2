# i2i-v3 — Fase 3: Múltiples Conversaciones y Chats Grupales

Base de desarrollo para la Fase 3 del proyecto i2i.

## Cambios en v3

### Etapa 3.1 (Conversaciones Independientes)
- Modelo `Conversation` para separar chats
- Campo `conversationId` en `Message`
- `ConversationRepository` con índices
- UI de inbox de conversaciones
- Migración automática de mensajes existentes

### Etapas futuras
- 3.2: Chats grupales (fan-out cliente)
- 3.3: Invitación a grupos sin pairing previo

## Setup
```
cd ios
xcodegen generate
open i2i.xcodeproj
```

## Estructura
```
i2i-v3/
├── Core/
│   ├── Models/       Conversation, Message (actualizado)
│   ├── Storage/      ConversationRepository, MessageRepository
│   ├── Transport/    (sin cambios en v3.0)
│   └── Security/     (sin cambios en v3.0)
├── Features/
│   ├── Messaging/    MessagingViewModel, MessagingView (refactorizado)
│   └── Conversations/ (NUEVO)
└── UI/Shared/        (sin cambios)
```
