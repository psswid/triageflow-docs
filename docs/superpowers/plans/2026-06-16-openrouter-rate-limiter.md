# OpenRouter Rate Limiter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Symfony Rate Limiter protection to triage and admin endpoints, plus exponential backoff with `Retry-After` awareness in `OpenRouterClient`.

**Architecture:** Three parallel workstreams: (1) install & configure `symfony/rate-limiter` with token bucket policies, (2) wire `RateLimiterFactory` into controllers via constructor injection, (3) refactor `OpenRouterClient` retry logic to use exponential backoff + jitter + `Retry-After` header parsing on HTTP 429 responses.

**Tech Stack:** Symfony 7.4, PHP 8.4, `symfony/rate-limiter` (standalone component), `symfony/http-client` (MockHttpClient for tests), PHPUnit 11.5.

---

## File Structure

| File | Action | Est. Lines | Purpose |
|------|--------|-----------|---------|
| `config/packages/rate_limiter.yaml` | **NEW** | +20 | Token bucket policies: `triage_submit` (5/min), `triage_answer` (5/min), `synthetic_generate` (2/min) |
| `config/packages/cache.yaml` | **MODIFY** | +7 | Add `cache.rate_limiter` pool with `cache.adapter.array` in test env |
| `src/Shared/Infrastructure/Ai/OpenRouterClient.php` | **MODIFY** | +65 | Add `parseRetryAfter()` and `calculateBackoff()` methods; modify 429-on-fallback to backoff-retry instead of throw |
| `src/Triage/Infrastructure/Controller/TriageController.php` | **MODIFY** | +40 | Inject two `RateLimiterFactory` services; guard `submit()` and `answer()` endpoints |
| `src/Admin/Infrastructure/Controller/SyntheticCaseController.php` | **MODIFY** | +25 | Inject `RateLimiterFactory`; guard `generate()` endpoint |
| `config/services.yaml` | **MODIFY** | +10 | Wire `RateLimiterFactory` services to controllers by parameter name |
| `tests/Shared/Infrastructure/Ai/OpenRouterClientTest.php` | **MODIFY** | +60 | Tests for `Retry-After` parsing, fallback backoff retries, Retry-After > cap behavior |
| `tests/Triage/Infrastructure/Controller/TriageControllerTest.php` | **MODIFY** | +40 | Rate limit activation test: 5 OK + 1 429 |
| `tests/Admin/Infrastructure/Controller/AdminControllerTest.php` | **MODIFY** | +40 | Synthetic generate rate limit test: 2 OK + 1 429 |

---

## Design Decisions (from grill session)

| Decision | Resolution |
|----------|-----------|
| Fallback + backoff interaction | **Option A**: Fallback model switch is free (no backoff), then fallback model gets 3 exponential backoff retries with `Retry-After` awareness |
| Rate limiter keys | **Option C**: user UUID for `triage_submit`/`triage_answer`, static `'admin'` for `synthetic_generate` |
| Synthetic cooldown | Symfony Rate Limiter IS the cooldown (2/min = ~30s per click) |
| Scheduler | No rate limiter needed — cron `0 * * * *` is sufficient interval |
| Test isolation | `$client->disableReboot()` keeps kernel alive + in-memory `cache.rate_limiter` resets per-test |
| Cache pool | Auto-created by Rate Limiter; test env overrides to `cache.adapter.array` |

---

### Task 1: Install `symfony/rate-limiter` and create config

**Files:**
- Create: `config/packages/rate_limiter.yaml`
- Modify: `config/packages/cache.yaml`

- [ ] **Step 1: Install the package**

```bash
composer require symfony/rate-limiter
```

Expected: Package installs with Symfony Flex recipe (may prompt about config — accept defaults if any).

- [ ] **Step 2: Create `config/packages/rate_limiter.yaml`**

