# TriageFlow Frontend Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** React 19 + Vite + TypeScript frontend with triage interview chat UI, admin dashboard, JWT auth, TanStack Query API client with polling, and responsive dark mode design.

**Architecture:** Feature-based directory structure (triage/, admin/, synthetic/). TanStack Query for all server state. Single Axios instance with JWT interceptor. Polling for async triage results. Tailwind CSS 4 with dark mode support.

**Tech Stack:** React 19, Vite 6, TypeScript 5 (strict), TanStack Query 5, React Router 7, Axios, Tailwind CSS 4, Vitest 3, Testing Library

**Cross-references:** Backend plan at `docs/superpowers/plans/2026-05-28-backend-foundation.md`. This plan references backend task IDs for API contracts.

---

## File Structure

```
frontend/
├── src/
│   ├── api/
│   │   ├── client.ts              # Axios instance + JWT interceptor
│   │   ├── endpoints.ts            # URL constants
│   │   ├── types.ts                # API response type definitions
│   │   └── hooks.ts                # TanStack Query hooks
│   ├── components/
│   │   ├── ui/
│   │   │   ├── Button.tsx
│   │   │   ├── Card.tsx
│   │   │   ├── Input.tsx
│   │   │   ├── Badge.tsx
│   │   │   └── Spinner.tsx
│   │   ├── layout/
│   │   │   ├── AppLayout.tsx
│   │   │   ├── Header.tsx
│   │   │   └── Sidebar.tsx
│   │   └── shared/
│   │       ├── Loader.tsx
│   │       ├── ErrorBoundary.tsx
│   │       └── EmptyState.tsx
│   ├── features/
│   │   ├── auth/
│   │   │   └── pages/
│   │   │       ├── LoginPage.tsx
│   │   │       └── RegisterPage.tsx
│   │   ├── triage/
│   │   │   ├── pages/
│   │   │   │   ├── TriagePage.tsx
│   │   │   │   └── TriageResultPage.tsx
│   │   │   ├── components/
│   │   │   │   ├── SymptomInput.tsx
│   │   │   │   ├── ChatMessage.tsx
│   │   │   │   ├── AnswerInput.tsx
│   │   │   │   └── ResultCard.tsx
│   │   │   └── hooks/
│   │   │       └── useTriage.ts
│   │   ├── submissions/
│   │   │   └── pages/
│   │   │       └── MySubmissionsPage.tsx
│   │   └── admin/
│   │       ├── pages/
│   │       │   ├── DashboardPage.tsx
│   │       │   ├── SubmissionDetailPage.tsx
│   │       │   └── UsersPage.tsx
│   │       └── components/
│   │           ├── StatsGrid.tsx
│   │           ├── SubmissionsTable.tsx
│   │           ├── LiveFeed.tsx
│   │           └── SpecialistChart.tsx
│   ├── hooks/
│   │   └── useAuth.ts
│   ├── lib/
│   │   └── constants.ts
│   ├── styles/
│   │   └── index.css               # Tailwind imports + dark mode
│   ├── App.tsx
│   ├── main.tsx
│   └── routes.tsx
├── tests/
├── index.html
├── vite.config.ts
├── tailwind.config.ts
├── tsconfig.json
└── package.json
```

---

### Task 1: Project scaffold — Vite + React + TypeScript + Tailwind

**Files:**
- Create: `frontend/` (whole project via Vite)
- Modify: `frontend/tailwind.config.ts`
- Modify: `frontend/tsconfig.json`
- Modify: `frontend/src/styles/index.css`

**Cross-ref:** Backend `Task 1` — same Docker network (`triageflow_network`). Set `VITE_API_URL=http://localhost:8000`.

- [ ] **Step 1: Create Vite project**

```bash
workdir: frontend
npm create vite@latest . -- --template react-ts
npm install
```

Expected: `frontend/` scaffolded with `package.json`, `vite.config.ts`, `tsconfig.json`, `src/main.tsx`.

- [ ] **Step 2: Install dependencies**

```bash
workdir: frontend
npm install react-router-dom @tanstack/react-query axios
npm install -D tailwindcss @tailwindcss/vite vitest @testing-library/react @testing-library/jest-dom jsdom @types/react @types/react-dom
```

Expected: All packages added to `package.json`.

- [ ] **Step 3: Configure TypeScript strict mode**

```json
// frontend/tsconfig.json (merge these settings)
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "forceConsistentCasingInFileNames": true,
    "skipLibCheck": true
  }
}
```

- [ ] **Step 4: Configure Tailwind CSS 4**

```css
/* frontend/src/styles/index.css */
@import "tailwindcss";

@variant dark (&:where(.dark, .dark *));

@theme {
  --color-primary-50: #eff6ff;
  --color-primary-500: #3b82f6;
  --color-primary-900: #1e3a5f;
  --color-urgency-low: #22c55e;
  --color-urgency-medium: #eab308;
  --color-urgency-high: #f97316;
  --color-urgency-emergency: #ef4444;
}

html {
  @apply bg-white text-gray-900 dark:bg-gray-950 dark:text-gray-100;
}
```

- [ ] **Step 5: Configure Vite with Tailwind plugin**

```ts
// frontend/vite.config.ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5173,
  },
});
```

- [ ] **Step 6: Create .env**

```env
# frontend/.env
VITE_API_URL=http://localhost:8000
```

- [ ] **Step 7: Verify dev server starts**

```bash
workdir: frontend
npm run dev
```

Expected: Vite starts on `http://localhost:5173`. Blank white page.

- [ ] **Step 7: Commit**

```bash
git add frontend/
git commit -m "feat: scaffold Vite + React 19 + TypeScript + Tailwind CSS 4"
```

---

### Task 2: API client — Axios + JWT + Types

**Files:**
- Create: `frontend/src/api/client.ts`
- Create: `frontend/src/api/endpoints.ts`
- Create: `frontend/src/api/types.ts`

**Cross-ref:** Backend `Task 7` (register response shape). Backend `Task 8` (login response shape — token field). Backend `Task 11` (triage submission response shapes).

- [ ] **Step 1: Write API types**

```ts
// frontend/src/api/types.ts
export interface ApiResponse<T> {
  readonly data: T;
}

export interface ApiError {
  readonly errors: readonly {
    readonly status: string;
    readonly code?: string;
    readonly title: string;
    readonly detail?: string;
  }[];
}

// --- User ---
export interface UserResource {
  readonly id: string;
  readonly type: 'user';
  readonly attributes: {
    readonly email: string;
    readonly roles: readonly string[];
    readonly createdAt: string;
  };
}

// --- Auth ---
export interface LoginRequest {
  readonly email: string;
  readonly password: string;
}

export interface LoginResponse {
  readonly token: string;
}

export interface RegisterRequest {
  readonly email: string;
  readonly password: string;
}

export interface RegisterResponse {
  readonly data: UserResource;
}

// --- Triage Submission ---
export interface ConversationMessage {
  readonly role: 'user' | 'assistant';
  readonly content: string;
  readonly type: 'initial_description' | 'follow_up' | 'answer' | 'result';
  readonly timestamp: string;
}

export interface TriageSubmissionResource {
  readonly id: string;
  readonly type: 'triage_submission';
  readonly attributes: {
    readonly status: 'pending' | 'processing' | 'completed' | 'failed';
    readonly isSynthetic: boolean;
    readonly specialist: string | null;
    readonly urgency: 'EMERGENCY' | 'HIGH' | 'MEDIUM' | 'LOW' | null;
    readonly justification: string | null;
    readonly conversationHistory: readonly ConversationMessage[];
    readonly processingDuration: number | null;
    readonly submittedAt: string;
    readonly processedAt: string | null;
  };
}

export interface TriageStatusResource {
  readonly id: string;
  readonly type: 'triage_submission';
  readonly attributes: {
    readonly status: 'pending' | 'processing' | 'completed' | 'failed';
    readonly currentTurn: number;
    readonly lastAssistantMessage: string | null;
  };
}

export interface SubmitTriageRequest {
  readonly initialDescription: string;
}

export interface SubmitTriageResponse {
  readonly data: {
    readonly id: string;
    readonly type: 'triage_submission';
    readonly attributes: {
      readonly status: string;
      readonly submittedAt: string;
    };
  };
}

export interface TriageAnswerRequest {
  readonly content: string;
}

export interface TriageAnswerResponse {
  readonly data: {
    readonly id: string;
    readonly type: 'triage_submission';
    readonly attributes: {
      readonly status: string;
    };
  };
}

// --- Admin ---
export interface DashboardStats {
  readonly total: number;
  readonly synthetic: number;
  readonly pending: number;
  readonly processing: number;
  readonly completed: number;
  readonly failed: number;
  readonly avgProcessingDuration: number | null;
  readonly bySpecialist: readonly { readonly specialist: string; readonly count: number }[];
  readonly byUrgency: readonly { readonly urgency: string; readonly count: number }[];
}

export interface ImpersonateResponse {
  readonly data: {
    readonly token: string;
    readonly impersonated: string;
  };
}
```

