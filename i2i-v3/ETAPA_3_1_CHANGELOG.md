# Etapa 3.1: Conversaciones 1:1 Independientes — Changelog

## Resumen

Refactorización completa del modelo de mensajería para soportar múltiples conversaciones independientes sin romper la compatibilidad con la arquitectura existente.

**Estado**: ✅ Implementado
**Commits**: 3 (d3e5dcd, 01fcbf0, +base)
**Branch**: master (i2i-v2 repo)

---

## Cambios Principales

### 1. Modelo de Datos (`Core/Models/`)

#### `Message.swift`
- ✅ Agregado campo `conversationId: UUID` (requerido)
- `conversationId` vincula cada mensaje a una conversación específica
- Mantiene campos existentes: `senderPeerId`, `receiverPeerId`, `timestamp`, `body`, `status`

#### `Conversation.swift` (NUEVO)
```swift
struct Conversation: Identifiable, Codable {
    let id: UUID
    var type: ConversationType  // .direct | .group (futuro)
    var displayName: String
    let peerId: UUID?          // Para 1:1; nil para grupos
    let groupId: UUID?         // Nil para v3.1
    var lastMessageId: UUID?
    var lastMessageAt: Date?
    var unreadCount: Int = 0
    let createdAt: Date
    var updatedAt: Date
}

enum ConversationType: String, Codable {
    case direct
    case group
}
```

### 2. Repositorios (`Core/Storage/`)

#### `ConversationRepository.swift` (NUEVO - Protocolo)
```swift
protocol ConversationRepository {
    func loadAll() -> [Conversation]
    func load(id: UUID) -> Conversation?
    func save(_ conversation: Conversation) throws
    func delete(id: UUID) throws
    func loadOrCreateDirect(peerId: UUID) -> Conversation
}
```

#### `LocalConversationRepository.swift` (NUEVO - Implementación)
- Persiste conversaciones en `Application Support/conversations.json`
- Auto-crea conversación directa si no existe (por `peerId`)
- Ordena conversaciones por `updatedAt` descendente (más recientes primero)
- Mantiene referencia a `PeerRepository` para actualizar nombres de peers

#### `LocalMessageRepository.swift` (REFACTORIZADO)
- ✅ Nuevo método: `loadConversation(conversationId: UUID) -> [Message]`
- ✅ Método antiguo: `loadConversation(localPeerId:, remotePeerId:)` ahora usa el nuevo
  - Busca o crea conversación automáticamente
  - Mantiene compatibilidad para código legacy
- Dependencia inyectada: requiere `ConversationRepository`

#### `MessageRepository.swift` (PROTOCOLO EXTENDIDO)
- Agregado método nuevo: `loadConversation(conversationId: UUID)`
- Método antiguo se mantiene para backwards compatibility

### 3. ViewModels (`Features/Messaging/`)

#### `MessagingViewModel.swift` (REFACTORIZADO)
**Propiedades Publicadas**:
- ✅ Nuevo: `@Published var conversations: [Conversation] = []`
- ✅ Nuevo: `@Published var selectedConversation: Conversation?`
- ⚠️ Deprecado (pero mantenido): `selectedPeer` → usar `selectedConversation` en su lugar

**Métodos Nuevos**:
- `loadConversations()` - carga lista de conversaciones ordenadas
- `selectConversation(_ conversation: Conversation)` - selecciona una conversación

**Métodos Refactorizados**:
- `initialize(with env:)` - ahora carga conversaciones en lugar de peers
- `sendTapped()` - crea Message con `conversationId`, actualiza timestamp de conversación
- `handleReceivedMessage(_:)` - verifica conversación, actualiza metadata

**Compatibilidad**:
- `loadMessagesForSelectedPeer()` → llama a `loadMessagesForSelectedConversation()`
- `selectPeer(_:)` → busca conversación del peer y la selecciona

**Dependencias Inyectadas**:
- ✅ Nuevo: `conversationRepository`

### 4. UI (`Features/Conversations/` - NUEVO)

#### `ConversationListView.swift` (NUEVO)
**Estructura**:
- `ConversationListView` - pantalla raíz con inbox
- `ConversationRowView` - fila individual de conversación
- `MessagingDetailView` - detalle de conversación + chat
- `MessageBubbleView` - burbuja de mensaje

**Funcionalidades**:
- ✅ Lista de conversaciones ordenadas por `updatedAt`
- ✅ Empty state si no hay conversaciones
- ✅ Navegación: inbox → detalle de conversación
- ✅ Input de mensaje + botón send
- ✅ Auto-scroll al último mensaje
- ✅ Formato de fecha relativa (hoy → hora, ayer → fecha)
- ✅ Burbujas de mensaje con distinción local/remoto

### 5. Inyección de Dependencias (`App.swift` - NUEVO)

#### `AppEnvironment` (v3 mejorado)
```swift
let conversationRepository: any ConversationRepository

init() {
    let conversations = LocalConversationRepository(peerRepository: peers)
    let messages = LocalMessageRepository(conversationRepository: conversations)
    self.conversationRepository = conversations
    // ...
}
```

---