```yaml
framework:
    rate_limiter:
        triage_submit:
            policy: 'token_bucket'
            limit: 5
            rate: { interval: '1 minute' }

        triage_answer:
            policy: 'token_bucket'
            limit: 5
            rate: { interval: '1 minute' }

        synthetic_generate:
            policy: 'token_bucket'
            limit: 2
            rate: { interval: '1 minute' }
```

- [ ] **Step 3: Add test cache pool to `config/packages/cache.yaml`**

Append to existing file:

```yaml
when@test:
    framework:
        cache:
            pools:
                cache.rate_limiter:
                    adapter: cache.adapter.array
```

- [ ] **Step 4: Verify the config registers rate limiter services**

```bash
php bin/console debug:container --tag kernel.reset 2>&1 | grep rate_limiter
```

Expected: Shows three services — `limiter.triage_submit`, `limiter.triage_answer`, `limiter.synthetic_generate` as `Symfony\Component\RateLimiter\RateLimiterFactory` instances.

- [ ] **Step 5: Commit**

```bash
git add config/packages/rate_limiter.yaml config/packages/cache.yaml composer.json composer.lock symfony.lock
git commit -m "feat: install and configure symfony/rate-limiter

- Add token bucket policies: triage_submit (5/min), triage_answer (5/min),
  synthetic_generate (2/min)
- Configure cache.rate_limiter pool with array adapter in test env"
```

---

### Task 2: Modify `OpenRouterClient` — exponential backoff + `Retry-After` parsing

**Files:**
- Modify: `src/Shared/Infrastructure/Ai/OpenRouterClient.php`

**Architecture notes:**
- Existing 429 handling: primary → switch to fallback (free, sleep 2s) → fallback 429 → throw
- **New behavior**: primary → switch to fallback (free, sleep 2s) → fallback 429 → exponential backoff + Retry-After → retry up to 3 times → throw
- `calculateBackoff()` returns milliseconds; use `usleep()` for fractional-second precision
- `parseRetryAfter()` handles both numeric seconds and HTTP-date formats

- [ ] **Step 1: Add `parseRetryAfter()` private method**

Add after the `chat()` method, before the closing `}` of the class:

```php
/**
 * Parse the Retry-After header from an OpenRouter response.
 *
 * Handles both numeric seconds (e.g. "15") and HTTP-date
 * (e.g. "Wed, 21 Oct 2024 07:28:00 GMT") formats.
 *
 * @param \Symfony\Contracts\HttpClient\ResponseInterface $response The HTTP response
 *
 * @return int|null Seconds to wait, or null if header is absent/unparseable
 */
private function parseRetryAfter(\Symfony\Contracts\HttpClient\ResponseInterface $response): ?int
{
    $headers = $response->getHeaders(false);

    if (!isset($headers['retry-after']) || $headers['retry-after'] === []) {
        return null;
    }

    $value = trim($headers['retry-after'][0]);

    if (is_numeric($value)) {
        return (int) $value;
    }

    $timestamp = strtotime($value);

    if ($timestamp === false) {
        return null;
    }

    return max(0, $timestamp - time());
}
```

- [ ] **Step 2: Add `calculateBackoff()` private method**

```php
/**
 * Calculate the backoff delay in milliseconds using exponential backoff
 * with jitter, respecting the server's Retry-After header.
 *
 * @param int      $attempt          The current retry attempt (1-based)
 * @param int|null $retryAfterSeconds The Retry-After value in seconds, if available
 *
 * @return int Delay in milliseconds. Returns -1 if Retry-After exceeds cap (signal to give up).
 */
private function calculateBackoff(int $attempt, ?int $retryAfterSeconds): int
{
    $baseMs = 2_000;     // 2 seconds base delay
    $capMs = 30_000;     // 30 seconds maximum delay
    $jitterMs = 500;     // up to 500ms random jitter

    $exponentialDelay = (int) min($capMs, $baseMs * 2 ** ($attempt - 1));
    $jitter = \random_int(0, $jitterMs);
    $ourDelay = $exponentialDelay + $jitter;

    if ($retryAfterSeconds !== null) {
        if ($retryAfterSeconds > 30) {
            $this->logger?->warning('OpenRouter Retry-After exceeds cap, giving up', [
                'retry_after' => $retryAfterSeconds,
                'cap' => 30,
            ]);

            return -1; // Signal: do not retry
        }

        return max($ourDelay, $retryAfterSeconds * 1_000);
    }

    return $ourDelay;
}
```

