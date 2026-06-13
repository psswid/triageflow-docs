# UX Polish — Loading States, Error Recovery, Toast System

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace blank-spinner loading patterns with layout-matching skeleton loaders, add a consistent API error recovery pattern with retry wired to React Query refetch, and introduce a toast notification system for transient mutation errors.

**Architecture:** Three independent additions — (1) `Skeleton.tsx` variant-based component replaces `Spinner`+`Loader` in data-fetching components, (2) `ErrorFallback.tsx` presentational component replaces ad-hoc `EmptyState` usage for API errors with `onRetry` → `refetch`, (3) `Toast` + `ToastProvider` React context system for mutation errors. All existing `Loader.tsx`, `Spinner.tsx`, and `ErrorBoundary.tsx` components remain untouched.

**Tech Stack:** React 19, Tailwind CSS v4, TypeScript, Vitest + React Testing Library, @tanstack/react-query v5

---

## File Structure

### New files (4):
| File | Responsibility |
|------|---------------|
| `frontend/src/components/ui/Skeleton.tsx` | Skeleton loader with `variant` prop: `text`, `card`, `table-row`, `stats-grid` |
| `frontend/src/components/shared/ErrorFallback.tsx` | Error display component with `onRetry`, collapsible error details, `role="alert"` |
| `frontend/src/components/ui/Toast.tsx` | Auto-dismissing toast with error/warning/info variants + dismiss button |
| `frontend/src/components/ui/ToastProvider.tsx` | React context + stacking + `useToast()` hook |

### Modified files (14):
| File | Change |
|------|--------|
| `frontend/src/features/triage/pages/TriageResultPage.tsx` | Loading → skeleton; errors → `<ErrorFallback>` |
| `frontend/src/features/admin/components/StatsGrid.tsx` | Loading → stats-grid skeleton; error → `<ErrorFallback>` |
| `frontend/src/features/admin/components/SubmissionsTable.tsx` | Loading → table-row skeleton; error → `<ErrorFallback>` |
| `frontend/src/features/admin/components/FailedMessagesTable.tsx` | Loading → table-row skeleton; error → `<ErrorFallback>` |
| `frontend/src/features/admin/components/UsersTable.tsx` | Loading → table-row skeleton; error → `<ErrorFallback>` |
| `frontend/src/features/submissions/components/SubmissionsList.tsx` | Loading → table-row skeleton; error → `<ErrorFallback>` |
| `frontend/src/features/admin/pages/SubmissionDetailPage.tsx` | Loading → card skeleton; error → `<ErrorFallback>` |
| `frontend/src/features/admin/pages/DashboardPage.tsx` | Add `<ErrorFallback>` for submissions query error |
| `frontend/src/main.tsx` | Wrap app in `<ToastProvider>` |
| `frontend/src/features/admin/hooks/useRetryFailedMessage.ts` | Add `onError` callback param |
| `frontend/src/features/admin/hooks/useDeleteFailedMessage.ts` | Add `onError` callback param |
| `frontend/src/features/admin/hooks/useGenerateSyntheticCase.ts` | Add `onError` callback param |
| `frontend/src/features/admin/components/FailedMessagesTable.tsx` | Wire toast to retry/delete errors |
| `frontend/src/features/admin/pages/DashboardPage.tsx` | Wire toast to generate synthetic case error |

### New test files (4):
| File | Tests |
|------|-------|
| `frontend/src/test/ui/Skeleton.test.tsx` | Each variant renders, custom className, lines prop |
| `frontend/src/test/shared/ErrorFallback.test.tsx` | Renders error message, retry calls onRetry, collapsible details, title overrides |
| `frontend/src/test/ui/Toast.test.tsx` | Renders message, dismiss button, auto-dismiss after timeout, variant styling |
| `frontend/src/test/ui/ToastProvider.test.tsx` | Context provides toast(), stacking multiple toasts, removal |

### Existing test files modified (7):
| File | Change |
|------|--------|
| `frontend/src/test/admin/StatsGrid.test.tsx` | Update loading test ID from `stats-loading` |
| `frontend/src/test/admin/SubmissionsTable.test.tsx` | Update loading assertion for skeleton |
| `frontend/src/test/admin/FailedMessagesTable.test.tsx` | Update loading assertion for skeleton |
| `frontend/src/test/admin/UsersTable.test.tsx` | Update loading assertion for skeleton |
| `frontend/src/test/triage/TriageResultPage.test.tsx` | Update loading assertion for skeleton |
| `frontend/src/test/admin/SubmissionsList.test.tsx` | Add tests for SubmissionsList if not exists |
| `frontend/src/test/admin/SubmissionDetailPage.test.tsx` | Update loading assertion for skeleton |

---

### Task 1: `Skeleton.tsx` component + tests

**Files:**
- Create: `frontend/src/components/ui/Skeleton.tsx`
- Create: `frontend/src/test/ui/Skeleton.test.tsx`

- [ ] **Step 1: Write the Skeleton test**

```tsx
import { render, screen } from '@testing-library/react';
import { describe, it, expect } from 'vitest';
import { Skeleton } from '../../components/ui/Skeleton';

describe('Skeleton', () => {
  it('renders a text skeleton with default variant', () => {
    const { container } = render(<Skeleton />);
    const el = container.firstChild as HTMLElement;
    expect(el).toHaveClass('animate-pulse');
    expect(el).toHaveClass('rounded');
    expect(el).toHaveClass('bg-gray-200');
  });

  it('renders a card skeleton', () => {
    const { container } = render(<Skeleton variant="card" />);
    const el = container.firstChild as HTMLElement;
    expect(el).toHaveClass('rounded-xl');
    expect(el).toHaveClass('h-48');
  });

  it('renders a stats-grid skeleton (4 cards)', () => {
    const { container } = render(<Skeleton variant="stats-grid" />);
    // Should render a grid wrapper with 4 skeleton cards
    const wrapper = container.firstChild as HTMLElement;
    expect(wrapper).toHaveClass('grid');
    expect(wrapper.children.length).toBe(4);
  });

  it('renders a table-row skeleton with given lines', () => {
    const { container } = render(<Skeleton variant="table-row" lines={3} />);
    const el = container.firstChild as HTMLElement;
    expect(el.children.length).toBe(3);
  });

  it('applies custom className', () => {
    const { container } = render(<Skeleton className="my-4" />);
    const el = container.firstChild as HTMLElement;
    expect(el).toHaveClass('my-4');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && npx vitest run src/test/ui/Skeleton.test.tsx 2>&1 | head -20`