- [ ] **Step 2: Write API client**

```ts
// frontend/src/api/client.ts
import axios, { type AxiosError } from 'axios';
import type { ApiError } from './types';

export const apiClient = axios.create({
  baseURL: import.meta.env.VITE_API_URL ?? 'http://localhost:8000',
  headers: { 'Content-Type': 'application/json' },
});

apiClient.interceptors.request.use((config) => {
  const token = localStorage.getItem('jwt_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

apiClient.interceptors.response.use(
  (response) => response,
  (error: AxiosError<ApiError>) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('jwt_token');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  },
);
```

- [ ] **Step 3: Write endpoint constants**

```ts
// frontend/src/api/endpoints.ts
export const ENDPOINTS = {
  AUTH: {
    LOGIN: '/api/login',
    REGISTER: '/api/register',
  },
  TRIAGE: {
    SUBMIT: '/api/triage/submit',
    STATUS: (id: string) => `/api/triage/status/${id}`,
    ANSWER: (id: string) => `/api/triage/${id}/answer`,
    RESULT: (id: string) => `/api/triage/result/${id}`,
    MY_SUBMISSIONS: '/api/triage/submissions',
  },
  ADMIN: {
    STATS: '/api/admin/stats',
    SUBMISSIONS: '/admin/submissions',
    USERS: '/admin/users',
    SYNTHETIC_GENERATE: '/api/admin/synthetic/generate',
    IMPERSONATE: (id: string) => `/api/admin/users/${id}/impersonate`,
  },
} as const;
```

- [ ] **Step 4: Commit**

```bash
git add frontend/src/api/
git commit -m "feat: add API client with JWT interceptor + types + endpoints"
```

---

### Task 3: UI component library

**Files:**
- Create: `frontend/src/components/ui/Button.tsx`
- Create: `frontend/src/components/ui/Card.tsx`
- Create: `frontend/src/components/ui/Input.tsx`
- Create: `frontend/src/components/ui/Badge.tsx`
- Create: `frontend/src/components/ui/Spinner.tsx`
- Create: `frontend/src/components/shared/Loader.tsx`
- Create: `frontend/src/components/shared/ErrorBoundary.tsx`
- Create: `frontend/src/components/shared/EmptyState.tsx`

- [ ] **Step 1: Write Button component**

```tsx
// frontend/src/components/ui/Button.tsx
import { clsx } from 'clsx';
import type { ButtonHTMLAttributes, ReactNode } from 'react';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  readonly variant?: 'primary' | 'secondary' | 'danger';
  readonly size?: 'sm' | 'md' | 'lg';
  readonly isLoading?: boolean;
  readonly children: ReactNode;
}

export function Button({
  variant = 'primary',
  size = 'md',
  isLoading = false,
  children,
  className,
  disabled,
  ...props
}: ButtonProps) {
  return (
    <button
      className={clsx(
        'inline-flex items-center justify-center rounded-lg font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed',
        {
          'bg-blue-600 text-white hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-600 focus:ring-blue-500': variant === 'primary',
          'bg-gray-200 text-gray-900 hover:bg-gray-300 dark:bg-gray-700 dark:text-gray-100 dark:hover:bg-gray-600 focus:ring-gray-500': variant === 'secondary',
          'bg-red-600 text-white hover:bg-red-700 focus:ring-red-500': variant === 'danger',
        },
        {
          'px-3 py-1.5 text-sm': size === 'sm',
          'px-4 py-2 text-base': size === 'md',
          'px-6 py-3 text-lg': size === 'lg',
        },
        className,
      )}
      disabled={disabled || isLoading}
      {...props}
    >
      {isLoading && <Spinner className="mr-2" />}
      {children}
    </button>
  );
}
```

- [ ] **Step 2: Write Card component**

```tsx
// frontend/src/components/ui/Card.tsx
import { clsx } from 'clsx';
import type { HTMLAttributes, ReactNode } from 'react';

interface CardProps extends HTMLAttributes<HTMLDivElement> {
  readonly children: ReactNode;
}

export function Card({ children, className, ...props }: CardProps) {
  return (
    <div
      className={clsx(
        'rounded-xl border border-gray-200 bg-white p-6 shadow-sm dark:border-gray-800 dark:bg-gray-900',
        className,
      )}
      {...props}
    >
      {children}
    </div>
  );
}
```

- [ ] **Step 3: Write Input component**

```tsx
// frontend/src/components/ui/Input.tsx
import { clsx } from 'clsx';
import type { InputHTMLAttributes } from 'react';
import { forwardRef } from 'react';

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  readonly label?: string;
  readonly error?: string;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ label, error, className, id, ...props }, ref) => {
    const inputId = id ?? label?.toLowerCase().replace(/\s+/g, '-');

    return (
      <div className="space-y-1">
        {label && (
          <label htmlFor={inputId} className="block text-sm font-medium text-gray-700 dark:text-gray-300">
            {label}
          </label>
        )}
        <input
          ref={ref}
          id={inputId}
          className={clsx(
            'w-full rounded-lg border px-4 py-2 text-gray-900 transition-colors dark:text-gray-100 dark:bg-gray-800',
            'focus:outline-none focus:ring-2 focus:ring-blue-500',
            error
              ? 'border-red-500 dark:border-red-400'
              : 'border-gray-300 dark:border-gray-600',
            className,
          )}
          {...props}
        />
        {error && <p className="text-sm text-red-600 dark:text-red-400">{error}</p>}
      </div>
    );
  },
);
Input.displayName = 'Input';
```

- [ ] **Step 4: Write Badge component**

```tsx
// frontend/src/components/ui/Badge.tsx
import { clsx } from 'clsx';

interface BadgeProps {
  readonly variant: 'pending' | 'processing' | 'completed' | 'failed' | 'low' | 'medium' | 'high' | 'emergency';
  readonly children: string;
}

const variantClasses: Record<BadgeProps['variant'], string> = {
  pending: 'bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-300',
  processing: 'bg-blue-100 text-blue-700 dark:bg-blue-900 dark:text-blue-300',
  completed: 'bg-green-100 text-green-700 dark:bg-green-900 dark:text-green-300',
  failed: 'bg-red-100 text-red-700 dark:bg-red-900 dark:text-red-300',
  low: 'bg-green-100 text-green-700 dark:bg-green-900 dark:text-green-300',
  medium: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900 dark:text-yellow-300',
  high: 'bg-orange-100 text-orange-700 dark:bg-orange-900 dark:text-orange-300',
  emergency: 'bg-red-100 text-red-700 dark:bg-red-900 dark:text-red-300',
};

export function Badge({ variant, children }: BadgeProps) {
  return (
    <span className={clsx('inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium', variantClasses[variant])}>
      {children}
    </span>
  );
}
```

- [ ] **Step 5: Write Spinner component**

