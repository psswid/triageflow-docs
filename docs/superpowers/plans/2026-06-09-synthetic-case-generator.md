# Synthetic Case Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automated synthetic case generation — Symfony Scheduler every 60s → OpenRouter AI generates realistic symptom descriptions → pushes through triage pipeline with `isSynthetic=true`. Plus extraction of two 501 stubs from AdminController into dedicated controllers.

**Architecture:** DDD Light with bounded contexts. New `Synthetic` bounded context for generation logic. Scheduler task triggers `GenerateSyntheticCaseHandler` → calls OpenRouter for symptom → creates `TriageSubmission::create(systemUser, symptom, isSynthetic: true)` → runs initial AI analysis → dispatches `ProcessSyntheticTurnMessage` with 10s `DelayStamp` for follow-up turns. `ProcessSyntheticTurnHandler` simulates patient answers via OpenRouter. Admin stubs extracted to `SyntheticCaseController` and `ImpersonationController`.

**Tech Stack:** Symfony 7.4, `symfony/scheduler`, `symfony/messenger` (DelayedStamp), OpenRouterClientInterface, Doctrine migrations (raw SQL for system user), Lexik JWT (`JWTTokenManagerInterface` for impersonation)

**Branch:** `feature/synthetic-case-generator` (off `main`)

---

### Task 1: Create branch + system user migration

**Files:**
- Create: `backend/migrations/Version20260609000001.php`

- [ ] **Step 1: Create feature branch**

```bash
cd /home/stefan/dev/projects/triageflow
git checkout main && git pull origin main && git checkout -b feature/synthetic-case-generator
```

- [ ] **Step 2: Create system user migration**

Create `backend/migrations/Version20260609000001.php`:

```php
<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

final class Version20260609000001 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Create system user for synthetic case generation';
    }

    public function up(Schema $schema): void
    {
        $this->addSql("INSERT INTO users (id, email, roles, password, created_at)
            VALUES (
                '00000000-0000-0000-0000-000000000001',
                'system@triageflow.local',
                '[\"ROLE_SYSTEM\"]',
                '',
                '2026-06-09T00:00:00+00:00'
            )");
    }

    public function down(Schema $schema): void
    {
        $this->addSql("DELETE FROM users WHERE id = '00000000-0000-0000-0000-000000000001'");
    }
}
```

- [ ] **Step 3: Run migration to verify**

```bash
cd /home/stefan/dev/projects/triageflow/backend
php bin/console doctrine:migrations:migrate 20260609000001 --no-interaction
# Expected: "[OK] Successfully migrated to version 20260609000001"
```

- [ ] **Step 4: Verify system user exists**

```bash
cd /home/stefan/dev/projects/triageflow/backend
php bin/console dbal:run-sql "SELECT id, email, roles FROM users WHERE id = '00000000-0000-0000-0000-000000000001'"
# Expected: one row with system@triageflow.local and ["ROLE_SYSTEM"]
```

- [ ] **Step 5: Commit**

```bash
cd /home/stefan/dev/projects/triageflow
git add backend/migrations/Version20260609000001.php
git commit -m "feat: add system user migration for synthetic case generation"
```

---

### Task 2: Add `TriageSubmission::create()` factory with `isSynthetic` support

**Files:**
- Modify: `backend/src/Triage/Domain/Entity/TriageSubmission.php`

- [ ] **Step 1: Add `create()` named constructor after `submit()`** (after line 70)

Add this method:

```php
/**
 * Named constructor — create a triage submission with explicit isSynthetic flag.
 *
 * Used by the synthetic case generator. Regular user submissions
 * should continue using submit().
 */
public static function create(User $user, string $initialDescription, bool $isSynthetic = false): self
{
    $submission = new self($user, $initialDescription);
    $submission->isSynthetic = $isSynthetic;
    return $submission;
}
```

- [ ] **Step 2: Run tests to confirm no regressions**

```bash
cd /home/stefan/dev/projects/triageflow/backend
php bin/phpunit --no-coverage
# Expected: all tests pass (existing submit() still works)
```

- [ ] **Step 3: Commit**

```bash
cd /home/stefan/dev/projects/triageflow
git add backend/src/Triage/Domain/Entity/TriageSubmission.php
git commit -m "feat: add TriageSubmission::create() factory with isSynthetic param"
```

---

### Task 3: Create `SyntheticSystemPrompt` service

**Files:**
- Create: `backend/src/Synthetic/Application/Service/SyntheticSystemPrompt.php`

- [ ] **Step 1: Create the synthetic prompt service**

