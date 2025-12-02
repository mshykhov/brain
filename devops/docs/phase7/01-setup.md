# Phase 7: Setup Guide

## Prerequisites

- Node.js >= 20
- Auth0 account with SPA Application configured
- API endpoint (from Phase 6)

## Quick Start

```bash
cd example-ui
npm install
cp .env.example .env.local
# Edit .env.local with your Auth0 credentials
npm run dev
```

## Auth0 SPA Configuration

### 1. Create Application

In Auth0 Dashboard → Applications → Create Application:

- **Type**: Single Page Application
- **Name**: example-ui

### 2. Configure URLs

Settings → Application URIs:

| Field | Development | Production |
|-------|-------------|------------|
| Allowed Callback URLs | `http://localhost:5173` | `https://app.untrustedonline.org` |
| Allowed Logout URLs | `http://localhost:5173` | `https://app.untrustedonline.org` |
| Allowed Web Origins | `http://localhost:5173` | `https://app.untrustedonline.org` |

### 3. Get Credentials

Copy from Application Settings:
- Domain → `VITE_AUTH0_DOMAIN`
- Client ID → `VITE_AUTH0_CLIENT_ID`

### 4. API Audience (Optional)

If your API validates tokens:
1. APIs → Select your API
2. Copy Identifier → `VITE_AUTH0_AUDIENCE`

## Development

```bash
npm run dev      # Start dev server
npm run build    # Production build
npm run preview  # Preview build
```

## Features Implemented (v1)

- [x] Public endpoints page (no auth)
- [x] Login via Auth0 (SPA Application)
- [x] Private endpoints page (requires auth)
- [x] Show current user info + groups/roles

## Deployment Options

### Option 1: Cloudflare Tunnel (like example-api)

Add hostname in Cloudflare Dashboard:
- `app.untrustedonline.org` → `example-ui.prd:80`

### Option 2: Static Hosting

Build and deploy to:
- Vercel
- Netlify
- Cloudflare Pages

```bash
npm run build
# Deploy dist/ folder
```
