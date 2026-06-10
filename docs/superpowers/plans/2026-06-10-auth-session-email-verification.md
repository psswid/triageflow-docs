# Auth Session Validation + Registration Security Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix auth session surviving DB resets (page refresh stays on `/triage` instead of redirecting to `/login`), and add password confirmation + email verification with Mailpit to registration flow.

**Architecture:** Two independent concerns but both touch auth — Issue 1 adds mount-time token validation via a new `GET /api/me` endpoint; Issue 2 adds `symfony/mailer`, Mailpit container, `email_verified` fields, verification endpoint, and frontend password confirmation.

**Tech Stack:** Symfony 7.4 (backend), React 19 + React Router v7 (frontend), PostgreSQL 16, Docker Compose with Mailpit, Symfony Mailer

---

## File Structure

### Issue 1 — Auth Session Validation (`/api/me` + mount-time check)

| File | Action | Responsibility |
|------|--------|---------------|
| `backend/src/User/Infrastructure/Controller/MeController.php` | **Create** | Returns authenticated user info via `GET /api/me` |
| `backend/tests/User/Infrastructure/Controller/MeControllerTest.php` | **Create** | Tests for `/api/me` endpoint |
| `frontend/src/api/endpoints.ts` | **Modify** | Add `AUTH.ME` endpoint constant |
| `frontend/src/api/types.ts` | **Modify** | Add `MeResponse` type |
| `frontend/src/components/auth/AuthProvider.tsx` | **Modify** | Add mount-time token validation against `/api/me` |
| `frontend/src/components/layout/ProtectedRoute.tsx` | **Modify** | Add loading state while validating |
| `frontend/src/components/shared/Loader.tsx` | **Check** | May use existing Spinner/Loader component |

### Issue 2 — Registration Security (password confirm + email verification + Mailpit)

| File | Action | Responsibility |
|------|--------|---------------|
| `backend/composer.json` | **Modify** | Add `symfony/mailer` dependency |
| `backend/src/User/Domain/Entity/User.php` | **Modify** | Add `emailVerifiedAt`, `emailVerificationToken`, `verificationTokenExpiresAt` |
| `backend/migrations/Version20260610000002.php` | **Create** | Migration for new User fields |
| `backend/src/User/Infrastructure/Controller/RegistrationController.php` | **Modify** | Add password confirmation validation, generate verification token, send email |
| `backend/src/User/Infrastructure/Controller/VerifyEmailController.php` | **Create** | Handle email verification token (`GET /api/verify-email`) |
| `backend/src/User/Infrastructure/Controller/AuthController.php` | **Modify** | Check email verified on login, return appropriate error |
| `backend/config/packages/security.yaml` | **Modify** | Allow `PUBLIC_ACCESS` for `/api/verify-email` |
| `backend/config/packages/framework.yaml` | **Modify** | Add mailer config |
| `backend/.env.example` | **Modify** | Add `MAILER_DSN` |
| `backend/.env` | **Modify** | Add `MAILER_DSN` |
| `backend/docker-compose.yml` | **Modify** | Add Mailpit service |
| `backend/tests/User/Infrastructure/Controller/RegistrationControllerTest.php` | **Modify** | Update for password confirmation + verification flow |
| `backend/tests/User/Infrastructure/Controller/AuthControllerTest.php` | **Read** | Update login test for email verified check |
| `backend/tests/User/Infrastructure/Controller/VerifyEmailControllerTest.php` | **Create** | Tests for email verification |
| `backend/tests/User/Domain/Entity/UserTest.php` | **Modify** | Test new User fields |
| `frontend/src/features/auth/pages/RegisterPage.tsx` | **Modify** | Add password confirmation field + validation |
| `frontend/src/features/auth/pages/LoginPage.tsx` | **Modify** | Show "verify your email" warning if unverified |
| `frontend/src/api/types.ts` | **Modify** | Add `RegisterRequest` update with password confirmation |
| `frontend/src/routes.tsx` | **Modify** | Add `/verify-email` route (optional — could handle via direct link) |
| `README.md` | **Modify** | Add Mailpit access info, user creation instructions |
| `docs/operating-guide.md` | **Modify** | Add Mailpit + email verification to operating guide |
| `bin/setup.sh` | **Modify** | Add Mailpit setup/verification steps |

---

## Issue 1: Auth Session Validation

### Task 1: Backend — Create `/api/me` endpoint

**Files:**
- Create: `backend/src/User/Infrastructure/Controller/MeController.php`
- Test: `backend/tests/User/Infrastructure/Controller/MeControllerTest.php`

- [ ] **Step 1: Write the failing test**