- [ ] **Step 3: Modify the 429-on-fallback branch**

In the `catch` block, find the existing 429 handling (currently throws `OpenRouterException` when fallback is also rate limited). Replace the throw-with-error-log section (the code after the fallback-switch `if` block) with backoff retry logic:

**Before** (current code block after `// ── Rate limited (429): try fallback model ──`):

```php
if ($e instanceof HttpExceptionInterface && $e->getResponse()->getStatusCode() === 429) {
    if (!$triedFallback && $currentModel !== $this->fallbackModel) {
        // Log, switch to fallback, sleep, continue (free retry — unchanged)
        // ... existing fallback switch logic ...
    }

    // ⬇️ THIS IS WHAT GETS REPLACED — was: throw immediately on fallback 429
    $this->logger?->error('OpenRouter API rate limited on all models', [
        'model' => $currentModel,
        'duration_ms' => round((microtime(true) - $startTime) * 1000),
        'success' => false,
        'error' => 'rate_limited_all_models',
    ]);

    throw new OpenRouterException(
        'OpenRouter API rate limited on both default and fallback models',
        previous: $e,
    );
}
```

**After** (add backoff retry for fallback 429s):

```php
if ($e instanceof HttpExceptionInterface && $e->getResponse()->getStatusCode() === 429) {
    // ── Primary model 429: free switch to fallback (unchanged) ──
    if (!$triedFallback && $currentModel !== $this->fallbackModel) {
        $this->logger?->warning('OpenRouter API rate limited on primary model, switching to fallback', [
            'model' => $currentModel,
            'fallback_model' => $this->fallbackModel,
            'duration_ms' => round((microtime(true) - $startTime) * 1000),
        ]);

        $currentModel = $this->fallbackModel;
        $triedFallback = true;
        sleep(self::RETRY_DELAY_SECONDS);

        continue;
    }

    // ── Fallback model 429: retry with exponential backoff ──
    $lastException = $e;
    $retryAfter = $this->parseRetryAfter($e->getResponse());
    $attempts++;

    if ($attempts >= self::MAX_RETRIES) {
        $this->logger?->error('OpenRouter API rate limited after all retries', [
            'model' => $currentModel,
            'attempts' => $attempts,
            'duration_ms' => round((microtime(true) - $startTime) * 1000),
            'success' => false,
            'error' => 'rate_limited_exhausted',
        ]);

        throw new OpenRouterException(
            sprintf(
                'OpenRouter API rate limited after %d retries on fallback model "%s"',
                $attempts,
                $currentModel,
            ),
            previous: $e,
        );
    }

    $backoffMs = $this->calculateBackoff($attempts, $retryAfter);

    if ($backoffMs < 0) {
        throw new OpenRouterException(
            sprintf(
                'OpenRouter API rate limited with Retry-After %ds (exceeds %ds cap)',
                $retryAfter,
                30,
            ),
            previous: $e,
        );
    }

    $this->logger?->warning('OpenRouter API rate limited on fallback model, retrying with backoff', [
        'model' => $currentModel,
        'attempt' => $attempts,
        'delay_ms' => $backoffMs,
        'retry_after' => $retryAfter,
        'duration_ms' => round((microtime(true) - $startTime) * 1000),
    ]);

    \usleep($backoffMs * 1_000);

    continue;
}
```

- [ ] **Step 4: Add `Symfony\Contracts\HttpClient\ResponseInterface` import**

Add to the imports at the top of the file (needed for the `parseRetryAfter` type hint):

```php
use Symfony\Contracts\HttpClient\ResponseInterface;
```

- [ ] **Step 5: Run existing tests to verify nothing broke**