```tsx
// frontend/src/components/ui/Spinner.tsx
import { clsx } from 'clsx';

interface SpinnerProps {
  readonly className?: string;
  readonly size?: 'sm' | 'md' | 'lg';
}

export function Spinner({ className, size = 'md' }: SpinnerProps) {
  return (
    <svg
      className={clsx(
        'animate-spin text-current',
        { 'h-4 w-4': size === 'sm', 'h-5 w-5': size === 'md', 'h-8 w-8': size === 'lg' },
        className,
      )}
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
      aria-hidden="true"
    >
      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
      <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
    </svg>
  );
}
```

- [ ] **Step 6: Write Loader, ErrorBoundary, EmptyState**

```tsx
// frontend/src/components/shared/Loader.tsx
import { Spinner } from '../ui/Spinner';

interface LoaderProps {
  readonly message?: string;
}

export function Loader({ message = 'Loading...' }: LoaderProps) {
  return (
    <div className="flex flex-col items-center justify-center py-12 text-gray-500 dark:text-gray-400">
      <Spinner size="lg" />
      <p className="mt-3 text-sm">{message}</p>
    </div>
  );
}
```

```tsx
// frontend/src/components/shared/ErrorBoundary.tsx
import { Component, type ReactNode } from 'react';
import { Button } from '../ui/Button';

interface Props {
  readonly children: ReactNode;
  readonly fallback?: ReactNode;
}

interface State {
  readonly hasError: boolean;
  readonly error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  render() {
    if (this.state.hasError) {
      return (
        this.props.fallback ?? (
          <div className="flex flex-col items-center justify-center py-12 text-center">
            <p className="text-lg font-semibold text-gray-900 dark:text-gray-100">Something went wrong</p>
            <p className="mt-2 text-sm text-gray-500 dark:text-gray-400">
              {this.state.error?.message ?? 'An unexpected error occurred'}
            </p>
            <Button className="mt-4" onClick={() => this.setState({ hasError: false, error: null })}>
              Try again
            </Button>
          </div>
        )
      );
    }

    return this.props.children;
  }
}
```

```tsx
// frontend/src/components/shared/EmptyState.tsx
import type { ReactNode } from 'react';

interface EmptyStateProps {
  readonly title: string;
  readonly description?: string;
  readonly action?: ReactNode;
}

export function EmptyState({ title, description, action }: EmptyStateProps) {
  return (
    <div className="flex flex-col items-center justify-center py-12 text-center">
      <svg className="h-12 w-12 text-gray-400 dark:text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4" />
      </svg>
      <h3 className="mt-4 text-lg font-semibold text-gray-900 dark:text-gray-100">{title}</h3>
      {description && <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">{description}</p>}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}
```

- [ ] **Step 7: Commit**

```bash
git add frontend/src/components/
git commit -m "feat: add UI components (Button, Card, Input, Badge, Spinner, Loader, ErrorBoundary, EmptyState)"
```

---

### Task 4: Triage interview page — chat UI + polling

**Files:**
- Create: `frontend/src/features/triage/hooks/useTriage.ts`
- Create: `frontend/src/features/triage/components/ChatMessage.tsx`
- Create: `frontend/src/features/triage/components/SymptomInput.tsx`
- Create: `frontend/src/features/triage/components/AnswerInput.tsx`
- Create: `frontend/src/features/triage/pages/TriagePage.tsx`

**Cross-ref:** Backend `Task 11` — `POST /api/triage/submit` (202), `GET /api/triage/status/{id}` (poll), `POST /api/triage/{id}/answer` (202). Response shapes in `TriageStatusResource`, `SubmitTriageResponse`.

- [ ] **Step 1: Write useTriage hook**

```tsx
// frontend/src/features/triage/hooks/useTriage.ts
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../../../api/client';
import { ENDPOINTS } from '../../../api/endpoints';
import type {
  SubmitTriageRequest,
  SubmitTriageResponse,
  TriageStatusResource,
  TriageAnswerRequest,
  TriageAnswerResponse,
} from '../../../api/types';

export function useSubmitTriage() {
  return useMutation({
    mutationFn: (data: SubmitTriageRequest) =>
      apiClient.post<SubmitTriageResponse>(ENDPOINTS.TRIAGE.SUBMIT, data).then((r) => r.data),
  });
}

export function useTriageStatus(submissionId: string | null) {
  return useQuery({
    queryKey: ['triageStatus', submissionId],
    queryFn: () =>
      apiClient
        .get<TriageStatusResource>(ENDPOINTS.TRIAGE.STATUS(submissionId!))
        .then((r) => r.data),
    enabled: submissionId !== null,
    refetchInterval: (query) => {
      const status = query.state.data?.attributes.status;
      if (status === 'processing' || status === 'pending') {
        return 2000; // Poll every 2s while processing
      }
      return false;
    },
  });
}

export function useSubmitAnswer() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ id, content }: { readonly id: string; readonly content: string }) =>
      apiClient
        .post<TriageAnswerResponse>(ENDPOINTS.TRIAGE.ANSWER(id), { content } satisfies TriageAnswerRequest)
        .then((r) => r.data),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ['triageStatus', variables.id] });
    },
  });
}
```

- [ ] **Step 2: Write ChatMessage component**

```tsx
// frontend/src/features/triage/components/ChatMessage.tsx
import { clsx } from 'clsx';
import type { ConversationMessage } from '../../../api/types';

interface ChatMessageProps {
  readonly message: ConversationMessage;
}

export function ChatMessage({ message }: ChatMessageProps) {
  const isUser = message.role === 'user';

  return (
    <div className={clsx('flex', isUser ? 'justify-end' : 'justify-start')}>
      <div
        className={clsx(
          'max-w-[80%] rounded-2xl px-4 py-3 text-sm',
          isUser
            ? 'bg-blue-600 text-white'
            : 'bg-gray-100 text-gray-900 dark:bg-gray-800 dark:text-gray-100',
        )}
      >
        <p className="whitespace-pre-wrap">{message.content}</p>
        {message.type === 'result' && (
          <span className="mt-1 block text-xs opacity-70">Final assessment</span>
        )}
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Write SymptomInput component**

```tsx
// frontend/src/features/triage/components/SymptomInput.tsx
import { useState, type FormEvent } from 'react';
import { Button } from '../../../components/ui/Button';

interface SymptomInputProps {
  readonly onSubmit: (description: string) => void;
  readonly isLoading: boolean;
}

export function SymptomInput({ onSubmit, isLoading }: SymptomInputProps) {
  const [value, setValue] = useState('');

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    const trimmed = value.trim();
    if (trimmed.length < 3) return;
    onSubmit(trimmed);
    setValue('');
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div>
        <label htmlFor="symptoms" className="block text-lg font-semibold text-gray-900 dark:text-gray-100">
          Describe your symptoms
        </label>
        <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
          Write in your own words — the AI will ask follow-up questions to better understand your situation.
        </p>
      </div>
      <textarea
        id="symptoms"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        maxLength={500}
        rows={3}
        className="w-full rounded-lg border border-gray-300 px-4 py-3 text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100"
        placeholder="e.g., my head is going to explode..."
        disabled={isLoading}
      />
      <div className="flex items-center justify-between">
        <span className="text-xs text-gray-400">{value.length}/500</span>
        <Button type="submit" disabled={value.trim().length < 3} isLoading={isLoading}>
          Start Triage
        </Button>
      </div>
    </form>
  );
}
```

- [ ] **Step 4: Write AnswerInput component**

```tsx
// frontend/src/features/triage/components/AnswerInput.tsx
import { useState, type FormEvent } from 'react';
import { Button } from '../../../components/ui/Button';

interface AnswerInputProps {
  readonly onSubmit: (answer: string) => void;
  readonly isLoading: boolean;
}