```php
<?php

declare(strict_types=1);

namespace App\Tests\User\Infrastructure\Controller;

use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;

final class MeControllerTest extends WebTestCase
{
    public function testGetMeReturnsAuthenticatedUser(): void
    {
        $client = static::createClient();

        // Register a user first
        $email = 'me-test-' . \uniqid() . '@example.com';
        $client->jsonRequest('POST', '/api/register', [
            'email' => $email,
            'password' => 'SecurePass123!',
        ]);
        $this->assertResponseStatusCodeSame(201);

        // Login to get token
        $client->jsonRequest('POST', '/api/login', [
            'email' => $email,
            'password' => 'SecurePass123!',
        ]);
        $this->assertResponseStatusCodeSame(200);
        $data = json_decode($client->getResponse()->getContent(), true);
        $token = $data['token'];

        // Call /api/me with token
        $client->jsonRequest('GET', '/api/me', [], [
            'HTTP_Authorization' => 'Bearer ' . $token,
        ]);
        $this->assertResponseStatusCodeSame(200);
        $meData = json_decode($client->getResponse()->getContent(), true);

        $this->assertArrayHasKey('data', $meData);
        $this->assertSame($email, $meData['data']['email']);
        $this->assertSame('user', $meData['data']['type']);
        $this->assertContains('ROLE_USER', $meData['data']['roles']);
    }

    public function testGetMeWithoutTokenReturns401(): void
    {
        $client = static::createClient();
        $client->jsonRequest('GET', '/api/me');
        $this->assertResponseStatusCodeSame(401);
    }

    public function testGetMeWithInvalidTokenReturns401(): void
    {
        $client = static::createClient();
        $client->jsonRequest('GET', '/api/me', [], [
            'HTTP_Authorization' => 'Bearer invalid-token-here',
        ]);
        $this->assertResponseStatusCodeSame(401);
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `docker compose exec -T php php vendor/bin/phpunit tests/User/Infrastructure/Controller/MeControllerTest.php`
Expected: ERROR — class not found (controller doesn't exist yet)

- [ ] **Step 3: Create the MeController**

```php
<?php

declare(strict_types=1);

namespace App\User\Infrastructure\Controller;

use App\User\Domain\Entity\User;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\CurrentUser;

