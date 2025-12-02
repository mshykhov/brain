# Phase 7: Testing UI

## Зачем

Internal UI для тестирования API:
- Public endpoints (без авторизации)
- Private endpoints (Auth0 login)
- Role-based access testing
- CRUD examples для проверки permissions

## Stack

**Refine** — React framework для admin/internal tools
- Auth0 integration из коробки
- CRUD генерируется автоматически
- Role-based access control
- Красивый UI (Ant Design / Material UI / Chakra)

Docs: https://refine.dev/docs/

## Roadmap

### v1 — Basic Testing
- [ ] Public endpoints page (no auth required)
- [ ] Login via Auth0
- [ ] Private endpoints page (requires auth)
- [ ] Show current user info + roles

### v2 — Role-Based Testing
- [ ] Different views based on role (admin vs user)
- [ ] Permission denied examples
- [ ] API error handling UI

### v3 — Data Management
- [ ] DB viewer (read-only)
- [ ] CRUD examples (create/edit/delete)
- [ ] Kafka message viewer
- [ ] Test data generator

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Testing UI (Refine)                   │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Public Page  │  │ Private Page │  │  Admin Page  │   │
│  │  (no auth)   │  │ (auth req)   │  │ (admin role) │   │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘   │
│         │                 │                  │           │
│         └────────────┬────┴──────────────────┘           │
│                      │                                   │
│              ┌───────▼───────┐                          │
│              │  Auth0 Login  │                          │
│              │  (roles/groups)│                          │
│              └───────┬───────┘                          │
└──────────────────────┼──────────────────────────────────┘
                       │
              ┌────────▼────────┐
              │   example-api   │
              │  (Spring Boot)  │
              └─────────────────┘
```

## Deployment Options

### Option A: Static (Vercel/Cloudflare Pages)
- Простой деплой
- Public access или Cloudflare Access
- Бесплатно

### Option B: Kubernetes (in cluster)
- За oauth2-proxy (как ArgoCD)
- Internal only (Tailscale)
- Full control

## Auth0 Configuration

Нужен отдельный Auth0 Application (SPA):
1. Auth0 → Applications → Create → Single Page Application
2. Allowed Callback URLs: `http://localhost:3000/callback, https://ui.<domain>/callback`
3. Allowed Logout URLs: `http://localhost:3000, https://ui.<domain>`
4. Allowed Web Origins: same

## API Requirements

example-api должен иметь:

```kotlin
// Public endpoint
@GetMapping("/api/public/health")
fun health(): Map<String, String>

// Private endpoint (any authenticated user)
@GetMapping("/api/private/me")
@PreAuthorize("isAuthenticated()")
fun me(principal: Principal): UserInfo

// Admin only endpoint
@GetMapping("/api/admin/users")
@PreAuthorize("hasRole('admin')")
fun listUsers(): List<User>

// Role-based endpoint
@GetMapping("/api/private/data")
@PreAuthorize("hasAnyRole('user', 'admin')")
fun getData(): List<Data>
```

## Tech Stack

| Component | Choice | Why |
|-----------|--------|-----|
| Framework | Refine | Best for admin/internal tools |
| UI Library | Ant Design | Clean, feature-rich |
| Auth | @refinedev/auth0 | Official provider |
| API Client | REST (axios) | Simple |
| State | React Query | Built into Refine |

## Getting Started

```bash
# Create project
npm create refine-app@latest example-ui

# Select:
# - refine-react
# - Ant Design
# - REST API
# - Auth0

cd example-ui
npm run dev
```

## Files Structure

```
example-ui/
├── src/
│   ├── App.tsx
│   ├── authProvider.ts      # Auth0 config
│   ├── dataProvider.ts      # API config
│   ├── pages/
│   │   ├── public/          # No auth required
│   │   ├── private/         # Auth required
│   │   └── admin/           # Admin role required
│   └── components/
│       └── RoleGuard.tsx    # Role-based rendering
├── package.json
└── .env                     # Auth0 credentials
```

## Doppler Secrets (if deployed to K8s)

| Key | Description |
|-----|-------------|
| `AUTH0_CLIENT_ID_UI` | SPA Client ID |
| `AUTH0_AUDIENCE` | API identifier |

## Next Steps

1. Create example-ui repo
2. Setup Refine with Auth0
3. Create public/private pages
4. Add role-based components
5. Deploy (Vercel or K8s)
