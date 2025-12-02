# Phase 7: API + UI Integration Checklist

## Part 1: API (example-api)

### 1.1 Add Spring Security with OAuth2 Resource Server

```kotlin
// build.gradle.kts
implementation("org.springframework.boot:spring-boot-starter-oauth2-resource-server")
```

### 1.2 Configure Auth0 JWT validation

```yaml
# application.yml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://${AUTH0_DOMAIN}/
          audiences: ${AUTH0_AUDIENCE:}
```

### 1.3 Security Config

- [ ] Create `SecurityConfig.kt`
- [ ] Public endpoints: `/actuator/**`, `/api/public/**`
- [ ] Private endpoints: `/api/**` (require JWT)

### 1.4 Public Endpoints (no auth required)

- [ ] `GET /api/public/health` - returns `{"status": "ok"}`
- [ ] `GET /api/public/info` - returns app name, version
- [ ] `GET /api/public/time` - returns server time

### 1.5 Private Endpoints (JWT required)

- [ ] `GET /api/me` - returns user info from JWT token
- [ ] `GET /api/protected` - simple protected endpoint
- [ ] `GET /api/admin/stats` - admin only (check roles/groups)

### 1.6 Environment Variables

```
AUTH0_DOMAIN=your-tenant.auth0.com
AUTH0_AUDIENCE=https://your-api-identifier (optional)
```

---

## Part 2: Auth0 Setup

### 2.1 Create API in Auth0

- [ ] Auth0 Dashboard → APIs → Create API
- [ ] Name: `example-api`
- [ ] Identifier: `https://api.untrustedonline.org` (this is AUTH0_AUDIENCE)
- [ ] Signing Algorithm: RS256

### 2.2 Create SPA Application

- [ ] Auth0 Dashboard → Applications → Create Application
- [ ] Type: Single Page Application
- [ ] Name: `example-ui`

### 2.3 Configure SPA URLs

- [ ] Allowed Callback URLs: `http://localhost:5173, https://app.untrustedonline.org`
- [ ] Allowed Logout URLs: same
- [ ] Allowed Web Origins: same

### 2.4 Get Credentials

- [ ] Domain → `AUTH0_DOMAIN`
- [ ] Client ID → `AUTH0_CLIENT_ID`
- [ ] API Identifier → `AUTH0_AUDIENCE`

---

## Part 3: UI (example-ui) ✅

### 3.1 Fix Routing

- [x] `/` - redirect to `/public` (not login)
- [x] `/public` - accessible without auth (public endpoints testing)
- [x] `/login` - Auth0 login page
- [x] `/dashboard` - requires auth (private endpoints + user info)

### 3.2 Public Page Features

- [x] Test public API endpoints (health, info, time)
- [x] Show results in table
- [x] "Login" button to go to Auth0

### 3.3 Private Page Features (Dashboard)

- [x] Show user info (name, email, picture)
- [x] Show groups/roles from token
- [x] Test private API endpoints (me, protected)
- [x] Show JWT token (collapsed)
- [x] Logout button

### 3.4 Auth0 Integration

- [x] Use `@auth0/auth0-react` v2.x
- [x] Configure audience for API access
- [x] Get access token for API calls
- [x] Handle token refresh

---

## Part 4: Testing

### 4.1 Local Testing

```bash
# API
cd example-api
AUTH0_DOMAIN=xxx AUTH0_AUDIENCE=xxx ./gradlew bootRun

# UI
cd example-ui
cp .env.example .env.local
# fill AUTH0_DOMAIN, AUTH0_CLIENT_ID, AUTH0_AUDIENCE
npm run dev
```

### 4.2 Test Flow

1. [ ] Open http://localhost:5173 → see public page
2. [ ] Click "Check Public Endpoints" → see health, info
3. [ ] Click "Login" → Auth0 login
4. [ ] After login → redirect to dashboard
5. [ ] See user info + groups
6. [ ] Click "Check Private Endpoints" → see me, protected
7. [ ] Logout → back to public page

---

## Reference Links

- [Spring Security OAuth2 Resource Server](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html)
- [Auth0 Spring Boot API](https://auth0.com/docs/quickstart/backend/java-spring-security5)
- [Auth0 React SPA](https://auth0.com/docs/quickstart/spa/react)
- [Refine Auth Provider](https://refine.dev/docs/guides-concepts/authentication/)