```bash
php bin/phpunit --filter OpenRouterClientTest
```

Expected: All existing OpenRouterClient tests pass (tests for fallback switch, 429 on both models, transport retries).

- [ ] **Step 6: Run PHPStan**

```bash
php vendor/bin/phpstan analyse
```

Expected: No errors at level 5.

- [ ] **Step 7: Commit**

```bash
git add src/Shared/Infrastructure/Ai/OpenRouterClient.php
git commit -m "feat: add exponential backoff with Retry-After to OpenRouterClient

- Add parseRetryAfter() — handles numeric seconds and HTTP-date formats
- Add calculateBackoff() — exponential backoff + jitter, respects Retry-After cap (30s)
- Fallback model switch remains free; subsequent fallback 429s get 3 backoff retries"
```

---

### Task 3: Wire `RateLimiterFactory` to controllers

**Files:**
- Modify: `src/Triage/Infrastructure/Controller/TriageController.php`
- Modify: `src/Admin/Infrastructure/Controller/SyntheticCaseController.php`
- Modify: `config/services.yaml`

- [ ] **Step 1: Modify `TriageController` constructor — add two `RateLimiterFactory` parameters**

Add the import:
```php
use Symfony\Component\RateLimiter\RateLimiterFactory;
```

Update the constructor:
```php
public function __construct(
    private readonly SubmitTriageHandler $submitHandler,
    private readonly TriageSubmissionRepository $repository,
    private readonly ValidatorInterface $validator,
    private readonly MessageBusInterface $messageBus,
    private readonly RateLimiterFactory $triageSubmitLimiter,
    private readonly RateLimiterFactory $triageAnswerLimiter,
) {}
```

- [ ] **Step 2: Guard `submit()` method with rate limiter check**

At the top of the `submit()` method, right after getting the `$user` and before the try/catch:

```php
/** @var User $user */
$user = $this->getUser();

// ── Rate limiter ──
$rateLimit = $this->triageSubmitLimiter->create($user->getId()->toRfc4122())->consume(1);

if (!$rateLimit->isAccepted()) {
    $retryAfter = $rateLimit->getRetryAfter()->getTimestamp() - \time();
    $resetTimestamp = $rateLimit->getRetryAfter()->getTimestamp();

    return $this->json(
        [
            'errors' => [[
                'status' => '429',
                'code' => 'RATE_LIMIT_EXCEEDED',
                'title' => 'Too Many Requests',
                'detail' => \sprintf(
                    'Rate limit exceeded. You can make 5 requests per minute. Retry in %d seconds.',
                    $retryAfter,
                ),
            ]],
        ],
        Response::HTTP_TOO_MANY_REQUESTS,
        [
            'Retry-After' => (string) $retryAfter,
            'X-Rate-Limit-Limit' => '5',
            'X-Rate-Limit-Remaining' => '0',
            'X-Rate-Limit-Reset' => (string) $resetTimestamp,
        ],
    );
}
// ── End rate limiter ──
```

- [ ] **Step 3: Guard `answer()` method with rate limiter check**

At the top of the `answer()` method, right after getting the `$user`:

```php
/** @var User $user */
$user = $this->getUser();

// ── Rate limiter ──
$rateLimit = $this->triageAnswerLimiter->create($user->getId()->toRfc4122())->consume(1);

if (!$rateLimit->isAccepted()) {
    $retryAfter = $rateLimit->getRetryAfter()->getTimestamp() - \time();

    return $this->json(
        [
            'errors' => [[
                'status' => '429',
                'code' => 'RATE_LIMIT_EXCEEDED',
                'title' => 'Too Many Requests',
                'detail' => \sprintf(
                    'Rate limit exceeded. You can make 5 requests per minute. Retry in %d seconds.',
                    $retryAfter,
                ),
            ]],
        ],
        Response::HTTP_TOO_MANY_REQUESTS,
        ['Retry-After' => (string) $retryAfter],
    );
}
// ── End rate limiter ──
```

