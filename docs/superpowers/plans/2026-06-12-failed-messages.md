# Failed Messages (Worker Monitoring + Dead Letter Queue) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Failed Messages monitoring to the admin dashboard — list failed Symfony Messenger messages with inline retry/delete actions.

**Architecture:** Backend raw SQL via DBAL\Connection in existing AdminController (no service layer). Frontend self-fetching component with TanStack Query polling. Single tab added to existing DashboardPage.

**Tech Stack:** PHP 8.3, Symfony 7.2, Doctrine DBAL, React 18, TanStack Query v5, TailwindCSS

---

### Task 1: Add GET /api/admin/failed-messages endpoint

**Files:**
- Modify: `backend/src/Admin/Infrastructure/Controller/AdminController.php`
- Test: `backend/tests/Admin/Infrastructure/Controller/AdminControllerTest.php`

- [ ] **Step 1: Add use statements and DBAL dependency to AdminController**

Add to imports in `AdminController.php`:
```php
use Doctrine\DBAL\Connection;
use Doctrine\DBAL\Exception as DBALException;
```

Change constructor to inject `Connection`:
```php
public function __construct(
    private readonly TriageSubmissionRepository $triageRepository,
    private readonly UserRepository $userRepository,
    private readonly Connection $dbal,
) {}
```

- [ ] **Step 2: Add GET /api/admin/failed-messages endpoint**

Add the following method to `AdminController.php` between `users()` and `serializeSubmission()`:

```php
#[Route('/api/admin/failed-messages', methods: ['GET'], name: 'api_admin_failed_messages')]
public function failedMessages(): JsonResponse
{
    try {
        $rows = $this->dbal->fetchAllAssociative(
            "SELECT id, body, headers, created_at FROM messenger_messages WHERE queue_name = 'failed' ORDER BY created_at DESC"
        );
    } catch (DBALException) {
        return $this->json(['data' => []], 200);
    }

    return $this->json([
        'data' => array_map(fn(array $row) => $this->serializeFailedMessage($row), $rows),
    ]);
}
```

- [ ] **Step 3: Add serializeFailedMessage private method**

Add to `AdminController.php` at the end of the class, after `serializeSubmission`:

```php
/**
 * @param array<string, mixed> $row
 * @return array<string, mixed>
 */
private function serializeFailedMessage(array $row): array
{
    $headers = json_decode($row['headers'], true) ?? [];
    $body = $row['body'];
    // Extract first ~120 chars for preview, strip JSON escaping
    $preview = \mb_substr(\trim((string) \json_decode($body, true)['description'] ?? $body), 0, 120);

    return [
        'id' => (int) $row['id'],
        'type' => 'failed_message',
        'attributes' => [
            'messageId' => (int) $row['id'],
            'type' => $headers['X-Message-Class'] ?? 'Unknown',
            'failedAt' => (new \DateTimeImmutable($row['created_at']))->format('c'),
            'error' => $headers['X-Failed-Description'] ?? 'Unknown error',
            'preview' => $preview,
        ],
    ];
}
```

- [ ] **Step 4: Add GET test — returns 200 with data array**

Add to `AdminControllerTest.php`:

```php
// ─────────────────────────────────────────────────────────────────
// GET /api/admin/failed-messages
// ─────────────────────────────────────────────────────────────────

public function testFailedMessagesReturns200(): void
{
    $client = $this->createAdminClient();

    $client->jsonRequest('GET', '/api/admin/failed-messages');

    $this->assertResponseStatusCodeSame(200);
    $data = json_decode($client->getResponse()->getContent(), true);
    $this->assertArrayHasKey('data', $data);
    $this->assertIsArray($data['data']);
    // Response is valid even if empty; rows have expected structure
    foreach ($data['data'] as $msg) {
        $this->assertArrayHasKey('id', $msg);
        $this->assertSame('failed_message', $msg['type']);
        $this->assertArrayHasKey('attributes', $msg);
        $this->assertArrayHasKey('messageId', $msg['attributes']);
        $this->assertArrayHasKey('type', $msg['attributes']);
        $this->assertArrayHasKey('error', $msg['attributes']);
        $this->assertArrayHasKey('preview', $msg['attributes']);
        $this->assertArrayHasKey('failedAt', $msg['attributes']);
    }
}

public function testFailedMessagesReturns401WithoutAuth(): void
{
    $client = static::createClient();

    $client->jsonRequest('GET', '/api/admin/failed-messages');

    $this->assertResponseStatusCodeSame(401);
}
```

