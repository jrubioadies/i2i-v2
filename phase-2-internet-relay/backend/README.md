# Backend Prototype

This folder is reserved for the phase 2 internet relay backend.

The first backend should be intentionally small:

- WebSocket endpoint for device connections.
- In-memory map from `deviceId` to active connection.
- Signed device registration with trust-on-first-use public key persistence.
- Message forwarding by `receiverDeviceId`.
- Persistent offline queue for encrypted envelopes while a receiver is disconnected.
- Basic logging for connection and delivery state.

Authentication hardening and deployment automation can come after the first end-to-end test.

The offline queue is capped by `MAX_QUEUED_MESSAGES_PER_DEVICE` (default: 100) and persisted to `./data/offline-queue.json` by default. Override the path with `RELAY_QUEUE_FILE`.

Device public keys are persisted to `./data/device-keys.json` by default. Override the path with `RELAY_DEVICE_KEYS_FILE`. This is a trust-on-first-use registry: the first valid registration for a `deviceId` pins its signing public key, and future registrations must match it.

## Run Locally

```bash
npm install
npm run dev
```

The relay listens on:

```text
ws://localhost:8080/ws
```

For physical iPhones, use the Mac's LAN IP instead of `localhost`, for example:

```text
ws://192.168.1.50:8080/ws
```

## Health Check

```bash
curl http://localhost:8080/health
```

Example response:

```json
{
  "ok": true,
  "clients": 2,
  "queuedMessages": 0,
  "queuedDevices": 0
}
```

## Message Privacy

The relay treats `body` as opaque ciphertext. It routes by `receiverDeviceId` and does not decrypt or inspect message content.