- [ ] **Step 4: Modify `SyntheticCaseController` constructor — add `RateLimiterFactory`**

```php
use Symfony\Component\RateLimiter\RateLimiterFactory;

final class SyntheticCaseController extends AbstractController
{
    public function __construct(
        private readonly GenerateSyntheticCaseHandler $handler,
        private readonly RateLimiterFactory $syntheticGenerateLimiter,
    ) {}
```

- [ ] **Step 5: Guard `generate()` method**

At the top of the `generate()` method, before the try/catch:

```php
// ── Rate limiter ──
$rateLimit = $this->syntheticGenerateLimiter->create('admin')->consume(1);

if (!$rateLimit->isAccepted()) {
    $retryAfter = $rateLimit->getRetryAfter()->getTimestamp() - \time();

    return $this->json(
        [
            'errors' => [[
                'status' => '429',
                'code' => 'RATE_LIMIT_EXCEEDED',
                'title' => 'Too Many Requests',
                'detail' => \sprintf(
                    'Rate limit exceeded. You can make 2 requests per minute. Retry in %d seconds.',
                    $retryAfter,
                ),
            ]],
        ],
        Response::HTTP_TOO_MANY_REQUESTS,
        ['Retry-After' => (string) $retryAfter],
    );
}
// ── End rate limiter ──
```

- [ ] **Step 6: Wire `RateLimiterFactory` services in `config/services.yaml`**

Add after the existing `RegistrationController` definition:

```yaml
    App\Triage\Infrastructure\Controller\TriageController:
        arguments:
            $triageSubmitLimiter: '@limiter.triage_submit'
            $triageAnswerLimiter: '@limiter.triage_answer'

    App\Admin\Infrastructure\Controller\SyntheticCaseController:
        arguments:
            $syntheticGenerateLimiter: '@limiter.synthetic_generate'
```

- [ ] **Step 7: Run PHPStan to verify DI wiring is typed correctly**

```bash
php vendor/bin/phpstan analyse
```

Expected: No errors. The `RateLimiterFactory` injection is auto-detected as `Symfony\Component\RateLimiter\RateLimiterFactory` from the `@limiter.*` service IDs.

- [ ] **Step 8: Commit**

```bash
git add src/Triage/Infrastructure/Controller/TriageController.php src/Admin/Infrastructure/Controller/SyntheticCaseController.php config/services.yaml
git commit -m "feat: wire RateLimiterFactory into controllers

- TriageController: guard submit() and answer() endpoints (5/min each, keyed by user UUID)
- SyntheticCaseController: guard generate() endpoint (2/min, static 'admin' key)
- Return JSON:API 429 response with Retry-After and X-Rate-Limit-* headers"
```

---

### Task 4: Add rate limiter tests to `TriageControllerTest`

**Files:**
- Modify: `tests/Triage/Infrastructure/Controller/TriageControllerTest.php`

- [ ] **Step 1: Add rate limit exhaust test for `submit()`**

Add after the existing `testSubmitWithoutAuthReturns401` test:

```php
public function testSubmitReturns429WhenRateLimitExceeded(): void
{
    TestTriageAnalyzer::willReturnResultOnNextCall();
    $client = $this->createAuthenticatedClient();
    $client->disableReboot();

    // Exhaust the 5-requests-per-minute limit
    for ($i = 0; $i < 5; $i++) {
        TestTriageAnalyzer::willReturnResultOnNextCall(
            specialist: 'GP',
            urgency: 'LOW',
            justification: 'Test case %d.' . $i,
        );
        $client->jsonRequest('POST', '/api/triage/submit', [
            'initialDescription' => "Test request number {$i}",
        ]);
        $this->assertResponseStatusCodeSame(202);
    }

    // 6th request — rate limited
    $client->jsonRequest('POST', '/api/triage/submit', [
        'initialDescription' => 'This should be blocked.',
    ]);
    $this->assertResponseStatusCodeSame(429);

    $data = json_decode($client->getResponse()->getContent(), true);
    $this->assertSame('RATE_LIMIT_EXCEEDED', $data['errors'][0]['code']);
    $this->assertSame('429', $data['errors'][0]['status']);

    // Verify response headers
    $headers = $client->getResponse()->headers;
    $this->assertNotNull($headers->get('Retry-After'));
    $this->assertNotNull($headers->get('X-Rate-Limit-Limit'));
    $this->assertNotNull($headers->get('X-Rate-Limit-Remaining'));
    $this->assertNotNull($headers->get('X-Rate-Limit-Reset'));
}
```

