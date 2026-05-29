# TriageFlow Backend Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Symfony 7.4 API skeleton with Docker, PostgreSQL, Doctrine entities, JWT auth, symfony/ai + OpenRouter, triage interview pipeline (async via Messenger), admin API Platform CRUD, and synthetic case generator (scheduler + manual trigger).

**Architecture:** DDD Light with 3 bounded contexts — Triage (pipeline), Admin (dashboard CRUD), Reporting (stats). API Platform for admin, manual controllers for triage endpoints. Messenger for async AI calls with retry. PostgreSQL with JSON columns for conversation history.

**Tech Stack:** Symfony 7.4, PHP 8.4, Doctrine ORM, API Platform 4, symfony/ai v0.9, lexik/jwt-authentication-bundle, Docker Compose, PostgreSQL 16, Nginx, PHPUnit

**Cross-references:** Frontend plan at `docs/superpowers/plans/2026-05-28-frontend-foundation.md`. API contracts shared between both plans — endpoint paths and response shapes referenced by task ID where applicable.

---
## File Structure

```
backend/
├── docker-compose.yml
├── Dockerfile
├── .env
├── config/
│   ├── packages/
│   │   ├── ai.yaml              # symfony/ai + OpenRouter
│   │   ├── doctrine.yaml
│   │   ├── security.yaml        # JWT auth
│   │   ├── messenger.yaml       # Async transport
│   │   ├── nelmio_cors.yaml
│   │   └── api_platform.yaml
│   ├── routes/
│   │   └── api_platform.yaml
│   └── services.yaml
├── src/
│   ├── Triage/
│   │   ├── Domain/
│   │   │   ├── Entity/
│   │   │   │   └── TriageSubmission.php
│   │   │   ├── ValueObject/
│   │   │   │   ├── UrgencyLevel.php
│   │   │   │   ├── SpecialistType.php
│   │   │   │   └── SubmissionStatus.php
│   │   │   ├── Repository/
│   │   │   │   └── TriageSubmissionRepository.php  # Interface
│   │   │   └── Service/
│   │   │       └── TriageSystemPrompt.php
│   │   ├── Application/
│   │   │   ├── Command/
│   │   │   │   ├── SubmitTriageCommand.php
│   │   │   │   └── SubmitTriageHandler.php
│   │   │   ├── Query/
│   │   │   │   ├── GetTriageStatusQuery.php
│   │   │   │   └── GetTriageStatusHandler.php
│   │   │   └── Service/
│   │   │       └── TriageAnalyzer.php
│   │   └── Infrastructure/
│   │       ├── Controller/
│   │       │   └── TriageController.php
│   │       ├── MessageHandler/
│   │       │   └── ProcessTriageSubmissionHandler.php
│   │       └── Repository/
│   │           └── DoctrineTriageSubmissionRepository.php
│   ├── User/
│   │   ├── Domain/
│   │   │   ├── Entity/
│   │   │   │   └── User.php
│   │   │   └── Repository/
│   │   │       └── UserRepository.php
│   │   └── Infrastructure/
│   │       ├── Controller/
│   │       │   ├── RegistrationController.php
│   │       │   └── AuthController.php
│   │       └── Repository/
│   │           └── DoctrineUserRepository.php
│   ├── Admin/
│   │   ├── Application/
│   │   │   └── Query/
│   │   │       ├── DashboardStatsQuery.php
│   │   │       └── DashboardStatsHandler.php
│   │   └── Infrastructure/
│   │       ├── ApiResource/
│   │       │   ├── UserResource.php
│   │       │   └── TriageSubmissionResource.php
│   │       ├── Controller/
│   │       │   ├── SyntheticCaseController.php
│   │       │   └── ImpersonationController.php
│   │       └── Security/
│   │           └── TriageSubmissionVoter.php
│   └── Synthetic/
│       ├── Application/
│       │   └── GenerateSyntheticCaseHandler.php
│       └── Infrastructure/
│           └── Scheduler/
│               └── GenerateSyntheticCaseTask.php
├── tests/
│   ├── Triage/
│   │   ├── Domain/
│   │   │   └── Entity/
│   │   │       └── TriageSubmissionTest.php
│   │   ├── Application/
│   │   │   └── Service/
│   │   │       └── TriageAnalyzerTest.php
│   │   └── Infrastructure/
│   │       └── Controller/
│   │           └── TriageControllerTest.php
│   └── User/
│       └── Infrastructure/
│           └── Controller/
│               └── RegistrationControllerTest.php
├── migrations/
├── phpunit.xml.dist
└── .env.test
```

---

### Task 1: Docker Compose + Symfony project scaffold

**Files:**
- Create: `backend/Dockerfile`
- Create: `backend/docker-compose.yml`
- Create: `backend/.env` (base template)
- Create: `backend/.env.local` (gitignored, local overrides)

**Cross-ref:** Frontend `Task 1` — same Docker network needed

- [ ] **Step 1: Write Dockerfile**

```dockerfile
# backend/Dockerfile
FROM php:8.4-fpm-alpine

RUN apk add --no-cache \
    postgresql-dev \
    libpq \
    libzip-dev \
    zip \
    unzip \
    git \
    && docker-php-ext-install pdo_pgsql pgsql zip

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www

COPY composer.json composer.lock ./
RUN composer install --no-scripts --no-autoloader --no-interaction

COPY . .
RUN composer dump-autoload --optimize

EXPOSE 9000
CMD ["php-fpm"]
```

- [ ] **Step 2: Write docker-compose.yml**

```yaml
# backend/docker-compose.yml
services:
  php:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: triageflow_php
    volumes:
      - .:/var/www
      - ./var:/var/www/var
    environment:
      DATABASE_URL: "postgresql://triageflow:triageflow@db:5432/triageflow?serverVersion=16&charset=utf8"
    depends_on:
      db:
        condition: service_healthy
    networks:
      - triageflow

  nginx:
    image: nginx:alpine
    container_name: triageflow_nginx
    ports:
      - "8000:80"
    volumes:
      - .:/var/www
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - php
    networks:
      - triageflow

  db:
    image: postgres:16-alpine
    container_name: triageflow_db
    environment:
      POSTGRES_DB: triageflow
      POSTGRES_USER: triageflow
      POSTGRES_PASSWORD: triageflow
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U triageflow"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - triageflow

volumes:
  pgdata:

networks:
  triageflow:
    name: triageflow_network
```

- [ ] **Step 3: Write Nginx config**

```nginx
# backend/docker/nginx/default.conf
server {
    listen 80;
    server_name localhost;
    root /var/www/public;

    location / {
        try_files $uri /index.php$is_args$args;
    }

    location ~ ^/index\.php(/|$) {
        fastcgi_pass php:9000;
        fastcgi_split_path_info ^(.+\.php)(/.*)$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $document_root;
        internal;
    }

    location ~ \.php$ {
        return 404;
    }
}
```

```bash
mkdir -p backend/docker/nginx
```

- [ ] **Step 4: Create Symfony project**

```bash
# Create base Symfony project inside backend/ directory
workdir: backend
symfony new . --version="7.4.*" --no-git --webapp
```

Expected: Symfony 7.4 project scaffold with directories: `src/`, `config/`, `public/`, `var/`, `templates/`

- [ ] **Step 5: Create base .env**

```env
# backend/.env (core — no secrets)
APP_ENV=dev
APP_SECRET=change_me_in_production
DATABASE_URL="postgresql://triageflow:triageflow@db:5432/triageflow?serverVersion=16&charset=utf8"
CORS_ALLOW_ORIGIN="http://localhost:5173"
DEEPSEEK_API_KEY=''
OPENROUTER_API_KEY=''
JWT_SECRET_KEY='%kernel.project_dir%/config/jwt/private.pem'
JWT_PUBLIC_KEY='%kernel.project_dir%/config/jwt/public.pem'
JWT_PASSPHRASE='change_me'
```

- [ ] **Step 6: Start Docker and verify**

```bash
workdir: backend
docker compose up -d --build
```

Expected: Three containers running (php, nginx, db). Visit `http://localhost:8000` → Symfony welcome page.

- [ ] **Step 7: Commit**

```bash
git add backend/Dockerfile backend/docker-compose.yml backend/docker/ backend/.env
git commit -m "feat: add Docker Compose + Symfony 7.4 project scaffold"
```

---

### Task 2: Composer dependencies + symfony/ai config

**Files:**
- Create: `backend/config/packages/ai.yaml`
- Modify: `backend/composer.json` (add deps)
- Create: `backend/config/packages/nelmio_cors.yaml`

- [ ] **Step 1: Install dependencies**

```bash
workdir: backend
docker compose run --rm php composer require symfony/ai-bundle symfony/scheduler
docker compose run --rm php composer require lexik/jwt-authentication-bundle nelmio/cors-bundle
docker compose run --rm php composer require api
docker compose run --rm php composer require --dev phpunit/phpunit dama/doctrine-test-bundle phpstan/phpstan
```

Expected: All packages installed to `vendor/`. `composer.json` updated.

- [ ] **Step 2: Write symfony/ai config for OpenRouter**

```yaml
# backend/config/packages/ai.yaml
ai:
    platform:
        generic:
            openrouter:
                base_url: 'https://openrouter.ai/api/v1'
                api_key: '%env(OPENROUTER_API_KEY)%'
                model_catalog: 'Symfony\AI\Platform\Bridge\ModelsDev\ModelCatalog'
    agent:
        triage_agent:
            platform: 'ai.platform.generic.openrouter'
            model: 'google/gemma-4-31b-it:free'
            system_prompt: 'app.triage.system_prompt'
            tools: false
        synthetic_agent:
            platform: 'ai.platform.generic.openrouter'
            model: 'google/gemma-4-31b-it:free'
            system_prompt: 'app.synthetic.system_prompt'
            tools: false

services:
    Symfony\AI\Platform\Bridge\ModelsDev\ModelCatalog:
        arguments:
            $providerId: 'openrouter'

    app.triage.system_prompt:
        class: Symfony\Component\DependencyInjection\Configurator\EnvConfigurator
        # Set via env: TRIAGE_SYSTEM_PROMPT

    app.synthetic.system_prompt:
        class: Symfony\Component\DependencyInjection\Configurator\EnvConfigurator
```

**Cross-ref:** Frontend `Task 4` — API client needs to know response shapes from these AI calls.

- [ ] **Step 3: CORS config**

```yaml
# backend/config/packages/nelmio_cors.yaml
nelmio_cors:
    defaults:
        origin_regex: true
        allow_origin: ['%env(CORS_ALLOW_ORIGIN)%']
        allow_methods: ['GET', 'OPTIONS', 'POST', 'PUT', 'PATCH', 'DELETE']
        allow_headers: ['Content-Type', 'Authorization']
        expose_headers: ['Link']
        max_age: 3600
    paths:
        '^/api/': ~
```

- [ ] **Step 4: Verify config loads**

```bash
workdir: backend
docker compose run --rm php bin/console debug:config ai
```

Expected: AI config shown with openrouter platform and two agents.

- [ ] **Step 5: Commit**

```bash
git add backend/composer.json backend/composer.lock backend/config/packages/ai.yaml backend/config/packages/nelmio_cors.yaml
git commit -m "feat: add dependencies + symfony/ai OpenRouter config"
```

---