- [ ] **Step 5: Run backend tests to verify**

Run: `cd backend && php vendor/bin/phpunit tests/Admin/Infrastructure/Controller/AdminControllerTest.php --filter="testFailedMessages" -v`

Expected: All `testFailedMessages*` tests PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/src/Admin/Infrastructure/Controller/AdminController.php backend/tests/Admin/Infrastructure/Controller/AdminControllerTest.php
git commit -m "feat(admin): add GET /api/admin/failed-messages endpoint"
```

---

### Task 2: Add POST /api/admin/failed-messages/{id}/retry and DELETE endpoints

**Files:**
- Modify: `backend/src/Admin/Infrastructure/Controller/AdminController.php`
- Test: `backend/tests/Admin/Infrastructure/Controller/AdminControllerTest.php`

- [ ] **Step 1: Add retry endpoint to AdminController**

Add before `serializeFailedMessage`:

```php
#[Route('/api/admin/failed-messages/{id}/retry', methods: ['POST'], name: 'api_admin_failed_message_retry')]
public function retryFailedMessage(int $id): JsonResponse
{
    try {
        $row = $this->dbal->fetchAssociative(
            "SELECT id FROM messenger_messages WHERE id = :id AND queue_name = 'failed'",
            ['id' => $id]
        );
    } catch (DBALException) {
        $row = false;
    }

    if ($row === false) {
        throw new NotFoundHttpException(sprintf('Failed message "%d" not found.', $id));
    }

    try {
        $this->dbal->executeStatement(
            "UPDATE messenger_messages SET queue_name = 'default', delivered_at = NULL WHERE id = :id",
            ['id' => $id]
        );
    } catch (DBALException $e) {
        throw new \RuntimeException('Failed to retry message: ' . $e->getMessage());
    }

    return $this->json(['data' => ['id' => $id, 'status' => 'retried']], 200);
}
```

- [ ] **Step 2: Add delete endpoint to AdminController**

Add after `retryFailedMessage`:

```php
#[Route('/api/admin/failed-messages/{id}', methods: ['DELETE'], name: 'api_admin_failed_message_delete')]
public function deleteFailedMessage(int $id): JsonResponse
{
    try {
        $row = $this->dbal->fetchAssociative(
            "SELECT id FROM messenger_messages WHERE id = :id AND queue_name = 'failed'",
            ['id' => $id]
        );
    } catch (DBALException) {
        $row = false;
    }

    if ($row === false) {
        throw new NotFoundHttpException(sprintf('Failed message "%d" not found.', $id));
    }

    try {
        $this->dbal->executeStatement(
            "DELETE FROM messenger_messages WHERE id = :id",
            ['id' => $id]
        );
    } catch (DBALException $e) {
        throw new \RuntimeException('Failed to delete message: ' . $e->getMessage());
    }

    return $this->json(['data' => ['id' => $id, 'status' => 'deleted']], 200);
}
```

- [ ] **Step 3: Add test helper to seed a failed message**

Add to `AdminControllerTest.php` before the retry tests (as a private method):

```php
/**
 * Insert a fake failed message into messenger_messages for testing.
 * Returns the inserted row id.
 */
private function seedFailedMessage(KernelBrowser $client): int
{
    $conn = $client->getContainer()->get('doctrine.dbal.default_connection');
    $conn->executeStatement(
        "INSERT INTO messenger_messages (body, headers, queue_name, created_at, available_at)
         VALUES (:body, :headers, 'failed', NOW(), NOW())",
        [
            'body' => '{"description": "Test patient needs immediate attention for chest pain and shortness of breath"}',
            'headers' => json_encode([
                'X-Message-Class' => 'App\\Triage\\Application\\Message\\ProcessTriageMessage',
                'X-Failed-Description' => 'Connection timed out after 5 seconds',
            ]),
        ]
    );

    return (int) $conn->lastInsertId();
}
```

- [ ] **Step 4: Add retry endpoint tests**

Add to `AdminControllerTest.php`:

```php
// ─────────────────────────────────────────────────────────────────
// POST /api/admin/failed-messages/{id}/retry
// ─────────────────────────────────────────────────────────────────