- [ ] **Step 2: Run the new test in isolation**

```bash
php bin/phpunit --filter testSubmitReturns429WhenRateLimitExceeded
```

Expected: PASS (test takes ~1s, rate limiter checks are instant since no sleep involved — the rate limiter just tracks token consumption in the in-memory cache).

- [ ] **Step 3: Run all Triage controller tests**

```bash
php bin/phpunit --filter TriageControllerTest
```

Expected: All 8+ existing tests + new test pass.

- [ ] **Step 4: Commit**

```bash
git add tests/Triage/Infrastructure/Controller/TriageControllerTest.php
git commit -m "test: add rate limit activation test for triage submit

- Exhaust 5/min rate limit then verify 429 with RATE_LIMIT_EXCEEDED code
- Verify Retry-After and X-Rate-Limit-* response headers"
```

---

### Task 5: Add rate limiter test to `AdminControllerTest`

**Files:**
- Modify: `tests/Admin/Infrastructure/Controller/AdminControllerTest.php`

- [ ] **Step 1: Add synthetic generate rate limit test**

Add after the existing `testGenerateSyntheticReturns401WithoutAuth` test:

```php
public function testGenerateSyntheticReturns429WhenRateLimited(): void
{
    $client = $this->createAdminClient();
    $client->disableReboot();

    // Ensure system user exists in test DB
    $entityManager = $client->getContainer()->get('doctrine.orm.entity_manager');
    $userRepo = $client->getContainer()->get(\App\User\Domain\Repository\UserRepository::class);

    $systemUser = $userRepo->findById(\Symfony\Component\Uid\Uuid::fromString('00000000-0000-0000-0000-000000000001'));
    if ($systemUser === null) {
        $systemUser = \App\User\Domain\Entity\User::register('system@triageflow.local', '');
        $ref = new \ReflectionProperty($systemUser, 'id');
        $ref->setAccessible(true);
        $ref->setValue($systemUser, \Symfony\Component\Uid\Uuid::fromString('00000000-0000-0000-0000-000000000001'));
        $entityManager->persist($systemUser);
        $entityManager->flush();
    }

    // Exhaust the 2-requests-per-minute limit
    \App\Tests\Triage\Infrastructure\Controller\TestTriageAnalyzer::willReturnResultOnNextCall();
    $client->jsonRequest('POST', '/api/admin/synthetic/generate');
    $this->assertResponseStatusCodeSame(201);

    \App\Tests\Triage\Infrastructure\Controller\TestTriageAnalyzer::willReturnResultOnNextCall();
    $client->jsonRequest('POST', '/api/admin/synthetic/generate');
    $this->assertResponseStatusCodeSame(201);

    // 3rd request — rate limited
    $client->jsonRequest('POST', '/api/admin/synthetic/generate');
    $this->assertResponseStatusCodeSame(429);

    $data = json_decode($client->getResponse()->getContent(), true);
    $this->assertSame('RATE_LIMIT_EXCEEDED', $data['errors'][0]['code']);
    $this->assertSame('429', $data['errors'][0]['status']);
    $this->assertNotNull($client->getResponse()->headers->get('Retry-After'));
}
```

- [ ] **Step 2: Run the new test in isolation**

```bash
php bin/phpunit --filter testGenerateSyntheticReturns429WhenRateLimited
```

Expected: PASS.

- [ ] **Step 3: Run all admin controller tests**

```bash
php bin/phpunit --filter AdminControllerTest
```