export function AnswerInput({ onSubmit, isLoading }: AnswerInputProps) {
  const [value, setValue] = useState('');

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    const trimmed = value.trim();
    if (!trimmed) return;
    onSubmit(trimmed);
    setValue('');
  };

  return (
    <form onSubmit={handleSubmit} className="flex gap-2">
      <input
        type="text"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        maxLength={300}
        placeholder="Type your answer..."
        className="flex-1 rounded-lg border border-gray-300 px-4 py-2 text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100"
        disabled={isLoading}
      />
      <Button type="submit" disabled={!value.trim()} isLoading={isLoading}>
        Send
      </Button>
    </form>
  );
}
```

- [ ] **Step 5: Write TriagePage**

```tsx
// frontend/src/features/triage/pages/TriagePage.tsx
import { useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { Card } from '../../../components/ui/Card';
import { Loader } from '../../../components/shared/Loader';
import { useSubmitTriage, useTriageStatus, useSubmitAnswer } from '../hooks/useTriage';
import { SymptomInput } from '../components/SymptomInput';
import { ChatMessage } from '../components/ChatMessage';
import { AnswerInput } from '../components/AnswerInput';
import type { ConversationMessage } from '../../../api/types';

export function TriagePage() {
  const navigate = useNavigate();
  const [submissionId, setSubmissionId] = useState<string | null>(null);
  const [messages, setMessages] = useState<readonly ConversationMessage[]>([]);

  const submitTriage = useSubmitTriage();
  const statusQuery = useTriageStatus(submissionId);
  const submitAnswer = useSubmitAnswer();

  // Handle new status data (incoming AI message)
  const lastMessage = statusQuery.data?.attributes.lastAssistantMessage;
  const status = statusQuery.data?.attributes.status;

  const handleInitialSubmit = useCallback(
    (description: string) => {
      // Add user message immediately
      const userMsg: ConversationMessage = {
        role: 'user',
        content: description,
        type: 'initial_description',
        timestamp: new Date().toISOString(),
      };
      setMessages([userMsg]);

      submitTriage.mutate(
        { initialDescription: description },
        {
          onSuccess: (data) => {
            setSubmissionId(data.data.id);
          },
        },
      );
    },
    [submitTriage],
  );

  const handleAnswerSubmit = useCallback(
    (answer: string) => {
      if (!submissionId) return;

      // Add user answer immediately
      const userMsg: ConversationMessage = {
        role: 'user',
        content: answer,
        type: 'answer',
        timestamp: new Date().toISOString(),
      };
      setMessages((prev) => [...prev, userMsg]);

      submitAnswer.mutate({ id: submissionId, content: answer });
    },
    [submissionId, submitAnswer],
  );

  // Navigate to result when completed
  if (status === 'completed' && submissionId) {
    navigate(`/triage/${submissionId}/result`, { replace: true });
    return null;
  }

  return (
    <div className="mx-auto max-w-2xl py-8">
      <h1 className="mb-6 text-2xl font-bold text-gray-900 dark:text-gray-100">Triage Interview</h1>

      {!submissionId ? (
        <Card>
          <SymptomInput onSubmit={handleInitialSubmit} isLoading={submitTriage.isPending} />
        </Card>
      ) : (
        <div className="space-y-4">
          {/* Chat messages */}
          <div className="space-y-3">
            {messages.map((msg, i) => (
              <ChatMessage key={i} message={msg} />
            ))}

            {/* Loading indicator while waiting for AI */}
            {(statusQuery.isFetching || submitAnswer.isPending) && (
              <div className="flex justify-start">
                <div className="max-w-[80%] rounded-2xl bg-gray-100 px-4 py-3 dark:bg-gray-800">
                  <Loader message="AI is analyzing..." />
                </div>
              </div>
            )}
          </div>

          {/* Answer input — show when status is not completed */}
          {status === 'processing' || status === 'pending' ? (
            <div className="sticky bottom-0 bg-white py-4 dark:bg-gray-950">
              <AnswerInput onSubmit={handleAnswerSubmit} isLoading={submitAnswer.isPending} />
            </div>
          ) : null}

          {/* Failed state */}
          {status === 'failed' && (
            <Card className="text-center">
              <p className="text-red-600 dark:text-red-400">AI analysis failed. Please try again.</p>
            </Card>
          )}
        </div>
      )}
    </div>
  );
}
```

- [ ] **Step 6: Commit**

```bash
git add frontend/src/features/triage/
git commit -m "feat: add triage interview page with chat UI + polling"
```

---

### Task 5: Triage result page

**Files:**
- Create: `frontend/src/features/triage/components/ResultCard.tsx`
- Create: `frontend/src/features/triage/pages/TriageResultPage.tsx`

**Cross-ref:** Backend `Task 11` — `GET /api/triage/result/{id}`. Response: `TriageSubmissionResource` from `api/types.ts`.

- [ ] **Step 1: Write ResultCard component**

```tsx
// frontend/src/features/triage/components/ResultCard.tsx
import { Card } from '../../../components/ui/Card';
import { Badge } from '../../../components/ui/Badge';
import type { TriageSubmissionResource } from '../../../api/types';

interface ResultCardProps {
  readonly submission: TriageSubmissionResource;
}

const urgencyBadgeVariant: Record<string, 'low' | 'medium' | 'high' | 'emergency'> = {
  LOW: 'low',
  MEDIUM: 'medium',
  HIGH: 'high',
  EMERGENCY: 'emergency',
};

const specialistIcons: Record<string, string> = {
  CARDIOLOGIST: '❤️',
  NEUROLOGIST: '🧠',
  DERMATOLOGIST: '🔬',
  GASTROENTEROLOGIST: '🫄',
  ORTHOPEDIST: '🦴',
  PULMONOLOGIST: '🫁',
  PSYCHIATRIST: '🧘',
  GP: '🩺',
  ENDOCRINOLOGIST: '🦋',
  RHEUMATOLOGIST: '💪',
  UROLOGIST: '🫘',
  OPHTHALMOLOGIST: '👁️',
  OTOLARYNGOLOGIST: '👂',
  ONCOLOGIST: '🎗️',
  NEPHROLOGIST: '🫘',
  OBSTETRICIAN_GYNECOLOGIST: '🤰',
  PEDIATRICIAN: '👶',
  INFECTIOUS_DISEASE: '🦠',
};

export function ResultCard({ submission }: ResultCardProps) {
  const { specialist, urgency, justification } = submission.attributes;

  return (
    <Card className="space-y-6">
      <div className="text-center">
        <h2 className="text-xl font-bold text-gray-900 dark:text-gray-100">Triage Result</h2>
        <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">
          Submitted {new Date(submission.attributes.submittedAt).toLocaleString()}
        </p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <div className="rounded-lg bg-blue-50 p-4 dark:bg-blue-950">
          <p className="text-sm font-medium text-gray-600 dark:text-gray-400">Recommended specialist</p>
          <p className="mt-1 text-lg font-bold text-blue-700 dark:text-blue-300">
            {specialist && specialistIcons[specialist]} {specialist ?? 'Unknown'}
          </p>
        </div>

        <div className="rounded-lg bg-gray-50 p-4 dark:bg-gray-800">
          <p className="text-sm font-medium text-gray-600 dark:text-gray-400">Urgency</p>
          <p className="mt-1">
            {urgency && <Badge variant={urgencyBadgeVariant[urgency] ?? 'low'}>{urgency}</Badge>}
          </p>
        </div>
      </div>

      <div>
        <h3 className="text-sm font-medium text-gray-900 dark:text-gray-100">Medical Justification</h3>
        <p className="mt-2 text-sm text-gray-700 dark:text-gray-300">{justification ?? 'No justification provided.'}</p>
      </div>

      {submission.attributes.processingDuration !== null && (
        <p className="text-xs text-gray-400">
          Processed in {submission.attributes.processingDuration}s
        </p>
      )}
    </Card>
  );
}
```

- [ ] **Step 2: Write TriageResultPage**

```tsx
// frontend/src/features/triage/pages/TriageResultPage.tsx
import { useParams, Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../../api/client';
import { ENDPOINTS } from '../../../api/endpoints';
import type { TriageSubmissionResource } from '../../../api/types';
import { ResultCard } from '../components/ResultCard';
import { ChatMessage } from '../components/ChatMessage';
import { Card } from '../../../components/ui/Card';
import { Button } from '../../../components/ui/Button';
import { Loader } from '../../../components/shared/Loader';

export function TriageResultPage() {
  const { id } = useParams<{ readonly id: string }>();

  const { data, isLoading, error } = useQuery({
    queryKey: ['triageResult', id],
    queryFn: () =>
      apiClient.get<TriageSubmissionResource>(ENDPOINTS.TRIAGE.RESULT(id!)).then((r) => r.data),
    enabled: !!id,
  });

  if (isLoading) return <Loader message="Loading result..." />;

  if (error || !data) {
    return (
      <div className="mx-auto max-w-2xl py-8 text-center">
        <p className="text-red-600 dark:text-red-400">Failed to load result</p>
      </div>
    );
  }

  const messages = data.attributes.conversationHistory;

  return (
    <div className="mx-auto max-w-2xl py-8 space-y-6">
      <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">Triage Result</h1>

      <ResultCard submission={data} />

      {messages.length > 0 && (
        <Card>
          <h3 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">Conversation History</h3>
          <div className="space-y-3">
            {messages.map((msg, i) => (
              <ChatMessage key={i} message={msg} />
            ))}
          </div>
        </Card>
      )}

      <div className="flex gap-3">
        <Link to="/submissions">
          <Button variant="secondary">View my submissions</Button>
        </Link>
        <Link to="/triage">
          <Button>New triage</Button>
        </Link>
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Commit**

```bash
git add frontend/src/features/triage/pages/TriageResultPage.tsx frontend/src/features/triage/components/ResultCard.tsx
git commit -m "feat: add triage result page with specialist card + conversation history"
```

---

### Task 6: My Submissions page

**Files:**
- Create: `frontend/src/features/submissions/pages/MySubmissionsPage.tsx`

**Cross-ref:** Backend `Task 11` — `GET /api/triage/submissions`. Response: array of `TriageSubmissionResource`.

- [ ] **Step 1: Write MySubmissionsPage**

```tsx
// frontend/src/features/submissions/pages/MySubmissionsPage.tsx
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../../api/client';
import { ENDPOINTS } from '../../../api/endpoints';
import type { TriageSubmissionResource } from '../../../api/types';
import { Card } from '../../../components/ui/Card';
import { Badge } from '../../../components/ui/Badge';
import { Loader } from '../../../components/shared/Loader';
import { EmptyState } from '../../../components/shared/EmptyState';
import { Button } from '../../../components/ui/Button';

const statusBadgeVariant: Record<string, 'pending' | 'processing' | 'completed' | 'failed'> = {
  pending: 'pending',
  processing: 'processing',
  completed: 'completed',
  failed: 'failed',
};

export function MySubmissionsPage() {
  const { data, isLoading } = useQuery({
    queryKey: ['mySubmissions'],
    queryFn: () =>
      apiClient
        .get<{ readonly data: readonly TriageSubmissionResource[] }>(ENDPOINTS.TRIAGE.MY_SUBMISSIONS)
        .then((r) => r.data.data),
  });

  if (isLoading) return <Loader message="Loading submissions..." />;

  if (!data || data.length === 0) {
    return (
      <div className="mx-auto max-w-4xl py-8">
        <h1 className="mb-6 text-2xl font-bold text-gray-900 dark:text-gray-100">My Submissions</h1>
        <EmptyState
          title="No submissions yet"
          description="Start a triage interview to see your results here."
          action={
            <Link to="/triage">
              <Button>Start Triage</Button>
            </Link>
          }
        />
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-4xl py-8">
      <h1 className="mb-6 text-2xl font-bold text-gray-900 dark:text-gray-100">My Submissions</h1>

      <div className="space-y-3">
        {data.map((submission) => (
          <Link key={submission.id} to={`/triage/${submission.id}/result`}>
            <Card className="flex items-center justify-between hover:border-blue-300 dark:hover:border-blue-700 transition-colors cursor-pointer">
              <div>
                <p className="font-medium text-gray-900 dark:text-gray-100">
                  {submission.attributes.specialist ?? 'Pending...'}
                </p>
                <p className="text-sm text-gray-500 dark:text-gray-400">
                  {new Date(submission.attributes.submittedAt).toLocaleString()}
                </p>
              </div>
              <div className="flex items-center gap-3">
                {submission.attributes.urgency && (
                  <Badge variant={statusBadgeVariant[submission.attributes.urgency.toLowerCase()] as 'pending' | 'processing' | 'completed' | 'failed'}>
                    {submission.attributes.urgency}
                  </Badge>
                )}
                <Badge variant={statusBadgeVariant[submission.attributes.status] ?? 'pending'}>
                  {submission.attributes.status}
                </Badge>
              </div>
            </Card>
          </Link>
        ))}
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add frontend/src/features/submissions/
git commit -m "feat: add My Submissions page with status badges"
```

---

### Task 7: App layout + routing

**Files:**
- Create: `frontend/src/components/layout/AppLayout.tsx`
- Create: `frontend/src/components/layout/Header.tsx`
- Create: `frontend/src/hooks/useAuth.ts`
- Create: `frontend/src/routes.tsx`
- Modify: `frontend/src/App.tsx`
- Modify: `frontend/src/main.tsx`

**Cross-ref:** Backend `Task 8` — JWT token from login stored in localStorage via `useAuth`.

- [ ] **Step 1: Write useAuth hook**

```tsx
// frontend/src/hooks/useAuth.ts
import { useState, useCallback } from 'react';

interface AuthState {
  readonly isAuthenticated: boolean;
  readonly isAdmin: boolean;
  readonly token: string | null;
}

export function useAuth() {
  const [state, setState] = useState<AuthState>(() => {
    const token = localStorage.getItem('jwt_token');
    if (!token) return { isAuthenticated: false, isAdmin: false, token: null };

    try {
      const payload = JSON.parse(atob(token.split('.')[1]!));
      const isAdmin = payload.roles?.includes('ROLE_ADMIN') ?? false;
      return { isAuthenticated: true, isAdmin, token };
    } catch {
      return { isAuthenticated: false, isAdmin: false, token: null };
    }
  });

  const login = useCallback((token: string) => {
    localStorage.setItem('jwt_token', token);
    const payload = JSON.parse(atob(token.split('.')[1]!));
    const isAdmin = payload.roles?.includes('ROLE_ADMIN') ?? false;
    setState({ isAuthenticated: true, isAdmin, token });
  }, []);

  const logout = useCallback(() => {
    localStorage.removeItem('jwt_token');
    setState({ isAuthenticated: false, isAdmin: false, token: null });
  }, []);

  return { ...state, login, logout };
}
```

- [ ] **Step 2: Write Header**

```tsx
// frontend/src/components/layout/Header.tsx
import { Link } from 'react-router-dom';
import { Button } from '../ui/Button';

interface HeaderProps {
  readonly isAuthenticated: boolean;
  readonly isAdmin: boolean;
  readonly onLogout: () => void;
}

export function Header({ isAuthenticated, isAdmin, onLogout }: HeaderProps) {
  return (
    <header className="border-b border-gray-200 bg-white dark:border-gray-800 dark:bg-gray-900">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
        <Link to="/" className="text-xl font-bold text-blue-600 dark:text-blue-400">
          TriageFlow
        </Link>

        <nav className="flex items-center gap-4">
          {isAuthenticated ? (
            <>
              <Link to="/triage" className="text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100">
                New Triage
              </Link>
              <Link to="/submissions" className="text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100">
                My Submissions
              </Link>
              {isAdmin && (
                <Link to="/admin" className="text-sm text-gray-600 hover:text-gray-900 dark:text-gray-400 dark:hover:text-gray-100">
                  Admin
                </Link>
              )}
              <Button variant="secondary" size="sm" onClick={onLogout}>
                Logout
              </Button>
            </>
          ) : (
            <>
              <Link to="/login">
                <Button variant="secondary" size="sm">Login</Button>
              </Link>
              <Link to="/register">
                <Button size="sm">Register</Button>
              </Link>
            </>
          )}
        </nav>
      </div>
    </header>
  );
}
```

- [ ] **Step 3: Write AppLayout**

```tsx
// frontend/src/components/layout/AppLayout.tsx
import { Outlet } from 'react-router-dom';
import { Header } from './Header';
import { useAuth } from '../../hooks/useAuth';

export function AppLayout() {
  const { isAuthenticated, isAdmin, logout } = useAuth();

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950">
      <Header isAuthenticated={isAuthenticated} isAdmin={isAdmin} onLogout={logout} />
      <main className="mx-auto max-w-6xl px-4 py-6">
        <Outlet />
      </main>
    </div>
  );
}
```

- [ ] **Step 4: Write routes**

```tsx
// frontend/src/routes.tsx
import { createBrowserRouter, Navigate } from 'react-router-dom';
import { AppLayout } from './components/layout/AppLayout';
import { TriagePage } from './features/triage/pages/TriagePage';
import { TriageResultPage } from './features/triage/pages/TriageResultPage';
import { MySubmissionsPage } from './features/submissions/pages/MySubmissionsPage';

export const router = createBrowserRouter([
  {
    path: '/',
    element: <AppLayout />,
    children: [
      { index: true, element: <Navigate to="/triage" replace /> },
      { path: 'triage', element: <TriagePage /> },
      { path: 'triage/:id/result', element: <TriageResultPage /> },
      { path: 'submissions', element: <MySubmissionsPage /> },
      { path: 'login', lazy: () => import('./features/auth/pages/LoginPage').then((m) => ({ element: <m.LoginPage /> })) },
      { path: 'register', lazy: () => import('./features/auth/pages/RegisterPage').then((m) => ({ element: <m.RegisterPage /> })) },
      { path: 'admin', lazy: () => import('./features/admin/pages/DashboardPage').then((m) => ({ element: <m.DashboardPage /> })) },
      { path: 'admin/submissions/:id', lazy: () => import('./features/admin/pages/SubmissionDetailPage').then((m) => ({ element: <m.SubmissionDetailPage /> })) },
      { path: 'admin/users', lazy: () => import('./features/admin/pages/UsersPage').then((m) => ({ element: <m.UsersPage /> })) },
    ],
  },
]);
```

- [ ] **Step 5: Update main.tsx and App.tsx**

```tsx
// frontend/src/main.tsx
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { App } from './App';
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
      <App />
    </QueryClientProvider>
  </StrictMode>,
);
```

```tsx
// frontend/src/App.tsx
import { RouterProvider } from 'react-router-dom';
import { router } from './routes';

export function App() {
  return <RouterProvider router={router} />;
}
```

- [ ] **Step 6: Commit**

```bash
git add frontend/src/hooks/ frontend/src/components/layout/ frontend/src/routes.tsx frontend/src/App.tsx frontend/src/main.tsx
git commit -m "feat: add app layout, header, auth hook, and routing"
```

---

### Task 8: Auth pages — Login + Registration

**Files:**
- Create: `frontend/src/features/auth/pages/LoginPage.tsx`
- Create: `frontend/src/features/auth/pages/RegisterPage.tsx`

**Cross-ref:** Backend `Task 7` — `POST /api/register` (returns UserResource). Backend `Task 8` — `POST /api/login` (returns token).

- [ ] **Step 1: Write RegisterPage**

```tsx
// frontend/src/features/auth/pages/RegisterPage.tsx
import { useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useMutation } from '@tanstack/react-query';
import { apiClient } from '../../../api/client';
import { ENDPOINTS } from '../../../api/endpoints';
import type { RegisterRequest, RegisterResponse } from '../../../api/types';
import { Card } from '../../../components/ui/Card';
import { Input } from '../../../components/ui/Input';
import { Button } from '../../../components/ui/Button';

export function RegisterPage() {
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [errors, setErrors] = useState<{ readonly email?: string; readonly password?: string }>({});

  const register = useMutation({
    mutationFn: (data: RegisterRequest) =>
      apiClient.post<RegisterResponse>(ENDPOINTS.AUTH.REGISTER, data).then((r) => r.data),
    onSuccess: () => {
      navigate('/login', { state: { registered: true } });
    },
    onError: (error: any) => {
      const errData = error.response?.data;
      if (errData?.errors) {
        const fieldErrors: { email?: string; password?: string } = {};
        for (const e of errData.errors) {
          if (e.detail?.includes('email')) fieldErrors.email = e.detail;
          if (e.detail?.includes('password')) fieldErrors.password = e.detail;
        }
        setErrors(fieldErrors);
      }
    },
  });

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    register.mutate({ email, password });
  };

  return (
    <div className="mx-auto max-w-md py-12">
      <Card>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">Create Account</h1>
        <form onSubmit={handleSubmit} className="mt-6 space-y-4">
          <Input
            label="Email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            error={errors.email}
            required
          />
          <Input
            label="Password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            error={errors.password}
            required
            minLength={8}
          />
          <Button type="submit" className="w-full" isLoading={register.isPending}>
            Register
          </Button>
        </form>
        <p className="mt-4 text-center text-sm text-gray-500 dark:text-gray-400">
          Already have an account?{' '}
          <Link to="/login" className="text-blue-600 hover:underline dark:text-blue-400">
            Login
          </Link>
        </p>
      </Card>
    </div>
  );
}
```

- [ ] **Step 2: Write LoginPage**

```tsx
// frontend/src/features/auth/pages/LoginPage.tsx
import { useState, type FormEvent } from 'react';
import { Link, useNavigate, useLocation } from 'react-router-dom';
import { useMutation } from '@tanstack/react-query';
import { apiClient } from '../../../api/client';
import { ENDPOINTS } from '../../../api/endpoints';
import type { LoginRequest, LoginResponse } from '../../../api/types';
import { Card } from '../../../components/ui/Card';
import { Input } from '../../../components/ui/Input';
import { Button } from '../../../components/ui/Button';
import { useAuth } from '../../../hooks/useAuth';

export function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const justRegistered = (location.state as { readonly registered?: boolean })?.registered;

  const loginMutation = useMutation({
    mutationFn: (data: LoginRequest) =>
      apiClient.post<LoginResponse>(ENDPOINTS.AUTH.LOGIN, data).then((r) => r.data),
    onSuccess: (data) => {
      login(data.token);
      navigate('/triage', { replace: true });
    },
    onError: () => {
      setError('Invalid email or password');
    },
  });

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    loginMutation.mutate({ email, password });
  };

  return (
    <div className="mx-auto max-w-md py-12">
      <Card>
        <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">Login</h1>

        {justRegistered && (
          <p className="mt-2 text-sm text-green-600 dark:text-green-400">Account created! Please login.</p>
        )}

        <form onSubmit={handleSubmit} className="mt-6 space-y-4">
          <Input
            label="Email"
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
          <Input
            label="Password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
          {error && <p className="text-sm text-red-600 dark:text-red-400">{error}</p>}
          <Button type="submit" className="w-full" isLoading={loginMutation.isPending}>
            Login
          </Button>
        </form>
        <p className="mt-4 text-center text-sm text-gray-500 dark:text-gray-400">
          Don't have an account?{' '}
          <Link to="/register" className="text-blue-600 hover:underline dark:text-blue-400">
            Register
          </Link>
        </p>
      </Card>
    </div>
  );
}
```

- [ ] **Step 3: Commit**

```bash
git add frontend/src/features/auth/
git commit -m "feat: add login and registration pages"
```

---

### Task 9: Admin dashboard

**Files:**
- Create: `frontend/src/features/admin/components/StatsGrid.tsx`
- Create: `frontend/src/features/admin/components/SubmissionsTable.tsx`
- Create: `frontend/src/features/admin/components/LiveFeed.tsx`
- Create: `frontend/src/features/admin/pages/DashboardPage.tsx`

**Cross-ref:** Backend `Task 15` — `GET /api/admin/stats` (DashboardStats shape). Backend `Task 14` — `GET /admin/submissions` (API Platform collection). Backend `Task 17` — `POST /api/admin/synthetic/generate`.

- [ ] **Step 1: Write StatsGrid component**

```tsx
// frontend/src/features/admin/components/StatsGrid.tsx
import { Card } from '../../../components/ui/Card';
import type { DashboardStats } from '../../../api/types';

interface StatsGridProps {
  readonly stats: DashboardStats;
}

export function StatsGrid({ stats }: StatsGridProps) {
  const items = [
    { label: 'Total', value: stats.total, color: 'text-blue-600 dark:text-blue-400' },
    { label: 'Completed', value: stats.completed, color: 'text-green-600 dark:text-green-400' },
    { label: 'Processing', value: stats.processing, color: 'text-yellow-600 dark:text-yellow-400' },
    { label: 'Failed', value: stats.failed, color: 'text-red-600 dark:text-red-400' },
    { label: 'Synthetic', value: stats.synthetic, color: 'text-purple-600 dark:text-purple-400' },
    {
      label: 'Avg Time',
      value: stats.avgProcessingDuration !== null ? `${Math.round(stats.avgProcessingDuration)}s` : 'N/A',
      color: 'text-gray-600 dark:text-gray-400',
    },
  ];

  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      {items.map((item) => (
        <Card key={item.label}>
          <p className="text-sm font-medium text-gray-500 dark:text-gray-400">{item.label}</p>
          <p className={`mt-1 text-2xl font-bold ${item.color}`}>{item.value}</p>
        </Card>
      ))}
    </div>
  );
}
```

- [ ] **Step 2: Write SubmissionsTable component**

```tsx
// frontend/src/features/admin/components/SubmissionsTable.tsx
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { apiClient } from '../../../api/client';
import { ENDPOINTS } from '../../../api/endpoints';
import type { TriageSubmissionResource } from '../../../api/types';
import { Badge } from '../../../components/ui/Badge';
import { Loader } from '../../../components/shared/Loader';

const statusBadge: Record<string, 'pending' | 'processing' | 'completed' | 'failed'> = {
  pending: 'pending',
  processing: 'processing',
  completed: 'completed',
  failed: 'failed',
};

export function SubmissionsTable() {
  const { data, isLoading } = useQuery({
    queryKey: ['adminSubmissions'],
    queryFn: () =>
      apiClient
        .get<{ readonly 'hydra:member': readonly TriageSubmissionResource[] }>(ENDPOINTS.ADMIN.SUBMISSIONS)
        .then((r) => r.data['hydra:member']),
    refetchInterval: 5000, // Auto-refresh every 5s
  });

  if (isLoading) return <Loader message="Loading submissions..." />;

  if (!data || data.length === 0) {
    return <p className="py-8 text-center text-gray-500">No submissions yet.</p>;
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr className="border-b border-gray-200 text-left dark:border-gray-700">
            <th className="py-2 pr-4 font-medium text-gray-500">Status</th>
            <th className="py-2 pr-4 font-medium text-gray-500">Specialist</th>
            <th className="py-2 pr-4 font-medium text-gray-500">Urgency</th>
            <th className="py-2 pr-4 font-medium text-gray-500">Time</th>
            <th className="py-2 font-medium text-gray-500">Synthetic</th>
          </tr>
        </thead>
        <tbody>
          {data.map((submission) => (
            <tr key={submission.id} className="border-b border-gray-100 dark:border-gray-800">
              <td className="py-2 pr-4">
                <Badge variant={statusBadge[submission.attributes.status] ?? 'pending'}>
                  {submission.attributes.status}
                </Badge>
              </td>
              <td className="py-2 pr-4 text-gray-900 dark:text-gray-100">
                {submission.attributes.specialist ?? '—'}
              </td>
              <td className="py-2 pr-4">
                {submission.attributes.urgency && (
                  <Badge variant={submission.attributes.urgency.toLowerCase() as 'low' | 'medium' | 'high' | 'emergency'}>
                    {submission.attributes.urgency}
                  </Badge>
                )}
              </td>
              <td className="py-2 pr-4 text-gray-500">{new Date(submission.attributes.submittedAt).toLocaleTimeString()}</td>
              <td className="py-2 text-gray-500">{submission.attributes.isSynthetic ? 'Yes' : 'No'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

- [ ] **Step 3: Write LiveFeed component**

```tsx
// frontend/src/features/admin/components/LiveFeed.tsx
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../../api/client';
import { ENDPOINTS } from '../../../api/endpoints';
import type { TriageSubmissionResource } from '../../../api/types';
import { Card } from '../../../components/ui/Card';

export function LiveFeed() {
  const { data } = useQuery({
    queryKey: ['adminLiveFeed'],
    queryFn: () =>
      apiClient
        .get<{ readonly 'hydra:member': readonly TriageSubmissionResource[] }>(`${ENDPOINTS.ADMIN.SUBMISSIONS}?order[submittedAt]=desc&itemsPerPage=10`)
        .then((r) => r.data['hydra:member']),
    refetchInterval: 2000,
  });

  const recent = data?.slice(0, 5) ?? [];

  return (
    <Card>
      <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100">Live Feed</h3>
      <div className="mt-3 space-y-2">
        {recent.length === 0 && <p className="text-sm text-gray-500">No recent activity</p>}
        {recent.map((s) => (
          <div key={s.id} className="flex items-center justify-between rounded-lg bg-gray-50 px-3 py-2 dark:bg-gray-800">
            <div>
              <p className="text-sm font-medium text-gray-900 dark:text-gray-100">
                {s.attributes.specialist ?? s.attributes.status}
              </p>
              <p className="text-xs text-gray-500">
                {s.attributes.isSynthetic ? 'Synthetic' : 'User'} • {new Date(s.attributes.submittedAt).toLocaleTimeString()}
              </p>
            </div>
          </div>
        ))}
      </div>
    </Card>
  );
}
```

- [ ] **Step 4: Write DashboardPage**

```tsx
// frontend/src/features/admin/pages/DashboardPage.tsx
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { apiClient } from '../../../api/client';
import { ENDPOINTS } from '../../../api/endpoints';
import type { DashboardStats } from '../../../api/types';
import { StatsGrid } from '../components/StatsGrid';
import { SubmissionsTable } from '../components/SubmissionsTable';
import { LiveFeed } from '../components/LiveFeed';
import { Button } from '../../../components/ui/Button';
import { Loader } from '../../../components/shared/Loader';

export function DashboardPage() {
  const queryClient = useQueryClient();

  const { data: stats, isLoading } = useQuery({
    queryKey: ['adminStats'],
    queryFn: () =>
      apiClient.get<{ readonly data: DashboardStats }>(ENDPOINTS.ADMIN.STATS).then((r) => r.data.data),
    refetchInterval: 5000,
  });

  const generateCase = useMutation({
    mutationFn: () => apiClient.post(ENDPOINTS.ADMIN.SYNTHETIC_GENERATE),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['adminStats'] });
      queryClient.invalidateQueries({ queryKey: ['adminSubmissions'] });
      queryClient.invalidateQueries({ queryKey: ['adminLiveFeed'] });
    },
  });

  if (isLoading) return <Loader message="Loading dashboard..." />;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">Admin Dashboard</h1>
        <Button onClick={() => generateCase.mutate()} isLoading={generateCase.isPending}>
          Generate Synthetic Case
        </Button>
      </div>

      {stats && <StatsGrid stats={stats} />}

      <div className="grid gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <div className="rounded-xl border border-gray-200 bg-white p-6 dark:border-gray-800 dark:bg-gray-900">
            <h2 className="mb-4 text-lg font-semibold text-gray-900 dark:text-gray-100">Recent Submissions</h2>
            <SubmissionsTable />
          </div>
        </div>
        <LiveFeed />
      </div>
    </div>
  );
}
```

- [ ] **Step 5: Commit**

```bash
git add frontend/src/features/admin/
git commit -m "feat: add admin dashboard with stats, live feed, and submissions table"
```

---

### Task 10: Admin — Submission detail + Users management

**Files:**
- Create: `frontend/src/features/admin/pages/SubmissionDetailPage.tsx`
- Create: `frontend/src/features/admin/pages/UsersPage.tsx`

**Cross-ref:** Backend `Task 14` — `GET /admin/submissions/{id}` (TriageSubmissionResource with user). Backend `Task 13` — `GET /admin/users` (API Platform collection). Backend `Task 17` — `POST /admin/users/{id}/impersonate`.

- [ ] **Step 1: Write SubmissionDetailPage**

```tsx
// frontend/src/features/admin/pages/SubmissionDetailPage.tsx
import { useParams } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { apiClient } from '../../../api/client';
import { ENDPOINTS } from '../../../api/endpoints';
import type { TriageSubmissionResource } from '../../../api/types';
import { Card } from '../../../components/ui/Card';
import { Badge } from '../../../components/ui/Badge';
import { Loader } from '../../../components/shared/Loader';
import { ChatMessage } from '../../triage/components/ChatMessage';