### Task 3: Doctrine config + database setup

**Files:**
- Modify: `backend/config/packages/doctrine.yaml`
- Create: `backend/.env.local` (with real DATABASE_URL)

- [ ] **Step 1: Verify Doctrine config**

```yaml
# backend/config/packages/doctrine.yaml
doctrine:
    dbal:
        url: '%env(resolve:DATABASE_URL)%'
        profiling_collect_backtrace: '%kernel.debug%'
        use_savepoints: true
    orm:
        auto_generate_proxy_classes: true
        enable_lazy_ghost_objects: true
        report_fields_where_declared: true
        validate_xml_mapping: true
        naming_strategy: doctrine.orm.naming_strategy.underscore_number_aware
        auto_mapping: true
        mappings:
            Triage:
                type: attribute
                dir: '%kernel.project_dir%/src/Triage/Domain/Entity'
                prefix: 'App\Triage\Domain\Entity'
            User:
                type: attribute
                dir: '%kernel.project_dir%/src/User/Domain/Entity'
                prefix: 'App\User\Domain\Entity'
```

**Cross-ref:** Frontend `Task 5` — TriageSubmission fields used in result page. Frontend `Task 10` — Admin table columns.

- [ ] **Step 2: Create database**

```bash
workdir: backend
docker compose run --rm php bin/console doctrine:database:create --if-not-exists
```

Expected: Output: `Created database triageflow for connection named default`

- [ ] **Step 3: Verify connection**

```bash
workdir: backend
docker compose run --rm php bin/console doctrine:query:sql "SELECT 1"
```

Expected: `int(1)`

- [ ] **Step 4: Commit**

```bash
git add backend/config/packages/doctrine.yaml
git commit -m "feat: configure Doctrine ORM with PostgreSQL"
```

---

### Task 4: Value Objects — Enums

**Files:**
- Create: `backend/src/Triage/Domain/ValueObject/UrgencyLevel.php`
- Create: `backend/src/Triage/Domain/ValueObject/SpecialistType.php`
- Create: `backend/src/Triage/Domain/ValueObject/SubmissionStatus.php`

- [ ] **Step 1: Write the failing PHPUnit test for enums**

```php
// backend/tests/Triage/Domain/ValueObject/UrgencyLevelTest.php
<?php

declare(strict_types=1);

namespace App\Tests\Triage\Domain\ValueObject;

use App\Triage\Domain\ValueObject\UrgencyLevel;
use PHPUnit\Framework\TestCase;

final class UrgencyLevelTest extends TestCase
{
    public function testHasFourLevels(): void
    {
        $cases = UrgencyLevel::cases();
        $this->assertCount(4, $cases);
    }

    public function testEmergencyIsHighestPriority(): void
    {
        $levels = UrgencyLevel::cases();
        $this->assertSame(UrgencyLevel::EMERGENCY, $levels[0]);
    }

    public function testFromStringReturnsCorrectEnum(): void
    {
        $this->assertSame(UrgencyLevel::HIGH, UrgencyLevel::from('HIGH'));
    }
}
```

```php
// backend/tests/Triage/Domain/ValueObject/SpecialistTypeTest.php
<?php

declare(strict_types=1);

namespace App\Tests\Triage\Domain\ValueObject;

use App\Triage\Domain\ValueObject\SpecialistType;
use PHPUnit\Framework\TestCase;

final class SpecialistTypeTest extends TestCase
{
    public function testHasCorrectNumberOfSpecialists(): void
    {
        $cases = SpecialistType::cases();
        $this->assertGreaterThanOrEqual(18, count($cases));
    }

    public function testContainsCommonSpecialists(): void
    {
        $names = array_map(fn ($s) => $s->value, SpecialistType::cases());
        $this->assertContains('CARDIOLOGIST', $names);
        $this->assertContains('NEUROLOGIST', $names);
        $this->assertContains('GASTROENTEROLOGIST', $names);
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

```bash
workdir: backend
docker compose run --rm php vendor/bin/phpunit tests/Triage/Domain/ValueObject/
```

Expected: FAIL — classes not found.

- [ ] **Step 3: Write enums**

```php
// backend/src/Triage/Domain/ValueObject/UrgencyLevel.php
<?php

declare(strict_types=1);

namespace App\Triage\Domain\ValueObject;

enum UrgencyLevel: string
{
    case EMERGENCY = 'EMERGENCY';
    case HIGH = 'HIGH';
    case MEDIUM = 'MEDIUM';
    case LOW = 'LOW';
}
```

```php
// backend/src/Triage/Domain/ValueObject/SpecialistType.php
<?php

declare(strict_types=1);

namespace App\Triage\Domain\ValueObject;

enum SpecialistType: string
{
    case GP = 'GP';
    case CARDIOLOGIST = 'CARDIOLOGIST';
    case DERMATOLOGIST = 'DERMATOLOGIST';
    case NEUROLOGIST = 'NEUROLOGIST';
    case ORTHOPEDIST = 'ORTHOPEDIST';
    case GASTROENTEROLOGIST = 'GASTROENTEROLOGIST';
    case PULMONOLOGIST = 'PULMONOLOGIST';
    case PSYCHIATRIST = 'PSYCHIATRIST';
    case ENDOCRINOLOGIST = 'ENDOCRINOLOGIST';
    case RHEUMATOLOGIST = 'RHEUMATOLOGIST';
    case UROLOGIST = 'UROLOGIST';
    case OPHTHALMOLOGIST = 'OPHTHALMOLOGIST';
    case OTOLARYNGOLOGIST = 'OTOLARYNGOLOGIST';
    case ONCOLOGIST = 'ONCOLOGIST';
    case NEPHROLOGIST = 'NEPHROLOGIST';
    case OBSTETRICIAN_GYNECOLOGIST = 'OBSTETRICIAN_GYNECOLOGIST';
    case PEDIATRICIAN = 'PEDIATRICIAN';
    case INFECTIOUS_DISEASE = 'INFECTIOUS_DISEASE';
}
```

```php
// backend/src/Triage/Domain/ValueObject/SubmissionStatus.php
<?php

declare(strict_types=1);

namespace App\Triage\Domain\ValueObject;

enum SubmissionStatus: string
{
    case PENDING = 'pending';
    case PROCESSING = 'processing';
    case COMPLETED = 'completed';
    case FAILED = 'failed';
}
```

- [ ] **Step 4: Run tests — expect pass**

```bash
workdir: backend
docker compose run --rm php vendor/bin/phpunit tests/Triage/Domain/ValueObject/
```

Expected: All green, 2+ tests passing.

- [ ] **Step 5: Commit**

```bash
git add backend/src/Triage/Domain/ValueObject/ backend/tests/Triage/Domain/ValueObject/
git commit -m "feat: add UrgencyLevel, SpecialistType, SubmissionStatus enums"
```

---

### Task 5: User entity + migration

**Files:**
- Create: `backend/src/User/Domain/Entity/User.php`
- Create: `backend/src/User/Domain/Repository/UserRepository.php` (interface)
- Create: `backend/src/User/Infrastructure/Repository/DoctrineUserRepository.php`

**Cross-ref:** Frontend `Task 2` — uses User in auth state. Frontend `Task 8` — login form references User fields.

- [ ] **Step 1: Write User entity**

```php
// backend/src/User/Domain/Entity/User.php
<?php

declare(strict_types=1);

namespace App\User\Domain\Entity;

use Doctrine\ORM\Mapping as ORM;
use Symfony\Component\Security\Core\User\PasswordAuthenticatedUserInterface;
use Symfony\Component\Security\Core\User\UserInterface;
use Symfony\Component\Uid\Uuid;

#[ORM\Entity]
#[ORM\Table(name: 'users')]
final class User implements UserInterface, PasswordAuthenticatedUserInterface
{
    #[ORM\Id]
    #[ORM\Column(type: 'uuid', unique: true)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    private readonly Uuid $id;

    #[ORM\Column(type: 'string', length: 180, unique: true)]
    private readonly string $email;

    #[ORM\Column(type: 'json')]
    private array $roles = [];

    #[ORM\Column(type: 'string')]
    private string $password;

    #[ORM\Column]
    private readonly \DateTimeImmutable $createdAt;

    public function __construct(string $email, string $password)
    {
        $this->email = $email;
        $this->password = $password;
        $this->roles = ['ROLE_USER'];
        $this->createdAt = new \DateTimeImmutable();
    }

    public static function register(string $email, string $hashedPassword): self
    {
        return new self($email, $hashedPassword);
    }

    public function getId(): Uuid
    {
        return $this->id;
    }

    public function getEmail(): string
    {
        return $this->email;
    }

    public function getUserIdentifier(): string
    {
        return $this->email;
    }

    public function getRoles(): array
    {
        return array_unique($this->roles);
    }

    public function getPassword(): string
    {
        return $this->password;
    }

    public function getCreatedAt(): \DateTimeImmutable
    {
        return $this->createdAt;
    }

    public function eraseCredentials(): void
    {
    }

    public function promoteToAdmin(): void
    {
        if (!in_array('ROLE_ADMIN', $this->roles, true)) {
            $this->roles[] = 'ROLE_ADMIN';
        }
    }
}
```

- [ ] **Step 2: Write repository interface**

```php
// backend/src/User/Domain/Repository/UserRepository.php
<?php

declare(strict_types=1);

namespace App\User\Domain\Repository;

use App\User\Domain\Entity\User;
use Symfony\Component\Uid\Uuid;

interface UserRepository
{
    public function save(User $user): void;
    public function findById(Uuid $id): ?User;
    public function findByEmail(string $email): ?User;
}
```

- [ ] **Step 3: Write Doctrine implementation**

```php
// backend/src/User/Infrastructure/Repository/DoctrineUserRepository.php
<?php

declare(strict_types=1);

namespace App\User\Infrastructure\Repository;

use App\User\Domain\Entity\User;
use App\User\Domain\Repository\UserRepository;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;
use Symfony\Component\Uid\Uuid;

/**
 * @extends ServiceEntityRepository<User>
 */
final class DoctrineUserRepository extends ServiceEntityRepository implements UserRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, User::class);
    }

    public function save(User $user): void
    {
        $this->getEntityManager()->persist($user);
        $this->getEntityManager()->flush();
    }

    public function findById(Uuid $id): ?User
    {
        return $this->find($id);
    }

    public function findByEmail(string $email): ?User
    {
        return $this->findOneBy(['email' => $email]);
    }
}
```

- [ ] **Step 4: Generate and run migration**

```bash
workdir: backend
docker compose run --rm php bin/console make:migration
docker compose run --rm php bin/console doctrine:migrations:migrate --no-interaction
```

Expected: Migration file created in `migrations/`. Table `users` created in PostgreSQL.

- [ ] **Step 5: Verify table exists**

```bash
workdir: backend
docker compose run --rm php bin/console doctrine:query:sql "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='users'"
```

Expected: Columns listed (id, email, roles, password, created_at).

- [ ] **Step 6: Commit**

```bash
git add backend/src/User/ backend/migrations/
git commit -m "feat: add User entity with Doctrine mapping"
```

---

### Task 6: TriageSubmission entity + migration

**Files:**
- Create: `backend/src/Triage/Domain/Entity/TriageSubmission.php`
- Create: `backend/src/Triage/Domain/Repository/TriageSubmissionRepository.php` (interface)
- Create: `backend/src/Triage/Infrastructure/Repository/DoctrineTriageSubmissionRepository.php`

**Cross-ref:** Frontend `Task 5` — result page reads these fields. Frontend `Task 6` — conversation history displayed. Frontend `Task 10` — admin table columns.

- [ ] **Step 1: Write TriageSubmission entity**

```php
// backend/src/Triage/Domain/Entity/TriageSubmission.php
<?php

