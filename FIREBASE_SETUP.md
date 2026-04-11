# Firebase App Distribution Setup Guide

Este documento describe cómo configurar Firebase App Distribution para distribuir la app i2i-v3 a testers sin necesidad de App Store ni Xcode.

## 📋 Requisitos Previos

- Cuenta Google (para Firebase)
- Cuenta Apple Developer (para Ad-Hoc provisioning profiles)
- Mac con Xcode 15+
- Terminal/bash access

---

## Fase 1: Crear Proyecto Firebase

### Paso 1: Crear Proyecto en Firebase Console

1. Ir a [Firebase Console](https://console.firebase.google.com)
2. Click "Crear un proyecto"
3. Nombre del proyecto: `i2i-v3`
4. Desactivar Google Analytics (opcional, para acelerar)
5. Click "Crear proyecto"

### Paso 2: Añadir App iOS

1. En la pantalla del proyecto, click el ícono iOS (+)
2. Rellenar el formulario:
   - **Bundle ID**: `com.i2i.app`
   - **App Name**: `i2i`
   - **App Store ID**: (dejar vacío)
3. Descargar `GoogleService-Info.plist`
4. Guardar en: `ios/i2i/App/GoogleService-Info.plist` ← IMPORTANTE

### Paso 3: Activar App Distribution

1. En Firebase Console, ir a **App Distribution**
2. Si no está visible, activar desde **Más productos** → **App Distribution**
3. Click "Comenzar"

### Paso 4: Crear Grupo de Testers

1. En App Distribution, ir a **Testers y grupos**
2. Click "Crear grupo"
3. Nombre: `beta-testers`
4. Añadir emails de los testers:
   - Aquí van los emails de los iPhones a probar
5. Click "Crear"

### Paso 5: Obtener Firebase App ID

1. En Firebase Console, ir a **Configuración del proyecto**
2. En **General**, buscar **ID de la app** (formato: `1:XXXX:ios:YYYY`)
3. Copiar este ID, lo necesitarás luego

---

## Fase 2: Crear Ad-Hoc Provisioning Profile

### Paso 1: Registrar Dispositivos Testers

En [Apple Developer Account](https://developer.apple.com):

1. Ir a **Certificates, Identifiers & Profiles**
2. Click **Devices**
3. Para cada iPhone tester:
   - Click "+" para registrar nuevo dispositivo
   - **Name**: `iPhone A`, `iPhone B`, etc.
   - **Device ID (UDID)**: (ver instrucciones abajo)
   - Click "Continuar"

**Cómo obtener el UDID**:
- **Opción 1 (Fácil)**: Conectar iPhone a Mac vía USB → Xcode → Window → Devices and Simulators → seleccionar dispositivo → copiar UUID
- **Opción 2 (iTunes)**: Conectar iPhone → abrir iTunes/Finder → seleccionar iPhone → copiar "Serial Number" (UDID es diferente, usar opción 1)

### Paso 2: Crear Identificador de App

1. En Apple Developer, ir a **Identifiers**
2. Click "+"
3. **Bundle ID**: `com.i2i.app`
4. **Capabilities**: Seleccionar:
   - ✅ App Groups
   - ✅ Network Extension
   - ✅ HomeKit (si necesario para futuras features)
5. Click "Continuar" y **Register**

### Paso 3: Crear Ad-Hoc Provisioning Profile

1. En Apple Developer, ir a **Profiles**
2. Click "+"
3. Seleccionar **Ad Hoc**
4. Seleccionar Bundle ID: `com.i2i.app`
5. Seleccionar certificado de firma
6. Nombre: `i2i Ad-Hoc Distribution`
7. Seleccionar TODOS los dispositivos registrados (A, B, C)
8. Descargar el perfil
9. Hacer doble-click para instalar en Xcode

**Ubicación del perfil descargado**:
```bash
~/Library/MobileDevice/Provisioning\ Profiles/
```

---

## Fase 3: Configurar Firebase CLI

### Paso 1: Instalar Firebase CLI

```bash
npm install -g firebase-tools
```

Verificar instalación:
```bash
firebase --version
```

### Paso 2: Login en Firebase

```bash
firebase login
```

Esto abrirá el navegador para autenticarse con tu cuenta Google.

### Paso 3: Configurar Variables de Entorno

Crear o editar `~/.zshrc` (o `~/.bashrc` según tu shell):

```bash
export FIREBASE_APP_ID="1:XXXX:ios:YYYY"  # Copiar del paso 5 de Fase 1
export FIREBASE_TOKEN=$(firebase login:ci)  # Para CI/CD (GitHub Actions)
```

Recargar shell:
```bash
source ~/.zshrc
```

Verificar:
```bash
echo $FIREBASE_APP_ID
echo $FIREBASE_TOKEN
```

---

## Fase 4: Usar el Script de Distribución

### Opción A: Distribución Local (Mac)

Después de completar Fases 1-3:

```bash
cd /Users/jrubio/Documents/MIDEA/i2i-v2

# Distribución automática con notas por defecto
./scripts/distribute.sh

# O con notas personalizadas
./scripts/distribute.sh "Mi versión v3.1 — Chats independientes"
```

**Qué hace el script**:
1. ✅ Genera proyecto Xcode con xcodegen
2. ✅ Compila en Release con ad-hoc
3. ✅ Exporta .ipa
4. ✅ Sube a Firebase App Distribution
5. ✅ Envía emails a `beta-testers`

**Tiempo estimado**: ~15-20 minutos (primera vez más lento)

### Opción B: Distribución Automática (GitHub Actions)

Para que la app se distribuya automáticamente en cada push:

1. Ir a tu repositorio GitHub
2. Settings → Secrets and variables → Actions
3. Crear secreto: `FIREBASE_APP_ID`
   - Valor: `1:XXXX:ios:YYYY`
4. Crear secreto: `FIREBASE_TOKEN`
   - Valor: output del comando `firebase login:ci`

Luego, cada push a `main`/`master` o un tag `v*` dispara la distribución automáticamente.

---

## 📱 Flujo para Testers

Una vez distribuida la app:

1. **Email**: Tester recibe email con asunto "Nueva versión de i2i disponible"
2. **Link**: Email contiene link a Firebase App Distribution
3. **Instalar**: Abrir link → descargar + instalar i2i
4. **First time only**: Instalar "Firebase App Tester" (app que permite las instalaciones)
5. **En el iPhone**: i2i aparece automáticamente, lista para usar

---

## 🔍 Troubleshooting

### Error: `FIREBASE_APP_ID not set`
```bash
export FIREBASE_APP_ID="1:XXXX:ios:YYYY"
```

### Error: `firebase command not found`
```bash
npm install -g firebase-tools
firebase login
```

### Error: `xcodegen not found`
```bash
brew install xcodegen
```

### Error: `Code signing issue`
- Verificar que el Ad-Hoc provisioning profile está instalado
- Verificar que todos los dispositivos están registrados en el perfil
- En Xcode: Product → Clean Build Folder, luego reintentear

### Error: `.ipa not created`
- Revisar logs en `build/` directory
- Verificar que `scripts/ExportOptions.plist` tiene `teamID: 4GH5R96VHF`
- Verificar que bundle ID en `project.yml` es `com.i2i.app`

### La app no aparece en iPhone del tester
- Verificar email llegó a bandeja de spam
- Instalar "Firebase App Tester" primero (si no está instalada)
- Verificar el tester está en grupo `beta-testers` en Firebase Console

---

## 📚 Documentación Relacionada

- `INSTALLATION.md` - Instalar en simulador/iPhone real vía Xcode
- `V3_1_SUMMARY.md` - Resumen de v3.1
- `V3_1_TESTING_REPORT.md` - Resultados de testing
- `scripts/distribute.sh` - Script de distribución

---

## Próximos Pasos

Después de configurar Firebase Distribution:

1. ✅ Compilar una versión Release
2. ✅ Distribuir a grupo de testers
3. ✅ Recopilar feedback
4. ✅ Etapa 3.2: Group Chats

---

**Última actualización**: 2026-04-11  
**Estado**: ✅ Listo para implementar  
**Contacto**: jrubioadies (GitHub)
