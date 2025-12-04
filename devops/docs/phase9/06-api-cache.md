# API Cache Implementation

## Overview

Spring Boot API использует `StringRedisTemplate` для прямых Redis операций с TTL.

## Configuration

### Dependencies

```kotlin
// modules/api/build.gradle.kts
implementation("org.springframework.boot:spring-boot-starter-data-redis")
```

### Application Properties

```yaml
# application.yaml
spring:
  data:
    redis:
      host: ${SPRING_DATA_REDIS_HOST:localhost}
      port: ${SPRING_DATA_REDIS_PORT:6379}
      password: ${SPRING_DATA_REDIS_PASSWORD:}
```

## Implementation

### StringRedisTemplate

Используем прямые Redis операции вместо `@Cacheable`:

```kotlin
// CacheTestController.kt
@RestController
@RequestMapping("/api/cache")
class CacheTestController(
    private val redisTemplate: StringRedisTemplate
) {
    @PostMapping("/set")
    fun setValue(@RequestBody request: SetValueRequest): CacheResponse {
        // TTL обязателен! Без него ключи живут вечно
        redisTemplate.opsForValue().set(
            "test:${request.key}",
            request.value,
            1,                    // TTL value
            TimeUnit.MINUTES      // TTL unit
        )
        return CacheResponse(...)
    }

    @GetMapping("/get/{key}")
    fun getValue(@PathVariable key: String): CacheResponse {
        val value = redisTemplate.opsForValue().get("test:$key")
        return CacheResponse(...)
    }

    @DeleteMapping("/delete/{key}")
    fun deleteValue(@PathVariable key: String): CacheResponse {
        redisTemplate.delete("test:$key")
        return CacheResponse(...)
    }
}
```

## Key Points

| Aspect | Decision |
|--------|----------|
| Template | `StringRedisTemplate` (auto-configured) |
| TTL | Explicit in `set()` call |
| Prefix | Manual key prefixing (`test:${key}`) |
| `@Cacheable` | Not used (simpler approach) |
| `CacheConfig` | Not needed (no cache manager required) |

## Why Not @Cacheable?

1. **Simpler**: Прямые операции понятнее
2. **Explicit TTL**: TTL задаётся явно при каждом `set()`
3. **No Config**: Не нужен `CacheManager` bean
4. **Control**: Полный контроль над ключами и операциями

## Removed Code

Удалён `CacheConfig.kt` - не нужен для `StringRedisTemplate`:

```kotlin
// REMOVED - не нужен
@Configuration
@EnableCaching
class CacheConfig {
    @Bean
    fun cacheManager(connectionFactory: RedisConnectionFactory): RedisCacheManager { ... }
}
```

## Environment Connection

### DEV

```yaml
# services/example-api/values.yaml
extraEnv:
  - name: SPRING_DATA_REDIS_HOST
    value: "example-api-cache-dev"
```

### PRD (Sentinel Mode)

```yaml
# services/example-api/values-prd.yaml
extraEnv:
  - name: SPRING_DATA_REDIS_HOST
    value: "example-api-cache-prd-master"  # Use -master!
```

**IMPORTANT**: В PRD (Sentinel mode) использовать `-master` service для write операций!

## Testing

```bash
# Set value with TTL
curl -X POST https://api.example.com/api/cache/set \
  -H "Content-Type: application/json" \
  -d '{"key": "test1", "value": "hello"}'

# Get value
curl https://api.example.com/api/cache/get/test1

# Wait 1 minute, then get again (should be null)
curl https://api.example.com/api/cache/get/test1

# Delete value
curl -X DELETE https://api.example.com/api/cache/delete/test1
```

