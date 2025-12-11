# Desktop Application Patterns

**Self-Deploy Blueprint Documentation**

Patterns for deploying desktop applications with web-based backends.

---

## Overview

Desktop apps often need a backend API. Self-deploy patterns:

| Pattern | Description | Best For |
|---------|-------------|----------|
| Local Backend | API runs on user's machine | Offline-first, privacy-focused |
| Remote Backend | API on your server | Real-time sync, multi-device |
| Hybrid | Local-first with remote sync | Best of both worlds |

---

## Electron Applications

### Architecture

```
┌─────────────────────────────────────┐
│  Electron App (Desktop)             │
│  ┌─────────────┐  ┌──────────────┐  │
│  │  Renderer   │  │    Main      │  │
│  │  (React/    │◄─┤   Process    │  │
│  │   Vue/etc)  │  │              │  │
│  └─────────────┘  └──────┬───────┘  │
└────────────────────────────┼────────┘
                             │ HTTPS
                    ┌────────▼────────┐
                    │  Self-Hosted    │
                    │  Backend API    │
                    │  (Cloudflare    │
                    │   Tunnel)       │
                    └─────────────────┘
```

### OS-Specific Considerations

| OS | Considerations |
|----|----------------|
| **Windows** | Code signing required for distribution; MSI or NSIS installer |
| **macOS** | Notarization required; Universal binary for Intel + Apple Silicon |
| **Linux** | AppImage, deb, rpm, snap; different distros have different deps |

### Electron Dockerfile (for backend)

```dockerfile
# Backend API for Electron app
FROM node:20-alpine
WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

# CORS configured for desktop app origins
ENV ALLOWED_ORIGINS="app://-,electron://altair"

EXPOSE 8000
CMD ["node", "dist/index.js"]
```

### Electron Main Process (API Connection)

```javascript
// main.js - Electron main process
const { app, BrowserWindow, session } = require('electron');

// Configure API URL based on environment
const API_URL = process.env.API_URL || 'https://api.your-domain.com';

// Allow self-signed certs in development
if (process.env.NODE_ENV === 'development') {
  app.commandLine.appendSwitch('ignore-certificate-errors');
}

// Set CSP to allow API connections
session.defaultSession.webRequest.onHeadersReceived((details, callback) => {
  callback({
    responseHeaders: {
      ...details.responseHeaders,
      'Content-Security-Policy': [
        `default-src 'self'; connect-src 'self' ${API_URL}; script-src 'self' 'unsafe-inline';`
      ]
    }
  });
});
```

### Auto-Update with Self-Hosted Server

```javascript
// main.js - Auto-update configuration
const { autoUpdater } = require('electron-updater');

// Point to your self-hosted update server
autoUpdater.setFeedURL({
  provider: 'generic',
  url: 'https://updates.your-domain.com/releases'
});

// Check for updates
app.whenReady().then(() => {
  autoUpdater.checkForUpdatesAndNotify();
});
```

### Update Server (Simple)

```javascript
// update-server.js - Minimal update server
const express = require('express');
const app = express();

app.use('/releases', express.static('./releases'));

// latest.yml must exist for electron-updater
// Generate with: electron-builder --publish never
// Then copy to releases/

app.listen(8080);
```

---

## Tauri Applications

### Architecture

```
┌─────────────────────────────────────┐
│  Tauri App (Desktop)                │
│  ┌─────────────┐  ┌──────────────┐  │
│  │  WebView    │  │    Rust      │  │
│  │  (Your UI)  │◄─┤   Backend    │  │
│  │             │  │   (Sidecar)  │  │
│  └─────────────┘  └──────┬───────┘  │
└────────────────────────────┼────────┘
                             │ HTTPS
                    ┌────────▼────────┐
                    │  Self-Hosted    │
                    │  Backend API    │
                    └─────────────────┘
```

### OS-Specific Considerations

| OS | Considerations |
|----|----------------|
| **Windows** | Uses WebView2 (Edge); smaller than Electron |
| **macOS** | Uses WKWebView; notarization required |
| **Linux** | Uses WebKitGTK; ensure webkit2gtk installed |

### Tauri Configuration

```json
// tauri.conf.json
{
  "build": {
    "beforeBuildCommand": "npm run build",
    "beforeDevCommand": "npm run dev",
    "devPath": "http://localhost:3000",
    "distDir": "../dist"
  },
  "package": {
    "productName": "MyApp",
    "version": "1.0.0"
  },
  "tauri": {
    "allowlist": {
      "http": {
        "all": true,
        "request": true,
        "scope": ["https://api.your-domain.com/*"]
      }
    },
    "security": {
      "csp": "default-src 'self'; connect-src https://api.your-domain.com"
    },
    "updater": {
      "active": true,
      "endpoints": [
        "https://updates.your-domain.com/tauri/{{target}}/{{current_version}}"
      ],
      "dialog": true,
      "pubkey": "YOUR_PUBLIC_KEY"
    }
  }
}
```

### Tauri Rust Backend (Sidecar API)