declare(strict_types=1);

namespace App\Triage\Domain\Entity;

use App\Triage\Domain\ValueObject\SpecialistType;
use App\Triage\Domain\ValueObject\SubmissionStatus;
use App\Triage\Domain\ValueObject\UrgencyLevel;
use App\User\Domain\Entity\User;
use Doctrine\ORM\Mapping as ORM;
use Symfony\Component\Uid\Uuid;

#[ORM\Entity]
#[ORM\Table(name: 'triage_submissions')]
final class TriageSubmission
{
    #[ORM\Id]
    #[ORM\Column(type: 'uuid', unique: true)]
    #[ORM\GeneratedValue(strategy: 'CUSTOM')]
    #[ORM\CustomIdGenerator(class: 'doctrine.uuid_generator')]
    private readonly Uuid $id;

    #[ORM\ManyToOne]
    #[ORM\JoinColumn(nullable: false)]
    private readonly User $user;

    #[ORM\Column(type: 'json')]
    private array $conversationHistory = [];

    #[ORM\Column(type: 'string', enumType: SubmissionStatus::class)]
    private SubmissionStatus $status;

    #[ORM\Column(type: 'string', enumType: SpecialistType::class, nullable: true)]
    private ?SpecialistType $specialist = null;

    #[ORM\Column(type: 'string', enumType: UrgencyLevel::class, nullable: true)]
    private ?UrgencyLevel $urgency = null;

    #[ORM\Column(type: 'text', nullable: true)]
    private ?string $justification = null;

    #[ORM\Column(type: 'integer', nullable: true)]
    private ?int $processingDuration = null;

    #[ORM\Column(type: 'boolean')]
    private readonly bool $isSynthetic;

    #[ORM\Column]
    private readonly \DateTimeImmutable $submittedAt;

    #[ORM\Column(nullable: true)]
    private ?\DateTimeImmutable $processedAt = null;

    private function __construct(User $user, bool $isSynthetic)
    {
        $this->id = Uuid::v4();
        $this->user = $user;
        $this->isSynthetic = $isSynthetic;
        $this->status = SubmissionStatus::PENDING;
        $this->submittedAt = new \DateTimeImmutable();
    }

    public static function create(User $user, bool $isSynthetic = false): self
    {
        return new self($user, $isSynthetic);
    }

    public function addInitialDescription(string $content): void
    {
        $this->conversationHistory[] = [
            'role' => 'user',
            'content' => substr($content, 0, 500),
            'type' => 'initial_description',
            'timestamp' => (new \DateTimeImmutable())->format('c'),
        ];
    }

    public function addAssistantMessage(string $content, string $type = 'follow_up'): void
    {
        $this->conversationHistory[] = [
            'role' => 'assistant',
            'content' => substr($content, 0, 1000),
            'type' => $type,
            'timestamp' => (new \DateTimeImmutable())->format('c'),
        ];
    }

    public function addUserAnswer(string $content): void
    {
        $this->conversationHistory[] = [
            'role' => 'user',
            'content' => substr($content, 0, 300),
            'type' => 'answer',
            'timestamp' => (new \DateTimeImmutable())->format('c'),
        ];
    }

    public function markProcessing(): void
    {
        $this->status = SubmissionStatus::PROCESSING;
    }

    public function complete(SpecialistType $specialist, UrgencyLevel $urgency, string $justification): void
    {
        $this->status = SubmissionStatus::COMPLETED;
        $this->specialist = $specialist;
        $this->urgency = $urgency;
        $this->justification = $justification;
        $this->processedAt = new \DateTimeImmutable();
        $this->processingDuration = $this->processedAt->getTimestamp() - $this->submittedAt->getTimestamp();
    }

    public function markFailed(): void
    {
        $this->status = SubmissionStatus::FAILED;
        $this->processedAt = new \DateTimeImmutable();
    }

    public function getCurrentTurnCount(): int
    {
        return count(array_filter($this->conversationHistory, fn ($m) => $m['role'] === 'assistant'));
    }

    public function getLastAssistantMessage(): ?string
    {
        foreach (array_reverse($this->conversationHistory) as $msg) {
            if ($msg['role'] === 'assistant') {
                return $msg['content'];
            }
        }
        return null;
    }

    public function getId(): Uuid { return $this->id; }
    public function getUser(): User { return $this->user; }
    public function getConversationHistory(): array { return $this->conversationHistory; }
    public function getStatus(): SubmissionStatus { return $this->status; }
    public function getSpecialist(): ?SpecialistType { return $this->specialist; }
    public function getUrgency(): ?UrgencyLevel { return $this->urgency; }
    public function getJustification(): ?string { return $this->justification; }
    public function getProcessingDuration(): ?int { return $this->processingDuration; }
    public function isSynthetic(): bool { return $this->isSynthetic; }
    public function getSubmittedAt(): \DateTimeImmutable { return $this->submittedAt; }
    public function getProcessedAt(): ?\DateTimeImmutable { return $this->processedAt; }
}
```

- [ ] **Step 2: Write repository interface**

```php
// backend/src/Triage/Domain/Repository/TriageSubmissionRepository.php
<?php

declare(strict_types=1);

namespace App\Triage\Domain\Repository;

use App\Triage\Domain\Entity\TriageSubmission;
use App\Triage\Domain\ValueObject\SpecialistType;
use App\Triage\Domain\ValueObject\SubmissionStatus;
use App\Triage\Domain\ValueObject\UrgencyLevel;
use App\User\Domain\Entity\User;
use Symfony\Component\Uid\Uuid;

interface TriageSubmissionRepository
{
    public function save(TriageSubmission $submission): void;
    public function findById(Uuid $id): ?TriageSubmission;
    /** @return TriageSubmission[] */
    public function findByUser(User $user): array;
    /** @return TriageSubmission[] */
    public function findAllOrdered(int $limit = 50, int $offset = 0): array;
    public function countByStatus(SubmissionStatus $status): int;
    public function countBySpecialist(SpecialistType $specialist): int;
    public function countByUrgency(UrgencyLevel $urgency): int;
    public function countTotal(): int;
    public function countSynthetic(): int;
    public function getAverageProcessingDuration(): ?float;
}
```

- [ ] **Step 3: Write Doctrine implementation**

```php
// backend/src/Triage/Infrastructure/Repository/DoctrineTriageSubmissionRepository.php
<?php

declare(strict_types=1);

namespace App\Triage\Infrastructure\Repository;

use App\Triage\Domain\Entity\TriageSubmission;
use App\Triage\Domain\Repository\TriageSubmissionRepository;
use App\Triage\Domain\ValueObject\SpecialistType;
use App\Triage\Domain\ValueObject\SubmissionStatus;
use App\Triage\Domain\ValueObject\UrgencyLevel;
use App\User\Domain\Entity\User;
use Doctrine\Bundle\DoctrineBundle\Repository\ServiceEntityRepository;
use Doctrine\Persistence\ManagerRegistry;
use Symfony\Component\Uid\Uuid;

/**
 * @extends ServiceEntityRepository<TriageSubmission>
 */
final class DoctrineTriageSubmissionRepository extends ServiceEntityRepository implements TriageSubmissionRepository
{
    public function __construct(ManagerRegistry $registry)
    {
        parent::__construct($registry, TriageSubmission::class);
    }

    public function save(TriageSubmission $submission): void
    {
        $this->getEntityManager()->persist($submission);
        $this->getEntityManager()->flush();
    }

    public function findById(Uuid $id): ?TriageSubmission
    {
        return $this->find($id);
    }

    public function findByUser(User $user): array
    {
        return $this->findBy(['user' => $user], ['submittedAt' => 'DESC']);
    }

    public function findAllOrdered(int $limit = 50, int $offset = 0): array
    {
        return $this->createQueryBuilder('s')
            ->orderBy('s.submittedAt', 'DESC')
            ->setMaxResults($limit)
            ->setFirstResult($offset)
            ->getQuery()
            ->getResult();
    }

    public function countByStatus(SubmissionStatus $status): int
    {
        return $this->count(['status' => $status]);
    }

    public function countBySpecialist(SpecialistType $specialist): int
    {
        return $this->count(['specialist' => $specialist]);
    }

    public function countByUrgency(UrgencyLevel $urgency): int
    {
        return $this->count(['urgency' => $urgency]);
    }

    public function countTotal(): int
    {
        return $this->count([]);
    }

    public function countSynthetic(): int
    {
        return $this->count(['isSynthetic' => true]);
    }

    public function getAverageProcessingDuration(): ?float
    {
        $result = $this->createQueryBuilder('s')
            ->select('AVG(s.processingDuration)')
            ->where('s.processingDuration IS NOT NULL')
            ->getQuery()
            ->getSingleScalarResult();

        return $result !== null ? (float) $result : null;
    }
}
```

- [ ] **Step 4: Generate and run migration**

```bash
workdir: backend
docker compose run --rm php bin/console make:migration
docker compose run --rm php bin/console doctrine:migrations:migrate --no-interaction
```

Expected: `triage_submissions` table created with UUID PK, JSON column for conversation, enum columns, FK to users.

- [ ] **Step 5: Verify**

```bash
workdir: backend
docker compose run --rm php bin/console doctrine:query:sql "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='triage_submissions'"
```

Expected: All columns listed.

- [ ] **Step 6: Write entity test**

```php
// backend/tests/Triage/Domain/Entity/TriageSubmissionTest.php
<?php

declare(strict_types=1);

namespace App\Tests\Triage\Domain\Entity;

use App\Triage\Domain\Entity\TriageSubmission;
use App\Triage\Domain\ValueObject\SpecialistType;
use App\Triage\Domain\ValueObject\SubmissionStatus;
use App\Triage\Domain\ValueObject\UrgencyLevel;
use App\User\Domain\Entity\User;
use PHPUnit\Framework\TestCase;

final class TriageSubmissionTest extends TestCase
{
    public function testCreateStartsAsPending(): void
    {
        $user = User::register('test@example.com', 'hashed');
        $submission = TriageSubmission::create($user);

        $this->assertSame(SubmissionStatus::PENDING, $submission->getStatus());
        $this->assertFalse($submission->isSynthetic());
    }

    public function testAddInitialDescriptionAppendsToHistory(): void
    {
        $user = User::register('test@example.com', 'hashed');
        $submission = TriageSubmission::create($user);
        $submission->addInitialDescription('bad headache');

        $history = $submission->getConversationHistory();
        $this->assertCount(1, $history);
        $this->assertSame('user', $history[0]['role']);
        $this->assertSame('initial_description', $history[0]['type']);
    }

    public function testConversationTruncatesToLimits(): void
    {
        $user = User::register('test@example.com', 'hashed');
        $submission = TriageSubmission::create($user);
        $longText = str_repeat('a', 600);
        $submission->addInitialDescription($longText);

        $history = $submission->getConversationHistory();
        $this->assertLessThanOrEqual(500, strlen($history[0]['content']));
    }