public function testRetryFailedMessageReturns200(): void
{
    $client = $this->createAdminClient();
    $failedId = $this->seedFailedMessage($client);

    $client->jsonRequest('POST', '/api/admin/failed-messages/' . $failedId . '/retry');

    $this->assertResponseStatusCodeSame(200);
    $data = json_decode($client->getResponse()->getContent(), true);
    $this->assertArrayHasKey('data', $data);
    $this->assertSame('retried', $data['data']['status']);

    // Verify message was moved back to default queue
    $conn = $client->getContainer()->get('doctrine.dbal.default_connection');
    $row = $conn->fetchAssociative("SELECT queue_name FROM messenger_messages WHERE id = :id", ['id' => $failedId]);
    $this->assertSame('default', $row['queue_name']);
}

public function testRetryFailedMessageReturns404ForMissing(): void
{
    $client = $this->createAdminClient();

    $client->jsonRequest('POST', '/api/admin/failed-messages/999999/retry');

    $this->assertResponseStatusCodeSame(404);
}

public function testRetryFailedMessageReturns401WithoutAuth(): void
{
    $client = static::createClient();

    $client->jsonRequest('POST', '/api/admin/failed-messages/1/retry');

    $this->assertResponseStatusCodeSame(401);
}
```

- [ ] **Step 5: Add delete endpoint tests**

Add to `AdminControllerTest.php`:

```php
// ─────────────────────────────────────────────────────────────────
// DELETE /api/admin/failed-messages/{id}
// ─────────────────────────────────────────────────────────────────

public function testDeleteFailedMessageReturns200(): void
{
    $client = $this->createAdminClient();
    $failedId = $this->seedFailedMessage($client);

    $client->jsonRequest('DELETE', '/api/admin/failed-messages/' . $failedId);

    $this->assertResponseStatusCodeSame(200);
    $data = json_decode($client->getResponse()->getContent(), true);
    $this->assertArrayHasKey('data', $data);
    $this->assertSame('deleted', $data['data']['status']);

    // Verify message was deleted
    $conn = $client->getContainer()->get('doctrine.dbal.default_connection');
    $row = $conn->fetchAssociative("SELECT id FROM messenger_messages WHERE id = :id", ['id' => $failedId]);
    $this->assertFalse($row, 'Message should have been deleted');
}

public function testDeleteFailedMessageReturns404ForMissing(): void
{
    $client = $this->createAdminClient();

    $client->jsonRequest('DELETE', '/api/admin/failed-messages/999999');

    $this->assertResponseStatusCodeSame(404);
}

public function testDeleteFailedMessageReturns401WithoutAuth(): void
{
    $client = static::createClient();

    $client->jsonRequest('DELETE', '/api/admin/failed-messages/1');

    $this->assertResponseStatusCodeSame(401);
}
```

- [ ] **Step 6: Run backend tests**

Run: `cd backend && php vendor/bin/phpunit tests/Admin/Infrastructure/Controller/AdminControllerTest.php --filter="testRetryFailedMessage|testDeleteFailedMessage" -v`

Expected: All 6 new tests PASS.

- [ ] **Step 7: Commit**

```bash
git add backend/src/Admin/Infrastructure/Controller/AdminController.php backend/tests/Admin/Infrastructure/Controller/AdminControllerTest.php
git commit -m "feat(admin): add retry and delete endpoints for failed messages"
```

---

### Task 3: Add FailedMessageResource type and endpoint

**Files:**
- Modify: `frontend/src/api/types.ts`
- Modify: `frontend/src/api/endpoints.ts`

- [ ] **Step 1: Add FailedMessageResource type to types.ts**

Add after the `ImpersonateResponse` block (before the closing of the file):

```typescript
// --- Failed Messages ---
export interface FailedMessageResource {
  readonly id: number;
  readonly type: 'failed_message';
  readonly attributes: {
    readonly messageId: number;
    readonly type: string;
    readonly failedAt: string;
    readonly error: string;
    readonly preview: string;
  };
}