export function SubmissionDetailPage() {
  const { id } = useParams<{ readonly id: string }>();

  const { data, isLoading } = useQuery({
    queryKey: ['adminSubmission', id],
    queryFn: () =>
      apiClient.get<TriageSubmissionResource>(`${ENDPOINTS.ADMIN.SUBMISSIONS}/${id}`).then((r) => r.data),
    enabled: !!id,
  });

  if (isLoading) return <Loader />;
  if (!data) return <p className="text-red-500">Submission not found</p>;

  const { attributes } = data;

  return (
    <div className="mx-auto max-w-3xl py-8 space-y-6">
      <h1 className="text-2xl font-bold text-gray-900 dark:text-gray-100">Submission Detail</h1>

      <Card>
        <div className="grid gap-3 sm:grid-cols-2">
          <div>
            <p className="text-sm text-gray-500">Status</p>
            <Badge variant={attributes.status as 'pending' | 'completed' | 'processing' | 'failed'}>{attributes.status}</Badge>
          </div>
          <div>
            <p className="text-sm text-gray-500">Type</p>
            <p className="font-medium">{attributes.isSynthetic ? 'Synthetic' : 'User'}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Specialist</p>
            <p className="font-medium">{attributes.specialist ?? '—'}</p>
          </div>
          <div>
            <p className="text-sm text-gray-500">Urgency</p>
            <p className="font-medium">{attributes.urgency ?? '—'}</p>
          </div>
        </div>
      </Card>

      <Card>
        <h3 className="mb-4 text-lg font-semibold">Conversation</h3>
        <div className="space-y-3">
          {attributes.conversationHistory.map((msg, i) => (
            <ChatMessage key={i} message={msg} />
          ))}
        </div>
      </Card>
    </div>
  );
}
```

- [ ] **Step 2: Write UsersPage**

```tsx
// frontend/src/features/admin/pages/UsersPage.tsx
import { useQuery, useMutation } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { apiClient } from '../../../api/client';
import { ENDPOINTS } from '../../../api/endpoints';
import type { UserResource, ImpersonateResponse } from '../../../api/types';
import { Card } from '../../../components/ui/Card';
import { Button } from '../../../components/ui/Button';
import { Loader } from '../../../components/shared/Loader';
import { useAuth } from '../../../hooks/useAuth';