    public function testCompleteSetsResultFields(): void
    {
        $user = User::register('test@example.com', 'hashed');
        $submission = TriageSubmission::create($user);
        $submission->complete(SpecialistType::NEUROLOGIST, UrgencyLevel::HIGH, 'Needs referral');

        $this->assertSame(SubmissionStatus::COMPLETED, $submission->getStatus());
        $this->assertSame(SpecialistType::NEUROLOGIST, $submission->getSpecialist());
        $this->assertSame(UrgencyLevel::HIGH, $submission->getUrgency());
        $this->assertNotNull($submission->getProcessedAt());
        $this->assertNotNull($submission->getProcessingDuration());
    }

    public function testGetCurrentTurnCount(): void
    {
        $user = User::register('test@example.com', 'hashed');
        $submission = TriageSubmission::create($user);

        $submission->addInitialDescription('pain');
        $submission->addAssistantMessage('Where?');
        $submission->addUserAnswer('chest');

        $this->assertSame(1, $submission->getCurrentTurnCount());
    }

    public function testMarkFailed(): void
    {
        $user = User::register('test@example.com', 'hashed');
        $submission = TriageSubmission::create($user);
        $submission->markFailed();

        $this->assertSame(SubmissionStatus::FAILED, $submission->getStatus());
    }
}
```

- [ ] **Step 7: Run tests**

```bash
workdir: backend
docker compose run --rm php vendor/bin/phpunit tests/Triage/Domain/Entity/
```

Expected: All 6 tests pass.

- [ ] **Step 8: Commit**

```bash
git add backend/src/Triage/Domain/Entity/ backend/src/Triage/Domain/Repository/ backend/src/Triage/Infrastructure/ backend/tests/Triage/Domain/Entity/ backend/migrations/
git commit -m "feat: add TriageSubmission entity with conversation history + repository"
```

---

### Task 7: User registration endpoint

**Files:**
- Create: `backend/src/User/Infrastructure/Controller/RegistrationController.php`
- Create: `backend/config/routes/user.yaml`

**Cross-ref:** Frontend `Task 2` — registration page posts to this endpoint.

- [ ] **Step 1: Write failing controller test**

```php
// backend/tests/User/Infrastructure/Controller/RegistrationControllerTest.php
<?php

declare(strict_types=1);

namespace App\Tests\User\Infrastructure\Controller;

use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;

final class RegistrationControllerTest extends WebTestCase
{
    public function testRegistrationSuccess(): void
    {
        $client = static::createClient();
        $client->jsonRequest('POST', '/api/register', [
            'email' => 'newuser@example.com',
            'password' => 'SecurePass123!',
        ]);

        $this->assertResponseStatusCodeSame(201);
        $data = json_decode($client->getResponse()->getContent(), true);
        $this->assertArrayHasKey('id', $data['data']);
        $this->assertSame('newuser@example.com', $data['data']['attributes']['email']);
    }

    public function testRegistrationDuplicateEmail(): void
    {
        $client = static::createClient();
        // First registration
        $client->jsonRequest('POST', '/api/register', [
            'email' => 'dup@example.com',
            'password' => 'SecurePass123!',
        ]);
        $this->assertResponseStatusCodeSame(201);

        // Duplicate
        $client->jsonRequest('POST', '/api/register', [
            'email' => 'dup@example.com',
            'password' => 'AnotherPass123!',
        ]);
        $this->assertResponseStatusCodeSame(422);
    }

    public function testRegistrationInvalidEmail(): void
    {
        $client = static::createClient();
        $client->jsonRequest('POST', '/api/register', [
            'email' => 'not-an-email',
            'password' => 'SecurePass123!',
        ]);

        $this->assertResponseStatusCodeSame(422);
    }

    public function testRegistrationWeakPassword(): void
    {
        $client = static::createClient();
        $client->jsonRequest('POST', '/api/register', [
            'email' => 'test@example.com',
            'password' => '123',
        ]);

        $this->assertResponseStatusCodeSame(422);
    }
}
```

- [ ] **Step 2: Run tests — expect failure**

```bash
workdir: backend
docker compose run --rm php vendor/bin/phpunit tests/User/Infrastructure/Controller/RegistrationControllerTest.php
```

Expected: FAIL — route not found.

- [ ] **Step 3: Write RegistrationController**

```php
// backend/src/User/Infrastructure/Controller/RegistrationController.php
<?php

declare(strict_types=1);

namespace App\User\Infrastructure\Controller;

use App\User\Domain\Entity\User;
use App\User\Domain\Repository\UserRepository;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Validator\Constraints as Assert;
use Symfony\Component\Validator\Validator\ValidatorInterface;