```php
<?php

declare(strict_types=1);

namespace App\Synthetic\Application\Service;

/**
 * System prompts for AI-driven synthetic symptom generation and patient simulation.
 *
 * These prompts instruct the AI to ACT as a patient, not as a medical triage
 * assistant (which is the role of TriageSystemPrompt).
 */
final readonly class SyntheticSystemPrompt
{
    /**
     * Prompt to generate a realistic first-person symptom description.
     * Rotates across 7 medical domains, keeps output under 500 characters.
     */
    public function getSymptomGenerationPrompt(): string
    {
        return <<<'PROMPT'
You are simulating a patient for a medical triage DEMONSTRATION system.
Generate a realistic first-person description of symptoms.

Rules:
1. Use natural first-person language ("I've been having chest pain for 3 days")
2. Vary the medical domain randomly. Choose from:
   - CARDIOLOGY: chest pain, palpitations, shortness of breath
   - NEUROLOGY: headaches, dizziness, numbness, vision changes
   - DERMATOLOGY: rashes, skin changes, itching
   - ORTHOPEDICS: joint pain, back pain, mobility issues
   - GASTROENTEROLOGY: abdominal pain, nausea, digestive issues
   - PULMONOLOGY: cough, wheezing, breathing difficulty
   - PSYCHIATRY: anxiety, depression, mood changes, sleep issues
3. Include 2-3 relevant details (duration, severity, location)
4. Keep under 500 characters
5. Vary severity from minor to potentially serious
6. Do NOT add greetings — just the symptom description

IMPORTANT: This is a DEMONSTRATION system. All data is synthetic.
Respond ONLY with the description text, no JSON, no prefix.
PROMPT;
    }

    /**
     * Prompt to generate a realistic patient answer to an AI follow-up question.
     */
    public function getPatientAnswerPrompt(): string
    {
        return <<<'PROMPT'
You are simulating a patient answering a doctor's follow-up question.

Rules:
1. Answer the question directly in first-person
2. Be concise — under 300 characters
3. Add one realistic detail the doctor asked about
4. Sound like a real person, not a textbook
5. Do NOT add greetings or sign-offs

IMPORTANT: This is a DEMONSTRATION system. All data is synthetic.
Respond ONLY with the answer text, no JSON, no prefix.
PROMPT;
    }
}
```

- [ ] **Step 2: Verify no syntax errors**

```bash
cd /home/stefan/dev/projects/triageflow/backend
php -l src/Synthetic/Application/Service/SyntheticSystemPrompt.php
# Expected: "No syntax errors detected"
```

- [ ] **Step 3: Commit**

```bash
cd /home/stefan/dev/projects/triageflow
git add backend/src/Synthetic/
git commit -m "feat: add SyntheticSystemPrompt service"
```

---

### Task 4: `ProcessSyntheticTurnMessage` + handler (10s delayed patient simulation)

**Files:**
- Create: `backend/src/Synthetic/Application/Message/ProcessSyntheticTurnMessage.php`
- Create: `backend/src/Synthetic/Application/Message/ProcessSyntheticTurnHandler.php`

- [ ] **Step 1: Create the message**

```php
<?php

declare(strict_types=1);

namespace App\Synthetic\Application\Message;

use Symfony\Component\Uid\Uuid;

/**
 * Dispatched after each AI question to a synthetic submission.
 * The handler generates a realistic patient answer via OpenRouter
 * and continues the triage interview.
 *
 * Dispatched with a 10-second DelayStamp to simulate human typing speed.
 */
final readonly class ProcessSyntheticTurnMessage
{
    public function __construct(
        public Uuid $submissionId,
    ) {}
}
```

- [ ] **Step 2: Create the handler**