```rust
// src-tauri/src/main.rs
use tauri::Manager;

#[tauri::command]
async fn api_request(endpoint: String) -> Result<String, String> {
    let api_url = std::env::var("API_URL")
        .unwrap_or_else(|_| "https://api.your-domain.com".to_string());

    let response = reqwest::get(format!("{}/{}", api_url, endpoint))
        .await
        .map_err(|e| e.to_string())?
        .text()
        .await
        .map_err(|e| e.to_string())?;

    Ok(response)
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![api_request])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

---

## Self-Hosted Update Server

### Directory Structure

```
updates/
├── electron/
│   ├── latest.yml
│   ├── latest-mac.yml
│   ├── latest-linux.yml
│   ├── MyApp-1.0.0.exe
│   ├── MyApp-1.0.0.dmg
│   └── MyApp-1.0.0.AppImage
└── tauri/
    ├── darwin-aarch64/
    │   └── latest.json
    ├── darwin-x86_64/
    │   └── latest.json
    ├── linux-x86_64/
    │   └── latest.json
    └── windows-x86_64/
        └── latest.json
```

### Update Server Dockerfile

```dockerfile
FROM nginx:alpine

# Copy update files
COPY updates /usr/share/nginx/html/updates

# NGINX config for byte-range requests (required for updates)
COPY <<EOF /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name _;
    root /usr/share/nginx/html;

    location /updates {
        autoindex on;
        add_header Accept-Ranges bytes;
        add_header Access-Control-Allow-Origin *;
    }
}
EOF

EXPOSE 80
```

### Cloudflare Tunnel Config for Updates

```yaml
# config.yml
ingress:
  - hostname: updates.your-domain.com
    service: http://localhost:8080
  - hostname: api.your-domain.com
    service: http://localhost:3000
  - service: http_status:404
```

---

## Local-First with Sync

### Pattern: SQLite + Remote Sync

```javascript
// Best for: Offline-capable apps with eventual sync

// Local database (in Electron/Tauri)
const db = new Database('local.db');

// Sync service
async function syncWithServer() {
  const localChanges = await db.getChangesSince(lastSync);

  const response = await fetch('https://api.your-domain.com/sync', {
    method: 'POST',
    body: JSON.stringify({
      changes: localChanges,
      lastSync: lastSync
    })
  });

  const { serverChanges, newSyncTime } = await response.json();

  // Apply server changes locally
  await db.applyChanges(serverChanges);
  lastSync = newSyncTime;
}
```

### Pattern: CRDTs for Conflict-Free Sync

```javascript
// Libraries: Yjs, Automerge, cr-sqlite
import * as Y from 'yjs';
import { WebsocketProvider } from 'y-websocket';

const doc = new Y.Doc();

// Connect to self-hosted y-websocket server
const provider = new WebsocketProvider(
  'wss://sync.your-domain.com',
  'my-document',
  doc
);

// Changes automatically sync across all clients
const items = doc.getArray('items');
items.push(['new item']); // Syncs automatically
```

---

## Security Considerations

### API Authentication for Desktop Apps

```javascript
// Don't store secrets in desktop app code!

// Option 1: OAuth with PKCE (recommended)
const { shell } = require('electron');
const crypto = require('crypto');

async function login() {
  const codeVerifier = crypto.randomBytes(32).toString('base64url');
  const codeChallenge = crypto.createHash('sha256')
    .update(codeVerifier)
    .digest('base64url');

  // Open browser for auth
  shell.openExternal(
    `https://auth.your-domain.com/authorize?` +
    `client_id=desktop-app&` +
    `code_challenge=${codeChallenge}&` +
    `code_challenge_method=S256&` +
    `redirect_uri=myapp://callback`
  );

  // Handle callback in custom protocol handler
}

// Option 2: Device flow (for CLI-like auth)
async function deviceLogin() {
  const { device_code, user_code, verification_uri } =
    await fetch('https://auth.your-domain.com/device/code', {
      method: 'POST',
      body: JSON.stringify({ client_id: 'desktop-app' })
    }).then(r => r.json());

  console.log(`Go to ${verification_uri} and enter: ${user_code}`);

  // Poll for token
  // ...
}
```

### Secure Storage

```javascript
// Electron: Use safeStorage
const { safeStorage } = require('electron');

function storeToken(token) {
  if (safeStorage.isEncryptionAvailable()) {
    const encrypted = safeStorage.encryptString(token);
    fs.writeFileSync('token.enc', encrypted);
  }
}

// Tauri: Use keyring
// Rust side handles secure storage automatically
```

---

## Distribution Checklist

### Pre-Release

- [ ] Code signing certificate obtained (Windows, macOS)
- [ ] Apple Developer account for notarization
- [ ] Update server deployed and tested
- [ ] API CORS configured for desktop origins
- [ ] Deep links / custom protocol registered

### Build Matrix

| OS | Architecture | Format |
|----|--------------|--------|
| Windows | x64 | NSIS, MSI |
| Windows | arm64 | NSIS |
| macOS | Universal | DMG, PKG |
| Linux | x64 | AppImage, deb, rpm |
| Linux | arm64 | AppImage |

### Post-Release

- [ ] Update server has new version
- [ ] Download links updated
- [ ] Release notes published
- [ ] Analytics tracking deployment

---

## When NOT to Self-Host

Consider managed services when:

| Scenario | Better Option |
|----------|---------------|
| Need app store distribution | Mac App Store, Microsoft Store |
| Enterprise MDM required | Managed deployment solutions |
| Automatic crash reporting | Sentry, BugSnag |
| Usage analytics at scale | Amplitude, Mixpanel |

Self-hosting is ideal for:
- Privacy-focused applications
- Internal enterprise tools
- Avoiding vendor dependencies
- Full control over update timing

---

**Version:** 1.0.0 | **Updated:** December 2025