final class MeController extends AbstractController
{
    #[Route('/api/me', methods: ['GET'], name: 'api_me')]
    public function __invoke(#[CurrentUser] ?User $user): JsonResponse
    {
        if (!$user) {
            return $this->json(['error' => 'Unauthorized'], 401);
        }

        return $this->json([
            'data' => [
                'id' => $user->getId()->toRfc4122(),
                'type' => 'user',
                'email' => $user->getEmail(),
                'roles' => $user->getRoles(),
                'createdAt' => $user->getCreatedAt()->format('c'),
            ],
        ]);
    }
}
```

The endpoint falls under the `api` firewall which requires JWT auth. No access_control rule needed — the default `{ path: ^/api, roles: IS_AUTHENTICATED_FULLY }` covers it.

- [ ] **Step 4: Run test to verify it passes**

Run: `docker compose exec -T php php vendor/bin/phpunit tests/User/Infrastructure/Controller/MeControllerTest.php`
Expected: OK (3 tests, 6 assertions)

- [ ] **Step 5: Verify all backend tests still pass**

Run: `docker compose exec -T php php vendor/bin/phpunit`
Expected: OK (207 tests — 204 existing + 3 new)

### Task 2: Frontend — Add mount-time token validation

**Files:**
- Modify: `frontend/src/api/endpoints.ts`
- Modify: `frontend/src/api/types.ts`
- Modify: `frontend/src/components/auth/AuthProvider.tsx`
- Modify: `frontend/src/components/layout/ProtectedRoute.tsx`

- [ ] **Step 1: Add ME endpoint to endpoints.ts**

```typescript
// In src/api/endpoints.ts, add to AUTH:
ME: '/api/me',
```

- [ ] **Step 2: Add MeResponse type to types.ts**

```typescript
// Add to types.ts:
export interface MeResponse {
  readonly data: {
    readonly id: string;
    readonly type: 'user';
    readonly email: string;
    readonly roles: readonly string[];
    readonly createdAt: string;
  };
}
```

- [ ] **Step 3: Add mount-time validation to AuthProvider**

Modify `AuthProvider.tsx` to validate the token on mount by calling `/api/me`:

```typescript
import { createContext, useState, useCallback, useEffect, type ReactNode } from 'react';
import { apiClient } from '../../api/client';
import { ENDPOINTS } from '../../api/endpoints';
import type { MeResponse } from '../../api/types';

interface AuthState {
  readonly isAuthenticated: boolean;
  readonly isAdmin: boolean;
  readonly token: string | null;
  readonly isLoading: boolean;  // NEW: true while validating on mount
}
```

Update the initial state to include `isLoading: true` when a token is present:

```typescript
const [state, setState] = useState<AuthState>(() => {
  const token = localStorage.getItem('jwt_token');
  if (!token) return { isAuthenticated: false, isAdmin: false, token: null, isLoading: false };

  try {
    // Decode and check exp client-side first for instant fail on expired tokens
    const payload = JSON.parse(atob(token.split('.')[1]!)) as { exp?: number };
    if (payload.exp && payload.exp * 1000 < Date.now()) {
      localStorage.removeItem('jwt_token');
      return { isAuthenticated: false, isAdmin: false, token: null, isLoading: false };
    }
    return { isAuthenticated: true, isAdmin: decodeIsAdmin(token), token, isLoading: true };
  } catch {
    localStorage.removeItem('jwt_token');
    return { isAuthenticated: false, isAdmin: false, token: null, isLoading: false };
  }
});
```

Add the mount-time validation effect:

```typescript
// Validate token against backend on mount
useEffect(() => {
  const token = localStorage.getItem('jwt_token');
  if (!token) return;

  apiClient.get<MeResponse>(ENDPOINTS.AUTH.ME)
    .then(() => {
      // Token is valid — mark loading complete
      setState(prev => ({ ...prev, isLoading: false }));
    })
    .catch(() => {
      // Token invalid/expired — clear and redirect
      localStorage.removeItem('jwt_token');
      sessionStorage.removeItem('jwt_original');
      sessionStorage.removeItem('impersonated');
      setState({ isAuthenticated: false, isAdmin: false, token: null, isLoading: false });
    });
}, []);
```

Update `login` to set `isLoading: false`:

```typescript
const login = useCallback((token: string) => {
  localStorage.setItem('jwt_token', token);
  setState({ isAuthenticated: true, isAdmin: decodeIsAdmin(token), token, isLoading: false });
}, []);
```

Update `logout` to include `isLoading: false`:

```typescript
const logout = useCallback(() => {
  localStorage.removeItem('jwt_token');
  sessionStorage.removeItem('jwt_original');
  sessionStorage.removeItem('impersonated');
  setState({ isAuthenticated: false, isAdmin: false, token: null, isLoading: false });
  setImpersonationState({ isImpersonating: false, impersonatedEmail: null, originalToken: null });
}, []);
```

- [ ] **Step 4: Add loading state to ProtectedRoute**

```typescript
import { Navigate, Outlet } from 'react-router-dom';
import { useAuth } from '../../hooks/useAuth';
import { Loader } from '../shared/Loader';

export function ProtectedRoute() {
  const { isAuthenticated, isLoading } = useAuth();

  if (isLoading) {
    return <Loader />;
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return <Outlet />;
}
```

- [ ] **Step 5: Run frontend tests to verify nothing broke**

Run: `npx vitest run` from `frontend/`
Expected: OK (81 tests)

### Task 3: Verify Issue 1 end-to-end

- [ ] **Step 1: Start frontend dev server**

Run: `npm run dev` from `frontend/`

- [ ] **Step 2: Manual test — login, refresh, then reset DB, refresh again**

1. Login as admin or register a new user
2. Page should redirect to `/triage`
3. Refresh the page — should stay on `/triage` (token valid)
4. Reset the DB: `docker compose exec -T php php bin/console doctrine:database:drop --force && docker compose exec -T php php bin/console doctrine:database:create && docker compose exec -T php php bin/console doctrine:migrations:migrate --no-interaction`
5. Refresh the frontend page — should now redirect to `/login` (token invalid after DB reset)

---

## Issue 2: Registration Security

### Task 4: Backend — Install `symfony/mailer` and configure

**Files:**
- Modify: `backend/composer.json`
- Modify: `backend/.env.example`
- Modify: `backend/.env`
- Modify: `backend/config/packages/framework.yaml`

- [ ] **Step 1: Require symfony/mailer**

Run from `backend/`:
```bash
docker compose exec -T php php -d memory_limit=-1 /usr/bin/composer require symfony/mailer
```

This installs `symfony/mailer` and the `symfony/mailer` bundle.

- [ ] **Step 2: Add MAILER_DSN to `.env.example` and `.env`**

In `.env.example` and `.env`, add:
```
###> symfony/mailer ###
MAILER_DSN=smtp://mailpit:1025
###< symfony/mailer ###
```

- [ ] **Step 3: Add mailer config to `framework.yaml`**

```yaml
# Add to framework.yaml:
framework:
    secret: '%env(APP_SECRET)%'
    session: true
    mailer:
        dsn: '%env(MAILER_DSN)%'
```

- [ ] **Step 4: Run tests to confirm mailer doesn't break anything**

Run: `docker compose exec -T php php vendor/bin/phpunit`
Expected: OK (204+ tests)

### Task 5: Backend — Update User entity with email verification fields

**Files:**
- Modify: `backend/src/User/Domain/Entity/User.php`
- Create: `backend/migrations/Version20260610000002.php`
- Modify: `backend/tests/User/Domain/Entity/UserTest.php`

- [ ] **Step 1: Write failing tests for new User fields**

Add tests to `UserTest.php`:

```php
public function testNewUserHasNullEmailVerifiedAt(): void
{
    $this->assertNull($this->user->getEmailVerifiedAt());
}

public function testMarkEmailVerifiedSetsTimestamp(): void
{
    $this->user->markEmailVerified();
    $this->assertNotNull($this->user->getEmailVerifiedAt());
}

public function testGetEmailVerificationTokenReturnsToken(): void
{
    $token = $this->user->getEmailVerificationToken();
    $this->assertNotNull($token);
    $this->assertNotEmpty($token);
}

public function testIsEmailVerifiedReturnsFalseInitially(): void
{
    $this->assertFalse($this->user->isEmailVerified());
}

public function testIsEmailVerifiedReturnsTrueAfterVerification(): void
{
    $this->user->markEmailVerified();
    $this->assertTrue($this->user->isEmailVerified());
}

public function testMarkEmailVerifiedIsIdempotent(): void
{
    $this->user->markEmailVerified();
    $verifiedAt = $this->user->getEmailVerifiedAt();
    $this->user->markEmailVerified();
    $this->assertSame($verifiedAt, $this->user->getEmailVerifiedAt());
}
```

Run the test: `docker compose exec -T php php vendor/bin/phpunit tests/User/Domain/Entity/UserTest.php`
Expected: FAIL — methods don't exist yet

- [ ] **Step 2: Add verification fields to User entity**

Add these properties:

```php
use Doctrine\DBAL\Types\Types;

#[ORM\Column(type: Types::DATETIME_IMMUTABLE, nullable: true)]
private ?\DateTimeImmutable $emailVerifiedAt = null;

#[ORM\Column(type: Types::STRING, length: 64, nullable: true)]
private ?string $emailVerificationToken = null;

#[ORM\Column(type: Types::DATETIME_IMMUTABLE, nullable: true)]
private ?\DateTimeImmutable $verificationTokenExpiresAt = null;
```

Add the constructor to generate a verification token:

```php
public function __construct(string $email, string $password)
{
    $this->id = Uuid::v4();
    $this->email = $email;
    $this->password = $password;
    $this->roles = ['ROLE_USER'];
    $this->createdAt = new \DateTimeImmutable();
    $this->emailVerificationToken = bin2hex(random_bytes(32));
    $this->verificationTokenExpiresAt = new \DateTimeImmutable('+24 hours');
}
```

Add methods:

```php
public function getEmailVerifiedAt(): ?\DateTimeImmutable
{
    return $this->emailVerifiedAt;
}

public function getEmailVerificationToken(): ?string
{
    return $this->emailVerificationToken;
}

public function isEmailVerified(): bool
{
    return $this->emailVerifiedAt !== null;
}

public function markEmailVerified(): void
{
    if ($this->emailVerifiedAt === null) {
        $this->emailVerifiedAt = new \DateTimeImmutable();
        $this->emailVerificationToken = null;
        $this->verificationTokenExpiresAt = null;
    }
}

public function isVerificationTokenExpired(): bool
{
    return $this->verificationTokenExpiresAt !== null
        && $this->verificationTokenExpiresAt < new \DateTimeImmutable();
}
```

- [ ] **Step 3: Create migration**

Run from `backend/`:
```bash
docker compose exec -T php php bin/console make:migration
```

Or create manually:

```php
<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260610000002 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Add email verification fields to users table';
    }