```php
<?php

declare(strict_types=1);

namespace App\Synthetic\Application\Message;

use App\Shared\Infrastructure\Ai\OpenRouterClientInterface;
use App\Synthetic\Application\Service\SyntheticSystemPrompt;
use App\Triage\Application\Service\TriageAnalyzerInterface;
use App\Triage\Application\Service\TriageAnalysisFailedException;
use App\Triage\Domain\Entity\TriageOutcome;
use App\Triage\Domain\Entity\TriageStatus;
use App\Triage\Domain\Repository\TriageSubmissionRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\Messenger\Attribute\AsMessageHandler;
use Symfony\Component\Messenger\Envelope;
use Symfony\Component\Messenger\MessageBusInterface;
use Symfony\Component\Messenger\Stamp\DelayStamp;

/**
 * Generates a synthetic patient answer and continues the triage interview.
 *
 * Flow:
 *   1. Load submission, no-op if already terminal
 *   2. Extract the last AI question from conversation history
 *   3. Call OpenRouter to generate a realistic patient answer
 *   4. Record the answer via addUserAnswer()
 *   5. Call TriageAnalyzer for follow-up analysis
 *   6. If AI returns a result → complete the submission
 *   7. If AI returns a question → addAiQuestion() + dispatch next turn (delayed 10s)
 */
#[AsMessageHandler]
final readonly class ProcessSyntheticTurnHandler
{
    public function __construct(
        private TriageSubmissionRepository $repository,
        private OpenRouterClientInterface $openRouter,
        private SyntheticSystemPrompt $syntheticPrompt,
        private TriageAnalyzerInterface $analyzer,
        private EntityManagerInterface $entityManager,
        private ?MessageBusInterface $messageBus = null,
    ) {}

    public function __invoke(ProcessSyntheticTurnMessage $message): void
    {
        $submission = $this->repository->findById($message->submissionId);

        if ($submission === null) {
            throw new \RuntimeException(sprintf(
                'Submission "%s" not found.',
                $message->submissionId->toRfc4122(),
            ));
        }

        // No-op if already terminal
        if ($submission->getStatus() === TriageStatus::Completed
            || $submission->getStatus() === TriageStatus::Failed) {
            return;
        }

        // No-op if not awaiting answer (shouldn't happen in normal flow)
        if ($submission->getStatus() !== TriageStatus::AwaitingAnswer) {
            return;
        }

        // Extract the last AI question from conversation history
        $lastQuestion = $this->extractLastQuestion($submission->getConversationHistory());
        if ($lastQuestion === null) {
            return;
        }

        // Generate a realistic patient answer via OpenRouter
        $patientAnswer = $this->openRouter->chat([
            ['role' => 'system', 'content' => $this->syntheticPrompt->getPatientAnswerPrompt()],
            ['role' => 'user', 'content' => "The doctor asks: {$lastQuestion}\n\nAnswer as the patient:"],
        ]);

        $patientAnswer = trim($patientAnswer);
        if ($patientAnswer === '') {
            $submission->markFailed();
            $this->entityManager->flush();
            return;
        }

        // Record the patient's answer (this transitions status back to Processing)
        $submission->addUserAnswer($patientAnswer);
        $this->entityManager->flush();

        // Run the AI follow-up analysis
        try {
            $result = $this->analyzer->analyzeFollowUp(
                $patientAnswer,
                $submission->getConversationHistory(),
                $submission->getCurrentTurn(),
            );
        } catch (TriageAnalysisFailedException) {
            $submission->markFailed();
            $this->entityManager->flush();
            return;
        }

        if ($result['type'] === 'result') {
            $outcome = TriageOutcome::create(
                specialist: $result['specialist'],
                urgency: $result['urgency'],
                justification: $result['justification'],
            );
            $submission->completeWithOutcome($outcome);
            $this->entityManager->flush();
        } else {
            // AI asked another question — record it and schedule next turn
            $submission->addAiQuestion($result['content']);
            $this->entityManager->flush();

            // Dispatch next synthetic turn with 10-second delay
            $this->messageBus?->dispatch(
                (new Envelope(new ProcessSyntheticTurnMessage($submission->getId())))
                    ->with(new DelayStamp(10000)),
            );
        }
    }

    /**
     * @param array<int, array{type: string, content: string, timestamp: string}> $history
     */
    private function extractLastQuestion(array $history): ?string
    {
        for ($i = count($history) - 1; $i >= 0; $i--) {
            if ($history[$i]['type'] === 'question') {
                return $history[$i]['content'];
            }
        }
        return null;
    }
}
```

- [ ] **Step 3: Verify no syntax errors**

```bash
cd /home/stefan/dev/projects/triageflow/backend
php -l src/Synthetic/Application/Message/ProcessSyntheticTurnMessage.php
php -l src/Synthetic/Application/Message/ProcessSyntheticTurnHandler.php
# Expected: "No syntax errors detected" for both
```

- [ ] **Step 4: Commit**

```bash
cd /home/stefan/dev/projects/triageflow
git add backend/src/Synthetic/Application/Message/
git commit -m "feat: add ProcessSyntheticTurnMessage + handler with 10s delay"
```

---

### Task 5: `GenerateSyntheticCaseHandler` — orchestrator