export interface FailedMessagesListResponse {
  readonly data: readonly FailedMessageResource[];
}

export interface RetryFailedMessageResponse {
  readonly data: {
    readonly id: number;
    readonly status: 'retried';
  };
}

export interface DeleteFailedMessageResponse {
  readonly data: {
    readonly id: number;
    readonly status: 'deleted';
  };
}
```

- [ ] **Step 2: Add FAILED_MESSAGES to endpoints.ts**

Add to the `ADMIN` block:

```typescript
FAILED_MESSAGES: '/api/admin/failed-messages',
FAILED_MESSAGE_RETRY: (id: number) => `/api/admin/failed-messages/${id}/retry`,
FAILED_MESSAGE_DELETE: (id: number) => `/api/admin/failed-messages/${id}`,
```

The full `ADMIN` block becomes:

```typescript
ADMIN: {
    STATS: '/api/admin/stats',
    SUBMISSIONS: '/api/admin/submissions',
    SUBMISSION_DETAIL: (id: string) => `/api/admin/submissions/${id}`,
    USERS: '/api/admin/users',
    SYNTHETIC_GENERATE: '/api/admin/synthetic/generate',
    IMPERSONATE: (id: string) => `/api/admin/users/${id}/impersonate`,
    FAILED_MESSAGES: '/api/admin/failed-messages',
    FAILED_MESSAGE_RETRY: (id: number) => `/api/admin/failed-messages/${id}/retry`,
    FAILED_MESSAGE_DELETE: (id: number) => `/api/admin/failed-messages/${id}`,
},
```

- [ ] **Step 3: Commit**

```bash
git add frontend/src/api/types.ts frontend/src/api/endpoints.ts
git commit -m "feat(admin): add FailedMessageResource type and endpoints"
```

---

### Task 4: Create useAdminFailedMessages hook with polling

**Files:**
- Create: `frontend/src/features/admin/hooks/useAdminFailedMessages.ts`

- [ ] **Step 1: Create the hook file**

Create `frontend/src/features/admin/hooks/useAdminFailedMessages.ts`:

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../../../api/client';
import { ENDPOINTS } from '../../../api/endpoints';
import type {
  FailedMessageResource,
  FailedMessagesListResponse,
  RetryFailedMessageResponse,
  DeleteFailedMessageResponse,
} from '../../../api/types';

export function useAdminFailedMessages() {
  return useQuery<readonly FailedMessageResource[]>({
    queryKey: ['admin', 'failed-messages'],
    queryFn: () =>
      apiClient
        .get<FailedMessagesListResponse>(ENDPOINTS.ADMIN.FAILED_MESSAGES)
        .then((r) => r.data.data),
    refetchInterval: 15_000,
  });
}

export function useRetryFailedMessage(onSuccess?: () => void) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: number) =>
      apiClient
        .post<RetryFailedMessageResponse>(ENDPOINTS.ADMIN.FAILED_MESSAGE_RETRY(id))
        .then((r) => r.data.data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'failed-messages'] });
      onSuccess?.();
    },
  });
}

export function useDeleteFailedMessage(onSuccess?: () => void) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: number) =>
      apiClient
        .delete<DeleteFailedMessageResponse>(ENDPOINTS.ADMIN.FAILED_MESSAGE_DELETE(id))
        .then((r) => r.data.data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin', 'failed-messages'] });
      onSuccess?.();
    },
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add frontend/src/features/admin/hooks/useAdminFailedMessages.ts
git commit -m "feat(admin): add useAdminFailedMessages hook with retry/delete mutations"
```

---

### Task 5: Create FailedMessagesTable component

**Files:**
- Create: `frontend/src/features/admin/components/FailedMessagesTable.tsx`

- [ ] **Step 1: Create the component**

Create `frontend/src/features/admin/components/FailedMessagesTable.tsx`:

```typescript
import { useAdminFailedMessages, useRetryFailedMessage, useDeleteFailedMessage } from '../hooks/useAdminFailedMessages';
import { Spinner } from '../../../components/ui/Spinner';
import { EmptyState } from '../../../components/shared/EmptyState';
import type { FailedMessageResource } from '../../../api/types';

function formatDate(iso: string): string {
  return new Date(iso).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function messageTypeLabel(type: string): string {
  // Strip the leading namespace parts for display
  const parts = type.split('\\');
  return parts[parts.length - 1] ?? type;
}

export function FailedMessagesTable() {
  const { data: messages, isLoading, error } = useAdminFailedMessages();

  const retryMutation = useRetryFailedMessage(() => {
    // Toast handled by caller or inline; using a simple alert for now
  });
  const deleteMutation = useDeleteFailedMessage();

  const handleRetry = (id: number) => {
    retryMutation.mutate(id);
  };

  const handleDelete = (id: number) => {
    if (window.confirm('Delete this failed message? This action cannot be undone.')) {
      deleteMutation.mutate(id);
    }
  };

  if (isLoading) {
    return (
      <div className="flex justify-center py-12">
        <Spinner size="lg" />
      </div>
    );
  }

  if (error) {
    return (
      <EmptyState
        title="Failed to load failed messages"
        description="Could not fetch the failed message list. Please try again."
      />
    );
  }

  if (!messages || messages.length === 0) {
    return (
      <EmptyState
        title="No failed messages"
        description="All messages are processing normally."
      />
    );
  }

  return (
    <div className="overflow-x-auto rounded-lg border border-gray-200 dark:border-gray-700">
      <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead className="bg-gray-50 dark:bg-gray-800">
          <tr>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              ID
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Type
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Failed At
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Error
            </th>
            <th className="px-6 py-3 text-left text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Preview
            </th>
            <th className="px-6 py-3 text-right text-xs font-medium uppercase tracking-wider text-gray-500 dark:text-gray-400">
              Actions
            </th>
          </tr>
        </thead>
        <tbody className="divide-y divide-gray-200 bg-white dark:divide-gray-700 dark:bg-gray-900">
          {messages.map((msg) => (
            <tr
              key={msg.id}
              className="hover:bg-gray-50 dark:hover:bg-gray-800/50"
            >
              <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                {msg.attributes.messageId}
              </td>
              <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-900 dark:text-gray-100">
                {messageTypeLabel(msg.attributes.type)}
              </td>
              <td className="whitespace-nowrap px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                {formatDate(msg.attributes.failedAt)}
              </td>
              <td className="max-w-xs truncate px-6 py-4 text-sm text-red-600 dark:text-red-400">
                {msg.attributes.error}
              </td>
              <td className="max-w-md truncate px-6 py-4 text-sm text-gray-500 dark:text-gray-400">
                {msg.attributes.preview}
              </td>
              <td className="whitespace-nowrap px-6 py-4 text-right">
                <div className="flex items-center justify-end gap-2">
                  <button
                    onClick={() => handleRetry(msg.id)}
                    disabled={retryMutation.isPending}
                    className="rounded bg-blue-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    {retryMutation.isPending ? '...' : 'Retry'}
                  </button>
                  <button
                    onClick={() => handleDelete(msg.id)}
                    disabled={deleteMutation.isPending}
                    className="rounded bg-red-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-red-700 disabled:cursor-not-allowed disabled:opacity-50"
                  >
                    {deleteMutation.isPending ? '...' : 'Delete'}
                  </button>
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add frontend/src/features/admin/components/FailedMessagesTable.tsx
git commit -m "feat(admin): add FailedMessagesTable component"
```

---

### Task 6: Add Failed Messages tab to DashboardPage

**Files:**
- Modify: `frontend/src/features/admin/pages/DashboardPage.tsx`
- Test: `frontend/src/test/admin/DashboardPage.test.tsx`

- [ ] **Step 1: Import FailedMessagesTable and add tab**

In `DashboardPage.tsx`, add import:
```typescript
import { FailedMessagesTable } from '../components/FailedMessagesTable';
```

Update the `Tab` type and initial state:
```typescript
type Tab = 'overview' | 'submissions' | 'users' | 'failed-messages';
```

Update the tabs array:
```typescript
const tabs: { key: Tab; label: string }[] = [
  { key: 'overview', label: 'Overview' },
  { key: 'submissions', label: 'Submissions' },
  { key: 'users', label: 'Users' },
  { key: 'failed-messages', label: 'Failed Messages' },
];
```

Add tab content before the closing `</div>`:
```typescript
{activeTab === 'failed-messages' && (
  <div>
    <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">
      Failed Messages
    </h2>
    <FailedMessagesTable />
  </div>
)}
```

