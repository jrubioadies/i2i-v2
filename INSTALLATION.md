# i2i v3.1 — Instrucciones de Instalación

## ✅ Estado Actual

- ✅ Código compilado exitosamente (Xcode Debug build)
- ✅ Etapa 3.1: Conversaciones independientes 1:1
- ✅ Código en GitHub: `https://github.com/jrubioadies/i2i-v2`

---

## Opción 1: Instalar en Simulador iOS (Más Rápido para Probar)

### Pasos:

1. **Abrir el proyecto en Xcode**
   ```bash
   cd /Users/jrubio/Documents/MIDEA/i2i-v2/ios
   open i2i.xcodeproj
   ```

2. **Seleccionar simulador**
   - En Xcode: arriba a la izquierda, junto a "i2i", verás selector de dispositivo
   - Click en el selector → Simulators → elige un iPhone (ej: iPhone 15)

3. **Compilar y ejecutar**
   - Xcode → Product → Run (o `Cmd + R`)
   - Espera a que compile y abra el simulador automáticamente

4. **La app abrirá en el simulador**
   - Sigue las instrucciones de pairing (tab "Pair")
   - Usa dos simuladores o un simulador + un iPhone real para probar

---

## Opción 2: Instalar en iPhones Físicos (Recomendado para Testing Real)

### Requisitos:
- Dos iPhones conectados por USB a tu Mac (o conectados vía WiFi)
- Xcode 15+
- Team ID configurado (ya está en `project.yml`)

### Pasos:

1. **Conectar los iPhones**
   - Conecta ambos iPhones a la Mac vía USB
   - En cada iPhone: Trust (confía en) la Mac cuando pida permiso

2. **Abrir proyecto en Xcode**
   ```bash
   cd /Users/jrubio/Documents/MIDEA/i2i-v2/ios
   open i2i.xcodeproj
   ```

3. **Seleccionar primer iPhone**
   - Arriba a la izquierda, selector de dispositivo
   - Elige el primer iPhone que conectaste

4. **Compilar e instalar en primer iPhone**
   - Xcode → Product → Run (o `Cmd + R`)
   - Esperará a que el iPhone se desbloquee y confíe en el desarrollador
   - Primera vez puede pedir "Allow Untrusted Developer"
     - En el iPhone: Settings → General → VPN & Device Management → Trust "[Tu nombre]"

5. **Compilar e instalar en segundo iPhone**
   - Cambia el selector de dispositivo al segundo iPhone
   - Xcode → Product → Run (`Cmd + R`)
   - Repite el paso de confiar en el desarrollador

6. **Verificar instalación**
   - Ambos iPhones deberían tener la app "i2i"
   - Abre la app en ambos

---

## Probar Conversaciones Independientes (Etapa 3.1)

### Dentro de la App:

1. **Pairing (si es la primera vez)**
   - iPhone A: Tab "Pair" → muestra un QR con su deviceId
   - iPhone B: Tab "Pair" → "Scan" → escanea el QR de A
   - Repite: A escanea el QR de B

2. **Mensajería**
   - Tab "Messages"
   - Deberías ver una lista de conversaciones (una por cada peer emparejado)
   - Toca una conversación para abrir el chat
   - Envía mensajes → deberían llegar en tiempo real (local o relay)

3. **Verificar que funcionan conversaciones independientes**
   - Si A y B están emparejados:
     - A abre chat con B → envía "Hola desde chat 1"
     - A abre chat con C → envía "Hola desde chat 2"
   - Los chats no se mezclan
   - El historial se persiste entre sesiones

---

## Ubicación de los Archivos

### Código Fuente
```
ios/
├── i2i/
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── Conversation.swift     (NUEVO)
│   │   │   └── Message.swift          (modificado: +conversationId)
│   │   └── Storage/
│   │       ├── ConversationRepository.swift      (NUEVO)
│   │       ├── LocalConversationRepository.swift (NUEVO)
│   │       └── LocalMessageRepository.swift      (modificado)
│   ├── Features/
│   │   └── Conversations/
│   │       └── ConversationListView.swift        (NUEVO)
│   └── App/
│       └── AppEnvironment.swift       (actualizado)
├── i2i.xcodeproj
└── project.yml
```

### Build Output
**Simulador Debug**: `/Users/jrubio/Library/Developer/Xcode/DerivedData/i2i-bdglblbhrhsxynasbmxnawtieikc/Build/Products/Debug-iphonesimulator/i2i.app`

---

## Troubleshooting

### "Device not found" en Xcode
- Desconecta y reconecta el iPhone vía USB
- O usa WiFi: Xcode → Window → Devices → agregar dispositivo vía red

### "Build failed"
```bash
# Limpiar build
cd ios
rm -rf ~/Library/Developer/Xcode/DerivedData/i2i-*
open i2i.xcodeproj
# Product → Clean Build Folder (Cmd + Shift + K)
# Product → Run (Cmd + R)
```

### "Untrusted Developer"
- En el iPhone: Settings → General → VPN & Device Management
- Busca "Desarrollo" y toca Trust

### App cierra al abrir
- Abre Xcode Console (View → Debug Area → Show Console)
- Mira los logs para errores de compilación

---

## Siguiente Paso: Etapa 3.2

Cuando quieras implementar **chats grupales** (Etapa 3.2):
- Crea `Group` model
- Implementa fan-out en cliente (cifra N copias de mensaje)
- Crea `GroupCreationView` para seleccionar múltiples peers

Ver: `i2i-v3/ETAPA_3_1_CHANGELOG.md` para más detalles

---

## Git Info

**Repositorio**: `https://github.com/jrubioadies/i2i-v2`

**Commits Recientes**:
```
c8a5d4b feat: integrate v3.1 conversions into xcode project
b502cf1 docs(v3.1): add comprehensive changelog for Etapa 3.1
01fcbf0 feat(v3.1): add conversation list UI and app environment
d3e5dcd feat(v3.1): add conversation model and refactor messaging
```

Para descargar cambios:
```bash
cd /Users/jrubio/Documents/MIDEA/i2i-v2
git pull origin master
```