    public function up(Schema $schema): void
    {
        $this->addSql('ALTER TABLE users ADD email_verified_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NULL');
        $this->addSql('ALTER TABLE users ADD email_verification_token VARCHAR(64) DEFAULT NULL');
        $this->addSql('ALTER TABLE users ADD verification_token_expires_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NULL');
        $this->addSql('COMMENT ON COLUMN users.email_verified_at IS \'(DC2Type:datetime_immutable)\'');
        $this->addSql('COMMENT ON COLUMN users.verification_token_expires_at IS \'(DC2Type:datetime_immutable)\'');
    }

    public function down(Schema $schema): void
    {
        $this->addSql('ALTER TABLE users DROP email_verified_at');
        $this->addSql('ALTER TABLE users DROP email_verification_token');
        $this->addSql('ALTER TABLE users DROP verification_token_expires_at');
    }
}
```

Run: `docker compose exec -T php php bin/console doctrine:migrations:migrate --no-interaction`

- [ ] **Step 4: Run User entity tests**

Run: `docker compose exec -T php php vendor/bin/phpunit tests/User/Domain/Entity/UserTest.php`
Expected: OK

### Task 6: Backend — Update Registration controller with password confirmation and email sending

**Files:**
- Modify: `backend/src/User/Infrastructure/Controller/RegistrationController.php`
- Modify: `backend/tests/User/Infrastructure/Controller/RegistrationControllerTest.php`

- [ ] **Step 1: Write failing tests for new registration behavior**

Add to `RegistrationControllerTest.php`:

```php
public function testRegistrationRequiresPasswordConfirmation(): void
{
    $client = static::createClient();
    $client->jsonRequest('POST', '/api/register', [
        'email' => $this->uniqueEmail(),
        'password' => 'SecurePass123!',
        // Missing password_confirmation
    ]);

    $this->assertResponseStatusCodeSame(422);
    $data = json_decode($client->getResponse()->getContent(), true);
    $this->assertSame('VALIDATION_FAILED', $data['errors'][0]['code']);
}

public function testRegistrationPasswordConfirmationMismatch(): void
{
    $client = static::createClient();
    $client->jsonRequest('POST', '/api/register', [
        'email' => $this->uniqueEmail(),
        'password' => 'SecurePass123!',
        'password_confirmation' => 'DifferentPass123!',
    ]);

    $this->assertResponseStatusCodeSame(422);
    $data = json_decode($client->getResponse()->getContent(), true);
    $this->assertSame('VALIDATION_FAILED', $data['errors'][0]['code']);
}