- [ ] **Step 2: Update DashboardPage test**

In `DashboardPage.test.tsx`, update the mock and add test for the new tab:

Add mock at top with other mocks:
```typescript
vi.mock('../../features/admin/components/FailedMessagesTable', () => ({
  FailedMessagesTable: () => <div data-testid="failed-messages-table">FailedMessagesTable</div>,
}));
```

Add test:
```typescript
it('shows Failed Messages tab when clicked', () => {
  render(<DashboardPage />, { wrapper: TestWrapper });

  fireEvent.click(screen.getByText('Failed Messages'));

  expect(screen.getByTestId('failed-messages-table')).toBeInTheDocument();
});
```

Update the "shows all three tabs" test to check for four tabs:
```typescript
it('shows all four tabs', () => {
  render(<DashboardPage />, { wrapper: TestWrapper });

  expect(screen.getByText('Overview')).toBeInTheDocument();
  expect(screen.getByText('Submissions')).toBeInTheDocument();
  expect(screen.getByText('Users')).toBeInTheDocument();
  expect(screen.getByText('Failed Messages')).toBeInTheDocument();
});
```

- [ ] **Step 3: Commit**

```bash
git add frontend/src/features/admin/pages/DashboardPage.tsx frontend/src/test/admin/DashboardPage.test.tsx
git commit -m "feat(admin): add Failed Messages tab to dashboard"
```

---

### Task 7: Test FailedMessagesTable component

**Files:**
- Create: `frontend/src/test/admin/FailedMessagesTable.test.tsx`

- [ ] **Step 1: Create the test file**

Create `frontend/src/test/admin/FailedMessagesTable.test.tsx`:

```typescript
import { render, screen, fireEvent } from '@testing-library/react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { FailedMessageResource } from '../../api/types';

const mockUseAdminFailedMessages = vi.fn();
const mockRetryMutation = { mutate: vi.fn(), isPending: false };
const mockDeleteMutation = { mutate: vi.fn(), isPending: false };

vi.mock('../../features/admin/hooks/useAdminFailedMessages', () => ({
  useAdminFailedMessages: () => mockUseAdminFailedMessages() as Record<string, unknown>,
  useRetryFailedMessage: () => mockRetryMutation,
  useDeleteFailedMessage: () => mockDeleteMutation,
}));

import { FailedMessagesTable } from '../../features/admin/components/FailedMessagesTable';

function createMessage(overrides: Partial<FailedMessageResource> = {}): FailedMessageResource {
  return {
    id: 1,
    type: 'failed_message',
    attributes: {
      messageId: 1,
      type: 'App\\Triage\\Application\\Message\\ProcessTriageMessage',
      failedAt: '2026-06-12T10:00:00Z',
      error: 'Connection timed out after 5 seconds',
      preview: 'Test patient needs immediate attention',
      ...overrides.attributes,
    },
    ...overrides,
  };
}

function renderComponent(): void {
  render(<FailedMessagesTable />);
}

describe('FailedMessagesTable', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders loading spinner initially', () => {
    mockUseAdminFailedMessages.mockReturnValue({ data: undefined, isLoading: true, error: null });

    renderComponent();

    const spinner = document.querySelector('.animate-spin');
    expect(spinner).toBeInTheDocument();
  });

  it('renders error EmptyState when API call fails', () => {
    mockUseAdminFailedMessages.mockReturnValue({
      data: undefined,
      isLoading: false,
      error: new Error('Network error'),
    });

    renderComponent();

    expect(screen.getByText('Failed to load failed messages')).toBeInTheDocument();
    expect(
      screen.getByText('Could not fetch the failed message list. Please try again.'),
    ).toBeInTheDocument();
  });

  it('renders empty state when no messages', () => {
    mockUseAdminFailedMessages.mockReturnValue({ data: [], isLoading: false, error: null });

    renderComponent();

    expect(screen.getByText('No failed messages')).toBeInTheDocument();
    expect(
      screen.getByText('All messages are processing normally.'),
    ).toBeInTheDocument();
  });

  it('renders message rows with type, error, preview, and action buttons', () => {
    const messages: readonly FailedMessageResource[] = [
      createMessage({
        id: 1,
        attributes: {
          messageId: 1,
          type: 'App\\Triage\\Application\\Message\\ProcessTriageMessage',
          failedAt: '2026-06-12T10:00:00Z',
          error: 'Connection timed out',
          preview: 'Test patient needs attention',
        },
      }),
      createMessage({
        id: 2,
        attributes: {
          messageId: 2,
          type: 'App\\Synthetic\\Application\\Message\\ProcessSyntheticTurnMessage',
          failedAt: '2026-06-12T11:00:00Z',
          error: 'API rate limit exceeded',
          preview: 'Synthetic case generation',
        },
      }),
    ];

    mockUseAdminFailedMessages.mockReturnValue({ data: messages, isLoading: false, error: null });

    renderComponent();

    // Check type labels (last namespace part)
    expect(screen.getByText('ProcessTriageMessage')).toBeInTheDocument();
    expect(screen.getByText('ProcessSyntheticTurnMessage')).toBeInTheDocument();

    // Check error messages
    expect(screen.getByText('Connection timed out')).toBeInTheDocument();
    expect(screen.getByText('API rate limit exceeded')).toBeInTheDocument();

    // Check previews
    expect(screen.getByText('Test patient needs attention')).toBeInTheDocument();
    expect(screen.getByText('Synthetic case generation')).toBeInTheDocument();

    // Check action buttons (Retry + Delete per row = 4 buttons)
    const retryButtons = screen.getAllByText('Retry');
    const deleteButtons = screen.getAllByText('Delete');
    expect(retryButtons).toHaveLength(2);
    expect(deleteButtons).toHaveLength(2);
  });

  it('calls retry mutation on Retry button click', () => {
    const messages: readonly FailedMessageResource[] = [createMessage()];
    mockUseAdminFailedMessages.mockReturnValue({ data: messages, isLoading: false, error: null });

    renderComponent();

    fireEvent.click(screen.getByText('Retry'));

    expect(mockRetryMutation.mutate).toHaveBeenCalledWith(1);
  });

  it('calls delete mutation on Delete button click after confirm', () => {
    const messages: readonly FailedMessageResource[] = [createMessage()];
    mockUseAdminFailedMessages.mockReturnValue({ data: messages, isLoading: false, error: null });

    // Mock window.confirm to return true
    const originalConfirm = window.confirm;
    window.confirm = vi.fn(() => true);

    renderComponent();

    fireEvent.click(screen.getByText('Delete'));

    expect(mockDeleteMutation.mutate).toHaveBeenCalledWith(1);

    window.confirm = originalConfirm;
  });

  it('does not call delete mutation on Delete button click when cancelled', () => {
    const messages: readonly FailedMessageResource[] = [createMessage()];
    mockUseAdminFailedMessages.mockReturnValue({ data: messages, isLoading: false, error: null });

    // Mock window.confirm to return false
    const originalConfirm = window.confirm;
    window.confirm = vi.fn(() => false);

    renderComponent();

    fireEvent.click(screen.getByText('Delete'));

    expect(mockDeleteMutation.mutate).not.toHaveBeenCalled();

    window.confirm = originalConfirm;
  });
});
```

- [ ] **Step 2: Run frontend tests**

Run: `cd frontend && npx vitest run src/test/admin/FailedMessagesTable.test.tsx`

Expected: All 7 tests PASS.

- [ ] **Step 3: Commit**

```bash
git add frontend/src/test/admin/FailedMessagesTable.test.tsx
git commit -m "test(admin): add FailedMessagesTable component tests"
```

---

### Task 8: Run final test suite

- [ ] **Step 1: Run full backend test suite**

Run: `cd backend && php vendor/bin/phpunit`

Expected: All tests PASS (no regressions from AdminController changes).

- [ ] **Step 2: Run full frontend test suite**

Run: `cd frontend && npx vitest run`

Expected: All tests PASS (existing tests updated, new tests green).

- [ ] **Step 3: Verify TypeScript compiles**

Run: `cd frontend && npx tsc --noEmit`

Expected: No type errors.

- [ ] **Step 4: Commit any final fixes**

```bash
git add -A
git commit -m "chore: final verification after failed messages implementation"
```