Expected: All existing tests + new test pass.

- [ ] **Step 4: Commit**

```bash
git add tests/Admin/Infrastructure/Controller/AdminControllerTest.php
git commit -m "test: add rate limit activation test for synthetic generate

- Exhaust 2/min rate limit then verify 429 with RATE_LIMIT_EXCEEDED code
- Verify Retry-After response header"
```

---

### Task 6: Add backoff + `Retry-After` tests to `OpenRouterClientTest`

**Files:**
- Modify: `tests/Shared/Infrastructure/Ai/OpenRouterClientTest.php`

- [ ] **Step 1: Add test for fallback model retry on consecutive 429s**

Add after the existing `testChatThrowsImmediatelyOn429WhenFallbackAlreadyPassed` test (in the `// ─── Rate Limiting (429) ────` section):

```php
public function testChatRetriesFallbackModelWithBackoffOnConsecutive429(): void
{
    $callCount = 0;
    $modelsUsed = [];

    $httpClient = new MockHttpClient(function (string $method, string $url, array $options) use (&$callCount, &$modelsUsed): MockResponse {
        $callCount++;
        $json = $options['json'] ?? json_decode((string) ($options['body'] ?? '[]'), true);
        $modelsUsed[] = $json['model'] ?? 'unknown';

        if ($callCount <= 3) {
            // Calls 1-3: 429 (primary → fallback, then two fallback retries)
            return new MockResponse('{"error":"Rate limited"}', ['http_code' => 429]);
        }

        $responseBody = json_encode([
            'choices' => [['message' => ['content' => 'Recovered after fallback retries']]],
        ], JSON_THROW_ON_ERROR);

        return new MockResponse($responseBody, ['http_code' => 200]);
    });

    $client = $this->createClient($httpClient);
    $result = $client->chat([['role' => 'user', 'content' => 'Hello']]);

    $this->assertSame('Recovered after fallback retries', $result);
    $this->assertSame(4, $callCount, 'Expected 4 calls: primary 429 + fallback 429 × 2 + success');
    $this->assertSame(self::DEFAULT_MODEL, $modelsUsed[0]);
    $this->assertSame(self::FALLBACK_MODEL, $modelsUsed[1]);
    $this->assertSame(self::FALLBACK_MODEL, $modelsUsed[2]);
    $this->assertSame(self::FALLBACK_MODEL, $modelsUsed[3]);
}
```

- [ ] **Step 2: Add test for all fallback retries exhausted**

```php
public function testChatThrowsAfterMaxFallbackRetries(): void
{
    $callCount = 0;

    $httpClient = new MockHttpClient(function () use (&$callCount): MockResponse {
        $callCount++;
        return new MockResponse('{"error":"Rate limited"}', ['http_code' => 429]);
    });

    $client = $this->createClient($httpClient);

    $this->expectException(OpenRouterException::class);
    $this->expectExceptionMessageMatches('/rate limited after/i');

    try {
        $client->chat([['role' => 'user', 'content' => 'Hello']]);
    } finally {
        // Call 1: primary 429 → fallback switch (free)
        // Calls 2-4: fallback 429 × 3 → throw
        $this->assertSame(4, $callCount, 'Expected 4 calls: primary + 3 fallback retries');
    }
}
```

- [ ] **Step 3: Add test for `Retry-After` header respected with cap**

```php
public function testChatRespectsRetryAfterHeaderWhenUnderCap(): void
{
    $callCount = 0;

    $httpClient = new MockHttpClient(function () use (&$callCount): MockResponse {
        $callCount++;

        // Call 1: primary 429 → fallback switch (free)
        if ($callCount === 1) {
            return new MockResponse('{"error":"Rate limited"}', ['http_code' => 429]);
        }

        // Call 2: fallback 429 with Retry-After: 1s (under 30s cap → should retry)
        return new MockResponse('{"error":"Rate limited"}', [
            'http_code' => 429,
            'response_headers' => ['Retry-After' => '1'],
        ]);
    });

    $client = $this->createClient($httpClient);

    $this->expectException(OpenRouterException::class);

    try {
        $client->chat([['role' => 'user', 'content' => 'Hello']]);
    } finally {
        // Primary (1) + fallback with Retry-After (1) + fallback without header (1) + fallback (1) = 4
        $this->assertSame(4, $callCount, 'Expected 4 calls: primary + 3 fallback retries');
    }
}
```