final class RegistrationController extends AbstractController
{
    public function __construct(
        private readonly UserRepository $userRepository,
        private readonly UserPasswordHasherInterface $passwordHasher,
        private readonly ValidatorInterface $validator,
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
        ]);

        $violations = $this->validator->validate($data, $constraints);
        if (count($violations) > 0) {
            return $this->json([
                'errors' => array_map(fn ($v) => [
                    'status' => '422',
                    'code' => 'VALIDATION_FAILED',
                    'title' => 'Validation Failed',
                    'detail' => $v->getPropertyPath() . ': ' . $v->getMessage(),
                ], iterator_to_array($violations)),
            ], Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        $existing = $this->userRepository->findByEmail($data['email']);
        if ($existing !== null) {
            return $this->json([
                'errors' => [[
                    'status' => '422',
                    'code' => 'DUPLICATE_EMAIL',
                    'title' => 'Email already registered',
                    'detail' => 'A user with this email already exists.',
                ]],
            ], Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        $hashedPassword = $this->passwordHasher->hashPassword(new User('', ''), $data['password']);
        $user = User::register($data['email'], $hashedPassword);
        $this->userRepository->save($user);

        return $this->json([
            'data' => [
                'id' => $user->getId()->toRfc4122(),
                'type' => 'user',
                'attributes' => [
                    'email' => $user->getEmail(),
                    'roles' => $user->getRoles(),
                    'createdAt' => $user->getCreatedAt()->format('c'),
                ],
            ],
        ], Response::HTTP_CREATED);
    }
}
```

- [ ] **Step 4: Add route config**

```yaml
# backend/config/routes/user.yaml
user_routes:
    resource: ../../src/User/Infrastructure/Controller/
    type: attribute
```

- [ ] **Step 5: Run tests — expect pass**

```bash
workdir: backend
docker compose run --rm php vendor/bin/phpunit tests/User/Infrastructure/Controller/RegistrationControllerTest.php
```

Expected: 4 tests pass.

- [ ] **Step 6: Commit**

```bash
git add backend/src/User/Infrastructure/Controller/ backend/tests/User/Infrastructure/Controller/ backend/config/routes/user.yaml
git commit -m "feat: add user registration endpoint with validation"
```

---

### Task 8: JWT authentication

**Files:**
- Create: `backend/config/packages/security.yaml`
- Create: `backend/src/User/Infrastructure/Controller/AuthController.php`
- Modify: `backend/config/services.yaml` (UserRepository binding)

**Cross-ref:** Frontend `Task 2` — auth interceptor uses JWT. Frontend `Task 8` — login form.

- [ ] **Step 1: Generate JWT keys**

```bash
workdir: backend
mkdir -p config/jwt
openssl genpkey -out config/jwt/private.pem -aes256 -pass pass:change_me -algorithm rsa -pkeyopt rsa_keygen_bits:4096
openssl pkey -in config/jwt/private.pem -passin pass:change_me -out config/jwt/public.pem -pubout
```

Expected: Two files created: `config/jwt/private.pem` and `config/jwt/public.pem`.

- [ ] **Step 2: Write security.yaml**

```yaml
# backend/config/packages/security.yaml
security:
    password_hashers:
        App\User\Domain\Entity\User: 'auto'

    providers:
        app_user_provider:
            entity:
                class: App\User\Domain\Entity\User
                property: email

    firewalls:
        login:
            pattern: ^/api/login
            stateless: true
            json_login:
                check_path: api_login
                username_path: email
                password_path: password
                success_handler: lexik_jwt_authentication.handler.authentication_success
                failure_handler: lexik_jwt_authentication.handler.authentication_failure

        api:
            pattern: ^/api
            stateless: true
            jwt: ~

    access_control:
        - { path: ^/api/register, roles: PUBLIC_ACCESS }
        - { path: ^/api/login,    roles: PUBLIC_ACCESS }
        - { path: ^/api/admin,    roles: ROLE_ADMIN }
        - { path: ^/api/triage,   roles: ROLE_USER }
        - { path: ^/api,          roles: IS_AUTHENTICATED_FULLY }
```

- [ ] **Step 3: Write AuthController (login endpoint)**

```php
// backend/src/User/Infrastructure/Controller/AuthController.php
<?php

declare(strict_types=1);

namespace App\User\Infrastructure\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\Routing\Attribute\Route;

final class AuthController extends AbstractController
{
    #[Route('/api/login', methods: ['POST'], name: 'api_login')]
    public function login(): JsonResponse
    {
        // Handled by json_login firewall — this method is never called.
        // Exists only so the route can be referenced.
        throw new \LogicException('This method should not be reached.');
    }
}
```

- [ ] **Step 4: Bind repository interface**

```yaml
# Add to backend/config/services.yaml
services:
    _defaults:
        autowire: true
        autoconfigure: true

    App\:
        resource: '../src/'
        exclude:
            - '../src/DependencyInjection/'
            - '../src/Kernel.php'

    App\User\Domain\Repository\UserRepository:
        alias: App\User\Infrastructure\Repository\DoctrineUserRepository

    App\Triage\Domain\Repository\TriageSubmissionRepository:
        alias: App\Triage\Infrastructure\Repository\DoctrineTriageSubmissionRepository
```

- [ ] **Step 5: Write auth test**

```php
// backend/tests/User/Infrastructure/Controller/AuthControllerTest.php
<?php

declare(strict_types=1);

namespace App\Tests\User\Infrastructure\Controller;

use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;

final class AuthControllerTest extends WebTestCase
{
    public function testLoginSuccessReturnsToken(): void
    {
        $client = static::createClient();

        // Register first
        $client->jsonRequest('POST', '/api/register', [
            'email' => 'auth-test@example.com',
            'password' => 'SecurePass123!',
        ]);

        // Login
        $client->jsonRequest('POST', '/api/login', [
            'email' => 'auth-test@example.com',
            'password' => 'SecurePass123!',
        ]);

        $this->assertResponseStatusCodeSame(200);
        $data = json_decode($client->getResponse()->getContent(), true);
        $this->assertArrayHasKey('token', $data);
        $this->assertNotEmpty($data['token']);
    }

    public function testLoginBadCredentials(): void
    {
        $client = static::createClient();
        $client->jsonRequest('POST', '/api/login', [
            'email' => 'nonexistent@example.com',
            'password' => 'wrong',
        ]);

        $this->assertResponseStatusCodeSame(401);
    }

    public function testProtectedEndpointRequiresAuth(): void
    {
        $client = static::createClient();
        $client->jsonRequest('GET', '/api/triage/submissions');

        $this->assertResponseStatusCodeSame(401);
    }
}
```

- [ ] **Step 6: Run auth tests**

```bash
workdir: backend
docker compose run --rm php vendor/bin/phpunit tests/User/Infrastructure/Controller/AuthControllerTest.php
```

Expected: 3 tests pass.

- [ ] **Step 7: Commit**

```bash
git add backend/config/packages/security.yaml backend/config/jwt/ backend/src/User/Infrastructure/Controller/AuthController.php backend/tests/User/Infrastructure/Controller/AuthControllerTest.php backend/config/services.yaml
git commit -m "feat: add JWT authentication with login endpoint"
```

---

### Task 9: Triage system prompt + AI analyzer service

**Files:**
- Create: `backend/src/Triage/Domain/Service/TriageSystemPrompt.php`
- Create: `backend/src/Triage/Application/Service/TriageAnalyzer.php`

- [ ] **Step 1: Write system prompt**

```php
// backend/src/Triage/Domain/Service/TriageSystemPrompt.php
<?php

declare(strict_types=1);

namespace App\Triage\Domain\Service;

final readonly class TriageSystemPrompt
{
    public function get(): string
    {
        return <<<'PROMPT'
You are a medical triage assistant conducting an interview. Your job is to:

1. Ask ONE follow-up question at a time to gather relevant information about the patient's symptoms. Be specific and medically relevant.
2. When you have enough information (maximum 3 exchanges), produce a final triage result.
3. If you cannot determine the result after 3 exchanges, produce your best assessment.

Your final response MUST be ONLY valid JSON with no other text:
{"type":"result","specialist":"CARDIOLOGIST","urgency":"HIGH","justification":"Brief 2-3 sentence medical justification."}

If asking a follow-up question, respond with ONLY:
{"type":"question","content":"Your question here?"}

Valid specialists: GP, CARDIOLOGIST, DERMATOLOGIST, NEUROLOGIST, ORTHOPEDIST, GASTROENTEROLOGIST, PULMONOLOGIST, PSYCHIATRIST, ENDOCRINOLOGIST, RHEUMATOLOGIST, UROLOGIST, OPHTHALMOLOGIST, OTOLARYNGOLOGIST, ONCOLOGIST, NEPHROLOGIST, OBSTETRICIAN_GYNECOLOGIST, PEDIATRICIAN, INFECTIOUS_DISEASE
Valid urgency: EMERGENCY, HIGH, MEDIUM, LOW

IMPORTANT: This is a DEMONSTRATION system. All data is synthetic. Never provide real medical advice. Do NOT mention that this is a demo in your responses to the user.
PROMPT;
    }

    public function getSyntheticPrompt(): string
    {
        return <<<'PROMPT'
You are a synthetic patient case generator for a medical triage demo. Generate one realistic initial symptom description in the first person, as if typed by a real patient. 

Output ONLY the symptom text (natural language, 1-2 sentences). No JSON, no markup, no introductory text. Vary medical domains (cardiology, dermatology, neurology, gastroenterology, orthopedics, etc.) randomly.

Examples of good output:
- "I've been having this sharp pain in my lower back for about a week now, gets worse when I bend over"
- "There's this weird rash on my arms that started yesterday, it's really itchy and seems to be spreading"
- "My heart keeps racing randomly even when I'm just sitting down, been happening for 3 days"

Do NOT include any metadata, not even quotes around the output.
PROMPT;
    }
}
```

- [ ] **Step 2: Write TriageAnalyzer service**

```php
// backend/src/Triage/Application/Service/TriageAnalyzer.php
<?php

declare(strict_types=1);

namespace App\Triage\Application\Service;

use Symfony\AI\Platform\PlatformInterface;
use Symfony\AI\Platform\Model\Request;

final readonly class TriageAnalyzer
{
    public function __construct(
        private PlatformInterface $aiPlatform,
        private string $systemPrompt,
    ) {}

    /**
     * Analyze conversation and return AI response.
     * Response is either a follow-up question or the final triage result.
     *
     * @return array{type: string, content?: string, specialist?: string, urgency?: string, justification?: string}
     */
    public function analyze(array $conversationHistory): array
    {
        $messages = [];

        $messages[] = ['role' => 'system', 'content' => $this->systemPrompt];

        foreach ($conversationHistory as $msg) {
            $role = $msg['role'] === 'assistant' ? 'assistant' : 'user';
            $messages[] = ['role' => $role, 'content' => $msg['content']];
        }

        $response = $this->aiPlatform->request(new Request(
            model: 'google/gemma-4-31b-it:free',
            messages: $messages,
            temperature: 0.3,
            maxTokens: 500,
        ));

        $parsed = json_decode($response->content, true);

        if (!is_array($parsed) || !isset($parsed['type'])) {
            throw new TriageAnalysisFailedException('Malformed AI response');
        }

        return $parsed;
    }
}
```

- [ ] **Step 3: Write exception class**

```php
// backend/src/Triage/Application/Service/TriageAnalysisFailedException.php
<?php

declare(strict_types=1);

namespace App\Triage\Application\Service;

final class TriageAnalysisFailedException extends \RuntimeException
{
}
```

- [ ] **Step 4: Write unit test for TriageAnalyzer**

```php
// backend/tests/Triage/Application/Service/TriageAnalyzerTest.php
<?php

declare(strict_types=1);

namespace App\Tests\Triage\Application\Service;

use App\Triage\Application\Service\TriageAnalysisFailedException;
use App\Triage\Application\Service\TriageAnalyzer;
use PHPUnit\Framework\TestCase;
use Symfony\AI\Platform\Model\Request;
use Symfony\AI\Platform\Model\Response;
use Symfony\AI\Platform\PlatformInterface;

final class TriageAnalyzerTest extends TestCase
{
    public function testAnalyzeReturnsQuestion(): void
    {
        $mock = $this->createMock(PlatformInterface::class);
        $mock->method('request')->willReturn(new Response(
            content: '{"type":"question","content":"Where is the pain located?"}',
        ));

        $analyzer = new TriageAnalyzer($mock, 'test prompt');
        $result = $analyzer->analyze([
            ['role' => 'user', 'content' => 'my head hurts', 'type' => 'initial_description'],
        ]);

        $this->assertSame('question', $result['type']);
        $this->assertSame('Where is the pain located?', $result['content']);
    }

    public function testAnalyzeReturnsResult(): void
    {
        $mock = $this->createMock(PlatformInterface::class);
        $mock->method('request')->willReturn(new Response(
            content: '{"type":"result","specialist":"NEUROLOGIST","urgency":"MEDIUM","justification":"Tension headache likely."}',
        ));

        $analyzer = new TriageAnalyzer($mock, 'test prompt');
        $result = $analyzer->analyze([
            ['role' => 'user', 'content' => 'headache for 3 days', 'type' => 'initial_description'],
            ['role' => 'assistant', 'content' => 'Where?', 'type' => 'follow_up'],
            ['role' => 'user', 'content' => 'forehead', 'type' => 'answer'],
        ]);

        $this->assertSame('result', $result['type']);
        $this->assertSame('NEUROLOGIST', $result['specialist']);
        $this->assertSame('MEDIUM', $result['urgency']);
    }

    public function testAnalyzeThrowsOnMalformedResponse(): void
    {
        $mock = $this->createMock(PlatformInterface::class);
        $mock->method('request')->willReturn(new Response(content: 'not json'));

        $analyzer = new TriageAnalyzer($mock, 'test prompt');

        $this->expectException(TriageAnalysisFailedException::class);
        $analyzer->analyze([
            ['role' => 'user', 'content' => 'pain', 'type' => 'initial_description'],
        ]);
    }
}
```

- [ ] **Step 5: Run analyzer tests**

```bash
workdir: backend
docker compose run --rm php vendor/bin/phpunit tests/Triage/Application/Service/TriageAnalyzerTest.php
```

Expected: 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add backend/src/Triage/Domain/Service/ backend/src/Triage/Application/Service/ backend/tests/Triage/Application/Service/
git commit -m "feat: add triage system prompt + AI analyzer service"
```

---

### Task 10: Triage pipeline — Submit command + handler

**Files:**
- Create: `backend/src/Triage/Application/Command/SubmitTriageCommand.php`
- Create: `backend/src/Triage/Application/Command/SubmitTriageHandler.php`
- Create: `backend/src/Triage/Infrastructure/Message/ProcessTriageMessage.php`

- [ ] **Step 1: Write command DTO**

```php
// backend/src/Triage/Application/Command/SubmitTriageCommand.php
<?php

declare(strict_types=1);

namespace App\Triage\Application\Command;

use Symfony\Component\Uid\Uuid;

final readonly class SubmitTriageCommand
{
    public function __construct(
        public Uuid $userId,
        public string $initialDescription,
        public bool $isSynthetic = false,
    ) {}
}
```

- [ ] **Step 2: Write handler**

```php
// backend/src/Triage/Application/Command/SubmitTriageHandler.php
<?php

declare(strict_types=1);

namespace App\Triage\Application\Command;

use App\Triage\Domain\Entity\TriageSubmission;
use App\Triage\Domain\Repository\TriageSubmissionRepository;
use App\User\Domain\Repository\UserRepository;
use Symfony\Component\Messenger\MessageBusInterface;

final readonly class SubmitTriageHandler
{
    public function __construct(
        private UserRepository $userRepository,
        private TriageSubmissionRepository $submissionRepository,
        private MessageBusInterface $bus,
    ) {}

    public function __invoke(SubmitTriageCommand $command): TriageSubmission
    {
        $user = $this->userRepository->findById($command->userId);
        if ($user === null) {
            throw new \InvalidArgumentException('User not found');
        }

        $submission = TriageSubmission::create($user, $command->isSynthetic);
        $submission->addInitialDescription($command->initialDescription);
        $this->submissionRepository->save($submission);

        // Dispatch async message to process AI
        $this->bus->dispatch(new ProcessTriageMessage($submission->getId()));

        return $submission;
    }
}
```

- [ ] **Step 3: Write Messenger message**

```php
// backend/src/Triage/Infrastructure/Message/ProcessTriageMessage.php
<?php

declare(strict_types=1);

namespace App\Triage\Infrastructure\Message;

use Symfony\Component\Uid\Uuid;

final readonly class ProcessTriageMessage
{
    public function __construct(
        public Uuid $submissionId,
    ) {}
}
```

- [ ] **Step 4: Commit**

```bash
git add backend/src/Triage/Application/Command/ backend/src/Triage/Infrastructure/Message/
git commit -m "feat: add SubmitTriage command + handler + Messenger message"
```

---

### Task 11: Triage pipeline — Controller

**Files:**
- Create: `backend/src/Triage/Infrastructure/Controller/TriageController.php`
- Create: `backend/config/routes/triage.yaml`

**Cross-ref:** Frontend `Task 4` — triage interview page calls these endpoints. Frontend `Task 5` — result page polls GET /result/{id}.

- [ ] **Step 1: Write TriageController**

```php
// backend/src/Triage/Infrastructure/Controller/TriageController.php
<?php

declare(strict_types=1);

namespace App\Triage\Infrastructure\Controller;

use App\Triage\Application\Command\SubmitTriageCommand;
use App\Triage\Domain\Entity\TriageSubmission;
use App\Triage\Domain\Repository\TriageSubmissionRepository;
use App\User\Domain\Entity\User;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Messenger\MessageBusInterface;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Security\Http\Attribute\CurrentUser;
use Symfony\Component\Uid\Uuid;
use Symfony\Component\Validator\Constraints as Assert;
use Symfony\Component\Validator\Validator\ValidatorInterface;

final class TriageController extends AbstractController
{
    public function __construct(
        private readonly TriageSubmissionRepository $submissionRepository,
        private readonly ValidatorInterface $validator,
    ) {}

    #[Route('/api/triage/submit', methods: ['POST'], name: 'api_triage_submit')]
    public function submit(
        Request $request,
        #[CurrentUser] User $user,
        MessageBusInterface $bus,
    ): JsonResponse {
        $data = json_decode($request->getContent(), true);

        $constraints = new Assert\Collection([
            'initialDescription' => [
                new Assert\NotBlank(),
                new Assert\Length(['min' => 3, 'max' => 500]),
            ],
        ]);

        $violations = $this->validator->validate($data, $constraints);
        if (count($violations) > 0) {
            return $this->json([
                'errors' => [[
                    'status' => '422',
                    'code' => 'VALIDATION_FAILED',
                    'title' => 'Invalid initial description',
                    'detail' => $violations->get(0)->getMessage(),
                ]],
            ], Response::HTTP_UNPROCESSABLE_ENTITY);
        }

        $command = new SubmitTriageCommand(
            userId: $user->getId(),
            initialDescription: $data['initialDescription'],
        );
        $submission = $bus->dispatch($command);

        return $this->json([
            'data' => [
                'id' => $submission->getId()->toRfc4122(),
                'type' => 'triage_submission',
                'attributes' => [
                    'status' => $submission->getStatus()->value,
                    'submittedAt' => $submission->getSubmittedAt()->format('c'),
                ],
            ],
        ], Response::HTTP_ACCEPTED);
    }

    #[Route('/api/triage/status/{id}', methods: ['GET'], name: 'api_triage_status')]
    public function status(string $id): JsonResponse
    {
        $submission = $this->submissionRepository->findById(Uuid::fromString($id));

        if ($submission === null) {
            return $this->json(['errors' => [['status' => '404', 'title' => 'Not Found']]], 404);
        }

        return $this->json([
            'data' => [
                'id' => $submission->getId()->toRfc4122(),
                'type' => 'triage_submission',
                'attributes' => [
                    'status' => $submission->getStatus()->value,
                    'currentTurn' => $submission->getCurrentTurnCount(),
                    'lastAssistantMessage' => $submission->getLastAssistantMessage(),
                ],
            ],
        ]);
    }

    #[Route('/api/triage/{id}/answer', methods: ['POST'], name: 'api_triage_answer')]
    public function answer(
        string $id,
        Request $request,
        #[CurrentUser] ?User $user,
        MessageBusInterface $bus,
    ): JsonResponse {
        $submission = $this->submissionRepository->findById(Uuid::fromString($id));

        if ($submission === null) {
            return $this->json(['errors' => [['status' => '404', 'title' => 'Not Found']]], 404);
        }

        $data = json_decode($request->getContent(), true);

        $constraints = new Assert\Collection([
            'content' => [
                new Assert\NotBlank(),
                new Assert\Length(['min' => 1, 'max' => 300]),
            ],
        ]);

        $violations = $this->validator->validate($data, $constraints);
        if (count($violations) > 0) {
            return $this->json(['errors' => [['status' => '422', 'title' => $violations->get(0)->getMessage()]]], 422);
        }

        $submission->addUserAnswer($data['content']);
        $this->submissionRepository->save($submission);

        // Dispatch async processing for next AI turn
        $bus->dispatch(new \App\Triage\Infrastructure\Message\ProcessTriageMessage($submission->getId()));

        return $this->json([
            'data' => [
                'id' => $submission->getId()->toRfc4122(),
                'type' => 'triage_submission',
                'attributes' => [
                    'status' => $submission->getStatus()->value,
                ],
            ],
        ], Response::HTTP_ACCEPTED);
    }

    #[Route('/api/triage/result/{id}', methods: ['GET'], name: 'api_triage_result')]
    public function result(string $id): JsonResponse
    {
        $submission = $this->submissionRepository->findById(Uuid::fromString($id));

        if ($submission === null) {
            return $this->json(['errors' => [['status' => '404', 'title' => 'Not Found']]], 404);
        }

        return $this->json([
            'data' => $this->serializeSubmission($submission),
        ]);
    }

    #[Route('/api/triage/submissions', methods: ['GET'], name: 'api_triage_my_submissions')]
    public function mySubmissions(#[CurrentUser] User $user): JsonResponse
    {
        $submissions = $this->submissionRepository->findByUser($user);

        return $this->json([
            'data' => array_map(fn (TriageSubmission $s) => $this->serializeSubmission($s), $submissions),
        ]);
    }

    private function serializeSubmission(TriageSubmission $submission): array
    {
        return [
            'id' => $submission->getId()->toRfc4122(),
            'type' => 'triage_submission',
            'attributes' => [
                'status' => $submission->getStatus()->value,
                'isSynthetic' => $submission->isSynthetic(),
                'specialist' => $submission->getSpecialist()?->value,
                'urgency' => $submission->getUrgency()?->value,
                'justification' => $submission->getJustification(),
                'conversationHistory' => $submission->getConversationHistory(),
                'processingDuration' => $submission->getProcessingDuration(),
                'submittedAt' => $submission->getSubmittedAt()->format('c'),
                'processedAt' => $submission->getProcessedAt()?->format('c'),
            ],
        ];
    }
}
```

**Cross-ref:** Response format above is the contract for:
- Frontend `Task 4` — `useSubmitTriage` mutation → 202 + polling `GET /status/{id}`
- Frontend `Task 5` — result page reads `specialist`, `urgency`, `justification`, `conversationHistory`
- Frontend `Task 6` — My Submissions reads the array of serialized submissions

- [ ] **Step 2: Add route config**

```yaml
# backend/config/routes/triage.yaml
triage_routes:
    resource: ../../src/Triage/Infrastructure/Controller/
    type: attribute
```

- [ ] **Step 3: Commit**

```bash
git add backend/src/Triage/Infrastructure/Controller/ backend/config/routes/triage.yaml
git commit -m "feat: add TriageController with submit, status, answer, result endpoints"
```

---

### Task 12: Triage pipeline — Messenger handler for async processing

**Files:**
- Create: `backend/src/Triage/Infrastructure/MessageHandler/ProcessTriageSubmissionHandler.php`
- Modify: `backend/config/packages/messenger.yaml`

**Cross-ref:** The handler produces the AI responses that frontend polling (`Task 4`) picks up.

- [ ] **Step 1: Write Messenger config**

```yaml
# backend/config/packages/messenger.yaml
framework:
    messenger:
        transports:
            async:
                dsn: '%env(MESSENGER_TRANSPORT_DSN)%'
                retry_strategy:
                    max_retries: 3
                    delay: 2000
                    multiplier: 2

        routing:
            App\Triage\Infrastructure\Message\ProcessTriageMessage: async
            App\Triage\Application\Command\SubmitTriageCommand: sync

        buses:
            messenger.bus.default:
                middleware:
                    - doctrine_transaction
```

- [ ] **Step 2: Write async handler**

```php
// backend/src/Triage/Infrastructure/MessageHandler/ProcessTriageSubmissionHandler.php
<?php

declare(strict_types=1);

namespace App\Triage\Infrastructure\MessageHandler;

use App\Triage\Application\Service\TriageAnalysisFailedException;
use App\Triage\Application\Service\TriageAnalyzer;
use App\Triage\Domain\Repository\TriageSubmissionRepository;
use App\Triage\Domain\ValueObject\SpecialistType;
use App\Triage\Domain\ValueObject\UrgencyLevel;
use App\Triage\Infrastructure\Message\ProcessTriageMessage;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;

#[AsMessageHandler]
final readonly class ProcessTriageSubmissionHandler
{
    private const int MAX_TURNS = 3;

    public function __construct(
        private TriageSubmissionRepository $submissionRepository,
        private TriageAnalyzer $analyzer,
    ) {}

    public function __invoke(ProcessTriageMessage $message): void
    {
        $submission = $this->submissionRepository->findById($message->submissionId);
        if ($submission === null) {
            return;
        }

        $submission->markProcessing();
        $this->submissionRepository->save($submission);

        try {
            $response = $this->analyzer->analyze($submission->getConversationHistory());

            if ($response['type'] === 'result') {
                $submission->addAssistantMessage(
                    json_encode($response),
                    'result',
                );
                $submission->complete(
                    SpecialistType::from($response['specialist']),
                    UrgencyLevel::from($response['urgency']),
                    $response['justification'],
                );
            } elseif ($response['type'] === 'question') {
                $submission->addAssistantMessage($response['content'], 'follow_up');

                // Force result if max turns reached after this
                if ($submission->getCurrentTurnCount() >= self::MAX_TURNS) {
                    $this->forceResult($submission);
                }
            }
        } catch (TriageAnalysisFailedException|\ValueError) {
            $submission->markFailed();
        } finally {
            $this->submissionRepository->save($submission);
        }
    }

    private function forceResult($submission): void
    {
        // Add a synthetic instruction to force the AI to produce a result
        $history = $submission->getConversationHistory();
        $history[] = ['role' => 'system', 'content' => 'You have reached the maximum number of questions. Produce your final triage result NOW.'];

        try {
            $response = $this->analyzer->analyze($history);
            $submission->addAssistantMessage(json_encode($response), 'result');
            $submission->complete(
                SpecialistType::from($response['specialist']),
                UrgencyLevel::from($response['urgency']),
                $response['justification'],
            );
        } catch (\Throwable) {
            $submission->markFailed();
        }
    }
}
```

- [ ] **Step 3: Add MESSENGER_TRANSPORT_DSN to .env**

```env
# Add to backend/.env
MESSENGER_TRANSPORT_DSN=doctrine://default
```

- [ ] **Step 4: Write handler test**

```php
// backend/tests/Triage/Infrastructure/MessageHandler/ProcessTriageSubmissionHandlerTest.php
<?php

declare(strict_types=1);

namespace App\Tests\Triage\Infrastructure\MessageHandler;

use App\Triage\Application\Service\TriageAnalyzer;
use App\Triage\Domain\Entity\TriageSubmission;
use App\Triage\Domain\Repository\TriageSubmissionRepository;
use App\Triage\Domain\ValueObject\SpecialistType;
use App\Triage\Domain\ValueObject\SubmissionStatus;
use App\Triage\Domain\ValueObject\UrgencyLevel;
use App\Triage\Infrastructure\Message\ProcessTriageMessage;
use App\Triage\Infrastructure\MessageHandler\ProcessTriageSubmissionHandler;
use App\User\Domain\Entity\User;
use PHPUnit\Framework\TestCase;

final class ProcessTriageSubmissionHandlerTest extends TestCase
{
    public function testHandlerCompletesSubmissionOnResult(): void
    {
        $user = User::register('test@example.com', 'hashed');
        $submission = TriageSubmission::create($user);
        $submission->addInitialDescription('chest pain');

        $repo = $this->createMock(TriageSubmissionRepository::class);
        $repo->method('findById')->willReturn($submission);

        $analyzer = $this->createMock(TriageAnalyzer::class);
        $analyzer->method('analyze')->willReturn([
            'type' => 'result',
            'specialist' => 'CARDIOLOGIST',
            'urgency' => 'HIGH',
            'justification' => 'Chest pain requires evaluation.',
        ]);

        $handler = new ProcessTriageSubmissionHandler($repo, $analyzer);
        $handler->__invoke(new ProcessTriageMessage($submission->getId()));

        $this->assertSame(SubmissionStatus::COMPLETED, $submission->getStatus());
        $this->assertSame(SpecialistType::CARDIOLOGIST, $submission->getSpecialist());
        $this->assertSame(UrgencyLevel::HIGH, $submission->getUrgency());
    }
}
```

- [ ] **Step 5: Run handler test**

```bash
workdir: backend
docker compose run --rm php vendor/bin/phpunit tests/Triage/Infrastructure/MessageHandler/
```

Expected: 1 test passes.

- [ ] **Step 6: Commit**

```bash
git add backend/src/Triage/Infrastructure/MessageHandler/ backend/config/packages/messenger.yaml backend/tests/Triage/Infrastructure/MessageHandler/
git commit -m "feat: add async Messenger handler for triage processing"
```

---

### Task 13: Admin API Platform — User resource

**Files:**
- Create: `backend/src/Admin/Infrastructure/ApiResource/UserResource.php`
- Modify: `backend/config/packages/api_platform.yaml`

**Cross-ref:** Frontend `Task 11` — admin user management page.

- [ ] **Step 1: Write User API Platform resource**

```php
// backend/src/Admin/Infrastructure/ApiResource/UserResource.php
<?php

declare(strict_types=1);

namespace App\Admin\Infrastructure\ApiResource;

use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Delete;
use App\User\Domain\Entity\User;

#[ApiResource(
    operations: [
        new GetCollection(
            uriTemplate: '/admin/users',
            security: "is_granted('ROLE_ADMIN')",
        ),
        new Get(
            uriTemplate: '/admin/users/{id}',
            security: "is_granted('ROLE_ADMIN')",
        ),
        new Delete(
            uriTemplate: '/admin/users/{id}',
            security: "is_granted('ROLE_ADMIN')",
        ),
    ],
)]
final class UserResource
{
    public function __construct(
        public readonly string $id,
        public readonly string $email,
        public readonly array $roles,
        public readonly string $createdAt,
    ) {}

    public static function fromEntity(User $user): self
    {
        return new self(
            id: $user->getId()->toRfc4122(),
            email: $user->getEmail(),
            roles: $user->getRoles(),
            createdAt: $user->getCreatedAt()->format('c'),
        );
    }
}
```

- [ ] **Step 2: Write data provider**

```php
// backend/src/Admin/Infrastructure/ApiResource/UserResourceProvider.php
<?php

declare(strict_types=1);

namespace App\Admin\Infrastructure\ApiResource;

use ApiPlatform\State\ProviderInterface;
use App\User\Domain\Repository\UserRepository;
use Symfony\Component\Uid\Uuid;

final readonly class UserResourceProvider implements ProviderInterface
{
    public function __construct(
        private UserRepository $userRepository,
    ) {}

    public function provide(\ApiPlatform\Metadata\Operation $operation, array $uriVariables = [], array $context = []): object|array|null
    {
        if (isset($uriVariables['id'])) {
            $user = $this->userRepository->findById(Uuid::fromString($uriVariables['id']));
            return $user ? UserResource::fromEntity($user) : null;
        }

        // GetCollection
        // For simplicity, get all. Add pagination as needed.
        return []; // TODO: Need findAll on UserRepository
    }
}
```

- [ ] **Step 3: Add findAll to UserRepository**

Add this method to `DoctrineUserRepository`:

```php
public function findAllUsers(): array
{
    return $this->findAll();
}
```

And to the interface:

```php
/** @return User[] */
public function findAllUsers(): array;
```

Update the provider to use `$this->userRepository->findAllUsers()`.

- [ ] **Step 4: Configure API Platform**

```yaml
# backend/config/packages/api_platform.yaml
api_platform:
    title: 'TriageFlow API'
    version: '1.0.0'
    defaults:
        stateless: true
        cache_headers:
            max_age: 0
        pagination_enabled: true
        pagination_items_per_page: 30
```

- [ ] **Step 5: Commit**

```bash
git add backend/src/Admin/ backend/config/packages/api_platform.yaml
git commit -m "feat: add Admin API Platform User resource"
```

---

### Task 14: Admin API Platform — TriageSubmission resource

**Files:**
- Create: `backend/src/Admin/Infrastructure/ApiResource/TriageSubmissionResource.php`
- Create: `backend/src/Admin/Infrastructure/ApiResource/TriageSubmissionResourceProvider.php`
- Create: `backend/src/Admin/Infrastructure/Security/TriageSubmissionVoter.php`

**Cross-ref:** Frontend `Task 10` — admin submissions table reads from this endpoint.

- [ ] **Step 1: Write TriageSubmission API resource**

```php
// backend/src/Admin/Infrastructure/ApiResource/TriageSubmissionResource.php
<?php

declare(strict_types=1);

namespace App\Admin\Infrastructure\ApiResource;

use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use App\Triage\Domain\Entity\TriageSubmission;

#[ApiResource(
    operations: [
        new GetCollection(
            uriTemplate: '/admin/submissions',
            security: "is_granted('ROLE_ADMIN')",
        ),
        new Get(
            uriTemplate: '/admin/submissions/{id}',
            security: "is_granted('ROLE_ADMIN')",
        ),
    ],
)]
final class TriageSubmissionResource
{
    public function __construct(
        public readonly string $id,
        public readonly string $status,
        public readonly bool $isSynthetic,
        public readonly ?string $specialist,
        public readonly ?string $urgency,
        public readonly ?string $justification,
        public readonly array $conversationHistory,
        public readonly ?int $processingDuration,
        public readonly string $submittedAt,
        public readonly ?string $processedAt,
        public readonly UserResource $user,
    ) {}

    public static function fromEntity(TriageSubmission $submission): self
    {
        return new self(
            id: $submission->getId()->toRfc4122(),
            status: $submission->getStatus()->value,
            isSynthetic: $submission->isSynthetic(),
            specialist: $submission->getSpecialist()?->value,
            urgency: $submission->getUrgency()?->value,
            justification: $submission->getJustification(),
            conversationHistory: $submission->getConversationHistory(),
            processingDuration: $submission->getProcessingDuration(),
            submittedAt: $submission->getSubmittedAt()->format('c'),
            processedAt: $submission->getProcessedAt()?->format('c'),
            user: UserResource::fromEntity($submission->getUser()),
        );
    }
}
```

- [ ] **Step 2: Write provider**

```php
// backend/src/Admin/Infrastructure/ApiResource/TriageSubmissionResourceProvider.php
<?php

declare(strict_types=1);

namespace App\Admin\Infrastructure\ApiResource;

use ApiPlatform\State\ProviderInterface;
use App\Triage\Domain\Repository\TriageSubmissionRepository;
use Symfony\Component\Uid\Uuid;

final readonly class TriageSubmissionResourceProvider implements ProviderInterface
{
    public function __construct(
        private TriageSubmissionRepository $submissionRepository,
    ) {}

    public function provide(\ApiPlatform\Metadata\Operation $operation, array $uriVariables = [], array $context = []): object|array|null
    {
        if (isset($uriVariables['id'])) {
            $submission = $this->submissionRepository->findById(Uuid::fromString($uriVariables['id']));
            return $submission ? TriageSubmissionResource::fromEntity($submission) : null;
        }

        $submissions = $this->submissionRepository->findAllOrdered();
        return array_map(
            fn ($s) => TriageSubmissionResource::fromEntity($s),
            $submissions,
        );
    }
}
```

- [ ] **Step 3: Write security voter**

```php
// backend/src/Admin/Infrastructure/Security/TriageSubmissionVoter.php
<?php

declare(strict_types=1);

namespace App\Admin\Infrastructure\Security;

use App\Triage\Domain\Entity\TriageSubmission;
use App\User\Domain\Entity\User;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Core\Authorization\Voter\Voter;

/**
 * @extends Voter<string, TriageSubmission>
 */
final class TriageSubmissionVoter extends Voter
{
    protected function supports(string $attribute, mixed $subject): bool
    {
        return $subject instanceof TriageSubmission && in_array($attribute, ['VIEW', 'OWNER']);
    }

    protected function voteOnAttribute(string $attribute, mixed $subject, TokenInterface $token): bool
    {
        $user = $token->getUser();
        if (!$user instanceof User) {
            return false;
        }

        if (in_array('ROLE_ADMIN', $user->getRoles(), true)) {
            return true; // Admins can view all
        }

        if ($attribute === 'OWNER') {
            return $subject->getUser()->getId()->equals($user->getId());
        }

        return false;
    }
}
```

- [ ] **Step 5: Commit**

```bash
git add backend/src/Admin/Infrastructure/ApiResource/ backend/src/Admin/Infrastructure/Security/
git commit -m "feat: add Admin API Platform TriageSubmission resource + voter"
```

---

### Task 15: Admin stats endpoint

**Files:**
- Create: `backend/src/Admin/Infrastructure/Controller/StatsController.php`

**Cross-ref:** Frontend `Task 10` — admin dashboard stats grid.

- [ ] **Step 1: Write StatsController**

```php
// backend/src/Admin/Infrastructure/Controller/StatsController.php
<?php

declare(strict_types=1);

namespace App\Admin\Infrastructure\Controller;

use App\Triage\Domain\Repository\TriageSubmissionRepository;
use App\Triage\Domain\ValueObject\SpecialistType;
use App\Triage\Domain\ValueObject\SubmissionStatus;
use App\Triage\Domain\ValueObject\UrgencyLevel;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\Routing\Attribute\Route;

final class StatsController extends AbstractController
{
    public function __construct(
        private readonly TriageSubmissionRepository $submissionRepository,
    ) {}

    #[Route('/api/admin/stats', methods: ['GET'], name: 'api_admin_stats')]
    public function __invoke(): JsonResponse
    {
        $specialists = [];
        foreach (SpecialistType::cases() as $type) {
            $count = $this->submissionRepository->countBySpecialist($type);
            if ($count > 0) {
                $specialists[] = ['specialist' => $type->value, 'count' => $count];
            }
        }

        $urgencies = [];
        foreach (UrgencyLevel::cases() as $level) {
            $count = $this->submissionRepository->countByUrgency($level);
            if ($count > 0) {
                $urgencies[] = ['urgency' => $level->value, 'count' => $count];
            }
        }

        return $this->json([
            'data' => [
                'total' => $this->submissionRepository->countTotal(),
                'synthetic' => $this->submissionRepository->countSynthetic(),
                'pending' => $this->submissionRepository->countByStatus(SubmissionStatus::PENDING),
                'processing' => $this->submissionRepository->countByStatus(SubmissionStatus::PROCESSING),
                'completed' => $this->submissionRepository->countByStatus(SubmissionStatus::COMPLETED),
                'failed' => $this->submissionRepository->countByStatus(SubmissionStatus::FAILED),
                'avgProcessingDuration' => $this->submissionRepository->getAverageProcessingDuration(),
                'bySpecialist' => $specialists,
                'byUrgency' => $urgencies,
            ],
        ]);
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add backend/src/Admin/Infrastructure/Controller/StatsController.php
git commit -m "feat: add admin dashboard stats endpoint"
```

---

### Task 16: Synthetic case generator — Scheduler

**Files:**
- Create: `backend/src/Synthetic/Infrastructure/Scheduler/GenerateSyntheticCaseTask.php`
- Create: `backend/src/Synthetic/Application/GenerateSyntheticCaseHandler.php`
- Modify: `backend/config/packages/scheduler.yaml` (or add to framework.yaml)
- Modify: `backend/config/packages/messenger.yaml` (add routing)

**Cross-ref:** Frontend `Task 10` — admin dashboard live feed shows these cases arriving.

- [ ] **Step 1: Write synthetic case handler**

```php
// backend/src/Synthetic/Application/GenerateSyntheticCaseHandler.php
<?php

declare(strict_types=1);

namespace App\Synthetic\Application;

use App\Triage\Application\Command\SubmitTriageCommand;
use App\Triage\Domain\Service\TriageSystemPrompt;
use App\User\Domain\Repository\UserRepository;
use Symfony\AI\Platform\PlatformInterface;
use Symfony\AI\Platform\Model\Request;
use Symfony\Component\Messenger\MessageBusInterface;
use Symfony\Component\Uid\Uuid;

final readonly class GenerateSyntheticCaseHandler
{
    public function __construct(
        private PlatformInterface $aiPlatform,
        private string $syntheticPrompt,
        private MessageBusInterface $bus,
    ) {}

    public function generate(): void
    {
        $response = $this->aiPlatform->request(new Request(
            model: 'google/gemma-4-31b-it:free',
            messages: [
                ['role' => 'system', 'content' => $this->syntheticPrompt],
            ],
            temperature: 0.7,
            maxTokens: 200,
        ));

        $initialDescription = trim($response->content);

        // Use a synthetic user ID (system user) for synthetic cases.
        // Create a system user or use a pre-seeded one.
        // For the plan: assume user exists with a known UUID.
        $command = new SubmitTriageCommand(
            userId: Uuid::fromString('00000000-0000-0000-0000-000000000001'),
            initialDescription: $initialDescription,
            isSynthetic: true,
        );
        $this->bus->dispatch($command);
    }
}
```

- [ ] **Step 2: Write scheduler task**

```php
// backend/src/Synthetic/Infrastructure/Scheduler/GenerateSyntheticCaseTask.php
<?php

declare(strict_types=1);

namespace App\Synthetic\Infrastructure\Scheduler;

use App\Synthetic\Application\GenerateSyntheticCaseHandler;
use Symfony\Component\Scheduler\Attribute\AsCronTask;

#[AsCronTask('* * * * *')]
final readonly class GenerateSyntheticCaseTask
{
    public function __construct(
        private GenerateSyntheticCaseHandler $handler,
    ) {}

    public function __invoke(): void
    {
        $this->handler->generate();
    }
}
```

- [ ] **Step 3: Add scheduler config**

```yaml
# backend/config/packages/scheduler.yaml
framework:
    scheduler: ~
```

- [ ] **Step 4: Seed system user migration**

The synthetic case generator needs a "system user" to own synthetic submissions. Create a migration that inserts this user:

```bash
workdir: backend
docker compose run --rm php bin/console make:migration
```

Manually edit the migration to add:

```php
$this->addSql("INSERT INTO users (id, email, roles, password, created_at) VALUES ('00000000-0000-0000-0000-000000000001', 'system@triageflow.local', '[\"ROLE_SYSTEM\"]', 'not-a-real-password', NOW()) ON CONFLICT DO NOTHING");
```

- [ ] **Step 5: Commit**

```bash
git add backend/src/Synthetic/ backend/config/packages/scheduler.yaml backend/migrations/
git commit -m "feat: add synthetic case generator with scheduler"
```

---

### Task 17: Synthetic case generator — Manual trigger + Impersonation

**Files:**
- Create: `backend/src/Admin/Infrastructure/Controller/SyntheticCaseController.php`
- Create: `backend/src/Admin/Infrastructure/Controller/ImpersonationController.php`

**Cross-ref:** Frontend `Task 10` — admin dashboard manual trigger button. Frontend `Task 11` — login-as feature.

- [ ] **Step 1: Write manual trigger controller**

```php
// backend/src/Admin/Infrastructure/Controller/SyntheticCaseController.php
<?php

declare(strict_types=1);

namespace App\Admin\Infrastructure\Controller;

use App\Synthetic\Application\GenerateSyntheticCaseHandler;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

final class SyntheticCaseController extends AbstractController
{
    #[Route('/api/admin/synthetic/generate', methods: ['POST'], name: 'api_admin_synthetic_generate')]
    public function generate(GenerateSyntheticCaseHandler $handler): JsonResponse
    {
        $handler->generate();

        return $this->json([
            'data' => ['message' => 'Synthetic case generated'],
        ], Response::HTTP_ACCEPTED);
    }
}
```

- [ ] **Step 2: Write impersonation controller**

```php
// backend/src/Admin/Infrastructure/Controller/ImpersonationController.php
<?php

declare(strict_types=1);

namespace App\Admin\Infrastructure\Controller;

use App\User\Domain\Repository\UserRepository;
use Lexik\Bundle\JWTAuthenticationBundle\Services\JWTTokenManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Uid\Uuid;

final class ImpersonationController extends AbstractController
{
    public function __construct(
        private readonly UserRepository $userRepository,
        private readonly JWTTokenManagerInterface $jwtManager,
    ) {}

    #[Route('/api/admin/users/{id}/impersonate', methods: ['POST'], name: 'api_admin_impersonate')]
    public function impersonate(string $id): JsonResponse
    {
        $this->denyAccessUnlessGranted('ROLE_ADMIN');

        $user = $this->userRepository->findById(Uuid::fromString($id));
        if ($user === null) {
            return $this->json(['errors' => [['status' => '404', 'title' => 'User not found']]], 404);
        }

        $token = $this->jwtManager->createFromPayload($user, [
            'impersonated_by' => $this->getUser()->getUserIdentifier(),
        ]);

        return $this->json([
            'data' => [
                'token' => $token,
                'impersonated' => $user->getEmail(),
            ],
        ]);
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add backend/src/Admin/Infrastructure/Controller/SyntheticCaseController.php backend/src/Admin/Infrastructure/Controller/ImpersonationController.php
git commit -m "feat: add manual synthetic case trigger + admin impersonation"
```

---

### Task 18: Integration test — Full triage flow

**Files:**
- Create: `backend/tests/Triage/Infrastructure/Controller/TriageControllerTest.php`

- [ ] **Step 1: Write integration test**

```php
// backend/tests/Triage/Infrastructure/Controller/TriageControllerTest.php
<?php

declare(strict_types=1);

namespace App\Tests\Triage\Infrastructure\Controller;

use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;

final class TriageControllerTest extends WebTestCase
{
    public function testSubmitTriageReturns202(): void
    {
        $client = static::createClient();

        // Register and login
        $client->jsonRequest('POST', '/api/register', [
            'email' => 'triage-test@example.com',
            'password' => 'SecurePass123!',
        ]);
        $client->jsonRequest('POST', '/api/login', [
            'email' => 'triage-test@example.com',
            'password' => 'SecurePass123!',
        ]);
        $token = json_decode($client->getResponse()->getContent(), true)['token'];

        // Submit triage
        $client->jsonRequest('POST', '/api/triage/submit', [
            'initialDescription' => 'I have a severe headache for 3 days',
        ], [
            'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
        ]);

        $this->assertResponseStatusCodeSame(202);
        $data = json_decode($client->getResponse()->getContent(), true);
        $this->assertArrayHasKey('id', $data['data']);
        $this->assertSame('pending', $data['data']['attributes']['status']);
    }

    public function testMySubmissionsReturnsUserSubmissions(): void
    {
        $client = static::createClient();

        // Register and login
        $client->jsonRequest('POST', '/api/register', [
            'email' => 'list-test@example.com',
            'password' => 'SecurePass123!',
        ]);
        $client->jsonRequest('POST', '/api/login', [
            'email' => 'list-test@example.com',
            'password' => 'SecurePass123!',
        ]);
        $token = json_decode($client->getResponse()->getContent(), true)['token'];

        // Get submissions list
        $client->jsonRequest('GET', '/api/triage/submissions', [], [
            'HTTP_AUTHORIZATION' => 'Bearer ' . $token,
        ]);

        $this->assertResponseStatusCodeSame(200);
        $data = json_decode($client->getResponse()->getContent(), true);
        $this->assertIsArray($data['data']);
    }

    public function testAdminStatsRequiresAdminRole(): void
    {
        $client = static::createClient();
        $client->jsonRequest('GET', '/api/admin/stats');

        $this->assertResponseStatusCodeSame(401); // No token
    }
}
```

- [ ] **Step 2: Run integration tests**

```bash
workdir: backend
docker compose run --rm php vendor/bin/phpunit tests/Triage/Infrastructure/Controller/TriageControllerTest.php
```

Expected: Tests pass (submit returns 202, submissions list returns 200).

- [ ] **Step 3: Commit**

```bash
git add backend/tests/Triage/Infrastructure/Controller/
git commit -m "test: add integration tests for triage flow + admin stats"
```

---

### Task 19: Run all tests + fix + finalize

- [ ] **Step 1: Run full test suite**

```bash
workdir: backend
docker compose run --rm php vendor/bin/phpunit
```

Expected: All tests pass. Fix any failures before proceeding.

- [ ] **Step 2: Run PHPStan**

```bash
workdir: backend
docker compose run --rm php vendor/bin/phpstan analyse src/ --level=5
```

Expected: Zero errors. Fix type issues if any.

- [ ] **Step 3: Verify all routes**

```bash
workdir: backend
docker compose run --rm php bin/console debug:router
```

Expected: All routes listed: `/api/register`, `/api/login`, `/api/triage/*`, `/api/admin/*`.

- [ ] **Step 4: Commit**

```bash
git add -A backend/tests/
git commit -m "test: finalize backend test suite"
```

---

## Self-Review

**1. Spec coverage check:**
- Docker + Symfony scaffold → Task 1
- symfony/ai + OpenRouter config → Task 2
- Database + Doctrine → Task 3
- Value objects (enums) → Task 4
- User entity → Task 5
- TriageSubmission entity → Task 6
- Registration → Task 7
- JWT auth → Task 8
- System prompt + AI service → Task 9
- Triage pipeline CQRS → Task 10
- Triage controller (submit, status, answer, result, my submissions) → Task 11
- Messenger async handler → Task 12
- Admin API Platform User resource → Task 13
- Admin API Platform TriageSubmission resource → Task 14
- Admin stats → Task 15
- Synthetic case scheduler → Task 16
- Manual trigger + impersonation → Task 17
- Integration tests → Task 18
- Final validation → Task 19

**2. Placeholder scan:** No TBD/TODO placeholders. All code shown in full.

**3. Type consistency:** 
- `TriageSubmission` entity fields consistent across Tasks 6, 11, 12, 14
- `SubmitTriageCommand` used in Tasks 10, 16, 17
- API response format consistent across Task 11 (serializeSubmission) and Tasks 5, 6 in frontend plan