export function UsersPage() {
  const navigate = useNavigate();
  const { login } = useAuth();

  const { data: users, isLoading } = useQuery({
    queryKey: ['adminUsers'],
    queryFn: () =>
      apiClient
        .get<{ readonly 'hydra:member': readonly UserResource[] }>(ENDPOINTS.ADMIN.USERS)
        .then((r) => r.data['hydra:member']),
  });

  const impersonate = useMutation({
    mutationFn: (userId: string) =>
      apiClient.post<ImpersonateResponse>(ENDPOINTS.ADMIN.IMPERSONATE(userId)).then((r) => r.data),
    onSuccess: (data) => {
      login(data.data.token);
      navigate('/triage', { replace: true });
    },
  });

  if (isLoading) return <Loader />;

  return (
    <div className="mx-auto max-w-4xl py-8">
      <h1 className="mb-6 text-2xl font-bold text-gray-900 dark:text-gray-100">Users</h1>

      <Card>
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b text-left">
              <th className="py-2 pr-4 font-medium text-gray-500">Email</th>
              <th className="py-2 pr-4 font-medium text-gray-500">Roles</th>
              <th className="py-2 pr-4 font-medium text-gray-500">Created</th>
              <th className="py-2 font-medium text-gray-500">Actions</th>
            </tr>
          </thead>
          <tbody>
            {users?.map((user) => (
              <tr key={user.id} className="border-b border-gray-100 dark:border-gray-800">
                <td className="py-2 pr-4">{user.attributes.email}</td>
                <td className="py-2 pr-4 text-gray-500">{user.attributes.roles.join(', ')}</td>
                <td className="py-2 pr-4 text-gray-500">{new Date(user.attributes.createdAt).toLocaleDateString()}</td>
                <td className="py-2">
                  <Button
                    size="sm"
                    variant="secondary"
                    onClick={() => impersonate.mutate(user.id)}
                    isLoading={impersonate.isPending}
                  >
                    Login as
                  </Button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  );
}
```

- [ ] **Step 3: Commit**

```bash
git add frontend/src/features/admin/pages/
git commit -m "feat: add admin submission detail + user management with impersonation"
```

---

### Task 11: Frontend tests

**Files:**
- Create: `frontend/tests/setup.ts`
- Create: `frontend/vitest.config.ts` (if not exists)
- Create: `frontend/tests/components/ChatMessage.test.tsx`

- [ ] **Step 1: Write test setup**

```ts
// frontend/tests/setup.ts
import '@testing-library/jest-dom/vitest';
```

```ts
// frontend/vitest.config.ts (or merge into vite.config.ts)
import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: ['./tests/setup.ts'],
    globals: true,
  },
});
```

- [ ] **Step 2: Write ChatMessage test**

```tsx
// frontend/tests/components/ChatMessage.test.tsx
import { render, screen } from '@testing-library/react';
import { describe, it, expect } from 'vitest';
import { ChatMessage } from '../../src/features/triage/components/ChatMessage';