public function testRegistrationWithPasswordConfirmationSucceeds(): void
{
    $client = static::createClient();
    $email = $this->uniqueEmail();
    $client->jsonRequest('POST', '/api/register', [
        'email' => $email,
        'password' => 'SecurePass123!',
        'password_confirmation' => 'SecurePass123!',
    ]);

    $this->assertResponseStatusCodeSame(201);
    $data = json_decode($client->getResponse()->getContent(), true);
    $this->assertArrayHasKey('data', $data);
    $this->assertSame($email, $data['data']['attributes']['email']);
}
```

Run: `docker compose exec -T php php vendor/bin/phpunit tests/User/Infrastructure/Controller/RegistrationControllerTest.php`
Expected: 2 new tests FAIL (existing tests may also fail if they don't include password_confirmation)

- [ ] **Step 2: Update existing tests to include password_confirmation**

Update all existing test calls in `RegistrationControllerTest.php` to include `'password_confirmation' => 'SecurePass123!'`.

- [ ] **Step 3: Update RegistrationController**

Add `password_confirmation` validation and email verification:

```php
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Mime\Email;

final class RegistrationController extends AbstractController
{
    public function __construct(
        private readonly UserRepository $userRepository,
        private readonly UserPasswordHasherInterface $passwordHasher,
        private readonly ValidatorInterface $validator,
        private readonly MailerInterface $mailer,
        private readonly string $defaultUri,
    ) {}

