# Phase 7: Testing UI Architecture

## Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| Vite | 5.4.15 | Build tool |
| React | 19.1.0 | UI library |
| TypeScript | 5.8.3 | Type safety |
| Refine | 5.0.6 | Admin framework |
| Ant Design | 5.23.0 | UI components |
| Auth0 React SDK | 2.2.4 | Authentication |

## Project Structure (DRY/Clean)

```
example-ui/
├── src/
│   ├── config/           # Configuration constants
│   │   └── constants.ts  # API URL, Auth0 config
│   ├── types/            # TypeScript types
│   │   └── index.ts      # User, API response types
│   ├── providers/        # Refine providers
│   │   └── authProvider.ts
│   ├── hooks/            # Custom hooks
│   │   └── useApiHealth.ts
│   ├── components/       # Reusable components
│   │   ├── EndpointResults.tsx
│   │   ├── UserInfo.tsx
│   │   └── index.ts
│   ├── pages/            # Page components
│   │   ├── login.tsx
│   │   ├── public/       # No auth required
│   │   │   └── health.tsx
│   │   ├── private/      # Auth required
│   │   │   └── dashboard.tsx
│   │   └── index.ts
│   ├── App.tsx           # Root component
│   └── main.tsx          # Entry point
├── .env.example          # Environment template
├── package.json
├── tsconfig.json
└── vite.config.ts
```

## Key Design Decisions

### DRY Principles Applied

1. **Constants centralized** in `src/config/constants.ts`
2. **Types shared** via `src/types/index.ts`
3. **Auth logic abstracted** into `createAuthProvider()` factory
4. **API calls encapsulated** in `useApiHealth` hook
5. **Barrel exports** for clean imports

### Clean Architecture

1. **Separation of concerns**: Config → Providers → Hooks → Components → Pages
2. **Single responsibility**: Each file has one purpose
3. **Dependency injection**: Auth0 context injected into auth provider
4. **Type safety**: Full TypeScript coverage

## Auth Flow

```
┌─────────────────────────────────────────────────────────────┐
│                        main.tsx                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                   Auth0Provider                        │  │
│  │   domain, clientId from environment                    │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │                     App.tsx                      │  │  │
│  │  │                                                  │  │  │
│  │  │  useAuth0() → createAuthProvider() → Refine     │  │  │
│  │  │                                                  │  │  │
│  │  │  Routes:                                         │  │  │
│  │  │    /public   → PublicHealthPage (no auth)       │  │  │
│  │  │    /login    → LoginPage                        │  │  │
│  │  │    /dashboard→ DashboardPage (requires auth)    │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Environment Variables

```bash
VITE_API_URL=https://api.untrustedonline.org
VITE_AUTH0_DOMAIN=your-tenant.auth0.com
VITE_AUTH0_CLIENT_ID=your-client-id
VITE_AUTH0_AUDIENCE=https://your-api-identifier
```

## References

- [Refine Auth0 Example](https://github.com/refinedev/refine/tree/main/examples/auth-auth0)
- [Refine Auth Provider Docs](https://refine.dev/docs/guides-concepts/authentication/)
- [Auth0 React SDK](https://auth0.com/docs/quickstart/spa/react)