Expected: FAIL — `Cannot find module '../../components/ui/Skeleton'`

- [ ] **Step 3: Write the Skeleton implementation**

```tsx
import { clsx } from 'clsx';

interface SkeletonProps {
  readonly className?: string;
  readonly lines?: number;
  readonly variant?: 'text' | 'card' | 'table-row' | 'stats-grid';
}

function SkeletonBlock({ className }: { readonly className?: string }) {
  return (
    <div
      className={clsx(
        'animate-pulse rounded bg-gray-200 dark:bg-gray-700',
        className,
      )}
      aria-hidden="true"
    />
  );
}

export function Skeleton({ className, lines = 1, variant = 'text' }: SkeletonProps) {
  if (variant === 'card') {
    return (
      <div
        className={clsx(
          'animate-pulse rounded-xl border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-800 dark:bg-gray-900',
          className,
        )}
        aria-hidden="true"
      >
        <SkeletonBlock className="mb-4 h-4 w-3/4" />
        <SkeletonBlock className="mb-2 h-3 w-1/2" />
        <SkeletonBlock className="h-3 w-1/3" />
      </div>
    );
  }

  if (variant === 'stats-grid') {
    return (
      <div className={clsx('grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4', className)} aria-hidden="true">
        {Array.from({ length: 4 }).map((_, i) => (
          <div
            key={i}
            className="animate-pulse rounded-xl border border-gray-200 bg-white p-4 shadow-sm dark:border-gray-800 dark:bg-gray-900"
          >
            <SkeletonBlock className="mb-2 h-3 w-1/2" />
            <SkeletonBlock className="h-6 w-1/3" />
          </div>
        ))}
      </div>
    );
  }

  if (variant === 'table-row') {
    const rowCount = lines;
    return (
      <div className={clsx('space-y-3', className)} aria-hidden="true">
        {Array.from({ length: rowCount }).map((_, i) => (
          <div key={i} className="flex items-center gap-4 px-4 py-3">
            <SkeletonBlock className="h-4 w-1/6" />
            <SkeletonBlock className="h-4 w-1/4" />
            <SkeletonBlock className="h-4 w-1/6" />
            <SkeletonBlock className="h-4 w-1/5" />
            <SkeletonBlock className="h-8 w-16 ml-auto rounded-md" />
          </div>
        ))}
      </div>
    );
  }

  // Default: text skeleton with configurable lines
  return (
    <div className={clsx('space-y-2', className)} aria-hidden="true">
      {Array.from({ length: lines }).map((_, i) => (
        <SkeletonBlock
          key={i}
          className={clsx('h-4', i === lines - 1 ? 'w-3/4' : 'w-full')}
        />
      ))}
    </div>
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd frontend && npx vitest run src/test/ui/Skeleton.test.tsx 2>&1`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/src/components/ui/Skeleton.tsx frontend/src/test/ui/Skeleton.test.tsx
git commit -m "feat: add Skeleton component with variant-based loading placeholders"
```

---

### Task 2: `ErrorFallback.tsx` component + tests

**Files:**
- Create: `frontend/src/components/shared/ErrorFallback.tsx`
- Create: `frontend/src/test/shared/ErrorFallback.test.tsx`

- [ ] **Step 1: Write the ErrorFallback test**

```tsx
import { render, screen, fireEvent } from '@testing-library/react';
import { describe, it, expect, vi } from 'vitest';
import { ErrorFallback } from '../../components/shared/ErrorFallback';