    #[Route('/api/register', methods: ['POST'], name: 'api_register')]
    public function __invoke(Request $request): JsonResponse
    {
        $data = json_decode($request->getContent(), true);

        $constraints = new Assert\Collection([
            'email' => [
                new Assert\NotBlank(),
                new Assert\Email(),
            ],
            'password' => [
                new Assert\NotBlank(),
                new Assert\Length(['min' => 8]),
            ],
            'password_confirmation' => [
                new Assert\NotBlank(),
            ],
        ]);

        $violations = $this->validator->validate($data, $constraints);
        if (count($violations) > 0) {
            return $this->json([...], Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        // Check passwords match
        if ($data['password'] !== $data['password_confirmation']) {
            return $this->json([
                'errors' => [[
                    'status' => '422',
                    'code' => 'VALIDATION_FAILED',
                    'title' => 'Validation Failed',
                    'detail' => '[password_confirmation]: Passwords do not match.',
                ]],
            ], Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        // Check for existing user
        $existing = $this->userRepository->findByEmail($data['email']);
        if ($existing !== null) {
            return $this->json([...], Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        // Create user (constructor generates verification token)
        $hashedPassword = $this->passwordHasher->hashPassword(new User('', ''), $data['password']);
        $user = User::register($data['email'], $hashedPassword);
        $this->userRepository->save($user);

        // Send verification email
        $verifyUrl = sprintf(
            '%s/api/verify-email?token=%s',
            rtrim($this->defaultUri, '/'),
            $user->getEmailVerificationToken()
        );

        try {
            $email = (new Email())
                ->from('noreply@triageflow.local')
                ->to($user->getEmail())
                ->subject('Verify your TriageFlow account')
                ->html(sprintf(
                    '<p>Thanks for registering! Click the link below to verify your email:</p>
                     <p><a href="%s">Verify Email</a></p>
                     <p>This link expires in 24 hours.</p>',
                    htmlspecialchars($verifyUrl)
                ));

            $this->mailer->send($email);
        } catch (\Throwable $e) {
            // Email failure is non-fatal in dev/demo mode — log and proceed
            // User can still use the app (email verification is best-effort)
        }

        return $this->json([
            'data' => [
                'id' => $user->getId()->toRfc4122(),
                'type' => 'user',
                'attributes' => [
                    'email' => $user->getEmail(),
                    'roles' => $user->getRoles(),
                    'createdAt' => $user->getCreatedAt()->format('c'),
                    'emailVerified' => false,
                ],
            ],
        ], Response::HTTP_CREATED);
    }
}
```

Update `services.yaml` to inject `$defaultUri`:

```yaml
App\User\Infrastructure\Controller\RegistrationController:
    arguments:
        $defaultUri: '%env(DEFAULT_URI)%'
```

Or register in the controller constructor differently. Check the existing pattern in the codebase — if other controllers use constructor DI without explicit wiring, Symfony autowire handles it. For the `$defaultUri` scalar, we need explicit wiring:

```yaml
# config/services.yaml
services:
    _defaults:
        autowire: true
        autoconfigure: true

    App\User\Infrastructure\Controller\RegistrationController:
        arguments:
            $defaultUri: '%env(DEFAULT_URI)%'
```

- [ ] **Step 4: Run registration tests**

Run: `docker compose exec -T php php vendor/bin/phpunit tests/User/Infrastructure/Controller/RegistrationControllerTest.php`
Expected: OK (5 tests — 2 existing updated + 3 new)

### Task 7: Backend — Create email verification endpoint

**Files:**
- Create: `backend/src/User/Infrastructure/Controller/VerifyEmailController.php`
- Create: `backend/tests/User/Infrastructure/Controller/VerifyEmailControllerTest.php`
- Modify: `backend/config/packages/security.yaml`

- [ ] **Step 1: Write failing tests**

```php
<?php

declare(strict_types=1);

namespace App\Tests\User\Infrastructure\Controller;

use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;

final class VerifyEmailControllerTest extends WebTestCase
{
    public function testVerifyEmailWithValidToken(): void
    {
        $client = static::createClient();
        $email = 'verify-test-' . \uniqid() . '@example.com';

        // Register
        $client->jsonRequest('POST', '/api/register', [
            'email' => $email,
            'password' => 'SecurePass123!',
            'password_confirmation' => 'SecurePass123!',
        ]);
        $this->assertResponseStatusCodeSame(201);

        // Get the verification token from the database
        // In test, we can't easily get it from the response,
        // so we use the container to fetch the user
        $user = $client->getContainer()->get('App\User\Domain\Repository\UserRepository')
            ->findByEmail($email);
        $token = $user->getEmailVerificationToken();
        $this->assertNotNull($token);

        // Verify
        $client->jsonRequest('GET', '/api/verify-email?token=' . $token);
        $this->assertResponseStatusCodeSame(200);

        $data = json_decode($client->getResponse()->getContent(), true);
        $this->assertArrayHasKey('message', $data);
        $this->assertSame('Email verified successfully', $data['message']);
    }

    public function testVerifyEmailWithInvalidToken(): void
    {
        $client = static::createClient();
        $client->jsonRequest('GET', '/api/verify-email?token=invalid-token-that-does-not-exist');
        $this->assertResponseStatusCodeSame(404);

        $data = json_decode($client->getResponse()->getContent(), true);
        $this->assertSame('Invalid verification token', $data['error']);
    }

    public function testVerifyEmailWithoutToken(): void
    {
        $client = static::createClient();
        $client->jsonRequest('GET', '/api/verify-email');
        $this->assertResponseStatusCodeSame(400);
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `docker compose exec -T php php vendor/bin/phpunit tests/User/Infrastructure/Controller/VerifyEmailControllerTest.php`
Expected: ERROR — class not found

- [ ] **Step 3: Create VerifyEmailController**

```php
<?php

declare(strict_types=1);

namespace App\User\Infrastructure\Controller;

use App\User\Domain\Repository\UserRepository;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

final class VerifyEmailController extends AbstractController
{
    public function __construct(
        private readonly UserRepository $userRepository,
    ) {}

    #[Route('/api/verify-email', methods: ['GET'], name: 'api_verify_email')]
    public function __invoke(Request $request): JsonResponse
    {
        $token = $request->query->get('token');

        if (!$token || !is_string($token)) {
            return $this->json(['error' => 'Missing verification token'], Response::HTTP_BAD_REQUEST);
        }

        $user = $this->userRepository->findByVerificationToken($token);

        if ($user === null) {
            return $this->json(['error' => 'Invalid verification token'], Response::HTTP_NOT_FOUND);
        }

        if ($user->isEmailVerified()) {
            return $this->json(['message' => 'Email already verified'], Response::HTTP_OK);
        }

        if ($user->isVerificationTokenExpired()) {
            return $this->json(['error' => 'Verification token has expired'], Response::HTTP_GONE);
        }

        $user->markEmailVerified();
        $this->userRepository->save($user);

        return $this->json(['message' => 'Email verified successfully'], Response::HTTP_OK);
    }
}
```

- [ ] **Step 4: Add `findByVerificationToken` to UserRepository**

In `UserRepository` interface:

```php
public function findByVerificationToken(string $token): ?User;
```

In `DoctrineUserRepository`:

```php
public function findByVerificationToken(string $token): ?User
{
    return $this->entityManager
        ->getRepository(User::class)
        ->findOneBy(['emailVerificationToken' => $token]);
}
```

- [ ] **Step 5: Add access control rule**

In `security.yaml`, add PUBLIC_ACCESS for verification:

```yaml
access_control:
    - { path: ^/api/register,    roles: PUBLIC_ACCESS }
    - { path: ^/api/verify-email, roles: PUBLIC_ACCESS }
    - { path: ^/api/login,       roles: PUBLIC_ACCESS }
    - { path: ^/api/admin,       roles: ROLE_ADMIN }
    - { path: ^/api/triage,      roles: ROLE_USER }
    - { path: ^/api,             roles: IS_AUTHENTICATED_FULLY }
```

- [ ] **Step 6: Run tests**

Run: `docker compose exec -T php php vendor/bin/phpunit tests/User/Infrastructure/Controller/VerifyEmailControllerTest.php`
Expected: OK (3 tests)

### Task 8: Backend — Check email verification on login

**Files:**
- Modify: `backend/src/User/Infrastructure/Controller/AuthController.php` (if it exists — currently a stub)
- Modify: `backend/tests/User/Infrastructure/Controller/AuthControllerTest.php`

Note: Currently the login is handled by the `json_login` firewall in `security.yaml`, not by the `AuthController` (which is a stub). To add email verification on login, we need to use a custom authentication success/failure handler or a custom user checker.

The cleanest Symfony approach: **Create a custom user checker** that checks `isEmailVerified()` and denies access if not verified.

- [ ] **Step 1: Create an EmailVerifiedUserChecker**

```php
<?php

declare(strict_types=1);

namespace App\User\Infrastructure\Security;

use App\User\Domain\Entity\User;
use Symfony\Component\Security\Core\Exception\CustomUserMessageAuthenticationException;
use Symfony\Component\Security\Core\User\UserCheckerInterface;
use Symfony\Component\Security\Core\User\UserInterface;

final class EmailVerifiedUserChecker implements UserCheckerInterface
{
    public function checkPreAuth(UserInterface $user): void
    {
        if (!$user instanceof User) {
            return;
        }

        // Skip check for admin users (seeded by migration) and system user
        if (in_array('ROLE_ADMIN', $user->getRoles(), true)) {
            return;
        }

        if (!$user->isEmailVerified()) {
            throw new CustomUserMessageAuthenticationException(
                'Please verify your email address before logging in.'
            );
        }
    }

    public function checkPostAuth(UserInterface $user): void
    {
        // No post-auth checks needed
    }
}
```

Register in `services.yaml`:

```yaml
App\User\Infrastructure\Security\EmailVerifiedUserChecker:
    tags:
        - { name: 'security.user_checker', firewall: 'login' }
```

Actually, `security.user_checker` is per-firewall in Symfony 7.4. Let me use a different approach — register as a global user checker:

```yaml
# In security.yaml
security:
    user_checker: App\User\Infrastructure\Security\EmailVerifiedUserChecker
```

Wait, this would apply to all firewalls. Better approach: just skip the system user check in the checker itself (which we already do).

Actually, checking again — the `user_checker` under `security` is global. We can set it per-firewall too:

```yaml
firewalls:
    login:
        pattern: ^/api/login
        stateless: true
        user_checker: App\User\Infrastructure\Security\EmailVerifiedUserChecker
        json_login: ...
```

Hmm, but the `login` firewall's user provider loads the user, so the user checker fires there. That's the right place. Let me use the per-firewall approach.

```yaml
login:
    pattern: ^/api/login
    stateless: true
    user_checker: App\User\Infrastructure\Security\EmailVerifiedUserChecker
    json_login:
        check_path: api_login
        username_path: email
        password_path: password
        success_handler: lexik_jwt_authentication.handler.authentication_success
        failure_handler: lexik_jwt_authentication.handler.authentication_failure
```

- [ ] **Step 2: Write failing test**

In `AuthControllerTest.php`, add:

```php
public function testLoginFailsForUnverifiedEmail(): void
{
    $client = static::createClient();
    $email = 'unverified-' . \uniqid() . '@example.com';

    // Register (user starts unverified)
    $client->jsonRequest('POST', '/api/register', [
        'email' => $email,
        'password' => 'SecurePass123!',
        'password_confirmation' => 'SecurePass123!',
    ]);
    $this->assertResponseStatusCodeSame(201);

    // Attempt login — should fail
    $client->jsonRequest('POST', '/api/login', [
        'email' => $email,
        'password' => 'SecurePass123!',
    ]);
    $this->assertResponseStatusCodeSame(401);
    $data = json_decode($client->getResponse()->getContent(), true);
    $this->assertStringContainsString('verify', strtolower($data['message'] ?? ''));
}
```

- [ ] **Step 3: Create the user checker and register it**

Create `src/User/Infrastructure/Security/EmailVerifiedUserChecker.php` as above.

Register in `security.yaml` per the `login` firewall.

- [ ] **Step 4: Run login tests**

Run: `docker compose exec -T php php vendor/bin/phpunit tests/User/Infrastructure/Controller/AuthControllerTest.php`
Expected: OK (new test passes)

### Task 9: Docker — Add Mailpit service

**Files:**
- Modify: `backend/docker-compose.yml`
- Check: `backend/Dockerfile` — probably no changes needed

- [ ] **Step 1: Add Mailpit to docker-compose.yml**

```yaml
mailpit:
    image: axllent/mailpit:latest
    container_name: triageflow_mailpit
    ports:
        - "1025:1025"   # SMTP port
        - "8025:8025"   # Web UI port
    networks:
        - triageflow
```

Add it after the `db` service, before `volumes`.

- [ ] **Step 2: Restart Docker and verify Mailpit**

```bash
docker compose up -d
docker compose ps  # Should show mailpit running
```

- [ ] **Step 3: Verify Mailpit web UI**

Open `http://localhost:8025` — should show Mailpit interface (no emails yet).

### Task 10: Frontend — Add password confirmation to registration form

**Files:**
- Modify: `frontend/src/features/auth/pages/RegisterPage.tsx`
- Modify: `frontend/src/api/types.ts` — Update RegisterRequest type

- [ ] **Step 1: Update RegisterRequest type**

```typescript
export interface RegisterRequest {
  readonly email: string;
  readonly password: string;
  readonly password_confirmation: string;
}
```

- [ ] **Step 2: Add password confirmation field and validation to RegisterPage**

```typescript
const [email, setEmail] = useState('');
const [password, setPassword] = useState('');
const [passwordConfirmation, setPasswordConfirmation] = useState('');
const [errors, setErrors] = useState<{
  readonly email?: string;
  readonly password?: string;
  readonly password_confirmation?: string;
}>({});

// Client-side validation before submit
const validatePasswordsMatch = (): boolean => {
  if (password !== passwordConfirmation) {
    setErrors((prev) => ({ ...prev, password_confirmation: 'Passwords do not match' }));
    return false;
  }
  return true;
};

const handleSubmit = (e: FormEvent) => {
  e.preventDefault();
  setErrors({});
  if (!validatePasswordsMatch()) return;
  register.mutate({ email, password, password_confirmation: passwordConfirmation });
};
```

Add the confirmation field in the JSX:

```tsx
<Input
  label="Confirm Password"
  type="password"
  value={passwordConfirmation}
  onChange={(e) => setPasswordConfirmation(e.target.value)}
  error={errors.password_confirmation}
  required
  minLength={8}
/>
```

Place it right after the Password field.

- [ ] **Step 3: Run frontend tests**

Run: `npx vitest run` from `frontend/`
Expected: OK (no existing RegisterPage tests to break)

### Task 11: Frontend — Show verification notice on login page

**Files:**
- Modify: `frontend/src/features/auth/pages/LoginPage.tsx`

- [ ] **Step 1: Show "check your email" notice after registration**

The existing code already shows a "Account created! Please login." message. Update it to mention email verification:

```tsx
{justRegistered && (
  <div className="mb-4 rounded-lg bg-blue-50 p-3 text-sm text-blue-700 dark:bg-blue-900/50 dark:text-blue-300">
    Account created! Check your email to verify your address, then login.
    <br />
    <span className="text-xs">
      (In development, check <a href="http://localhost:8025" className="underline" target="_blank" rel="noopener noreferrer">Mailpit</a> at port 8025)
    </span>
  </div>
)}
```

- [ ] **Step 2: Handle "email not verified" login error**

The custom user checker returns a 401 with a message. Update the login error handling:

```typescript
onError: (error: unknown) => {
  const axiosError = error as { readonly response?: { readonly data?: { readonly message?: string } } };
  const message = axiosError.response?.data?.message ?? 'Invalid email or password';
  setError(message);
},
```

- [ ] **Step 3: Add login error as a different color for verification vs bad credentials**

```typescript
const [errorType, setErrorType] = useState<'error' | 'warning'>('error');

onError: (error: unknown) => {
  const axiosError = error as { readonly response?: { readonly data?: { readonly message?: string } } };
  const message = axiosError.response?.data?.message ?? 'Invalid email or password';
  setError(message);
  setErrorType(message.includes('verify') ? 'warning' : 'error');
},
```

```tsx
{error && (
  <p className={clsx(
    'text-sm',
    errorType === 'warning'
      ? 'text-amber-600 dark:text-amber-400'
      : 'text-red-600 dark:text-red-400'
  )}>
    {error}
  </p>
)}
```

Need to import `clsx`:
```typescript
import { clsx } from 'clsx';
```

### Task 12: Documentation — Update README and operating guide

**Files:**
- Modify: `README.md`
- Modify: `docs/operating-guide.md`

- [ ] **Step 1: Update README with Mailpit info and user creation instructions**

Add a new section after "Quick Start":

```markdown
## Email Verification (Local Development)

This project uses **Mailpit** for local email testing. When you register a new user, a verification email is sent.

### Accessing Emails

1. Start the backend (`docker compose up -d`)
2. Register a new user via the frontend UI
3. Open [http://localhost:8025](http://localhost:8025) to see the verification email
4. Click the verification link in the email to activate your account

### Creating a New User

1. Navigate to `http://localhost:5173/register`
2. Enter your email and password (minimum 8 characters)
3. Confirm your password
4. Submit the form
5. Check Mailpit at `http://localhost:8025` for the verification email
6. Click the verification link (opens in browser)
7. Login with your credentials
```

- [ ] **Step 2: Update operating guide**

Add to `docs/operating-guide.md`:

```markdown
## Mailpit (Email Testing)

Mailpit runs as part of the Docker stack on ports:
- **SMTP:** `localhost:1025` (for Symfony Mailer)
- **Web UI:** `localhost:8025` (view captured emails)

Verification emails are sent on registration. All emails are caught by Mailpit and never leave your machine.
```

### Task 13: Update setup script

**Files:**
- Modify: `bin/setup.sh`

- [ ] **Step 1: Add Mailpit verification to setup script**

After Docker services are up, add:
```bash
echo "Verifying Mailpit..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8025 > /dev/null 2>&1; then
    echo "  ✅ Mailpit running at http://localhost:8025"
else
    echo "  ⚠️  Mailpit not accessible — check docker compose ps"
fi
```

### Task 14: Final verification

- [ ] **Step 1: Run all backend tests**

Run: `docker compose exec -T php php vendor/bin/phpunit`
Expected: OK (all tests pass)

- [ ] **Step 2: Run all frontend tests**

Run: `npx vitest run` from `frontend/`
Expected: OK

- [ ] **Step 3: Manual end-to-end test**

1. Start frontend: `npm run dev` from `frontend/`
2. Open `http://localhost:5173`
3. Register a new user with password confirmation
4. Check Mailpit at `http://localhost:8025` for verification email
5. Click verification link
6. Login with credentials
7. Submit a triage and verify it works
8. Logout, refresh page — should stay on login page (not sneak to /triage)

---

## Self-Review Checklist

| Requirement | Task | Status |
|-------------|------|--------|
| Page refresh after DB reset redirects to /login | Task 1, 2, 3 | ✅ |
| Password confirmation input on registration | Task 6 (backend), Task 10 (frontend) | ✅ |
| Email verification with verification token | Task 5, 6, 7, 8 | ✅ |
| SMTP container (Mailpit) | Task 9 | ✅ |
| README with Mailpit + user creation instructions | Task 12 | ✅ |
| Operating guide update | Task 12 | ✅ |
| Setup script update | Task 13 | ✅ |
| Block unverified email login | Task 8 | ✅ |
| All existing tests continue to pass | Task 14 | ✅ |