**Files:**
- Create: `backend/src/Synthetic/Application/Command/GenerateSyntheticCaseCommand.php`
- Create: `backend/src/Synthetic/Application/Command/GenerateSyntheticCaseHandler.php`

- [ ] **Step 1: Create the command**

```php
<?php

declare(strict_types=1);

namespace App\Synthetic\Application\Command;

/**
 * Command to generate one synthetic triage case.
 * Dispatched by the scheduler (every 60s) or by the manual admin endpoint.
 */
final readonly class GenerateSyntheticCaseCommand
{
    public function __construct() {}
}
```

- [ ] **Step 2: Create the handler**

This handler: generates symptom → creates submission with `isSynthetic=true` → runs initial AI analysis → dispatches follow-up turn with 10s delay if the AI asks a question.

```php
<?php

declare(strict_types=1);

namespace App\Synthetic\Application\Command;

use App\Shared\Infrastructure\Ai\OpenRouterClientInterface;
use App\Synthetic\Application\Message\ProcessSyntheticTurnMessage;
use App\Synthetic\Application\Service\SyntheticSystemPrompt;
use App\Triage\Application\Service\TriageAnalyzerInterface;
use App\Triage\Application\Service\TriageAnalysisFailedException;
use App\Triage\Domain\Entity\TriageOutcome;
use App\Triage\Domain\Entity\TriageSubmission;
use App\Triage\Domain\Repository\TriageSubmissionRepository;
use App\User\Domain\Repository\UserRepository;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Component\Messenger\Envelope;
use Symfony\Component\Messenger\MessageBusInterface;
use Symfony\Component\Messenger\Stamp\DelayStamp;
use Symfony\Component\Uid\Uuid;

/**
 * Generates one synthetic triage case end-to-end.
 *
 * Flow:
 *   1. Resolve the system user (UUID 00000000-...)
 *   2. Call OpenRouter to generate a realistic symptom description
 *   3. Create TriageSubmission::create(systemUser, symptom, isSynthetic: true)
 *   4. Run initial AI analysis via TriageAnalyzer
 *   5. If AI returns a result → complete immediately
 *   6. If AI asks a question → record it + dispatch ProcessSyntheticTurnMessage (10s delay)
 */
final readonly class GenerateSyntheticCaseHandler
{
    private const string SYSTEM_USER_ID = '00000000-0000-0000-0000-000000000001';

    public function __construct(
        private UserRepository $userRepository,
        private OpenRouterClientInterface $openRouter,
        private SyntheticSystemPrompt $syntheticPrompt,
        private TriageAnalyzerInterface $analyzer,
        private TriageSubmissionRepository $submissionRepository,
        private EntityManagerInterface $entityManager,
        private ?MessageBusInterface $messageBus = null,
    ) {}

    public function __invoke(GenerateSyntheticCaseCommand $command): TriageSubmission
    {
        $systemUser = $this->userRepository->findById(Uuid::fromString(self::SYSTEM_USER_ID));

        if ($systemUser === null) {
            throw new \RuntimeException(
                'System user not found. Run doctrine:migrations:migrate to create it.',
            );
        }

        // Step 1: Generate symptom description via OpenRouter
        $symptomDescription = $this->generateSymptom();

        // Step 2: Create submission with isSynthetic=true
        $submission = TriageSubmission::create($systemUser, $symptomDescription, isSynthetic: true);
        $this->submissionRepository->save($submission);

        // Step 3: Run initial AI analysis
        try {
            $result = $this->analyzer->analyzeInitial($symptomDescription);
        } catch (TriageAnalysisFailedException) {
            $submission->markFailed();
            $this->entityManager->flush();
            return $submission;
        }

        // Step 4: Handle result or question
        if ($result['type'] === 'result') {
            $outcome = TriageOutcome::create(
                specialist: $result['specialist'],
                urgency: $result['urgency'],
                justification: $result['justification'],
            );
            $submission->completeWithOutcome($outcome);
            $this->entityManager->flush();
        } else {
            $submission->addAiQuestion($result['content']);
            $this->entityManager->flush();

            // Dispatch follow-up turn with 10-second delay (simulate human typing)
            $this->messageBus?->dispatch(
                (new Envelope(new ProcessSyntheticTurnMessage($submission->getId())))
                    ->with(new DelayStamp(10000)),
            );
        }

        return $submission;
    }

    /**
     * Call OpenRouter to generate a realistic symptom description.
     * Retries once if the AI returns empty.
     */
    private function generateSymptom(): string
    {
        $symptom = $this->openRouter->chat([
            ['role' => 'system', 'content' => $this->syntheticPrompt->getSymptomGenerationPrompt()],
            ['role' => 'user', 'content' => 'Generate a random symptom description.'],
        ]);

        $symptom = trim($symptom);

        // Retry once if empty
        if ($symptom === '') {
            $symptom = $this->openRouter->chat([
                ['role' => 'system', 'content' => $this->syntheticPrompt->getSymptomGenerationPrompt()],
                ['role' => 'user', 'content' => 'Generate a random symptom description. Vary the medical domain.'],
            ]);
            $symptom = trim($symptom);
        }

        if ($symptom === '') {
            throw new \RuntimeException('OpenRouter returned empty symptom description after retry.');
        }

        return $symptom;
    }
}
```