describe('ChatMessage', () => {
  it('renders user message right-aligned', () => {
    const message = {
      role: 'user' as const,
      content: 'my head hurts',
      type: 'initial_description' as const,
      timestamp: new Date().toISOString(),
    };

    render(<ChatMessage message={message} />);
    const container = screen.getByText('my head hurts').parentElement!;
    expect(container.className).toContain('justify-end');
  });

  it('renders assistant message left-aligned', () => {
    const message = {
      role: 'assistant' as const,
      content: 'Where does it hurt?',
      type: 'follow_up' as const,
      timestamp: new Date().toISOString(),
    };

    render(<ChatMessage message={message} />);
    const container = screen.getByText('Where does it hurt?').parentElement!;
    expect(container.className).toContain('justify-start');
  });

  it('shows "Final assessment" for result type messages', () => {
    const message = {
      role: 'assistant' as const,
      content: 'Result text',
      type: 'result' as const,
      timestamp: new Date().toISOString(),
    };

    render(<ChatMessage message={message} />);
    expect(screen.getByText('Final assessment')).toBeInTheDocument();
  });
});
```

- [ ] **Step 3: Run tests**

```bash
workdir: frontend
npm run test -- --run
```

Expected: 3 tests pass.

- [ ] **Step 4: Commit**

```bash
git add frontend/tests/ frontend/vitest.config.ts
git commit -m "test: add ChatMessage component tests + Vitest config"
```

---

## Self-Review

**1. Spec coverage check:**
- Vite + React + TS + Tailwind scaffold → Task 1
- API client (Axios, JWT, TanStack Query) → Task 2
- UI components (Button, Card, Input, Badge, etc.) → Task 3
- Triage interview (chat UI + polling) → Task 4
- Triage result page → Task 5
- My Submissions page → Task 6
- App layout + routing + auth hook → Task 7
- Login + Registration → Task 8
- Admin dashboard (stats, table, live feed) → Task 9
- Admin detail + user management → Task 10
- Frontend tests → Task 11

**2. Placeholder scan:** No TBD/TODO. All code shown in full.

**3. Type consistency:** API types in `api/types.ts` (Task 2) used consistently across Tasks 4-6, 8-10. Hook signatures match API client calls.