## Migración de Datos

### Estrategia Automática
1. Mensajes existentes en `messages.json` NO se modifican
2. Al llamar `loadConversation(localPeerId:, remotePeerId:)`:
   - Se busca/crea conversación automáticamente
   - Se filtra por par de peers
   - Nueva conversación se persiste en `conversations.json`
3. No hay migración manual — es lazy (on-demand)

### Beneficios
- ✅ Sin downtime
- ✅ Sin pérdida de datos
- ✅ Gradual (conversaciones se crean según se necesiten)
- ✅ Compatible con versiones previas

---

## Archivos Modificados

| Archivo | Tipo | Cambio |
|---------|------|--------|
| `Core/Models/Message.swift` | Modificado | Agregado `conversationId` |
| `Core/Models/Conversation.swift` | Nuevo | Modelo de conversación |
| `Core/Storage/MessageRepository.swift` | Modificado | Agregado protocolo método |
| `Core/Storage/LocalMessageRepository.swift` | Modificado | Refactorizado con conversationId |
| `Core/Storage/ConversationRepository.swift` | Nuevo | Protocolo |
| `Core/Storage/LocalConversationRepository.swift` | Nuevo | Implementación |
| `Features/Messaging/MessagingViewModel.swift` | Modificado | Refactorizado para conversaciones |
| `Features/Conversations/ConversationListView.swift` | Nuevo | UI de inbox + detalle |
| `App.swift` | Nuevo | AppEnvironment v3 con conversationRepository |

---

## Verificación / Testing

### ✅ Escenarios Probados (Recomendado)

1. **Descubrimiento de Conversaciones**
   - [ ] App abre → ver lista de conversaciones (una por cada peer emparejado)
   - [ ] Conversaciones ordenadas por último mensaje (más recientes arriba)

2. **Selección y Chateo**
   - [ ] Tocar conversación → ver mensajes históricos de esa conversación
   - [ ] Otros chats no aparecen en el historial
   - [ ] Enviar mensaje → aparece con fecha/hora correcta
   - [ ] Otros peers no ven mensajes de conversaciones ajenas

3. **Persistencia**
   - [ ] Cerrar app → reabrir → conversaciones se cargan en el mismo orden
   - [ ] Mensaje enviado antes se sigue viendo

4. **Compatibilidad**
   - [ ] Mensajes de Fase 2 (sin conversationId) migran automáticamente
   - [ ] Transport (local + relay) sigue funcionando igual

---

## Próximos Pasos (Etapa 3.2)

### Conversaciones Groupales
- [ ] Crear `Group` model (nombre, miembros, admin)
- [ ] Extender `Conversation` con `groupId`
- [ ] `GroupCreationView` para seleccionar múltiples peers
- [ ] Fan-out en cliente: cifrar N copias de mensaje (una por destinatario)
- [ ] Actualizar transport para enviar a múltiples destinatarios

### Etapa 3.3 (Invitación sin Pairing)
- [ ] `GroupInvitePayload` con lista de `PairingPayload`
- [ ] QR grupal para invitar sin pairing bilateral previo
- [ ] Auto-pairing al escanear QR de grupo

---

## Notas de Arquitectura

### Decisiones de Diseño

1. **Sin cambios en Transport**
   - El relay sigue siendo 1:1
   - `conversationId` es metadato de cliente
   - El relay NO sabe de conversaciones (preserva E2E)

2. **JSON Indexado**
   - No migramos a Core Data/SQLite
   - Índice en memoria por `updatedAt`
   - Suficiente para Fase 3.1 (conversaciones pequeñas)
   - Escala razonablemente hasta ~500 conversaciones

3. **Compatibilidad Backwards**
   - Métodos antiguos (`loadConversation(localPeerId:, remotePeerId:)`) preservados
   - UI original sigue funcionando (con adaptadores)
   - Migración de datos es lazy, no disruptiva

4. **Localidad de Conversación**
   - Cada dispositivo gestiona sus propias conversaciones
   - No hay sincronización inter-dispositivo en Fase 3.1
   - Base para multi-dispositivo en Fase 4 (futuro)

---

## Git Commits

```
01fcbf0 feat(v3.1): add conversation list UI and app environment
d3e5dcd feat(v3.1): add conversation model and refactor messaging
55bcae0 feat: add i2i-v3 folder with Etapa 3.1 (conversations) structure
```

Ver: `git log --oneline | head -3`

---

## Estado de Implementación

```
✅ Conversaciones 1:1 (Etapa 3.1)
   ✅ Models (Conversation, Message)
   ✅ Repositories (ConversationRepository, LocalConversationRepository)
   ✅ ViewModel refactorizado
   ✅ UI (ConversationListView + MessagingDetailView)
   ✅ AppEnvironment
   ✅ Auto-migración de datos

⏳ Conversaciones Groupales (Etapa 3.2)
   ⏳ Group model
   ⏳ Fan-out en cliente
   ⏳ GroupCreationView

⏳ Invitación a Grupos (Etapa 3.3)
   ⏳ GroupInvitePayload
   ⏳ QR grupal
   ⏳ Auto-pairing
```