- [ ] **Step 3: Verify no syntax errors**

```bash
cd /home/stefan/dev/projects/triageflow/backend
php -l src/Synthetic/Application/Command/GenerateSyntheticCaseCommand.php
php -l src/Synthetic/Application/Command/GenerateSyntheticCaseHandler.php
```

- [ ] **Step 4: Commit**

```bash
cd /home/stefan/dev/projects/triageflow
git add backend/src/Synthetic/Application/Command/
git commit -m "feat: add GenerateSyntheticCaseHandler orchestrator"
```

---

### Task 6: `GenerateSyntheticCaseTask` — Scheduler task (every 60s)

**Files:**
- Create: `backend/src/Synthetic/Infrastructure/Scheduler/GenerateSyntheticCaseTask.php`

- [ ] **Step 1: Create the scheduler task**

```php
<?php

declare(strict_types=1);

namespace App\Synthetic\Infrastructure\Scheduler;

use App\Synthetic\Application\Command\GenerateSyntheticCaseCommand;
use App\Synthetic\Application\Command\GenerateSyntheticCaseHandler;
use Symfony\Component\Scheduler\Attribute\AsCronTask;

/**
 * Scheduled task that generates a synthetic triage case every 60 seconds.
 *
 * Triggered by the symfony/scheduler configured in scheduler.yaml.
 * Runs only when the messenger consumer for scheduler_default is running.
 */
#[AsCronTask('*/60 * * * *')]
final readonly class GenerateSyntheticCaseTask
{
    public function __construct(
        private GenerateSyntheticCaseHandler $handler,
    ) {}

    public function __invoke(): void
    {
        ($this->handler)(new GenerateSyntheticCaseCommand());
    }
}
```

- [ ] **Step 2: Create scheduler configuration**

Create `backend/config/packages/scheduler.yaml`:

```yaml
framework:
    scheduler:
        default_scheduler:
            enabled: true
```

Note: The `#[AsSchedule]` on `Schedule.php` already configures the transport. This YAML enables it. The cron task annotation on `GenerateSyntheticCaseTask` defines the 60s recurrence.

- [ ] **Step 3: Register the scheduler transport in messenger.yaml**

Add the `scheduler_default` transport to `backend/config/packages/messenger.yaml`:

```yaml
framework:
    messenger:
        failure_transport: failed
        transports:
            async:
                dsn: '%env(MESSENGER_TRANSPORT_DSN)%'
                retry_strategy:
                    max_retries: 3
                    delay: 2000
                    multiplier: 2
            scheduler_default:
                dsn: 'doctrine://default?queue_name=scheduler_default'
            failed: 'doctrine://default?queue_name=failed'
            sync: 'sync://'
        routing:
            App\Triage\Application\Message\ProcessTriageMessage: async
            App\Synthetic\Application\Message\ProcessSyntheticTurnMessage: async
```

- [ ] **Step 4: Verify the scheduler task is registered**

```bash
cd /home/stefan/dev/projects/triageflow/backend
php bin/console debug:scheduler
# Expected: shows "default_scheduler" with "App\Synthetic\Infrastructure\Scheduler\GenerateSyntheticCaseTask" recurring every 60s
```

- [ ] **Step 5: Commit**

```bash
cd /home/stefan/dev/projects/triageflow
git add backend/src/Synthetic/Infrastructure/Scheduler/ \
    backend/config/packages/scheduler.yaml \
    backend/config/packages/messenger.yaml
git commit -m "feat: add GenerateSyntheticCaseTask with 60s cron schedule"
```

---

### Task 7: `SyntheticCaseController` — extract from AdminController 501 stub

**Files:**
- Create: `backend/src/Admin/Infrastructure/Controller/SyntheticCaseController.php`
- Modify: `backend/src/Admin/Infrastructure/Controller/AdminController.php` (remove the 501 stub)