- [ ] **Step 4: Add test for `Retry-After` exceeding cap**

```php
public function testChatThrowsImmediatelyWhenRetryAfterExceedsCap(): void
{
    $callCount = 0;

    $httpClient = new MockHttpClient(function () use (&$callCount): MockResponse {
        $callCount++;

        if ($callCount === 1) {
            return new MockResponse('{"error":"Rate limited"}', ['http_code' => 429]);
        }

        // Retry-After: 60s exceeds the 30s cap → should give up immediately
        return new MockResponse('{"error":"Rate limited"}', [
            'http_code' => 429,
            'response_headers' => ['Retry-After' => '60'],
        ]);
    });

    $client = $this->createClient($httpClient);

    $this->expectException(OpenRouterException::class);
    $this->expectExceptionMessageMatches('/exceeds/i');

    try {
        $client->chat([['role' => 'user', 'content' => 'Hello']]);
    } finally {
        // Only 2 calls: primary 429 → fallback 429 with Retry-After: 60 → throw
        $this->assertSame(2, $callCount, 'Expected 2 calls: primary + fallback with excessive Retry-After');
    }
}
```

- [ ] **Step 5: Run all OpenRouterClient tests**

```bash
php bin/phpunit --filter OpenRouterClientTest
```

Expected: All 10+ existing tests + 4 new tests pass. The backoff tests take ~10s due to sleep delays.

- [ ] **Step 6: Commit**

```bash
git add tests/Shared/Infrastructure/Ai/OpenRouterClientTest.php
git commit -m "test: add backoff and Retry-After tests for OpenRouterClient

- Verify fallback model retries on consecutive 429s
- Verify max retries exhausted throws OpenRouterException
- Verify Retry-After header respected within 30s cap
- Verify Retry-After exceeding cap gives up immediately"
```

---

### Task 7: Final verification

- [ ] **Step 1: Run the full test suite**

```bash
php bin/phpunit
```

Expected: **OK (242+ new tests)** — all existing tests + new rate limiter + retry tests pass. (Note: new tests add approximately +5 tests, so expect ~247 total.)

- [ ] **Step 2: Run PHPStan level 5**

```bash
php vendor/bin/phpstan analyse
```

Expected: `[OK] No errors`

- [ ] **Step 3: Verify git status is clean (all changes committed)**

```bash
git status
```

Expected: Nothing to commit, working tree clean.

---

## Self-Review

### Spec coverage
Rate limiter config for all 3 endpoints covered in Task 1 ✅
OpenRouterClient `Retry-After` parsing + exponential backoff covered in Task 2 ✅
Controller wiring for `submit()`, `answer()`, `generate()` covered in Task 3 ✅
Service definition wiring in Task 3 ✅
Rate limit activation tests (200 + 429) covered in Tasks 4 + 5 ✅
Backoff + Retry-After tests covered in Task 6 ✅
PHPStan + full test suite final verification in Task 7 ✅

### Placeholder scan
No TBDs, TODOs, "implement later", or "add appropriate error handling" found ✅
Every code block shows complete PHP code ✅
Every command includes expected output ✅

### Type consistency
- `RateLimiterFactory` imported from `Symfony\Component\RateLimiter\RateLimiterFactory` — consistent across all 3 controllers and services.yaml ✅
- `parseRetryAfter()` returns `?int` — called with `$retryAfter` in all branches ✅
- `calculateBackoff()` returns `int` (ms) — consumed with `\usleep($backoffMs * 1_000)` ✅
- `consume(1)` returns `Limit` object — `isAccepted()`, `getRetryAfter()` called consistently ✅