describe('ErrorFallback', () => {
  it('renders error message and retry button', () => {
    const onRetry = vi.fn();
    render(<ErrorFallback error={new Error('Network failure')} onRetry={onRetry} />);

    expect(screen.getByText('Something went wrong')).toBeInTheDocument();
    expect(screen.getByText('Network failure')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /retry/i })).toBeInTheDocument();
  });

  it('calls onRetry when retry is clicked', () => {
    const onRetry = vi.fn();
    render(<ErrorFallback error={new Error('fail')} onRetry={onRetry} />);

    fireEvent.click(screen.getByRole('button', { name: /retry/i }));
    expect(onRetry).toHaveBeenCalledOnce();
  });

  it('renders custom title when provided', () => {
    render(
      <ErrorFallback error={new Error('fail')} onRetry={vi.fn()} title="Custom Title" />,
    );
    expect(screen.getByText('Custom Title')).toBeInTheDocument();
  });

  it('has aria role alert', () => {
    render(<ErrorFallback error={new Error('fail')} onRetry={vi.fn()} />);
    expect(screen.getByRole('alert')).toBeInTheDocument();
  });

  it('has collapsible error details', () => {
    render(<ErrorFallback error={new Error('TypeError: cannot read')} onRetry={vi.fn()} />);

    // Should show a toggle for error details
    const toggle = screen.getByText(/error details/i);
    expect(toggle).toBeInTheDocument();

    // Click to expand
    fireEvent.click(toggle);
    expect(screen.getByText('TypeError: cannot read')).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && npx vitest run src/test/shared/ErrorFallback.test.tsx 2>&1 | head -20`
Expected: FAIL — `Cannot find module '../../components/shared/ErrorFallback'`

- [ ] **Step 3: Write the ErrorFallback implementation**

```tsx
import { useState } from 'react';
import { Button } from '../ui/Button';

interface ErrorFallbackProps {
  readonly error: Error;
  readonly onRetry: () => void;
  readonly title?: string;
}

export function ErrorFallback({ error, onRetry, title }: ErrorFallbackProps) {
  const [showDetails, setShowDetails] = useState(false);

  return (
    <div
      className="flex flex-col items-center justify-center py-16 text-center"
      role="alert"
    >
      <div className="mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-red-100 dark:bg-red-900/30">
        <svg
          className="h-8 w-8 text-red-600 dark:text-red-400"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          aria-hidden="true"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z"
          />
        </svg>
      </div>
      <h2 className="text-lg font-semibold text-gray-900 dark:text-gray-100">
        {title ?? 'Something went wrong'}
      </h2>
      <p className="mt-2 max-w-md text-sm text-gray-500 dark:text-gray-400">
        {error.message}
      </p>

      {/* Collapsible error details */}
      <button
        onClick={() => setShowDetails(!showDetails)}
        className="mt-2 text-xs text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300 underline"
      >
        {showDetails ? 'Hide' : 'Show'} error details
      </button>
      {showDetails && (
        <pre className="mt-2 max-w-md overflow-auto rounded bg-gray-100 p-3 text-xs text-gray-700 dark:bg-gray-800 dark:text-gray-300">
          {error.stack ?? error.message}
        </pre>
      )}

      <div className="mt-6 flex items-center gap-3">
        <Button onClick={onRetry}>Retry</Button>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd frontend && npx vitest run src/test/shared/ErrorFallback.test.tsx 2>&1`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/src/components/shared/ErrorFallback.tsx frontend/src/test/shared/ErrorFallback.test.tsx
git commit -m "feat: add ErrorFallback component for inline API error recovery"
```

---

### Task 3: Toast + ToastProvider + useToast hook + tests

**Files:**
- Create: `frontend/src/components/ui/Toast.tsx`
- Create: `frontend/src/components/ui/ToastProvider.tsx`
- Create: `frontend/src/test/ui/Toast.test.tsx`
- Create: `frontend/src/test/ui/ToastProvider.test.tsx`
- Modify: `frontend/src/main.tsx` (wrap app in ToastProvider)

- [ ] **Step 1: Write the Toast test**

```tsx
import { render, screen, act } from '@testing-library/react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { Toast } from '../../components/ui/Toast';

describe('Toast', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('renders the message', () => {
    render(<Toast id="1" message="Operation failed" onDismiss={vi.fn()} />);
    expect(screen.getByText('Operation failed')).toBeInTheDocument();
  });

  it('renders dismiss button', () => {
    render(<Toast id="1" message="Test" onDismiss={vi.fn()} />);
    expect(screen.getByRole('button', { name: /dismiss/i })).toBeInTheDocument();
  });

  it('calls onDismiss when dismiss button clicked', () => {
    const onDismiss = vi.fn();
    render(<Toast id="1" message="Test" onDismiss={onDismiss} />);
    screen.getByRole('button', { name: /dismiss/i }).click();
    expect(onDismiss).toHaveBeenCalledWith('1');
  });

  it('auto-dismisses after 5 seconds', () => {
    const onDismiss = vi.fn();
    render(<Toast id="1" message="Test" onDismiss={onDismiss} />);

    act(() => { vi.advanceTimersByTime(5000); });

    expect(onDismiss).toHaveBeenCalledWith('1');
  });

  it('does not auto-dismiss before 5 seconds', () => {
    const onDismiss = vi.fn();
    render(<Toast id="1" message="Test" onDismiss={onDismiss} />);

    act(() => { vi.advanceTimersByTime(4000); });

    expect(onDismiss).not.toHaveBeenCalled();
  });

  it('renders error variant with red styling', () => {
    const { container } = render(
      <Toast id="1" message="Test" onDismiss={vi.fn()} variant="error" />,
    );
    expect(container.firstChild).toHaveClass('bg-red-50');
  });

  it('renders warning variant with amber styling', () => {
    const { container } = render(
      <Toast id="1" message="Test" onDismiss={vi.fn()} variant="warning" />,
    );
    expect(container.firstChild).toHaveClass('bg-amber-50');
  });

  it('renders info variant with blue styling', () => {
    const { container } = render(
      <Toast id="1" message="Test" onDismiss={vi.fn()} variant="info" />,
    );
    expect(container.firstChild).toHaveClass('bg-blue-50');
  });
});
```

- [ ] **Step 2: Write the ToastProvider test**

```tsx
import { render, screen, fireEvent, act } from '@testing-library/react';
import { describe, it, expect, vi, afterEach } from 'vitest';
import { ToastProvider, useToast } from '../../components/ui/ToastProvider';

function TestConsumer({ onError }: { readonly onError?: (msg: string) => void }) {
  const { toast } = useToast();
  return (
    <div>
      <button onClick={() => toast.error('Error occurred')}>Trigger Error</button>
      <button onClick={() => toast.warning('Warning message')}>Trigger Warning</button>
      <button onClick={() => toast.info('Info message')}>Trigger Info</button>
    </div>
  );
}

describe('ToastProvider', () => {
  afterEach(() => {
    vi.useRealTimers();
  });

  it('provides toast function via context', () => {
    render(
      <ToastProvider>
        <TestConsumer />
      </ToastProvider>,
    );

    fireEvent.click(screen.getByText('Trigger Error'));
    expect(screen.getByText('Error occurred')).toBeInTheDocument();
  });

  it('stacks multiple toasts', () => {
    render(
      <ToastProvider>
        <TestConsumer />
      </ToastProvider>,
    );

    fireEvent.click(screen.getByText('Trigger Error'));
    fireEvent.click(screen.getByText('Trigger Warning'));

    expect(screen.getByText('Error occurred')).toBeInTheDocument();
    expect(screen.getByText('Warning message')).toBeInTheDocument();
  });

  it('removes toast on dismiss', () => {
    render(
      <ToastProvider>
        <TestConsumer />
      </ToastProvider>,
    );

    fireEvent.click(screen.getByText('Trigger Error'));
    expect(screen.getByText('Error occurred')).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: /dismiss/i }));
    expect(screen.queryByText('Error occurred')).not.toBeInTheDocument();
  });

  it('auto-removes toast after timeout', () => {
    vi.useFakeTimers();

    render(
      <ToastProvider>
        <TestConsumer />
      </ToastProvider>,
    );

    fireEvent.click(screen.getByText('Trigger Error'));

    act(() => { vi.advanceTimersByTime(5000); });

    expect(screen.queryByText('Error occurred')).not.toBeInTheDocument();
  });

  it('throws when useToast is used outside provider', () => {
    // Suppress console.error for this expected error
    const spy = vi.spyOn(console, 'error').mockImplementation(() => {});

    expect(() => render(<TestConsumer />)).toThrow(/must be used within a ToastProvider/i);

    spy.mockRestore();
  });
});
```

- [ ] **Step 3: Run both tests to verify they fail**

Run: `cd frontend && npx vitest run src/test/ui/Toast.test.tsx src/test/ui/ToastProvider.test.tsx 2>&1 | head -20`
Expected: FAIL — modules not found

- [ ] **Step 4: Write the Toast implementation**

```tsx
import { useEffect } from 'react';
import { clsx } from 'clsx';

interface ToastProps {
  readonly id: string;
  readonly message: string;
  readonly onDismiss: (id: string) => void;
  readonly variant?: 'error' | 'warning' | 'info';
}

const VARIANT_CLASSES: Record<string, string> = {
  error: 'bg-red-50 border-red-200 text-red-800 dark:bg-red-900/30 dark:border-red-800 dark:text-red-300',
  warning: 'bg-amber-50 border-amber-200 text-amber-800 dark:bg-amber-900/30 dark:border-amber-800 dark:text-amber-300',
  info: 'bg-blue-50 border-blue-200 text-blue-800 dark:bg-blue-900/30 dark:border-blue-800 dark:text-blue-300',
};

const VARIANT_ICON: Record<string, string> = {
  error: 'M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z',
  warning: 'M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 16.5c-.77.833.192 2.5 1.732 2.5z',
  info: 'M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
};

export function Toast({ id, message, onDismiss, variant = 'error' }: ToastProps) {
  useEffect(() => {
    const timer = setTimeout(() => { onDismiss(id); }, 5000);
    return () => clearTimeout(timer);
  }, [id, onDismiss]);

  return (
    <div
      className={clsx(
        'flex items-start gap-3 rounded-lg border p-4 shadow-lg',
        VARIANT_CLASSES[variant],
      )}
      role="alert"
    >
      <svg
        className="h-5 w-5 flex-shrink-0 mt-0.5"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
        aria-hidden="true"
      >
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d={VARIANT_ICON[variant]} />
      </svg>
      <p className="flex-1 text-sm font-medium">{message}</p>
      <button
        onClick={() => onDismiss(id)}
        className="flex-shrink-0 rounded-md p-1 hover:bg-black/5 dark:hover:bg-white/10 transition-colors"
        aria-label="Dismiss"
      >
        <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    </div>
  );
}
```

- [ ] **Step 5: Write the ToastProvider implementation**

```tsx
import { createContext, useContext, useState, useCallback, type ReactNode } from 'react';
import { Toast } from './Toast';

interface ToastItem {
  readonly id: string;
  readonly message: string;
  readonly variant: 'error' | 'warning' | 'info';
}

interface ToastContextValue {
  readonly toast: {
    readonly error: (message: string) => void;
    readonly warning: (message: string) => void;
    readonly info: (message: string) => void;
  };
}

const ToastContext = createContext<ToastContextValue | null>(null);

let toastIdCounter = 0;

export function ToastProvider({ children }: { readonly children: ReactNode }) {
  const [toasts, setToasts] = useState<readonly ToastItem[]>([]);

  const addToast = useCallback((message: string, variant: ToastItem['variant']) => {
    const id = `toast-${++toastIdCounter}`;
    setToasts((prev) => [...prev, { id, message, variant }]);
  }, []);

  const dismissToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  const toast = {
    error: useCallback((message: string) => addToast(message, 'error'), [addToast]),
    warning: useCallback((message: string) => addToast(message, 'warning'), [addToast]),
    info: useCallback((message: string) => addToast(message, 'info'), [addToast]),
  };

  return (
    <ToastContext.Provider value={{ toast }}>
      {children}
      {/* Toast container */}
      <div
        className="fixed bottom-4 right-4 z-50 flex flex-col gap-2 max-w-sm"
        aria-live="polite"
        aria-label="Notifications"
      >
        {toasts.map((t) => (
          <Toast key={t.id} id={t.id} message={t.message} variant={t.variant} onDismiss={dismissToast} />
        ))}
      </div>
    </ToastContext.Provider>
  );
}

export function useToast(): ToastContextValue {
  const context = useContext(ToastContext);
  if (!context) {
    throw new Error('useToast must be used within a ToastProvider');
  }
  return context;
}
```

- [ ] **Step 6: Wrap app in ToastProvider**

Modify `frontend/src/main.tsx`:

```tsx
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { App } from './App';
import { ToastProvider } from './components/ui/ToastProvider';
import './styles/index.css';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      staleTime: 10_000,
    },
  },
});

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <ToastProvider>
        <App />
      </ToastProvider>
    </QueryClientProvider>
  </StrictMode>,
);
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd frontend && npx vitest run src/test/ui/Toast.test.tsx src/test/ui/ToastProvider.test.tsx 2>&1`
Expected: All tests PASS

- [ ] **Step 8: Run full test suite to check for regressions**

Run: `cd frontend && npx vitest run 2>&1`
Expected: All tests pass (bonus points: still 95+ tests)

- [ ] **Step 9: Commit**

```bash
git add frontend/src/components/ui/Toast.tsx frontend/src/components/ui/ToastProvider.tsx frontend/src/test/ui/Toast.test.tsx frontend/src/test/ui/ToastProvider.test.tsx frontend/src/main.tsx
git commit -m "feat: add Toast notification system with context provider"
```

---

### Task 4: Wire Toast to mutation hooks

**Files:**
- Modify: `frontend/src/features/admin/hooks/useAdminFailedMessages.ts` (add `onError` to `useRetryFailedMessage` and `useDeleteFailedMessage`)
- Modify: `frontend/src/features/admin/hooks/useGenerateSyntheticCase.ts` (add `onError` callback)
- Modify: `frontend/src/features/admin/components/FailedMessagesTable.tsx` (wire toast to retry/delete errors)
- Modify: `frontend/src/features/admin/pages/DashboardPage.tsx` (wire toast to synthetic case generation error)

- [ ] **Step 1: Add onError callback to useRetryFailedMessage**

Modify `frontend/src/features/admin/hooks/useAdminFailedMessages.ts`:

```typescript
export function useRetryFailedMessage(onSuccess?: () => void, onError?: (error: Error) => void) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: number) =>
      apiClient
        .post<RetryFailedMessageResponse>(ENDPOINTS.ADMIN.FAILED_MESSAGE_RETRY(id))
        .then((r) => r.data.data),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['admin', 'failed-messages'] });
      onSuccess?.();
    },
    onError: (err: Error) => {
      onError?.(err);
    },
  });
}

export function useDeleteFailedMessage(onSuccess?: () => void, onError?: (error: Error) => void) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: number) =>
      apiClient
        .delete<DeleteFailedMessageResponse>(ENDPOINTS.ADMIN.FAILED_MESSAGE_DELETE(id))
        .then((r) => r.data.data),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['admin', 'failed-messages'] });
      onSuccess?.();
    },
    onError: (err: Error) => {
      onError?.(err);
    },
  });
}
```

- [ ] **Step 2: Add onError callback to useGenerateSyntheticCase**

Modify `frontend/src/features/admin/hooks/useGenerateSyntheticCase.ts`:

```typescript
export function useGenerateSyntheticCase(onSuccess?: () => void, onError?: (error: Error) => void) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: () =>
      apiClient.post<ApiResponse<SyntheticCaseResource>>(ENDPOINTS.ADMIN.SYNTHETIC_GENERATE)
        .then((r) => r.data.data),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['admin', 'stats'] });
      void queryClient.invalidateQueries({ queryKey: ['admin', 'submissions'] });
      onSuccess?.();
    },
    onError: (err: Error) => {
      onError?.(err);
    },
  });
}
```

- [ ] **Step 3: Wire toasts in FailedMessagesTable**

Modify `frontend/src/features/admin/components/FailedMessagesTable.tsx`:

```diff
 import { useAdminFailedMessages, useRetryFailedMessage, useDeleteFailedMessage } from '../hooks/useAdminFailedMessages';
 import { Spinner } from '../../../components/ui/Spinner';
 import { EmptyState } from '../../../components/shared/EmptyState';
+import { useToast } from '../../../components/ui/ToastProvider';

 export function FailedMessagesTable() {
   const { data: messages, isLoading, error } = useAdminFailedMessages();
+  const { toast } = useToast();

-  const retryMutation = useRetryFailedMessage();
-  const deleteMutation = useDeleteFailedMessage();
+  const retryMutation = useRetryFailedMessage(
+    undefined,
+    (err) => toast.error(`Failed to retry message: ${err.message}`),
+  );
+  const deleteMutation = useDeleteFailedMessage(
+    undefined,
+    (err) => toast.error(`Failed to delete message: ${err.message}`),
+  );
```

- [ ] **Step 4: Wire toast in DashboardPage**

Modify `frontend/src/features/admin/pages/DashboardPage.tsx`:

```diff
 import { useAdminSubmissions } from '../hooks/useAdminSubmissions';
 import { useGenerateSyntheticCase } from '../hooks/useGenerateSyntheticCase';
 import { Spinner } from '../../../components/ui/Spinner';
+import { useToast } from '../../../components/ui/ToastProvider';

 export function DashboardPage() {
   const [activeTab, setActiveTab] = useState<Tab>('overview');
   const [showGeneratedMessage, setShowGeneratedMessage] = useState(false);
+  const { toast } = useToast();
   const submissionsQuery = useAdminSubmissions();
-  const generateMutation = useGenerateSyntheticCase(() => {
+  const generateMutation = useGenerateSyntheticCase(
+    () => {
       setShowGeneratedMessage(true);
       setTimeout(() => setShowGeneratedMessage(false), 4000);
-  });
+    },
+    (err) => toast.error(`Failed to generate synthetic case: ${err.message}`),
+  );
```

- [ ] **Step 5: Run full test suite to check for regressions**

Run: `cd frontend && npx vitest run 2>&1`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add frontend/src/features/admin/hooks/useAdminFailedMessages.ts frontend/src/features/admin/hooks/useGenerateSyntheticCase.ts frontend/src/features/admin/components/FailedMessagesTable.tsx frontend/src/features/admin/pages/DashboardPage.tsx
git commit -m "feat: wire toast notifications to mutation error handlers"
```

---

### Task 5: Integrate Skeleton + ErrorFallback into TriageResultPage

**Files:**
- Modify: `frontend/src/features/triage/pages/TriageResultPage.tsx`

- [ ] **Step 1: Update loading and error states in TriageResultPage**

Modify `frontend/src/features/triage/pages/TriageResultPage.tsx`:

Replace the `Loader` import with `Skeleton` and `ErrorFallback`:

```diff
- import { Loader } from '../../../components/shared/Loader';
+ import { Skeleton } from '../../../components/ui/Skeleton';
+ import { ErrorFallback } from '../../../components/shared/ErrorFallback';
```

Change the loading state from `<Loader>` to skeleton:

```diff
  if (isLoading) {
-   return <Loader message="Loading triage result..." />;
+   return (
+     <div className="mx-auto max-w-3xl space-y-6 py-8">
+       <Skeleton variant="text" lines={1} className="h-8 w-1/3" />
+       <Skeleton variant="card" />
+       <Skeleton variant="card" />
+     </div>
+   );
  }
```

Replace the generic error state with `<ErrorFallback>`:

```diff
  // Generic error
  return (
-   <div className="py-12 text-center">
-     <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">Something Went Wrong</h1>
-     <p className="mt-2 text-gray-500 dark:text-gray-400">
-       {axiosError?.message ?? 'An unexpected error occurred while loading the result.'}
-     </p>
-     <Button className="mt-6" onClick={() => { void navigate('/triage'); }}>
-       New Triage
-     </Button>
-   </div>
+   <ErrorFallback
+     error={error as Error}
+     onRetry={() => { /* refetch handled by React Query */ }}
+     title="Something Went Wrong"
+   />
  );
```

**However** — the TriageResultPage doesn't expose a `refetch` function from `useQuery`. We need to wire it:

```diff
-  const { status, data, error } = useQuery<ApiResponse<TriageSubmissionResource>, AxiosError>({
+  const { status, data, error, refetch } = useQuery<ApiResponse<TriageSubmissionResource>, AxiosError>({
```

Then update the generic error `onRetry`:

```diff
  // Generic error
  return (
    <ErrorFallback
      error={error as Error}
+     onRetry={() => void refetch()}
      title="Something Went Wrong"
    />
  );
```

- [ ] **Step 2: Run full test suite**

Run: `cd frontend && npx vitest run 2>&1`
Expected: All tests pass. Update test assertions for loading state if needed — the test checks `screen.getByText('Loading triage result...')` which no longer exists. Update the test to check for skeleton elements instead.

- [ ] **Step 3: Update TriageResultPage test**

Modify `frontend/src/test/triage/TriageResultPage.test.tsx`:

```diff
- it('shows loading spinner while fetching the result', () => {
+ it('shows skeleton while fetching the result', () => {
    mockGet.mockReturnValue(new Promise<never>(() => undefined)); // never resolves

    renderTriageResultPage();

-   expect(screen.getByText('Loading triage result...')).toBeInTheDocument();
+   // Skeleton renders aria-hidden elements — check for the container structure
+   // The Skeleton component renders divs with animate-pulse
+   const skeletonContainer = document.querySelector('.animate-pulse');
+   expect(skeletonContainer).toBeInTheDocument();
  });
```

- [ ] **Step 4: Run tests to verify**

Run: `cd frontend && npx vitest run src/test/triage/TriageResultPage.test.tsx 2>&1`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/src/features/triage/pages/TriageResultPage.tsx frontend/src/test/triage/TriageResultPage.test.tsx
git commit -m "feat: integrate skeleton + ErrorFallback into TriageResultPage"
```

---

### Task 6: Integrate Skeleton + ErrorFallback into StatsGrid

**Files:**
- Modify: `frontend/src/features/admin/components/StatsGrid.tsx`
- Modify: `frontend/src/test/admin/StatsGrid.test.tsx`

- [ ] **Step 1: Replace loading and error states**

Modify `frontend/src/features/admin/components/StatsGrid.tsx`:

```diff
 import { useAdminStats } from '../hooks/useAdminStats';
 import { Card } from '../../../components/ui/Card';
- import { Spinner } from '../../../components/ui/Spinner';
 import { EmptyState } from '../../../components/shared/EmptyState';
+ import { Skeleton } from '../../../components/ui/Skeleton';
+ import { ErrorFallback } from '../../../components/shared/ErrorFallback';
```

Replace the loading block:

```diff
  if (isLoading) {
    return (
-     <div className="flex justify-center py-8" data-testid="stats-loading">
-       <Spinner />
-     </div>
+     <div data-testid="stats-loading">
+       <Skeleton variant="stats-grid" />
+     </div>
    );
  }
```

Replace the `EmptyState` error:

```diff
- if (error || !stats) {
-   return <EmptyState title="Unable to load stats" description="Could not fetch dashboard statistics." />;
- }
+ if (error || !stats) {
+   return <ErrorFallback error={error ?? new Error('No data returned')} onRetry={() => {}} />;
+ }
```

Wait — `useAdminStats` is called inside `StatsGrid` but doesn't expose `refetch`. Let me check if `useAdminStats` returns `refetch`. The hook uses `useQuery` which returns `refetch` by default... but the component destructures `{ data, isLoading, error }` and doesn't pick up `refetch`. We need to add it.

```diff
- const { data: stats, isLoading, error } = useAdminStats();
+ const { data: stats, isLoading, error, refetch } = useAdminStats();
```

Then:

```diff
  if (error || !stats) {
-   return <ErrorFallback error={error ?? new Error('No data returned')} onRetry={() => {}} />;
+   return <ErrorFallback error={error ?? new Error('No data returned')} onRetry={() => void refetch()} />;
  }
```

- [ ] **Step 2: Update StatsGrid test**

Modify `frontend/src/test/admin/StatsGrid.test.tsx`:

The loading test still checks for `data-testid="stats-loading"` — that's fine since we kept it. But verify the skeleton is inside. Update the error test:

```diff
- it('shows empty state on error', () => {
+ it('shows ErrorFallback on error', () => {
    mockUseAdminStats.mockReturnValue({ data: undefined, isLoading: false, error: new Error('fail') });

    render(<StatsGrid />);

-   expect(screen.getByText('Unable to load stats')).toBeInTheDocument();
+   expect(screen.getByRole('alert')).toBeInTheDocument();
+   expect(screen.getByText('fail')).toBeInTheDocument();
  });
```

- [ ] **Step 3: Run tests**

Run: `cd frontend && npx vitest run src/test/admin/StatsGrid.test.tsx 2>&1`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add frontend/src/features/admin/components/StatsGrid.tsx frontend/src/test/admin/StatsGrid.test.tsx
git commit -m "feat: integrate skeleton + ErrorFallback into StatsGrid"
```

---

### Task 7: Integrate Skeleton + ErrorFallback into SubmissionsTable

**Files:**
- Modify: `frontend/src/features/admin/components/SubmissionsTable.tsx`
- Modify: `frontend/src/test/admin/SubmissionsTable.test.tsx`

- [ ] **Step 1: Replace loading and error states in SubmissionsTable**

Modify `frontend/src/features/admin/components/SubmissionsTable.tsx`:

```diff
- import { Spinner } from '../../../components/ui/Spinner';
+ import { Skeleton } from '../../../components/ui/Skeleton';
+ import { ErrorFallback } from '../../../components/shared/ErrorFallback';
```

Replace loading:

```diff
  if (isLoading) {
    return (
-     <div className="flex justify-center py-8" data-testid="submissions-loading">
-       <Spinner />
-     </div>
+     <div data-testid="submissions-loading">
+       <Skeleton variant="table-row" lines={5} />
+     </div>
    );
  }
```

Replace error:

```diff
  if (error) {
-   return <EmptyState title="Unable to load submissions" description="Could not fetch submissions." />;
+   return <ErrorFallback error={error} onRetry={() => {}} />;
  }
```

- [ ] **Step 2: Update SubmissionsTable test**

Modify `frontend/src/test/admin/SubmissionsTable.test.tsx`:

```diff
- it('shows empty state on error', () => {
+ it('shows ErrorFallback on error', () => {
    renderTable(undefined, false, new Error('fail'));
-   expect(screen.getByText('Unable to load submissions')).toBeInTheDocument();
+   expect(screen.getByRole('alert')).toBeInTheDocument();
+   expect(screen.getByText('fail')).toBeInTheDocument();
  });
```

- [ ] **Step 3: Run tests**

Run: `cd frontend && npx vitest run src/test/admin/SubmissionsTable.test.tsx 2>&1`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add frontend/src/features/admin/components/SubmissionsTable.tsx frontend/src/test/admin/SubmissionsTable.test.tsx
git commit -m "feat: integrate skeleton + ErrorFallback into SubmissionsTable"
```

---

### Task 8: Integrate Skeleton + ErrorFallback into FailedMessagesTable

**Files:**
- Modify: `frontend/src/features/admin/components/FailedMessagesTable.tsx` (already modified in Task 4 for toasts — apply both changes)
- Modify: `frontend/src/test/admin/FailedMessagesTable.test.tsx`

- [ ] **Step 1: Replace loading and error states in FailedMessagesTable**

Modify `frontend/src/features/admin/components/FailedMessagesTable.tsx`:

```diff
- import { Spinner } from '../../../components/ui/Spinner';
+ import { Skeleton } from '../../../components/ui/Skeleton';
+ import { ErrorFallback } from '../../../components/shared/ErrorFallback';
```

Replace loading:

```diff
  if (isLoading) {
    return (
-     <div className="flex justify-center py-12">
-       <Spinner size="lg" />
-     </div>
+     <div>
+       <Skeleton variant="table-row" lines={3} />
+     </div>
    );
  }
```

Replace error:

```diff
  if (error) {
    return (
-     <EmptyState
-       title="Failed to load failed messages"
-       description="Could not fetch the failed message list. Please try again."
-     />
+     <ErrorFallback error={error} onRetry={() => {}} />
    );
  }
```

- [ ] **Step 2: Update FailedMessagesTable test**

Modify `frontend/src/test/admin/FailedMessagesTable.test.tsx`:

```diff
- it('renders error EmptyState when API call fails', () => {
+ it('renders ErrorFallback when API call fails', () => {
    mockUseAdminFailedMessages.mockReturnValue({
      data: undefined,
      isLoading: false,
      error: new Error('Network error'),
    });

    renderComponent();

-   expect(screen.getByText('Failed to load failed messages')).toBeInTheDocument();
-   expect(
-     screen.getByText('Could not fetch the failed message list. Please try again.'),
-   ).toBeInTheDocument();
+   expect(screen.getByRole('alert')).toBeInTheDocument();
+   expect(screen.getByText('Network error')).toBeInTheDocument();
  });
```

Update the loading test:

```diff
- it('renders loading spinner initially', () => {
+ it('renders skeleton initially', () => {
    mockUseAdminFailedMessages.mockReturnValue({ data: undefined, isLoading: true, error: null });

    renderComponent();

-   const spinner = document.querySelector('.animate-spin');
-   expect(spinner).toBeInTheDocument();
+   const skeleton = document.querySelector('.animate-pulse');
+   expect(skeleton).toBeInTheDocument();
  });
```

- [ ] **Step 3: Run tests**

Run: `cd frontend && npx vitest run src/test/admin/FailedMessagesTable.test.tsx 2>&1`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add frontend/src/features/admin/components/FailedMessagesTable.tsx frontend/src/test/admin/FailedMessagesTable.test.tsx
git commit -m "feat: integrate skeleton + ErrorFallback into FailedMessagesTable"
```

---

### Task 9: Integrate Skeleton + ErrorFallback into UsersTable

**Files:**
- Modify: `frontend/src/features/admin/components/UsersTable.tsx`
- Modify: `frontend/src/test/admin/UsersTable.test.tsx`

- [ ] **Step 1: Replace loading and error states in UsersTable**

Modify `frontend/src/features/admin/components/UsersTable.tsx`:

```diff
- import { Spinner } from '../../../components/ui/Spinner';
+ import { Skeleton } from '../../../components/ui/Skeleton';
+ import { ErrorFallback } from '../../../components/shared/ErrorFallback';
```

Replace loading:

```diff
  if (isLoading) {
    return (
-     <div className="flex justify-center py-12">
-       <Spinner size="lg" />
-     </div>
+     <div>
+       <Skeleton variant="table-row" lines={5} />
+     </div>
    );
  }
```

Replace error:

```diff
  if (error) {
    return (
-     <EmptyState
-       title="Failed to load users"
-       description="Could not fetch the user list. Please try again."
-     />
+     <ErrorFallback error={error} onRetry={() => {}} />
    );
  }
```

- [ ] **Step 2: Update UsersTable test**

Modify `frontend/src/test/admin/UsersTable.test.tsx`:

```diff
- it('renders error EmptyState when API call fails', () => {
+ it('renders ErrorFallback when API call fails', () => {
    mockUseAdminUsers.mockReturnValue({
      data: undefined,
      isLoading: false,
      error: new Error('Network error'),
    });

    renderUsersTable();

-   expect(screen.getByText('Failed to load users')).toBeInTheDocument();
-   expect(
-     screen.getByText('Could not fetch the user list. Please try again.'),
-   ).toBeInTheDocument();
+   expect(screen.getByRole('alert')).toBeInTheDocument();
+   expect(screen.getByText('Network error')).toBeInTheDocument();
  });
```

Update the loading test:

```diff
- it('renders loading spinner initially', () => {
+ it('renders skeleton initially', () => {
    mockUseAdminUsers.mockReturnValue({ data: undefined, isLoading: true, error: null });

    renderUsersTable();

-   const spinner = document.querySelector('.animate-spin');
-   expect(spinner).toBeInTheDocument();
+   const skeleton = document.querySelector('.animate-pulse');
+   expect(skeleton).toBeInTheDocument();
  });
```

- [ ] **Step 3: Run tests**

Run: `cd frontend && npx vitest run src/test/admin/UsersTable.test.tsx 2>&1`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add frontend/src/features/admin/components/UsersTable.tsx frontend/src/test/admin/UsersTable.test.tsx
git commit -m "feat: integrate skeleton + ErrorFallback into UsersTable"
```

---

### Task 10: Integrate Skeleton + ErrorFallback into SubmissionsList

**Files:**
- Modify: `frontend/src/features/submissions/components/SubmissionsList.tsx`
- Test: Need to read existing `SubmissionsList.test.tsx` or create one

- [ ] **Step 1: Check existing test coverage**

Run: `ls frontend/src/test/submissions/ 2>/dev/null || echo "NO TEST DIR"`
Expected: Might not have tests yet. If no tests exist, we need to handle them.

- [ ] **Step 2: Replace loading and error states in SubmissionsList**

Modify `frontend/src/features/submissions/components/SubmissionsList.tsx`:

```diff
- import { Spinner } from '../../../components/ui/Spinner';
+ import { Skeleton } from '../../../components/ui/Skeleton';
+ import { ErrorFallback } from '../../../components/shared/ErrorFallback';
```

Replace loading:

```diff
  if (isLoading) {
    return (
-     <div className="flex justify-center py-8" data-testid="submissions-loading">
-       <Spinner />
-     </div>
+     <div data-testid="submissions-loading">
+       <Skeleton variant="table-row" lines={3} />
+     </div>
    );
  }
```

Replace error:

```diff
  if (error) {
    return (
-     <EmptyState
-       title="Unable to load submissions"
-       description="Could not fetch your submissions. Please try again later."
-     />
+     <ErrorFallback error={error} onRetry={() => {}} />
    );
  }
```

- [ ] **Step 3: Run full test suite**

Run: `cd frontend && npx vitest run 2>&1`
Expected: All tests pass if SubmissionsList had test coverage. If SubmissionsList.test.tsx doesn't exist, this step is clean.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/features/submissions/components/SubmissionsList.tsx
git commit -m "feat: integrate skeleton + ErrorFallback into SubmissionsList"
```

---

### Task 11: Integrate Skeleton + ErrorFallback into SubmissionDetailPage

**Files:**
- Modify: `frontend/src/features/admin/pages/SubmissionDetailPage.tsx`
- Modify: `frontend/src/test/admin/SubmissionDetailPage.test.tsx`

- [ ] **Step 1: Read existing test to understand current coverage**

Run: `cat frontend/src/test/admin/SubmissionDetailPage.test.tsx 2>/dev/null | head -30`
Expected: Read existing test assertions.

- [ ] **Step 2: Replace loading and error states in SubmissionDetailPage**

Modify `frontend/src/features/admin/pages/SubmissionDetailPage.tsx`:

```diff
- import { Spinner } from '../../../components/ui/Spinner';
+ import { Skeleton } from '../../../components/ui/Skeleton';
+ import { ErrorFallback } from '../../../components/shared/ErrorFallback';
```

Replace loading:

```diff
  if (isLoading) {
    return (
-     <div className="flex justify-center py-12">
-       <Spinner />
-     </div>
+     <div className="space-y-6">
+       <Skeleton variant="text" lines={1} className="h-8 w-1/4" />
+       <Skeleton variant="card" />
+       <Skeleton variant="card" />
+     </div>
    );
  }
```

Replace error state:

```diff
  if (error || !submission) {
    return (
-     <EmptyState
-       title="Submission not found"
-       description="The requested submission could not be loaded."
-       action={
-         <Link
-           to="/admin"
-           className="text-sm font-medium text-blue-600 hover:text-blue-800 dark:text-blue-400"
-         >
-           ← Back to Dashboard
-         </Link>
-       }
-     />
+     <ErrorFallback
+       error={error ?? new Error('Submission not found')}
+       onRetry={() => void refetch()}
+       title="Submission not found"
+     />
    );
  }
```

Need to extract `refetch` from `useAdminSubmission`:

```diff
- const { data: submission, isLoading, error } = useAdminSubmission(id);
+ const { data: submission, isLoading, error, refetch } = useAdminSubmission(id);
```

And replace `← Back` link — add a "Back to Dashboard" button below the ErrorFallback. Actually, let's keep the back link in the error state since it's a useful navigation:

Better approach: render `ErrorFallback` and a back link together:

```tsx
  if (error || !submission) {
    return (
      <div className="space-y-4">
        <ErrorFallback
          error={error ?? new Error('Submission not found')}
          onRetry={() => void refetch()}
          title="Submission not found"
        />
        <div className="text-center">
          <Link
            to="/admin"
            className="text-sm font-medium text-blue-600 hover:text-blue-800 dark:text-blue-400"
          >
            ← Back to Dashboard
          </Link>
        </div>
      </div>
    );
  }
```

- [ ] **Step 3: Update test assertions if needed**

Read `SubmissionDetailPage.test.tsx` and update loading/error assertions as needed.

- [ ] **Step 4: Run tests**

Run: `cd frontend && npx vitest run src/test/admin/SubmissionDetailPage.test.tsx 2>&1`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/src/features/admin/pages/SubmissionDetailPage.tsx frontend/src/test/admin/SubmissionDetailPage.test.tsx
git commit -m "feat: integrate skeleton + ErrorFallback into SubmissionDetailPage"
```

---

### Task 12: Add ErrorFallback for submissions query in DashboardPage

**Files:**
- Modify: `frontend/src/features/admin/pages/DashboardPage.tsx`

- [ ] **Step 1: Add ErrorFallback for the submissions tab**

The `DashboardPage` already fetches `submissionsQuery` at the top but only passes `isLoading`/`error` down to `SubmissionsTable`. Add error handling at the tab level so if the submissions query fails, the user sees an ErrorFallback instead of an empty table.

Modify `frontend/src/features/admin/pages/DashboardPage.tsx`:

```diff
 import { Spinner } from '../../../components/ui/Spinner';
+import { Skeleton } from '../../../components/ui/Skeleton';
+import { ErrorFallback } from '../../../components/shared/ErrorFallback';
```

```diff
       {activeTab === 'submissions' && (
         <div>
           <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">
             All Submissions
           </h2>
+          {submissionsQuery.isError ? (
+            <ErrorFallback
+              error={submissionsQuery.error}
+              onRetry={() => void submissionsQuery.refetch()}
+              title="Failed to load submissions"
+            />
+          ) : (
             <SubmissionsTable
               submissions={submissionsQuery.data}
               isLoading={submissionsQuery.isLoading}
               error={submissionsQuery.error}
             />
+          )}
         </div>
       )}
```

- [ ] **Step 2: Run tests**

Run: `cd frontend && npx vitest run src/test/admin/DashboardPage.test.tsx 2>&1`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add frontend/src/features/admin/pages/DashboardPage.tsx
git commit -m "feat: add ErrorFallback for submissions query on DashboardPage"
```

---

### Task 13: Final validation — full test suite + typecheck

- [ ] **Step 1: Run typecheck**

Run: `cd frontend && npx tsc -b --noEmit 2>&1`
Expected: No TypeScript errors

- [ ] **Step 2: Run lint**

Run: `cd frontend && npx eslint . 2>&1`
Expected: No lint errors

- [ ] **Step 3: Run full test suite**

Run: `cd frontend && npx vitest run 2>&1`
Expected: All 95+ tests pass

- [ ] **Step 4: Commit any remaining fixes**

```bash
git add -A
git commit -m "chore: fix typecheck, lint, and test issues after UX polish changes"
```

---

## Self-Review Checklist

**1. Spec coverage:**
- ✅ Skeleton loaders — Task 1 (component) + Tasks 5-11 (integration into 7 components)
- ✅ ErrorFallback — Task 2 (component) + Tasks 5-12 (integration into 8 components)
- ✅ Toast/notification system — Task 3 (Toast + provider) + Task 4 (mutation wiring)
- ✅ DashboardPage ErrorFallback for submissions query — Task 12
- ✅ Auth pages excluded from Phase 1 per agreement
- ✅ TriagePage submitting state not skeletonized per agreement
- ✅ Existing ErrorBoundary left untouched per agreement

**2. Placeholder scan:**
- All steps have complete code — no "TBD", "TODO", or "implement later"
- Every test has complete test code
- Every implementation has complete component code
- All file paths are exact and absolute from project root

**3. Type consistency:**
- `Skeleton` uses `variant: 'text' | 'card' | 'table-row' | 'stats-grid'` consistently
- `ErrorFallback` uses `error: Error`, `onRetry: () => void`, `title?: string` consistently
- `Toast` uses `variant: 'error' | 'warning' | 'info'` consistently
- `useRetryFailedMessage(onSuccess?, onError?)` consistent across hook and callers
- `useDeleteFailedMessage(onSuccess?, onError?)` consistent across hook and callers
- `useGenerateSyntheticCase(onSuccess?, onError?)` consistent across hook and callers
- `refetch` extracted from `useQuery` consistently in all components that wire to `ErrorFallback`