- [ ] **Step 1: Create SyntheticCaseController**

```php
<?php

declare(strict_types=1);

namespace App\Admin\Infrastructure\Controller;

use App\Synthetic\Application\Command\GenerateSyntheticCaseCommand;
use App\Synthetic\Application\Command\GenerateSyntheticCaseHandler;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;

/**
 * Admin endpoint to manually trigger synthetic case generation.
 *
 * POST /api/admin/synthetic/generate
 *
 * The scheduler also triggers generation automatically every 60s.
 * This endpoint provides a manual trigger for the dashboard button.
 */
final class SyntheticCaseController extends AbstractController
{
    public function __construct(
        private readonly GenerateSyntheticCaseHandler $handler,
    ) {}

    #[Route('/api/admin/synthetic/generate', methods: ['POST'], name: 'api_admin_synthetic_generate')]
    public function generate(): JsonResponse
    {
        try {
            $submission = ($this->handler)(new GenerateSyntheticCaseCommand());
        } catch (\RuntimeException $e) {
            return $this->json([
                'errors' => [[
                    'status' => '500',
                    'code' => 'GENERATION_FAILED',
                    'title' => 'Synthetic case generation failed',
                    'detail' => $e->getMessage(),
                ]],
            ], Response::HTTP_INTERNAL_SERVER_ERROR);
        }

        return $this->json([
            'data' => [
                'id' => $submission->getId()->toRfc4122(),
                'type' => 'triage_submission',
                'attributes' => [
                    'isSynthetic' => $submission->isSynthetic(),
                    'status' => $submission->getStatus()->value,
                    'submittedAt' => $submission->getSubmittedAt()->format('c'),
                ],
            ],
        ], Response::HTTP_CREATED);
    }
}
```

- [ ] **Step 2: Remove the `generateSynthetic` method from AdminController**

Delete lines 98-107 from `backend/src/Admin/Infrastructure/Controller/AdminController.php` (the `generateSynthetic` method and its route attribute):

```php
    // REMOVE this entire method (lines 98-107):
    #[Route('/api/admin/synthetic/generate', methods: ['POST'], name: 'api_admin_synthetic_generate')]
    public function generateSynthetic(): JsonResponse
    {
        ...
        ], Response::HTTP_NOT_IMPLEMENTED);
    }
```

- [ ] **Step 3: Verify the route works**

```bash
cd /home/stefan/dev/projects/triageflow/backend
php bin/console debug:router | grep synthetic
# Expected: api_admin_synthetic_generate  POST  /api/admin/synthetic/generate
```

- [ ] **Step 4: Commit**

```bash
cd /home/stefan/dev/projects/triageflow
git add backend/src/Admin/Infrastructure/Controller/SyntheticCaseController.php \
    backend/src/Admin/Infrastructure/Controller/AdminController.php
git commit -m "feat: extract SyntheticCaseController from AdminController 501 stub"
```

---

### Task 8: `ImpersonationController` — extract from AdminController 501 stub

**Files:**
- Create: `backend/src/Admin/Infrastructure/Controller/ImpersonationController.php`
- Modify: `backend/src/Admin/Infrastructure/Controller/AdminController.php` (remove the 501 stub)

- [ ] **Step 1: Create ImpersonationController**

Uses `Lexik\Bundle\JWTAuthenticationBundle\Services\JWTTokenManagerInterface` to generate a JWT for the target user.

```php
<?php

declare(strict_types=1);

namespace App\Admin\Infrastructure\Controller;

use App\User\Domain\Entity\User;
use App\User\Domain\Repository\UserRepository;
use Lexik\Bundle\JWTAuthenticationBundle\Services\JWTTokenManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Uid\Uuid;

/**
 * Admin endpoint to impersonate a user for debugging.
 *
 * Generates a valid JWT token for the target user, allowing
 * admins to log in-as that user and see their view of the system.
 */
final class ImpersonationController extends AbstractController
{
    public function __construct(
        private readonly UserRepository $userRepository,
        private readonly JWTTokenManagerInterface $jwtManager,
    ) {}

    #[Route('/api/admin/users/{id}/impersonate', methods: ['POST'], name: 'api_admin_impersonate')]
    public function impersonate(string $id): JsonResponse
    {
        $uuid = Uuid::fromString($id);
        $user = $this->userRepository->findById($uuid);

        if ($user === null) {
            throw new NotFoundHttpException(sprintf('User "%s" not found.', $id));
        }

        // Generate a JWT for the target user (same mechanism as login)
        $token = $this->jwtManager->create($user);

        return $this->json([
            'data' => [
                'token' => $token,
                'impersonated' => $user->getEmail(),
            ],
        ]);
    }
}
```

- [ ] **Step 2: Remove the `impersonate` method from AdminController**

Delete lines 109-127 from `backend/src/Admin/Infrastructure/Controller/AdminController.php` (the `impersonate` method and its route attribute):

```php
    // REMOVE this entire method (lines 109-127):
    #[Route('/api/admin/users/{id}/impersonate', methods: ['POST'], name: 'api_admin_impersonate')]
    public function impersonate(string $id): JsonResponse
    {
        ...
        ], Response::HTTP_NOT_IMPLEMENTED);
    }
```

After removal, verify imports in `AdminController.php` are still correct — remove unused `use` statements if any (specifically `use Symfony\Component\Uid\Uuid` if it's no longer needed).

- [ ] **Step 3: Verify the route works**

```bash
cd /home/stefan/dev/projects/triageflow/backend
php bin/console debug:router | grep impersonate
# Expected: api_admin_impersonate  POST  /api/admin/users/{id}/impersonate
```

- [ ] **Step 4: Commit**

```bash
cd /home/stefan/dev/projects/triageflow
git add backend/src/Admin/Infrastructure/Controller/ImpersonationController.php \
    backend/src/Admin/Infrastructure/Controller/AdminController.php
git commit -m "feat: extract ImpersonationController from AdminController 501 stub"
```

---

### Task 9: Update tests

**Files:**
- Modify: `backend/tests/Admin/Infrastructure/Controller/AdminControllerTest.php`

- [ ] **Step 1: Update `testGenerateSyntheticReturns501` to expect 201**

Replace the existing test method (lines 144-151) and add supporting setup:

```php
    // ─────────────────────────────────────────────────────────────────
    // POST /api/admin/synthetic/generate
    // ─────────────────────────────────────────────────────────────────

    public function testGenerateSyntheticReturns201(): void
    {
        $client = $this->createAdminClient();

        // Create the system user in the test DB
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

        // Configure TestTriageAnalyzer to return a result immediately
        \App\Tests\Triage\Infrastructure\Controller\TestTriageAnalyzer::willReturnResultOnNextCall();

        $client->jsonRequest('POST', '/api/admin/synthetic/generate');

        $this->assertResponseStatusCodeSame(201);
        $data = json_decode($client->getResponse()->getContent(), true);
        $this->assertArrayHasKey('data', $data);
        $this->assertArrayHasKey('id', $data['data']);
        $this->assertTrue($data['data']['attributes']['isSynthetic']);
    }

    public function testGenerateSyntheticReturns401WithoutAuth(): void
    {
        $client = static::createClient();

        $client->jsonRequest('POST', '/api/admin/synthetic/generate');

        $this->assertResponseStatusCodeSame(401);
    }
```

- [ ] **Step 2: Add impersonation test**

```php
    // ─────────────────────────────────────────────────────────────────
    // POST /api/admin/users/{id}/impersonate
    // ─────────────────────────────────────────────────────────────────

    public function testImpersonateReturns200(): void
    {
        $client = $this->createAdminClient();

        // First, create a regular user to impersonate
        $email = $this->uniqueEmail();
        $client->jsonRequest('POST', '/api/register', [
            'email' => $email,
            'password' => 'SecurePass123!',
        ]);
        $this->assertResponseStatusCodeSame(201);

        // Need to re-auth as admin (the register logs you in as the new user)
        $adminClient = $this->createAdminClient();

        // Find the user to impersonate
        $adminClient->jsonRequest('GET', '/api/admin/users');
        $this->assertResponseStatusCodeSame(200);
        $users = json_decode($adminClient->getResponse()->getContent(), true)['data'] ?? [];

        $targetUser = null;
        foreach ($users as $u) {
            if ($u['attributes']['email'] === $email) {
                $targetUser = $u;
                break;
            }
        }
        $this->assertNotNull($targetUser, 'Target user not found');

        $adminClient->jsonRequest('POST', '/api/admin/users/' . $targetUser['id'] . '/impersonate');

        $this->assertResponseStatusCodeSame(200);
        $data = json_decode($adminClient->getResponse()->getContent(), true);
        $this->assertArrayHasKey('data', $data);
        $this->assertArrayHasKey('token', $data['data']);
        $this->assertNotEmpty($data['data']['token']);
        $this->assertSame($email, $data['data']['impersonated']);
    }

    public function testImpersonateReturns404ForMissingUser(): void
    {
        $client = $this->createAdminClient();
        $fakeId = '00000000-0000-0000-0000-000000000000';

        $client->jsonRequest('POST', '/api/admin/users/' . $fakeId . '/impersonate');

        $this->assertResponseStatusCodeSame(404);
    }

    public function testImpersonateReturns401WithoutAuth(): void
    {
        $client = static::createClient();
        $fakeId = '00000000-0000-0000-0000-000000000000';

        $client->jsonRequest('POST', '/api/admin/users/' . $fakeId . '/impersonate');

        $this->assertResponseStatusCodeSame(401);
    }
```

- [ ] **Step 3: Run all tests**

```bash
cd /home/stefan/dev/projects/triageflow/backend
php bin/phpunit --no-coverage
# Expected: all tests pass (including updated synthetic/generate and new impersonation tests)
```

- [ ] **Step 4: Fix any test failures** — iterate until green

If tests fail, diagnose and fix before committing.

- [ ] **Step 5: Commit**

```bash
cd /home/stefan/dev/projects/triageflow
git add backend/tests/Admin/Infrastructure/Controller/AdminControllerTest.php
git commit -m "test: update tests for synthetic generate + impersonation endpoints"
```

---

### Task 10: Register synthetic services in services.yaml

**Files:**
- Modify: `backend/config/services.yaml`

- [ ] **Step 1: Add `ProcessSyntheticTurnMessage` routing to messenger.yaml** (already done in Task 6)

Double-check that `App\Synthetic\Application\Message\ProcessSyntheticTurnMessage` is routed to `async` transport in `messenger.yaml`. If Task 6 Step 3 was followed correctly, it's already there.

- [ ] **Step 2: Run final verification**

```bash
cd /home/stefan/dev/projects/triageflow/backend

# Check all routes
php bin/console debug:router | grep -E "synthetic|impersonate"
# Expected:
# api_admin_synthetic_generate  POST  /api/admin/synthetic/generate
# api_admin_impersonate         POST  /api/admin/users/{id}/impersonate

# Check scheduler
php bin/console debug:scheduler

# Check messenger
php bin/console debug:messenger
# Expected: ProcessSyntheticTurnMessage routed to async

# Run full test suite
php bin/phpunit --no-coverage
```

- [ ] **Step 3: Commit remaining config**

```bash
cd /home/stefan/dev/projects/triageflow
git add backend/config/services.yaml
git commit -m "chore: register synthetic services in DI config" || echo "No changes needed"
```

---

## Self-Review Checklist

### Spec Coverage

| Requirement | Covered By |
|---|---|
| Scheduler generates one synthetic case every 60s | Task 6: `GenerateSyntheticCaseTask` + `scheduler.yaml` |
| AI generates varied symptom descriptions (7 domains) | Task 3: `SyntheticSystemPrompt::getSymptomGenerationPrompt()` |
| Synthetic cases flow through same triage pipeline | Task 5: reuses `TriageAnalyzerInterface` |
| 10s cooldown between turns | Task 4: `DelayStamp(10000)` on `ProcessSyntheticTurnMessage` |
| All synthetic submissions have `isSynthetic=true` | Task 2: `TriageSubmission::create($user, $desc, isSynthetic: true)` |
| `POST /api/admin/synthetic/generate` returns 201 | Task 7: `SyntheticCaseController` |
| System user owns all synthetic submissions | Task 1: migration + Task 5: resolves system user by UUID |
| `POST /api/admin/users/{id}/impersonate` returns JWT | Task 8: `ImpersonationController` via `JWTTokenManagerInterface` |
| Frontend dashboard shows synthetic cases | Already built (Issue #4) — frontend wires to `ENDPOINTS.SYNTHETIC_GENERATE` |

### Placeholder Scan

- [ ] No "TBD", "TODO", "implement later", "fill in details"
- [ ] No "Add appropriate error handling" without code
- [ ] No "Write tests for the above" without actual test code
- [ ] No "Similar to Task N" — all code is self-contained
- [ ] No undefined type/function references

### Type Consistency

- `TriageSubmission::create($user, $desc, isSynthetic: true)` — consistent across Tasks 2, 5, 7
- `ProcessSyntheticTurnMessage` takes `Uuid $submissionId` — consistent in Task 4
- `JWTTokenManagerInterface::create($user)` — consistent in Task 8
- `GenerateSyntheticCaseCommand` — empty command used consistently in Tasks 5, 6, 7
