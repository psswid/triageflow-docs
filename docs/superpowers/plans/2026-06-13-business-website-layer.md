# Business Website Layer + i18n + Dark Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the frontend from a bare authenticated SPA into a dual-purpose application: public-facing marketing website (landing, about, how-it-works, legal pages) + authenticated triage tool — with i18n (EN + PL), dark mode toggle, cookie consent, and a unified medical triage design system.

**Architecture:** Two layout wrappers — `MarketingLayout` for public unauthenticated pages (with own header, footer, dark mode toggle, language switcher) and the existing `AppLayout` for authenticated pages. Both share a single `I18nProvider` (react-i18next), `ThemeProvider` (dark mode via system preference + localStorage override), and unified Tailwind design tokens. All pages translated via JSON locale files.

**Tech Stack:** react-i18next, i18next-browser-languagedetector, react-helmet-async, lucide-react (icon system), Tailwind CSS 4, Poppins (Google Fonts headings), React Router 7, TanStack Query (existing), clsx (existing)

---

## File Structure Map

```
src/
├── i18n/
│   ├── index.ts                          # i18next initialization + browser detection
│   └── locales/
│       ├── en/
│       │   ├── common.json               # Shared: buttons, nav, footer, errors
│       │   ├── landing.json              # Landing page copy
│       │   ├── about.json                # About page copy
│       │   ├── howItWorks.json           # How It Works page copy
│       │   ├── legal.json                # Privacy, Terms, Cookies pages
│       │   ├── auth.json                 # Login, Register, Verify Email
│       │   ├── triage.json               # Triage interview + result pages
│       │   └── admin.json                # Dashboard, submissions, users
│       └── pl/
│           ├── common.json
│           ├── landing.json
│           ├── about.json
│           ├── howItWorks.json
│           ├── legal.json
│           ├── auth.json
│           ├── triage.json
│           └── admin.json
├── hooks/
│   ├── useAuth.ts                        # (existing)
│   └── useDarkMode.ts                    # NEW: system pref + localStorage + toggle
├── components/
│   ├── auth/
│   │   └── AuthProvider.tsx              # (existing — add I18nProvider integration)
│   ├── layout/
│   │   ├── AdminRoute.tsx                # (existing)
│   │   ├── AppLayout.tsx                 # (existing — add Footer)
│   │   ├── Header.tsx                    # (existing — add i18n)
│   │   ├── ImpersonationBanner.tsx       # (existing — add i18n)
│   │   ├── ProtectedRoute.tsx            # (existing)
│   │   ├── MarketingLayout.tsx           # NEW: public page wrapper
│   │   ├── MarketingHeader.tsx           # NEW: public nav (Home, About, How It Works, Login, dark toggle, lang switcher)
│   │   └── Footer.tsx                    # NEW: copyright, legal links, dark toggle, lang switcher
│   ├── shared/
│   │   ├── CookieBanner.tsx              # NEW: minimal consent notice
│   │   ├── DarkModeToggle.tsx            # NEW: sun/moon icon button
│   │   ├── LanguageSwitcher.tsx          # NEW: EN/PL toggle
│   │   ├── EmptyState.tsx                # (existing — add i18n)
│   │   ├── ErrorBoundary.tsx             # (existing)
│   │   ├── ErrorFallback.tsx             # (existing — add i18n)
│   │   ├── Loader.tsx                    # (existing — add i18n)
│   │   ├── NotFoundPage.tsx              # (existing — add i18n)
│   │   └── RouteErrorFallback.tsx        # (existing — add i18n)
│   └── ui/
│       ├── Badge.tsx                     # (existing)
│       ├── Button.tsx                    # (existing)
│       ├── Card.tsx                      # (existing)
│       ├── Input.tsx                     # (existing — add i18n props)
│       ├── Skeleton.tsx                  # (existing)
│       ├── Spinner.tsx                   # (existing)
│       ├── Toast.tsx                     # (existing — add i18n)
│       └── ToastProvider.tsx             # (existing)
├── features/
│   ├── marketing/
│   │   ├── pages/
│   │   │   ├── LandingPage.tsx           # NEW: hero + features + CTA
│   │   │   ├── AboutPage.tsx             # NEW: project story + tech stack
│   │   │   ├── HowItWorksPage.tsx        # NEW: step-by-step triage flow
│   │   │   ├── PrivacyPage.tsx           # NEW: GDPR privacy policy
│   │   │   ├── TermsPage.tsx             # NEW: demo disclaimer
│   │   │   ├── CookiesPage.tsx           # NEW: what localStorage we use
│   │   │   └── ContactPage.tsx           # NEW: link to portfolio
│   │   └── components/
│   │   ├── HeroSection.tsx           # NEW: landing hero with glassmorphism frosted card
│   │   ├── StepCard.tsx              # NEW: How It Works step cards with timeline
│   │   ├── TableOfContents.tsx       # NEW: sticky sidebar nav for legal pages
│   │   └── DemoPreview.tsx           # NEW: screenshot browser-mockup section
│   ├── auth/pages/                       # (existing — wrap with i18n)
│   │   ├── LoginPage.tsx
│   │   ├── RegisterPage.tsx
│   │   └── VerifyEmailPage.tsx
│   ├── triage/pages/                     # (existing — wrap with i18n)
│   │   ├── TriagePage.tsx
│   │   └── TriageResultPage.tsx
│   ├── triage/components/                # (existing — wrap with i18n)
│   │   ├── AnswerInput.tsx
│   │   ├── ConversationBubble.tsx
│   │   ├── OutcomeCard.tsx
│   │   ├── SymptomInput.tsx
│   │   └── UrgencyBadge.tsx
│   ├── submissions/pages/                # (existing — wrap with i18n)
│   │   └── MySubmissionsPage.tsx
│   ├── submissions/components/           # (existing — wrap with i18n)
│   │   └── SubmissionsList.tsx
│   └── admin/pages/                      # (existing — wrap with i18n)
│       ├── DashboardPage.tsx
│       ├── SubmissionDetailPage.tsx
│       └── UsersPage.tsx
├── styles/
│   └── index.css                         # (expand — teal, slate, typography tokens)
├── routes.tsx                            # (add public routes, wrap in providers)
├── App.tsx                               # (add HelmetProvider, I18nProvider, ThemeProvider)
├── main.tsx                              # (existing)
└── index.html                            # (update <title>, add lang attribute as template)
```

---

## Task 1: Install Dependencies + Expand Design Tokens

**Files:**
- Modify: `frontend/package.json`
- Modify: `frontend/src/styles/index.css`

- [ ] **Step 1: Install i18n + helmet + icon packages**

```bash
cd frontend && pnpm add react-i18next i18next i18next-browser-languagedetector react-helmet-async lucide-react
```

Expected: packages added to `package.json` and `node_modules/`.

- [ ] **Step 2: Expand design tokens in index.css**

Read current `frontend/src/styles/index.css`, then replace the `@theme` block with expanded tokens:

```css
@import "tailwindcss";
@import url('https://fonts.googleapis.com/css2?family=Poppins:wght@600;700&display=swap');

@variant dark (&:where(.dark, .dark *));

@theme {
  /* Primary — trust, clinical authority */
  --color-primary-50: #eff6ff;
  --color-primary-100: #dbeafe;
  --color-primary-200: #bfdbfe;
  --color-primary-300: #93c5fd;
  --color-primary-400: #60a5fa;
  --color-primary-500: #3b82f6;
  --color-primary-600: #2563eb;
  --color-primary-700: #1d4ed8;
  --color-primary-800: #1e40af;
  --color-primary-900: #1e3a5f;
  --color-primary-950: #172554;

  /* Accent — modern medical tech, teal */
  --color-accent-50: #f0fdfa;
  --color-accent-100: #ccfbf1;
  --color-accent-200: #99f6e4;
  --color-accent-300: #5eead4;
  --color-accent-400: #2dd4bf;
  --color-accent-500: #14b8a6;
  --color-accent-600: #0d9488;
  --color-accent-700: #0f766e;
  --color-accent-800: #115e59;
  --color-accent-900: #134e4a;
  --color-accent-950: #042f2e;

  /* Urgency scale — triage coding */
  --color-urgency-low: #22c55e;
  --color-urgency-medium: #eab308;
  --color-urgency-high: #f97316;
  --color-urgency-emergency: #ef4444;

  /* Surface — clean clinical backgrounds */
  --color-surface-50: #f8fafc;
  --color-surface-100: #f1f5f9;
  --color-surface-200: #e2e8f0;
  --color-surface-300: #cbd5e1;
  --color-surface-400: #94a3b8;
  --color-surface-500: #64748b;
  --color-surface-600: #475569;
  --color-surface-700: #334155;
  --color-surface-800: #1e293b;
  --color-surface-900: #0f172a;
  --color-surface-950: #020617;

  /* Typography */
  --font-sans: 'Inter', ui-sans-serif, system-ui, sans-serif;
  --font-heading: 'Poppins', 'Inter', ui-sans-serif, system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', ui-monospace, monospace;

  /* Radius */
  --radius-sm: 0.375rem;
  --radius-md: 0.5rem;
  --radius-lg: 0.75rem;
  --radius-xl: 1rem;
  --radius-2xl: 1.5rem;
}

html {
  @apply bg-white text-gray-900 dark:bg-gray-950 dark:text-gray-100;
}

body {
  @apply antialiased;
}
```

- [ ] **Step 3: Verify build still passes**

```bash
cd frontend && pnpm build
```

Expected: build succeeds (0 errors). New tokens available via `bg-accent-500`, `text-surface-700`, etc.

- [ ] **Step 4: Commit**

```bash
cd frontend && git add package.json pnpm-lock.yaml src/styles/index.css
git commit -m "feat: install i18n/helmet/lucide deps, add Poppins font, expand design tokens with teal accent, surface scale, typography, and radius tokens"
```

---

## Task 2: i18n Infrastructure — Setup + EN Locale Files

**Files:**
- Create: `frontend/src/i18n/index.ts`
- Create: `frontend/src/i18n/locales/en/common.json`
- Create: `frontend/src/i18n/locales/en/landing.json`
- Create: `frontend/src/i18n/locales/en/about.json`
- Create: `frontend/src/i18n/locales/en/howItWorks.json`
- Create: `frontend/src/i18n/locales/en/legal.json`
- Create: `frontend/src/i18n/locales/en/auth.json`
- Create: `frontend/src/i18n/locales/en/triage.json`
- Create: `frontend/src/i18n/locales/en/admin.json`

- [ ] **Step 1: Create i18n initialization**

`frontend/src/i18n/index.ts`:

```typescript
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import LanguageDetector from 'i18next-browser-languagedetector';

import common from './locales/en/common.json';
import landing from './locales/en/landing.json';
import about from './locales/en/about.json';
import howItWorks from './locales/en/howItWorks.json';
import legal from './locales/en/legal.json';
import auth from './locales/en/auth.json';
import triage from './locales/en/triage.json';
import admin from './locales/en/admin.json';

i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources: {
      en: {
        common,
        landing,
        about,
        howItWorks,
        legal,
        auth,
        triage,
        admin,
      },
    },
    fallbackLng: 'en',
    defaultNS: 'common',
    interpolation: {
      escapeValue: false, // React already escapes
    },
    detection: {
      order: ['localStorage', 'navigator'],
      caches: ['localStorage'],
      lookupLocalStorage: 'i18nextLng',
    },
  });

export default i18n;
```

- [ ] **Step 2: Create English locale files**

`frontend/src/i18n/locales/en/common.json`:

```json
{
  "appName": "TriageFlow",
  "tagline": "AI-Powered Patient Pre-Screening Demo",
  "nav": {
    "home": "Home",
    "about": "About",
    "howItWorks": "How It Works",
    "login": "Log In",
    "register": "Register",
    "logout": "Log Out",
    "newTriage": "New Triage",
    "mySubmissions": "My Submissions",
    "admin": "Admin",
    "backToAdmin": "Back to Admin"
  },
  "footer": {
    "copyright": "© 2026 Piotr Świderski. All rights reserved.",
    "builtWith": "Built with Symfony, React, and AI — a portfolio project.",
    "privacy": "Privacy Policy",
    "terms": "Terms of Service",
    "cookies": "Cookie Policy",
    "contact": "Contact"
  },
  "languageSwitcher": {
    "label": "Language",
    "en": "English",
    "pl": "Polski"
  },
  "darkMode": {
    "toggle": "Toggle dark mode",
    "light": "Light mode",
    "dark": "Dark mode"
  },
  "cookieBanner": {
    "message": "This demo uses browser storage for authentication and preferences. No tracking. No cookies (in the traditional sense).",
    "accept": "OK, got it"
  },
  "loading": "Loading...",
  "error": {
    "title": "Something went wrong",
    "retry": "Try Again",
    "goHome": "Go Home",
    "details": "Error details"
  },
  "notFound": {
    "title": "Page Not Found",
    "message": "The page you're looking for doesn't exist.",
    "goHome": "Go to Home"
  },
  "empty": {
    "title": "Nothing here yet",
    "message": "Check back later."
  }
}
```

`frontend/src/i18n/locales/en/landing.json`:

```json
{
  "hero": {
    "title": "Tired of waiting for your first-contact medical specialist?",
    "subtitle": "Let's hallucinate who can help you based on your symptoms!",
    "disclaimer": "In case of a real medical issue, please contact a human specialist. This is a demonstration system.",
    "cta": "Try the Demo",
    "secondaryCta": "See How It Works"
  },
  "features": {
    "title": "What This Demo Showcases",
    "aiTriage": {
      "title": "AI-Powered Triage",
      "description": "An LLM-driven interview pipeline that asks follow-up questions and produces a triage recommendation — specialist, urgency, and justification."
    },
    "fullStack": {
      "title": "Full-Stack Architecture",
      "description": "Symfony 7.4 backend with DDD-inspired bounded contexts, async message queue, and PostgreSQL. React 19 frontend with TypeScript and TanStack Query."
    },
    "synthetic": {
      "title": "Synthetic Case Generator",
      "description": "A cron-driven scheduler that generates realistic symptom descriptions and simulates patient-AI conversations — the system runs itself."
    },
    "observability": {
      "title": "Observability & Monitoring",
      "description": "Structured logging with correlation IDs, failed message recovery, CI pipeline with PHPStan level 5."
    }
  },
  "techStack": {
    "title": "Tech Stack",
    "backend": "Backend",
    "frontend": "Frontend",
    "infra": "Infrastructure"
  }
}
```

`frontend/src/i18n/locales/en/about.json`:

```json
{
  "title": "About This Project",
  "intro": "TriageFlow is a two-week portfolio project demonstrating full-stack development proficiency with modern tools and AI integration.",
  "who": {
    "title": "Who Built This",
    "description": "Built by Piotr Świderski — a full-stack developer exploring the intersection of AI, healthcare simulation, and modern web architecture."
  },
  "why": {
    "title": "Why TriageFlow",
    "description": "The medical triage domain provides rich modeling challenges: state machines, async messaging, AI pipelines, and role-based access control — all in a compact, demonstrable scope."
  },
  "disclaimer": {
    "title": "Important Disclaimer",
    "description": "TriageFlow is a demonstration system. It does not provide real medical advice. All triage recommendations are generated by AI for illustrative purposes only. If you have a medical concern, please consult a qualified healthcare professional."
  }
}
```

`frontend/src/i18n/locales/en/howItWorks.json`:

```json
{
  "title": "How It Works",
  "subtitle": "A 4-step AI-powered triage pipeline, from symptom to recommendation.",
  "steps": {
    "step1": {
      "title": "1. Describe Your Symptoms",
      "description": "You start by describing what's bothering you — in your own words, just like you would to a real doctor. No forms, no checkboxes."
    },
    "step2": {
      "title": "2. AI Follow-Up Questions",
      "description": "The AI analyzes your description and asks clarifying follow-up questions, just like a triage nurse would. Up to 3 rounds of Q&A."
    },
    "step3": {
      "title": "3. Triage Recommendation",
      "description": "When the AI has enough information, it produces a recommendation: which specialist you should see, how urgent it is, and why."
    },
    "step4": {
      "title": "4. Review & Next Steps",
      "description": "You can review your full conversation history and the triage outcome. The system is transparent — you see exactly what the AI saw."
    }
  },
  "cta": "Try It Yourself",
  "disclaimer": "Remember: this is a demo. Not real medical advice. See our Terms of Service for details."
}
```

`frontend/src/i18n/locales/en/legal.json`:

```json
{
  "privacy": {
    "title": "Privacy Policy",
    "lastUpdated": "Last updated: June 13, 2026",
    "intro": "TriageFlow is a demonstration portfolio project. This privacy policy explains what data we collect and how we use it.",
    "dataCollected": {
      "title": "What Data We Collect",
      "items": [
        "Email address — used for account registration and login.",
        "Symptom descriptions — the text you enter during triage interviews.",
        "Triage outcomes — AI-generated recommendations based on your symptoms."
      ]
    },
    "dataUsage": {
      "title": "How We Use Your Data",
      "items": [
        "Authentication: your email identifies your account.",
        "Triage functionality: your symptom descriptions are sent to an AI model (OpenRouter) to generate triage recommendations.",
        "No data is sold, shared with third parties, or used for marketing."
      ]
    },
    "storage": {
      "title": "Data Storage",
      "items": [
        "All data is stored in a PostgreSQL database.",
        "JWT authentication tokens are stored in your browser's localStorage.",
        "Language and theme preferences are stored in localStorage.",
        "No tracking cookies, analytics, or third-party scripts are used."
      ]
    },
    "rights": {
      "title": "Your Rights",
      "description": "As this is a demo system with no persistent production deployment, data may be reset at any time. You can delete your account and all associated data by contacting the developer."
    },
    "contact": "For privacy-related questions, contact piotr@piotrswiderski.dev"
  },
  "terms": {
    "title": "Terms of Service",
    "lastUpdated": "Last updated: June 13, 2026",
    "intro": "By using TriageFlow, you acknowledge and agree to the following terms.",
    "demoNature": {
      "title": "Demonstration System",
      "description": "TriageFlow is a portfolio demonstration project, not a production medical service. All triage recommendations are generated by artificial intelligence for illustrative purposes only."
    },
    "notMedicalAdvice": {
      "title": "Not Medical Advice",
      "description": "The AI-generated triage recommendations are not real medical advice. They are synthetic demonstrations of what an AI triage pipeline could produce. Do not rely on them for actual medical decisions. If you have a medical concern, consult a qualified healthcare professional immediately."
    },
    "noLiability": {
      "title": "No Liability",
      "description": "The developer assumes no liability for any actions taken based on the AI-generated content in this demo application. Use is entirely at your own risk."
    },
    "dataHandling": {
      "title": "Data Handling",
      "description": "Data submitted to this demo may be processed by third-party AI providers (OpenRouter). No data is sold or used for purposes beyond the demo functionality. See our Privacy Policy for details."
    }
  },
  "cookies": {
    "title": "Cookie Policy",
    "lastUpdated": "Last updated: June 13, 2026",
    "intro": "TriageFlow doesn't use traditional browser cookies. Here's what we store in your browser:",
    "localStorage": {
      "title": "Local Storage Usage",
      "items": [
        "JWT authentication token — required to keep you logged in (essential).",
        "Language preference — remembers whether you chose English or Polish (preference).",
        "Theme preference — remembers whether you chose light or dark mode (preference).",
        "Cookie consent acknowledgment — remembers that you've seen the consent notice."
      ]
    },
    "sessionStorage": {
      "title": "Session Storage Usage",
      "items": [
        "Admin impersonation state — temporarily stores the admin's original token during user impersonation. Cleared when the tab is closed."
      ]
    },
    "noTracking": {
      "title": "No Tracking",
      "description": "We do not use any analytics, tracking cookies, third-party scripts, or any form of user behavior tracking. This is a demo application — what you see is what you get."
    }
  }
}
```

`frontend/src/i18n/locales/en/auth.json`:

```json
{
  "login": {
    "title": "Log In",
    "email": "Email",
    "emailPlaceholder": "you@example.com",
    "password": "Password",
    "passwordPlaceholder": "Enter your password",
    "submit": "Log In",
    "submitting": "Logging in...",
    "noAccount": "Don't have an account?",
    "registerLink": "Register",
    "invalidCredentials": "Invalid email or password.",
    "unverified": "Please verify your email address before logging in.",
    "registrationSuccess": "Account created! Check your email to verify your address, then log in.",
    "checkMailpit": "In development: check Mailpit at http://localhost:8025 for the verification email."
  },
  "register": {
    "title": "Create Account",
    "email": "Email",
    "emailPlaceholder": "you@example.com",
    "password": "Password",
    "passwordPlaceholder": "Min. 8 characters",
    "confirmPassword": "Confirm Password",
    "confirmPasswordPlaceholder": "Repeat your password",
    "submit": "Create Account",
    "submitting": "Creating account...",
    "haveAccount": "Already have an account?",
    "loginLink": "Log In",
    "passwordMismatch": "Passwords do not match.",
    "emailTaken": "This email is already registered.",
    "validation": {
      "emailRequired": "Email is required.",
      "emailInvalid": "Please enter a valid email.",
      "passwordRequired": "Password is required.",
      "passwordMinLength": "Password must be at least 8 characters."
    }
  },
  "verifyEmail": {
    "title": "Email Verification",
    "verifying": "Verifying your email...",
    "success": "Email verified successfully! You can now log in.",
    "invalidToken": "Invalid verification link.",
    "expiredToken": "This verification link has expired. Please register again.",
    "alreadyVerified": "Email already verified.",
    "goToLogin": "Go to Login"
  }
}
```

`frontend/src/i18n/locales/en/triage.json`:

```json
{
  "title": "New Triage",
  "subtitle": "Describe your symptoms and the AI will ask follow-up questions to determine urgency and specialist.",
  "symptomInput": {
    "label": "Describe your symptoms",
    "placeholder": "e.g., I have a severe headache that started this morning...",
    "maxLength": "Maximum 500 characters",
    "submit": "Submit Symptoms",
    "submitting": "Analyzing your symptoms..."
  },
  "answerInput": {
    "label": "Your answer",
    "placeholder": "Type your answer here...",
    "maxLength": "Maximum 300 characters",
    "submit": "Send Answer"
  },
  "status": {
    "pending": "Submitting your symptoms...",
    "processing": "AI is analyzing your symptoms...",
    "awaitingAnswer": "The AI has a follow-up question for you.",
    "completed": "Triage complete!",
    "failed": "Something went wrong. Please try again."
  },
  "conversation": {
    "you": "You",
    "aiAssistant": "AI Assistant",
    "initialDescription": "Your initial description",
    "finalResult": "Triage result available"
  },
  "result": {
    "title": "Triage Result",
    "specialist": "Recommended Specialist",
    "urgency": "Urgency",
    "justification": "Justification",
    "conversationHistory": "Conversation History",
    "processingTime": "Processing time",
    "seconds": "{{count}} second",
    "seconds_plural": "{{count}} seconds",
    "notCompleted": "Triage not yet completed",
    "checkBack": "The AI is still analyzing your case. Check back shortly.",
    "goToNewTriage": "Start New Triage"
  },
  "urgencyLabels": {
    "low": "Low",
    "medium": "Medium",
    "high": "High",
    "emergency": "Emergency"
  },
  "submissions": {
    "title": "My Submissions",
    "empty": "You haven't submitted any triage cases yet.",
    "startTriage": "Start Your First Triage",
    "viewResult": "View Result",
    "viewDetails": "View Details",
    "table": {
      "date": "Date",
      "status": "Status",
      "urgency": "Urgency",
      "specialist": "Specialist",
      "synthetic": "Synthetic",
      "actions": "Actions"
    }
  }
}
```

`frontend/src/i18n/locales/en/admin.json`:

```json
{
  "dashboard": {
    "title": "Admin Dashboard",
    "tabs": {
      "overview": "Overview",
      "submissions": "Submissions",
      "users": "Users",
      "failedMessages": "Failed Messages"
    },
    "stats": {
      "totalSubmissions": "Total Submissions",
      "syntheticCases": "Synthetic Cases",
      "userCases": "User Cases",
      "avgProcessingTime": "Avg Processing Time",
      "byStatus": "By Status",
      "bySpecialist": "By Specialist",
      "byUrgency": "By Urgency"
    },
    "generateSynthetic": {
      "button": "Generate Synthetic Case",
      "generating": "Generating...",
      "success": "Synthetic case generated! It will appear in the submissions list shortly."
    },
    "submissions": {
      "title": "All Submissions",
      "empty": "No submissions yet.",
      "table": {
        "user": "User",
        "date": "Date",
        "status": "Status",
        "urgency": "Urgency",
        "specialist": "Specialist",
        "synthetic": "Synthetic",
        "processingTime": "Time",
        "actions": "Actions"
      },
      "viewDetails": "View Details"
    },
    "users": {
      "title": "Users",
      "empty": "No users found.",
      "table": {
        "email": "Email",
        "roles": "Roles",
        "created": "Created",
        "actions": "Actions"
      },
      "impersonate": "Impersonate"
    },
    "failedMessages": {
      "title": "Failed Messages",
      "empty": "No failed messages.",
      "table": {
        "type": "Type",
        "error": "Error",
        "preview": "Preview",
        "timestamp": "Timestamp",
        "actions": "Actions"
      },
      "retry": "Retry",
      "retrying": "Retrying...",
      "delete": "Delete"
    },
    "impersonation": {
      "banner": "Viewing as {{email}}",
      "backToAdmin": "Back to Admin"
    }
  },
  "submissionDetail": {
    "title": "Submission Detail",
    "submissionInfo": "Submission Info",
    "user": "User",
    "submittedAt": "Submitted",
    "status": "Status",
    "processingTime": "Processing Time",
    "synthetic": "Synthetic Case",
    "conversation": "Conversation History",
    "notFound": "Submission not found.",
    "backToList": "Back to Submissions"
  }
}
```

- [ ] **Step 3: Verify TypeScript compiles with i18n imports**

```bash
cd frontend && npx tsc --noEmit src/i18n/index.ts
```

Expected: no errors (i18next types are self-contained).

- [ ] **Step 4: Commit**

```bash
cd frontend && git add src/i18n/
git commit -m "feat(i18n): add i18next setup and English locale files for all namespaces"
```

---

## Task 3: PL Locale Files (Polish Translations)

**Files:**
- Create: `frontend/src/i18n/locales/pl/common.json`
- Create: `frontend/src/i18n/locales/pl/landing.json`
- Create: `frontend/src/i18n/locales/pl/about.json`
- Create: `frontend/src/i18n/locales/pl/howItWorks.json`
- Create: `frontend/src/i18n/locales/pl/legal.json`
- Create: `frontend/src/i18n/locales/pl/auth.json`
- Create: `frontend/src/i18n/locales/pl/triage.json`
- Create: `frontend/src/i18n/locales/pl/admin.json`
- Modify: `frontend/src/i18n/index.ts` (add PL resources import)

- [ ] **Step 1: Create Polish locale files**

`frontend/src/i18n/locales/pl/common.json`:

```json
{
  "appName": "TriageFlow",
  "tagline": "Demo Preselekcji Medycznej Wspieranej przez AI",
  "nav": {
    "home": "Strona Główna",
    "about": "O Projekcie",
    "howItWorks": "Jak To Działa",
    "login": "Zaloguj Się",
    "register": "Zarejestruj Się",
    "logout": "Wyloguj Się",
    "newTriage": "Nowa Selekcja",
    "mySubmissions": "Moje Zgłoszenia",
    "admin": "Admin",
    "backToAdmin": "Powrót do Admina"
  },
  "footer": {
    "copyright": "© 2026 Piotr Świderski. Wszelkie prawa zastrzeżone.",
    "builtWith": "Zbudowane z Symfony, React i AI — projekt portfolio.",
    "privacy": "Polityka Prywatności",
    "terms": "Warunki Korzystania",
    "cookies": "Polityka Plików Cookie",
    "contact": "Kontakt"
  },
  "languageSwitcher": {
    "label": "Język",
    "en": "English",
    "pl": "Polski"
  },
  "darkMode": {
    "toggle": "Przełącz tryb ciemny",
    "light": "Tryb jasny",
    "dark": "Tryb ciemny"
  },
  "cookieBanner": {
    "message": "To demo używa przeglądarkowej pamięci lokalnej do autoryzacji i preferencji. Bez śledzenia. Bez tradycyjnych plików cookie.",
    "accept": "OK, rozumiem"
  },
  "loading": "Ładowanie...",
  "error": {
    "title": "Coś poszło nie tak",
    "retry": "Spróbuj Ponownie",
    "goHome": "Strona Główna",
    "details": "Szczegóły błędu"
  },
  "notFound": {
    "title": "Strona Nie Znaleziona",
    "message": "Strona, której szukasz, nie istnieje.",
    "goHome": "Przejdź na Stronę Główną"
  },
  "empty": {
    "title": "Jeszcze nic tu nie ma",
    "message": "Zajrzyj później."
  }
}
```

`frontend/src/i18n/locales/pl/landing.json`:

```json
{
  "hero": {
    "title": "Masz dość czekania na pierwszą konsultację medyczną?",
    "subtitle": "Pozwól nam zhalucynować, kto może Ci pomóc na podstawie Twoich objawów!",
    "disclaimer": "W przypadku prawdziwego problemu medycznego skontaktuj się z prawdziwym specjalistą. To jest system demonstracyjny.",
    "cta": "Wypróbuj Demo",
    "secondaryCta": "Zobacz Jak To Działa"
  },
  "features": {
    "title": "Co Demonstruje Ten Projekt",
    "aiTriage": {
      "title": "Selekcja Wspierana przez AI",
      "description": "Pipeline wywiadu sterowany przez LLM, który zadaje pytania uzupełniające i generuje rekomendację — specjalista, pilność, uzasadnienie."
    },
    "fullStack": {
      "title": "Architektura Full-Stack",
      "description": "Backend Symfony 7.4 z kontekstami ograniczonymi w stylu DDD, asynchroniczną kolejką wiadomości i PostgreSQL. Frontend React 19 z TypeScript i TanStack Query."
    },
    "synthetic": {
      "title": "Generator Syntetycznych Przypadków",
      "description": "Harmonogram cron generujący realistyczne opisy objawów i symulujący rozmowy pacjent-AI — system działa samodzielnie."
    },
    "observability": {
      "title": "Obserwowalność i Monitoring",
      "description": "Strukturyzowane logowanie z identyfikatorami korelacji, odzyskiwanie nieudanych wiadomości, pipeline CI z PHPStan poziom 5."
    }
  },
  "techStack": {
    "title": "Stack Technologiczny",
    "backend": "Backend",
    "frontend": "Frontend",
    "infra": "Infrastruktura"
  }
}
```

`frontend/src/i18n/locales/pl/about.json`:

```json
{
  "title": "O Projekcie",
  "intro": "TriageFlow to dwutygodniowy projekt portfolio demonstrujący biegłość w full-stack development z nowoczesnymi narzędziami i integracją AI.",
  "who": {
    "title": "Kto To Zbudował",
    "description": "Zbudowane przez Piotra Świderskiego — full-stack developera eksplorującego przecięcie AI, symulacji medycznych i nowoczesnej architektury webowej."
  },
  "why": {
    "title": "Dlaczego TriageFlow",
    "description": "Domena selekcji medycznej dostarcza bogatych wyzwań modelowania: maszyny stanów, asynchroniczne wiadomości, pipeline'y AI i kontrolę dostępu opartą na rolach — wszystko w kompaktowym, demonstracyjnym zakresie."
  },
  "disclaimer": {
    "title": "Ważne Zastrzeżenie",
    "description": "TriageFlow jest systemem demonstracyjnym. Nie udziela prawdziwych porad medycznych. Wszystkie rekomendacje selekcji są generowane przez AI wyłącznie w celach ilustracyjnych. Jeśli masz problem medyczny, skonsultuj się z wykwalifikowanym specjalistą."
  }
}
```

`frontend/src/i18n/locales/pl/howItWorks.json`:

```json
{
  "title": "Jak To Działa",
  "subtitle": "4-etapowy pipeline selekcji wspieranej przez AI, od objawu do rekomendacji.",
  "steps": {
    "step1": {
      "title": "1. Opisz Swoje Objawy",
      "description": "Zaczynasz od opisania co Ci dolega — własnymi słowami, tak jak powiedziałbyś prawdziwemu lekarzowi. Bez formularzy, bez checkboxów."
    },
    "step2": {
      "title": "2. Pytania Uzupełniające AI",
      "description": "AI analizuje Twój opis i zadaje doprecyzowujące pytania, tak jak zrobiłaby to pielęgniarka podczas selekcji. Do 3 rund pytań i odpowiedzi."
    },
    "step3": {
      "title": "3. Rekomendacja Selekcji",
      "description": "Gdy AI ma wystarczająco informacji, generuje rekomendację: do jakiego specjalisty powinieneś się udać, jak pilna jest sprawa i dlaczego."
    },
    "step4": {
      "title": "4. Przegląd i Następne Kroki",
      "description": "Możesz przejrzeć pełną historię rozmowy i wynik selekcji. System jest transparentny — widzisz dokładnie to, co widziała AI."
    }
  },
  "cta": "Wypróbuj Sam",
  "disclaimer": "Pamiętaj: to demo. Nie prawdziwa porada medyczna. Szczegóły w Warunkach Korzystania."
}
```

`frontend/src/i18n/locales/pl/legal.json`:

```json
{
  "privacy": {
    "title": "Polityka Prywatności",
    "lastUpdated": "Ostatnia aktualizacja: 13 czerwca 2026",
    "intro": "TriageFlow jest demonstracyjnym projektem portfolio. Ta polityka prywatności wyjaśnia, jakie dane zbieramy i jak ich używamy.",
    "dataCollected": {
      "title": "Jakie Dane Zbieramy",
      "items": [
        "Adres email — używany do rejestracji konta i logowania.",
        "Opisy objawów — tekst wprowadzany podczas wywiadów selekcji.",
        "Wyniki selekcji — rekomendacje generowane przez AI na podstawie Twoich objawów."
      ]
    },
    "dataUsage": {
      "title": "Jak Wykorzystujemy Twoje Dane",
      "items": [
        "Uwierzytelnianie: Twój email identyfikuje Twoje konto.",
        "Funkcjonalność selekcji: Twoje opisy objawów są wysyłane do modelu AI (OpenRouter) w celu generowania rekomendacji.",
        "Żadne dane nie są sprzedawane, udostępniane stronom trzecim ani wykorzystywane do marketingu."
      ]
    },
    "storage": {
      "title": "Przechowywanie Danych",
      "items": [
        "Wszystkie dane są przechowywane w bazie danych PostgreSQL.",
        "Tokeny uwierzytelniania JWT są przechowywane w localStorage przeglądarki.",
        "Preferencje języka i motywu są przechowywane w localStorage.",
        "Nie używamy plików cookie śledzących, analityki ani skryptów stron trzecich."
      ]
    },
    "rights": {
      "title": "Twoje Prawa",
      "description": "Ponieważ jest to system demonstracyjny bez trwałego wdrożenia produkcyjnego, dane mogą być resetowane w dowolnym momencie. Możesz usunąć swoje konto i wszystkie powiązane dane, kontaktując się z deweloperem."
    },
    "contact": "Pytania dotyczące prywatności: piotr@piotrswiderski.dev"
  },
  "terms": {
    "title": "Warunki Korzystania",
    "lastUpdated": "Ostatnia aktualizacja: 13 czerwca 2026",
    "intro": "Korzystając z TriageFlow, potwierdzasz i akceptujesz następujące warunki.",
    "demoNature": {
      "title": "System Demonstracyjny",
      "description": "TriageFlow jest projektem demonstracyjnym, a nie produkcyjną usługą medyczną. Wszystkie rekomendacje selekcji są generowane przez sztuczną inteligencję wyłącznie w celach ilustracyjnych."
    },
    "notMedicalAdvice": {
      "title": "Nie Porada Medyczna",
      "description": "Rekomendacje selekcji generowane przez AI nie są prawdziwą poradą medyczną. Są to syntetyczne demonstracje tego, co pipeline selekcji AI mógłby wygenerować. Nie polegaj na nich przy podejmowaniu rzeczywistych decyzji medycznych. Jeśli masz problem medyczny, natychmiast skonsultuj się z wykwalifikowanym specjalistą."
    },
    "noLiability": {
      "title": "Brak Odpowiedzialności",
      "description": "Deweloper nie ponosi odpowiedzialności za jakiekolwiek działania podjęte na podstawie treści generowanych przez AI w tej aplikacji demo. Korzystanie odbywa się wyłącznie na własne ryzyko."
    },
    "dataHandling": {
      "title": "Przetwarzanie Danych",
      "description": "Dane przesyłane do tego demo mogą być przetwarzane przez zewnętrznych dostawców AI (OpenRouter). Żadne dane nie są sprzedawane ani wykorzystywane do celów wykraczających poza funkcjonalność demo. Szczegóły w Polityce Prywatności."
    }
  },
  "cookies": {
    "title": "Polityka Plików Cookie",
    "lastUpdated": "Ostatnia aktualizacja: 13 czerwca 2026",
    "intro": "TriageFlow nie używa tradycyjnych plików cookie przeglądarki. Oto co przechowujemy w Twojej przeglądarce:",
    "localStorage": {
      "title": "Użycie Local Storage",
      "items": [
        "Token uwierzytelniania JWT — wymagany do utrzymania sesji (niezbędny).",
        "Preferencja języka — zapamiętuje wybór między angielskim a polskim (preferencja).",
        "Preferencja motywu — zapamiętuje wybór między trybem jasnym a ciemnym (preferencja).",
        "Potwierdzenie zgody cookie — zapamiętuje, że widziałeś powiadomienie o zgodzie."
      ]
    },
    "sessionStorage": {
      "title": "Użycie Session Storage",
      "items": [
        "Stan impersonacji admina — tymczasowo przechowuje oryginalny token admina podczas impersonacji użytkownika. Czyszczone po zamknięciu karty."
      ]
    },
    "noTracking": {
      "title": "Brak Śledzenia",
      "description": "Nie używamy żadnej analityki, plików cookie śledzących, skryptów stron trzecich ani żadnej formy śledzenia zachowań użytkowników. To jest aplikacja demonstracyjna — to co widzisz, to wszystko co jest."
    }
  }
}
```

`frontend/src/i18n/locales/pl/auth.json`:

```json
{
  "login": {
    "title": "Zaloguj Się",
    "email": "Email",
    "emailPlaceholder": "ty@przyklad.pl",
    "password": "Hasło",
    "passwordPlaceholder": "Wprowadź hasło",
    "submit": "Zaloguj Się",
    "submitting": "Logowanie...",
    "noAccount": "Nie masz konta?",
    "registerLink": "Zarejestruj Się",
    "invalidCredentials": "Nieprawidłowy email lub hasło.",
    "unverified": "Zweryfikuj swój adres email przed zalogowaniem.",
    "registrationSuccess": "Konto utworzone! Sprawdź email, aby zweryfikować adres, a następnie zaloguj się.",
    "checkMailpit": "W środowisku deweloperskim: sprawdź Mailpit na http://localhost:8025"
  },
  "register": {
    "title": "Utwórz Konto",
    "email": "Email",
    "emailPlaceholder": "ty@przyklad.pl",
    "password": "Hasło",
    "passwordPlaceholder": "Min. 8 znaków",
    "confirmPassword": "Potwierdź Hasło",
    "confirmPasswordPlaceholder": "Powtórz hasło",
    "submit": "Utwórz Konto",
    "submitting": "Tworzenie konta...",
    "haveAccount": "Masz już konto?",
    "loginLink": "Zaloguj Się",
    "passwordMismatch": "Hasła nie są zgodne.",
    "emailTaken": "Ten email jest już zarejestrowany.",
    "validation": {
      "emailRequired": "Email jest wymagany.",
      "emailInvalid": "Wprowadź poprawny adres email.",
      "passwordRequired": "Hasło jest wymagane.",
      "passwordMinLength": "Hasło musi mieć co najmniej 8 znaków."
    }
  },
  "verifyEmail": {
    "title": "Weryfikacja Email",
    "verifying": "Weryfikacja Twojego adresu email...",
    "success": "Email zweryfikowany pomyślnie! Możesz się teraz zalogować.",
    "invalidToken": "Nieprawidłowy link weryfikacyjny.",
    "expiredToken": "Ten link weryfikacyjny wygasł. Zarejestruj się ponownie.",
    "alreadyVerified": "Email już zweryfikowany.",
    "goToLogin": "Przejdź do Logowania"
  }
}
```

`frontend/src/i18n/locales/pl/triage.json`:

```json
{
  "title": "Nowa Selekcja",
  "subtitle": "Opisz swoje objawy, a AI zada pytania uzupełniające, aby określić pilność i specjalistę.",
  "symptomInput": {
    "label": "Opisz swoje objawy",
    "placeholder": "np. Mam silny ból głowy, który zaczął się dziś rano...",
    "maxLength": "Maksymalnie 500 znaków",
    "submit": "Wyślij Objawy",
    "submitting": "Analizowanie objawów..."
  },
  "answerInput": {
    "label": "Twoja odpowiedź",
    "placeholder": "Wpisz swoją odpowiedź tutaj...",
    "maxLength": "Maksymalnie 300 znaków",
    "submit": "Wyślij Odpowiedź"
  },
  "status": {
    "pending": "Wysyłanie Twoich objawów...",
    "processing": "AI analizuje Twoje objawy...",
    "awaitingAnswer": "AI ma do Ciebie pytanie uzupełniające.",
    "completed": "Selekcja zakończona!",
    "failed": "Coś poszło nie tak. Spróbuj ponownie."
  },
  "conversation": {
    "you": "Ty",
    "aiAssistant": "Asystent AI",
    "initialDescription": "Twój początkowy opis",
    "finalResult": "Wynik selekcji dostępny"
  },
  "result": {
    "title": "Wynik Selekcji",
    "specialist": "Zalecany Specjalista",
    "urgency": "Pilność",
    "justification": "Uzasadnienie",
    "conversationHistory": "Historia Rozmowy",
    "processingTime": "Czas przetwarzania",
    "seconds_one": "{{count}} sekunda",
    "seconds_few": "{{count}} sekundy",
    "seconds_many": "{{count}} sekund",
    "notCompleted": "Selekcja jeszcze nie zakończona",
    "checkBack": "AI wciąż analizuje Twoją sprawę. Zajrzyj za chwilę.",
    "goToNewTriage": "Rozpocznij Nową Selekcję"
  },
  "urgencyLabels": {
    "low": "Niski",
    "medium": "Średni",
    "high": "Wysoki",
    "emergency": "Nagły"
  },
  "submissions": {
    "title": "Moje Zgłoszenia",
    "empty": "Nie masz jeszcze żadnych zgłoszeń selekcji.",
    "startTriage": "Rozpocznij Pierwszą Selekcję",
    "viewResult": "Zobacz Wynik",
    "viewDetails": "Zobacz Szczegóły",
    "table": {
      "date": "Data",
      "status": "Status",
      "urgency": "Pilność",
      "specialist": "Specjalista",
      "synthetic": "Syntetyczne",
      "actions": "Akcje"
    }
  }
}
```

`frontend/src/i18n/locales/pl/admin.json`:

```json
{
  "dashboard": {
    "title": "Panel Administratora",
    "tabs": {
      "overview": "Przegląd",
      "submissions": "Zgłoszenia",
      "users": "Użytkownicy",
      "failedMessages": "Nieudane Wiadomości"
    },
    "stats": {
      "totalSubmissions": "Wszystkie Zgłoszenia",
      "syntheticCases": "Przypadki Syntetyczne",
      "userCases": "Przypadki Użytkowników",
      "avgProcessingTime": "Średni Czas Przetwarzania",
      "byStatus": "Według Statusu",
      "bySpecialist": "Według Specjalisty",
      "byUrgency": "Według Pilności"
    },
    "generateSynthetic": {
      "button": "Generuj Przypadek Syntetyczny",
      "generating": "Generowanie...",
      "success": "Przypadek syntetyczny wygenerowany! Pojawi się wkrótce na liście zgłoszeń."
    },
    "submissions": {
      "title": "Wszystkie Zgłoszenia",
      "empty": "Brak zgłoszeń.",
      "table": {
        "user": "Użytkownik",
        "date": "Data",
        "status": "Status",
        "urgency": "Pilność",
        "specialist": "Specjalista",
        "synthetic": "Syntetyczne",
        "processingTime": "Czas",
        "actions": "Akcje"
      },
      "viewDetails": "Zobacz Szczegóły"
    },
    "users": {
      "title": "Użytkownicy",
      "empty": "Nie znaleziono użytkowników.",
      "table": {
        "email": "Email",
        "roles": "Roles",
        "created": "Utworzono",
        "actions": "Akcje"
      },
      "impersonate": "Impersonuj"
    },
    "failedMessages": {
      "title": "Nieudane Wiadomości",
      "empty": "Brak nieudanych wiadomości.",
      "table": {
        "type": "Typ",
        "error": "Błąd",
        "preview": "Podgląd",
        "timestamp": "Czas",
        "actions": "Akcje"
      },
      "retry": "Ponów",
      "retrying": "Ponawianie...",
      "delete": "Usuń"
    },
    "impersonation": {
      "banner": "Przeglądasz jako {{email}}",
      "backToAdmin": "Powrót do Admina"
    }
  },
  "submissionDetail": {
    "title": "Szczegóły Zgłoszenia",
    "submissionInfo": "Informacje o Zgłoszeniu",
    "user": "Użytkownik",
    "submittedAt": "Zgłoszono",
    "status": "Status",
    "processingTime": "Czas Przetwarzania",
    "synthetic": "Przypadek Syntetyczny",
    "conversation": "Historia Rozmowy",
    "notFound": "Nie znaleziono zgłoszenia.",
    "backToList": "Powrót do Listy"
  }
}
```

- [ ] **Step 2: Add PL resources to i18n initialization**

In `frontend/src/i18n/index.ts`, add PL imports after the EN imports and add `pl` to the `resources` object:

```typescript
import plCommon from './locales/pl/common.json';
import plLanding from './locales/pl/landing.json';
import plAbout from './locales/pl/about.json';
import plHowItWorks from './locales/pl/howItWorks.json';
import plLegal from './locales/pl/legal.json';
import plAuth from './locales/pl/auth.json';
import plTriage from './locales/pl/triage.json';
import plAdmin from './locales/pl/admin.json';

// In the .init() call, add to resources:
resources: {
  en: { common: enCommon, landing: enLanding, /* ... */ },
  pl: {
    common: plCommon,
    landing: plLanding,
    about: plAbout,
    howItWorks: plHowItWorks,
    legal: plLegal,
    auth: plAuth,
    triage: plTriage,
    admin: plAdmin,
  },
},
```

To keep imports clean, refactor the top of `index.ts`:

```typescript
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import LanguageDetector from 'i18next-browser-languagedetector';

// EN locale
import enCommon from './locales/en/common.json';
import enLanding from './locales/en/landing.json';
import enAbout from './locales/en/about.json';
import enHowItWorks from './locales/en/howItWorks.json';
import enLegal from './locales/en/legal.json';
import enAuth from './locales/en/auth.json';
import enTriage from './locales/en/triage.json';
import enAdmin from './locales/en/admin.json';

// PL locale
import plCommon from './locales/pl/common.json';
import plLanding from './locales/pl/landing.json';
import plAbout from './locales/pl/about.json';
import plHowItWorks from './locales/pl/howItWorks.json';
import plLegal from './locales/pl/legal.json';
import plAuth from './locales/pl/auth.json';
import plTriage from './locales/pl/triage.json';
import plAdmin from './locales/pl/admin.json';

i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources: {
      en: {
        common: enCommon,
        landing: enLanding,
        about: enAbout,
        howItWorks: enHowItWorks,
        legal: enLegal,
        auth: enAuth,
        triage: enTriage,
        admin: enAdmin,
      },
      pl: {
        common: plCommon,
        landing: plLanding,
        about: plAbout,
        howItWorks: plHowItWorks,
        legal: plLegal,
        auth: plAuth,
        triage: plTriage,
        admin: plAdmin,
      },
    },
    fallbackLng: 'en',
    defaultNS: 'common',
    interpolation: {
      escapeValue: false,
    },
    detection: {
      order: ['localStorage', 'navigator'],
      caches: ['localStorage'],
      lookupLocalStorage: 'i18nextLng',
    },
  });

export default i18n;
```

- [ ] **Step 3: Verify TypeScript compiles**

```bash
cd frontend && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
cd frontend && git add src/i18n/
git commit -m "feat(i18n): add Polish locale files for all namespaces"
```

---

## Task 4: Dark Mode Infrastructure — useDarkMode Hook + Toggle

**Files:**
- Create: `frontend/src/hooks/useDarkMode.ts`
- Create: `frontend/src/components/shared/DarkModeToggle.tsx`
- Create: `frontend/src/test/shared/DarkModeToggle.test.tsx`

- [ ] **Step 1: Write failing test for DarkModeToggle**

`frontend/src/test/shared/DarkModeToggle.test.tsx`:

```tsx
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { DarkModeToggle } from '../../../src/components/shared/DarkModeToggle';

const getLocalStorage = (key: string): string | null => {
  return localStorage.getItem(key);
};

const getHtmlClass = (): string => {
  return document.documentElement.className;
};

describe('DarkModeToggle', () => {
  beforeEach(() => {
    localStorage.clear();
    document.documentElement.className = '';
  });

  it('renders a button with accessible label', () => {
    render(<DarkModeToggle />);
    const button = screen.getByRole('button');
    expect(button).toBeInTheDocument();
    expect(button.getAttribute('aria-label')).toBeTruthy();
  });

  it('toggles from light to dark on click', async () => {
    render(<DarkModeToggle />);
    const button = screen.getByRole('button');
    await userEvent.click(button);
    expect(document.documentElement.classList.contains('dark')).toBe(true);
    expect(localStorage.getItem('theme')).toBe('dark');
  });

  it('toggles back from dark to light on second click', async () => {
    document.documentElement.classList.add('dark');
    localStorage.setItem('theme', 'dark');
    render(<DarkModeToggle />);
    const button = screen.getByRole('button');
    await userEvent.click(button);
    expect(document.documentElement.classList.contains('dark')).toBe(false);
    expect(localStorage.getItem('theme')).toBe('light');
  });

  it('initializes with system preference when no localStorage', () => {
    // Default is light when system pref not explicitly dark
    render(<DarkModeToggle />);
    expect(document.documentElement.classList.contains('dark')).toBe(false);
  });

  it('initializes with saved preference from localStorage', () => {
    localStorage.setItem('theme', 'dark');
    render(<DarkModeToggle />);
    expect(document.documentElement.classList.contains('dark')).toBe(true);
  });
});
```

Run: `cd frontend && npx vitest run src/test/shared/DarkModeToggle.test.tsx`
Expected: FAIL — module not found.

- [ ] **Step 2: Create useDarkMode hook**

`frontend/src/hooks/useDarkMode.ts`:

```typescript
import { useState, useEffect, useCallback } from 'react';

type Theme = 'light' | 'dark';

function getSystemPreference(): Theme {
  if (typeof window === 'undefined') return 'light';
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function getStoredTheme(): Theme | null {
  if (typeof window === 'undefined') return null;
  const stored = localStorage.getItem('theme');
  if (stored === 'light' || stored === 'dark') return stored;
  return null;
}

function applyTheme(theme: Theme): void {
  const root = document.documentElement;
  if (theme === 'dark') {
    root.classList.add('dark');
  } else {
    root.classList.remove('dark');
  }
}

export function useDarkMode() {
  const [theme, setTheme] = useState<Theme>(() => {
    return getStoredTheme() || getSystemPreference();
  });

  useEffect(() => {
    applyTheme(theme);
    localStorage.setItem('theme', theme);
  }, [theme]);

  // Listen for system preference changes when no stored preference
  useEffect(() => {
    const stored = getStoredTheme();
    if (stored !== null) return; // User explicitly chose — don't override

    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    const handler = (e: MediaQueryListEvent) => {
      setTheme(e.matches ? 'dark' : 'light');
    };
    mq.addEventListener('change', handler);
    return () => mq.removeEventListener('change', handler);
  }, []);

  const toggle = useCallback(() => {
    setTheme((prev) => (prev === 'dark' ? 'light' : 'dark'));
  }, []);

  return { theme, toggle, isDark: theme === 'dark' };
}
```

- [ ] **Step 3: Create DarkModeToggle component**

`frontend/src/components/shared/DarkModeToggle.tsx`:

```tsx
import { useDarkMode } from '../../../src/hooks/useDarkMode';
import { useTranslation } from 'react-i18next';

export function DarkModeToggle() {
  const { isDark, toggle } = useDarkMode();
  const { t } = useTranslation();

  return (
    <button
      onClick={toggle}
      className="rounded-lg p-2 text-gray-500 hover:bg-gray-100 dark:text-gray-400 dark:hover:bg-gray-800 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary-500 transition-colors"
      aria-label={t('darkMode.toggle')}
      title={isDark ? t('darkMode.light') : t('darkMode.dark')}
    >
      {isDark ? (
        <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
          <path fillRule="evenodd" d="M10 2a1 1 0 011 1v1a1 1 0 11-2 0V3a1 1 0 011-1zm4 8a4 4 0 11-8 0 4 4 0 018 0zm-.464 4.95l.707.707a1 1 0 001.414-1.414l-.707-.707a1 1 0 00-1.414 1.414zm2.12-10.607a1 1 0 010 1.414l-.706.707a1 1 0 11-1.414-1.414l.707-.707a1 1 0 011.414 0zM17 11a1 1 0 100-2h-1a1 1 0 100 2h1zm-7 4a1 1 0 011 1v1a1 1 0 11-2 0v-1a1 1 0 011-1zM5.05 6.464A1 1 0 106.465 5.05l-.708-.707a1 1 0 00-1.414 1.414l.707.707zm1.414 8.486l-.707.707a1 1 0 01-1.414-1.414l.707-.707a1 1 0 011.414 1.414zM4 11a1 1 0 100-2H3a1 1 0 000 2h1z" clipRule="evenodd" />
        </svg>
      ) : (
        <svg xmlns="http://www.w3.org/2000/svg" className="h-5 w-5" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
          <path d="M17.293 13.293A8 8 0 016.707 2.707a8.001 8.001 0 1010.586 10.586z" />
        </svg>
      )}
    </button>
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd frontend && npx vitest run src/test/shared/DarkModeToggle.test.tsx
```

Expected: 5/5 pass.

- [ ] **Step 5: Commit**

```bash
cd frontend && git add src/hooks/useDarkMode.ts src/components/shared/DarkModeToggle.tsx src/test/shared/DarkModeToggle.test.tsx
git commit -m "feat: add useDarkMode hook and DarkModeToggle component with system preference detection"
```

---

## Task 5: Cookie Consent Banner + Language Switcher

**Files:**
- Create: `frontend/src/components/shared/CookieBanner.tsx`
- Create: `frontend/src/components/shared/LanguageSwitcher.tsx`

- [ ] **Step 1: Create CookieBanner**

`frontend/src/components/shared/CookieBanner.tsx`:

```tsx
import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';

export function CookieBanner() {
  const { t } = useTranslation();
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const dismissed = localStorage.getItem('cookieConsent');
    if (!dismissed) {
      setVisible(true);
    }
  }, []);

  const handleAccept = () => {
    localStorage.setItem('cookieConsent', 'true');
    setVisible(false);
  };

  if (!visible) return null;

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 bg-gray-900 text-gray-100 dark:bg-gray-800 dark:text-gray-200 border-t border-gray-700 shadow-lg">
      <div className="mx-auto max-w-7xl px-4 py-3 sm:px-6 lg:px-8">
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
          <p className="text-sm leading-relaxed flex-1">
            {t('cookieBanner.message')}
          </p>
          <button
            onClick={handleAccept}
            className="shrink-0 rounded-lg bg-accent-500 px-4 py-2 text-sm font-medium text-white hover:bg-accent-600 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent-500 transition-colors"
          >
            {t('cookieBanner.accept')}
          </button>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Create LanguageSwitcher**

`frontend/src/components/shared/LanguageSwitcher.tsx`:

```tsx
import { useTranslation } from 'react-i18next';

const LANGUAGES = [
  { code: 'en', label: 'EN' },
  { code: 'pl', label: 'PL' },
] as const;

export function LanguageSwitcher() {
  const { i18n } = useTranslation();
  const currentLang = i18n.language?.split('-')[0] || 'en';

  const switchLanguage = (lang: string) => {
    i18n.changeLanguage(lang);
  };

  return (
    <div className="flex items-center gap-0.5 rounded-lg bg-gray-100 dark:bg-gray-800 p-0.5" role="group" aria-label="Language selector">
      {LANGUAGES.map(({ code, label }) => (
        <button
          key={code}
          onClick={() => switchLanguage(code)}
          className={`px-2 py-1 text-xs font-medium rounded-md transition-colors focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary-500 ${
            currentLang === code
              ? 'bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 shadow-sm'
              : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-300'
          }`}
          aria-pressed={currentLang === code}
          aria-label={`Switch to ${label}`}
        >
          {label}
        </button>
      ))}
    </div>
  );
}
```

- [ ] **Step 3: Commit**

```bash
cd frontend && git add src/components/shared/CookieBanner.tsx src/components/shared/LanguageSwitcher.tsx
git commit -m "feat: add CookieBanner consent notice and LanguageSwitcher EN/PL toggle"
```

---

## Task 6: Marketing Layout — Header + Footer + Layout Wrapper

**Files:**
- Create: `frontend/src/components/layout/MarketingHeader.tsx`
- Create: `frontend/src/components/layout/Footer.tsx`
- Create: `frontend/src/components/layout/MarketingLayout.tsx`

- [ ] **Step 1: Create MarketingHeader**

`frontend/src/components/layout/MarketingHeader.tsx`:

```tsx
import { useState } from 'react';
import { NavLink, Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Menu, X } from 'lucide-react';
import clsx from 'clsx';
import { DarkModeToggle } from '../shared/DarkModeToggle';
import { LanguageSwitcher } from '../shared/LanguageSwitcher';

const navLinkClass = ({ isActive }: { isActive: boolean }) =>
  clsx(
    'text-sm pb-1 border-b-2 transition-colors',
    isActive
      ? 'border-primary-500 text-gray-900 dark:text-gray-100'
      : 'border-transparent text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-100'
  );

export function MarketingHeader() {
  const { t } = useTranslation();
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <header className="border-b border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-950 sticky top-0 z-40">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="flex h-16 items-center justify-between">
          {/* Logo + brand */}
          <div className="flex items-center gap-8">
            <Link to="/" className="flex items-center gap-2 font-bold text-lg text-primary-600 dark:text-primary-400 hover:text-primary-700 dark:hover:text-primary-300 transition-colors">
              <svg className="h-6 w-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden="true">
                <path strokeLinecap="round" strokeLinejoin="round" d="M4.26 10.147a60.438 60.438 0 0 0-.491 6.347A48.62 48.62 0 0 1 12 20.904a48.62 48.62 0 0 1 8.232-4.41 60.46 60.46 0 0 0-.491-6.347m-15.482 0a50.636 50.636 0 0 0-2.658-.813A59.906 59.906 0 0 1 12 3.493a59.903 59.903 0 0 1 10.399 5.84c-.896.248-1.783.52-2.658.814m-15.482 0A50.717 50.717 0 0 1 12 13.489a50.702 50.702 0 0 1 7.74-3.342M6.75 15a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5Zm0 0v-3.675A55.378 55.378 0 0 1 12 8.443m-7.007 11.55A5.981 5.981 0 0 0 6.75 15.75v-1.5" />
              </svg>
              {t('common:appName')}
            </Link>

            {/* Desktop nav with active state indicators */}
            <nav className="hidden md:flex items-center gap-6" aria-label="Main navigation">
              <NavLink to="/about" className={navLinkClass}>
                {t('common:nav.about')}
              </NavLink>
              <NavLink to="/how-it-works" className={navLinkClass}>
                {t('common:nav.howItWorks')}
              </NavLink>
            </nav>
          </div>

          {/* Right side: tools + CTAs (desktop) */}
          <div className="hidden md:flex items-center gap-3">
            <LanguageSwitcher />
            <DarkModeToggle />
            <Link
              to="/login"
              className="inline-flex items-center rounded-lg px-3 py-1.5 text-sm font-medium text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
            >
              {t('common:nav.login')}
            </Link>
            <Link
              to="/register"
              className="rounded-lg bg-accent-500 px-3 py-1.5 text-sm font-medium text-white hover:bg-accent-600 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent-500 transition-colors"
            >
              {t('common:nav.register')}
            </Link>
          </div>

          {/* Mobile hamburger */}
          <button
            className="md:hidden rounded-lg p-2 text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors"
            onClick={() => setMenuOpen(!menuOpen)}
            aria-label={menuOpen ? 'Close menu' : 'Open menu'}
          >
            {menuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
          </button>
        </div>
      </div>

      {/* Mobile slide-in drawer */}
      {menuOpen && (
        <div className="md:hidden fixed inset-0 z-50">
          <div className="fixed inset-0 bg-black/50" onClick={() => setMenuOpen(false)} />
          <div className="fixed right-0 top-0 bottom-0 w-64 bg-white dark:bg-gray-950 border-l border-gray-200 dark:border-gray-800 p-6 pt-20">
            <nav className="flex flex-col gap-4" aria-label="Mobile navigation">
              <NavLink to="/about" className={navLinkClass} onClick={() => setMenuOpen(false)}>
                {t('common:nav.about')}
              </NavLink>
              <NavLink to="/how-it-works" className={navLinkClass} onClick={() => setMenuOpen(false)}>
                {t('common:nav.howItWorks')}
              </NavLink>
              <hr className="border-gray-200 dark:border-gray-800" />
              <Link to="/login" className="text-sm text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-100" onClick={() => setMenuOpen(false)}>
                {t('common:nav.login')}
              </Link>
              <Link to="/register" className="rounded-lg bg-accent-500 px-3 py-1.5 text-sm font-medium text-white hover:bg-accent-600 text-center" onClick={() => setMenuOpen(false)}>
                {t('common:nav.register')}
              </Link>
              <hr className="border-gray-200 dark:border-gray-800" />
              <div className="flex items-center gap-2">
                <LanguageSwitcher />
                <DarkModeToggle />
              </div>
            </nav>
          </div>
        </div>
      )}
    </header>
  );
}
```

- [ ] **Step 2: Create Footer**

`frontend/src/components/layout/Footer.tsx`:

```tsx
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { DarkModeToggle } from '../shared/DarkModeToggle';
import { LanguageSwitcher } from '../shared/LanguageSwitcher';

export function Footer() {
  const { t } = useTranslation();
  const year = new Date().getFullYear();

  return (
    <footer className="border-t border-gray-200 dark:border-gray-800 bg-gray-50 dark:bg-gray-900 mt-auto">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
          {/* Col 1: Brand + copyright */}
          <div>
            <span className="font-bold text-primary-600 dark:text-primary-400">TriageFlow</span>
            <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
              © {year} Piotr Świderski
            </p>
            <p className="text-sm text-gray-400 dark:text-gray-500 mt-0.5">
              {t('common:footer.builtWith')}
            </p>
          </div>

          {/* Col 2: Legal links */}
          <div className="flex flex-wrap items-center gap-4 text-sm text-gray-500 dark:text-gray-400">
            <Link
              to="/privacy"
              className="hover:text-gray-700 dark:hover:text-gray-300 transition-colors"
            >
              {t('common:footer.privacy')}
            </Link>
            <Link
              to="/terms"
              className="hover:text-gray-700 dark:hover:text-gray-300 transition-colors"
            >
              {t('common:footer.terms')}
            </Link>
            <Link
              to="/cookies"
              className="hover:text-gray-700 dark:hover:text-gray-300 transition-colors"
            >
              {t('common:footer.cookies')}
            </Link>
            <Link
              to="/contact"
              className="hover:text-gray-700 dark:hover:text-gray-300 transition-colors"
            >
              {t('common:footer.contact')}
            </Link>
          </div>

          {/* Col 3: Tools */}
          <div className="flex items-center gap-2 justify-start sm:justify-end lg:justify-end">
            <LanguageSwitcher />
            <DarkModeToggle />
          </div>
        </div>
      </div>
    </footer>
  );
}
```

- [ ] **Step 3: Create MarketingLayout**

`frontend/src/components/layout/MarketingLayout.tsx`:

```tsx
import { Outlet } from 'react-router-dom';
import { MarketingHeader } from './MarketingHeader';
import { Footer } from './Footer';
import { CookieBanner } from '../shared/CookieBanner';

export function MarketingLayout() {
  return (
    <div className="flex min-h-screen flex-col">
      <MarketingHeader />
      <main className="flex-1">
        <Outlet />
      </main>
      <Footer />
      <CookieBanner />
    </div>
  );
}
```

- [ ] **Step 4: Verify TypeScript compiles**

```bash
cd frontend && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
cd frontend && git add src/components/layout/MarketingHeader.tsx src/components/layout/Footer.tsx src/components/layout/MarketingLayout.tsx
git commit -m "feat: add MarketingLayout with MarketingHeader, Footer, dark mode toggle, and language switcher"
```

---

## Task 7: Landing Page

**Files:**
- Create: `frontend/src/features/marketing/pages/LandingPage.tsx`
- Create: `frontend/src/test/marketing/LandingPage.test.tsx`

- [ ] **Step 1: Write failing test**

`frontend/src/test/marketing/LandingPage.test.tsx`:

```tsx
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { LandingPage } from '../../../src/features/marketing/pages/LandingPage';

function renderWithRouter() {
  return render(
    <MemoryRouter>
      <LandingPage />
    </MemoryRouter>
  );
}

describe('LandingPage', () => {
  it('renders the hero CTA button', () => {
    renderWithRouter();
    expect(screen.getByRole('link', { name: /try the demo/i })).toBeInTheDocument();
  });

  it('renders the secondary CTA link', () => {
    renderWithRouter();
    expect(screen.getByRole('link', { name: /how it works/i })).toBeInTheDocument();
  });

  it('renders the disclaimer text', () => {
    renderWithRouter();
    expect(screen.getByText(/demonstration system/i)).toBeInTheDocument();
  });

  it('renders feature cards', () => {
    renderWithRouter();
    expect(screen.getByText(/ai-powered triage/i)).toBeInTheDocument();
    expect(screen.getByText(/full-stack architecture/i)).toBeInTheDocument();
  });
});
```

Run: `cd frontend && npx vitest run src/test/marketing/LandingPage.test.tsx`
Expected: FAIL — module not found.

- [ ] **Step 2: Create LandingPage**

`frontend/src/features/marketing/pages/LandingPage.tsx`:

```tsx
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Helmet } from 'react-helmet-async';
import { BrainCircuit, Layers, RefreshCw, BarChart4 } from 'lucide-react';
import { DemoPreview } from '../components/DemoPreview';

const features = [
  { key: 'aiTriage', Icon: BrainCircuit },
  { key: 'fullStack', Icon: Layers },
  { key: 'synthetic', Icon: RefreshCw },
  { key: 'observability', Icon: BarChart4 },
] as const;

const techStack = [
  { name: 'Symfony 7.4', category: 'Backend' },
  { name: 'React 19', category: 'Frontend' },
  { name: 'TypeScript 6', category: 'Frontend' },
  { name: 'PostgreSQL 16', category: 'Backend' },
  { name: 'Docker', category: 'Infra' },
  { name: 'OpenRouter AI', category: 'AI' },
  { name: 'Tailwind CSS 4', category: 'Frontend' },
  { name: 'PHPStan L5', category: 'Backend' },
];

type Category = 'Backend' | 'Frontend' | 'Infra' | 'AI';

function groupByCategory(items: typeof techStack) {
  const groups: Record<Category, typeof techStack> = { Backend: [], Frontend: [], Infra: [], AI: [] };
  items.forEach(item => groups[item.category as Category].push(item));
  return groups;
}

export function LandingPage() {
  const { t } = useTranslation(['landing', 'common']);
  const grouped = groupByCategory(techStack);

  return (
    <>
      <Helmet>
        <title>{t('common:appName')} — {t('common:tagline')}</title>
        <meta name="description" content="AI-powered patient pre-screening demonstration. Full-stack portfolio project built with Symfony, React, and AI." />
      </Helmet>

      {/* Hero Section — glassmorphism on gradient */}
      <section className="relative overflow-hidden bg-gradient-to-br from-primary-900 via-primary-800 to-accent-800 dark:from-primary-950 dark:via-primary-900 dark:to-accent-950">
        <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZyBmaWxsPSJub25lIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiPjxnIGZpbGw9IiNmZmZmZmYiIGZpbGwtb3BhY2l0eT0iMC4wNSI+PGNpcmNsZSBjeD0iMzAiIGN5PSIzMCIgcj0iMiIvPjwvZz48L2c+PC9zdmc+')] opacity-50" />
        <div className="relative mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-16 sm:py-20 lg:py-28 flex justify-center">
          {/* Frosted glass card centering the hero message */}
          <div className="max-w-2xl w-full rounded-3xl bg-white/10 backdrop-blur-xl border border-white/20 shadow-2xl shadow-primary-950/30 dark:bg-white/5 dark:border-white/10 p-10 sm:p-14">
            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight text-white font-heading">
              {t('landing:hero.title')}
            </h1>
            <p className="mt-6 text-xl sm:text-2xl text-accent-200 font-medium">
              {t('landing:hero.subtitle')}
            </p>
            <p className="mt-4 text-sm text-primary-200 max-w-xl">
              {t('landing:hero.disclaimer')}
            </p>
            <div className="mt-10 flex flex-col sm:flex-row gap-4">
              <Link
                to="/register"
                className="inline-flex items-center justify-center rounded-xl bg-accent-500 px-8 py-4 text-lg font-semibold text-white shadow-lg hover:bg-accent-400 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white transition-colors"
              >
                {t('landing:hero.cta')}
              </Link>
              <Link
                to="/how-it-works"
                className="inline-flex items-center justify-center rounded-xl border-2 border-white/30 px-8 py-4 text-lg font-semibold text-white hover:bg-white/10 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white transition-colors"
              >
                {t('landing:hero.secondaryCta')}
              </Link>
            </div>
          </div>
        </div>
      </section>

      {/* Features Grid */}
      <section className="py-20 sm:py-28 bg-white dark:bg-gray-950">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl sm:text-4xl font-bold text-center text-gray-900 dark:text-gray-100 font-heading">
            {t('landing:features.title')}
          </h2>
          <div className="mt-16 grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
            {features.map(({ key, Icon }) => (
              <div
                key={key}
                className="group rounded-2xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 p-6 hover:shadow-xl hover:-translate-y-0.5 hover:border-primary-200 dark:hover:border-primary-800 transition-all duration-300 cursor-pointer"
              >
                <div className="w-12 h-12 rounded-xl bg-primary-50 dark:bg-primary-950 flex items-center justify-center mb-4 group-hover:bg-primary-100 dark:group-hover:bg-primary-900 transition-colors">
                  <Icon className="w-6 h-6 text-primary-600 dark:text-primary-400" />
                </div>
                <h3 className="text-lg font-semibold text-gray-900 dark:text-gray-100 mb-2">
                  {t(`landing:features.${key}.title`)}
                </h3>
                <p className="text-sm text-gray-600 dark:text-gray-400 leading-relaxed">
                  {t(`landing:features.${key}.description`)}
                </p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Live Demo Preview */}
      <DemoPreview />

      {/* Tech Stack */}
      <section className="py-16 bg-surface-50 dark:bg-surface-900">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-2xl font-bold text-gray-900 dark:text-gray-100 font-heading">
            {t('landing:techStack.title')}
          </h2>
          <div className="mt-8 space-y-6">
            {Object.entries(grouped).map(([category, items]) => (
              <div key={category}>
                <p className="text-xs font-semibold uppercase text-surface-500 dark:text-surface-400 mb-3 tracking-wider">{category}</p>
                <div className="flex flex-wrap items-center justify-center gap-3">
                  {items.map(item => (
                    <span
                      key={item.name}
                      className="inline-flex items-center rounded-full bg-white dark:bg-surface-800 border border-surface-200 dark:border-surface-700 px-4 py-2.5 text-sm font-medium text-surface-700 dark:text-surface-300 shadow-sm cursor-default"
                    >
                      {item.name}
                    </span>
                  ))}
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
```

- [ ] **Step 3: Run tests to verify they pass**

```bash
cd frontend && npx vitest run src/test/marketing/LandingPage.test.tsx
```

Expected: 4/4 pass.

- [ ] **Step 4: Commit**

```bash
cd frontend && git add src/features/marketing/pages/LandingPage.tsx src/test/marketing/LandingPage.test.tsx
git commit -m "feat: add LandingPage with hero section, feature cards, and tech stack showcase"
```

---

## Task 8: About + HowItWorks + Contact Pages

**Files:**
- Create: `frontend/src/features/marketing/pages/AboutPage.tsx`
- Create: `frontend/src/features/marketing/pages/HowItWorksPage.tsx`
- Create: `frontend/src/features/marketing/components/StepCard.tsx`
- Create: `frontend/src/features/marketing/pages/ContactPage.tsx`

- [ ] **Step 1: Create StepCard component with timeline design**

`frontend/src/features/marketing/components/StepCard.tsx`:

```tsx
interface StepCardProps {
  number: number;
  title: string;
  description: string;
}

export function StepCard({ number, title, description }: StepCardProps) {
  return (
    <div className="relative pl-16">
      {/* Vertical timeline line — render as sibling in parent for connection */}
      <div className="absolute left-0 w-12 h-12 rounded-full
                    bg-gradient-to-br from-primary-500 to-accent-500
                    flex items-center justify-center text-white text-xl font-bold
                    shadow-lg shadow-primary-500/25
                    ring-4 ring-white dark:ring-gray-950">
        {number}
      </div>
      <h3 className="text-xl font-semibold text-gray-900 dark:text-gray-100">{title}</h3>
      <p className="mt-2 text-gray-600 dark:text-gray-400 leading-relaxed">{description}</p>
    </div>
  );
}
```

- [ ] **Step 1b: Create DemoPreview component**

`frontend/src/features/marketing/components/DemoPreview.tsx`:

```tsx
import { useTranslation } from 'react-i18next';

export function DemoPreview() {
  const { t } = useTranslation('landing');

  return (
    <section className="py-20 bg-surface-50 dark:bg-surface-900">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <h2 className="text-3xl font-bold text-center text-gray-900 dark:text-gray-100 font-heading mb-4">
          {t('demo.title')}
        </h2>
        <p className="text-center text-surface-500 dark:text-surface-400 mb-12">
          {t('demo.subtitle')}
        </p>
        {/* Browser mockup frame with screenshot placeholder */}
        <div className="rounded-2xl border border-gray-200 dark:border-gray-700 shadow-2xl overflow-hidden max-w-5xl mx-auto">
          <div className="bg-gray-100 dark:bg-gray-800 px-4 py-2 flex gap-2">
            <span className="w-3 h-3 rounded-full bg-red-400" />
            <span className="w-3 h-3 rounded-full bg-yellow-400" />
            <span className="w-3 h-3 rounded-full bg-green-400" />
          </div>
          <img
            src="https://placehold.co/1200x600/1e3a5f/ffffff?text=TriageFlow+Demo+Screenshot"
            alt="TriageFlow interview interface showing AI follow-up questions"
            className="w-full"
          />
        </div>
      </div>
    </section>
  );
}
```

- [ ] **Step 2: Create AboutPage**

`frontend/src/features/marketing/pages/AboutPage.tsx`:

```tsx
import { useTranslation } from 'react-i18next';
import { Helmet } from 'react-helmet-async';
import { GithubIcon, AlertTriangle } from 'lucide-react';

export function AboutPage() {
  const { t } = useTranslation('about');

  return (
    <>
      <Helmet>
        <title>About — TriageFlow</title>
      </Helmet>
      <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8 py-16 sm:py-24">
        <h1 className="text-3xl sm:text-4xl font-bold text-gray-900 dark:text-gray-100 font-heading">{t('title')}</h1>
        <p className="mt-6 text-lg text-gray-600 dark:text-gray-400 leading-relaxed">{t('intro')}</p>

        {/* Developer identity */}
        <section className="mt-12">
          <h2 className="text-2xl font-semibold text-gray-900 dark:text-gray-100 border-l-4 border-primary-500 pl-4">{t('who.title')}</h2>
          <div className="mt-6 flex items-center gap-4">
            <div className="w-16 h-16 rounded-full bg-gradient-to-br from-primary-500 to-accent-500 flex items-center justify-center text-white text-xl font-bold shadow-lg">
              PŚ
            </div>
            <div>
              <p className="font-semibold text-lg text-gray-900 dark:text-gray-100">Piotr Świderski</p>
              <a href="https://github.com/psswid" target="_blank" rel="noopener noreferrer"
                 className="text-sm text-primary-600 hover:underline flex items-center gap-1 mt-0.5">
                <GithubIcon className="w-4 h-4" /> GitHub
              </a>
            </div>
          </div>
          <p className="mt-4 text-gray-600 dark:text-gray-400 leading-relaxed">{t('who.description')}</p>
        </section>

        {/* Why TriageFlow */}
        <section className="mt-12">
          <h2 className="text-2xl font-semibold text-gray-900 dark:text-gray-100 border-l-4 border-primary-500 pl-4">{t('why.title')}</h2>
          <p className="mt-4 text-gray-600 dark:text-gray-400 leading-relaxed">{t('why.description')}</p>
        </section>

        {/* Tech Decisions showcase */}
        <section className="mt-12">
          <h2 className="text-2xl font-semibold text-gray-900 dark:text-gray-100 border-l-4 border-primary-500 pl-4">{t('decisions.title')}</h2>
          <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {(['architecture', 'state', 'ddd', 'quality', 'observability', 'i18n'] as const).map((key) => (
              <div key={key} className="rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 p-4">
                <span className="text-xs font-mono text-primary-600 dark:text-primary-400 uppercase tracking-wider">
                  {t(`decisions.${key}.label`)}
                </span>
                <p className="mt-1 font-medium text-gray-900 dark:text-gray-100">
                  {t(`decisions.${key}.title`)}
                </p>
                <p className="text-sm text-gray-500 dark:text-gray-400 mt-0.5">
                  {t(`decisions.${key}.description`)}
                </p>
              </div>
            ))}
          </div>
        </section>

        {/* Disclaimer box — amber (caution), NOT red (emergency) */}
        <section className="mt-12 rounded-2xl border-2 border-amber-200 dark:border-amber-800 bg-amber-50 dark:bg-amber-950 p-6">
          <div className="flex items-start gap-3">
            <AlertTriangle className="w-5 h-5 text-amber-600 dark:text-amber-400 shrink-0 mt-0.5" />
            <div>
              <h2 className="text-xl font-semibold text-amber-800 dark:text-amber-200">{t('disclaimer.title')}</h2>
              <p className="mt-3 text-amber-700 dark:text-amber-300 leading-relaxed">{t('disclaimer.description')}</p>
            </div>
          </div>
        </section>
      </div>
    </>
  );
}
```

- [ ] **Step 3: Create HowItWorksPage**

`frontend/src/features/marketing/pages/HowItWorksPage.tsx`:

```tsx
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Helmet } from 'react-helmet-async';
import { StepCard } from '../components/StepCard';

export function HowItWorksPage() {
  const { t } = useTranslation('howItWorks');

  const steps = [
    { key: 'step1' },
    { key: 'step2' },
    { key: 'step3' },
    { key: 'step4' },
  ];

  return (
    <>
      <Helmet>
        <title>How It Works — TriageFlow</title>
      </Helmet>
      <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8 py-16 sm:py-24">
        <h1 className="text-3xl sm:text-4xl font-bold text-gray-900 dark:text-gray-100 font-heading">{t('title')}</h1>
        <p className="mt-4 text-lg text-gray-600 dark:text-gray-400">{t('subtitle')}</p>

        {/* Timeline: vertical line + numbered steps */}
        <div className="relative mt-16">
          {/* Vertical timeline connecting line */}
          <div className="absolute left-6 top-0 bottom-0 w-0.5 bg-gradient-to-b from-primary-300 via-accent-300 to-primary-300 dark:from-primary-800 dark:via-accent-700 dark:to-primary-800" />

          <div className="flex flex-col gap-12">
            {steps.map(({ key }, i) => (
              <StepCard
                key={key}
                number={i + 1}
                title={t(`steps.${key}.title`)}
                description={t(`steps.${key}.description`)}
              />
            ))}
          </div>
        </div>

        <div className="mt-16 text-center">
          <Link
            to="/register"
            className="inline-flex items-center justify-center rounded-xl bg-accent-500 px-8 py-4 text-lg font-semibold text-white hover:bg-accent-600 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent-500 transition-colors"
          >
            {t('cta')}
          </Link>
          <p className="mt-4 text-sm text-gray-400 dark:text-gray-500">{t('disclaimer')}</p>
        </div>
      </div>
    </>
  );
}
```

- [ ] **Step 4: Create ContactPage**

`frontend/src/features/marketing/pages/ContactPage.tsx`:

```tsx
import { Helmet } from 'react-helmet-async';
import { Globe, GithubIcon, LinkedinIcon, Mail } from 'lucide-react';

export function ContactPage() {
  return (
    <>
      <Helmet>
        <title>Contact — TriageFlow</title>
      </Helmet>
      <div className="mx-auto max-w-lg px-4 sm:px-6 lg:px-8 py-16 sm:py-24 text-center">
        {/* Frosted card */}
        <div className="rounded-2xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-xl p-8 sm:p-12">
          <div className="w-20 h-20 mx-auto rounded-full bg-gradient-to-br from-primary-500 to-accent-500 flex items-center justify-center text-white text-2xl font-bold shadow-lg mb-6">
            PŚ
          </div>
          <h1 className="text-3xl font-bold text-gray-900 dark:text-gray-100 font-heading">Let's Connect</h1>
          <p className="mt-4 text-gray-600 dark:text-gray-400">
            TriageFlow is built and maintained by Piotr Świderski.
          </p>

          {/* Connect grid — 2×2 */}
          <div className="mt-8 grid grid-cols-2 gap-3">
            <a
              href="https://piotrswiderski.dev"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center justify-center gap-2 rounded-xl bg-accent-500 text-white px-4 py-3 font-medium hover:bg-accent-600 transition-colors"
            >
              <Globe className="w-4 h-4" /> Portfolio
            </a>
            <a
              href="https://github.com/psswid"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center justify-center gap-2 rounded-xl border border-gray-300 dark:border-gray-700 px-4 py-3 font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
            >
              <GithubIcon className="w-4 h-4" /> GitHub
            </a>
            <a
              href="https://linkedin.com/in/psswid"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center justify-center gap-2 rounded-xl border border-gray-300 dark:border-gray-700 px-4 py-3 font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
            >
              <LinkedinIcon className="w-4 h-4" /> LinkedIn
            </a>
            <a
              href="mailto:piotr@piotrswiderski.dev"
              className="flex items-center justify-center gap-2 rounded-xl border border-gray-300 dark:border-gray-700 px-4 py-3 font-medium text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
            >
              <Mail className="w-4 h-4" /> Email
            </a>
          </div>
        </div>
      </div>
    </>
  );
}
```

- [ ] **Step 5: Verify TypeScript compiles**

```bash
cd frontend && npx tsc --noEmit
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
cd frontend && git add src/features/marketing/
git commit -m "feat: add About, HowItWorks (with StepCard), and Contact pages"
```

---

## Task 9: Legal Pages — Privacy, Terms, Cookies

**Files:**
- Create: `frontend/src/features/marketing/pages/PrivacyPage.tsx`
- Create: `frontend/src/features/marketing/pages/TermsPage.tsx`
- Create: `frontend/src/features/marketing/pages/CookiesPage.tsx`

- [ ] **Step 1: Create PrivacyPage**

`frontend/src/features/marketing/pages/PrivacyPage.tsx`:

```tsx
import { useTranslation } from 'react-i18next';
import { Helmet } from 'react-helmet-async';
import { TableOfContents } from '../components/TableOfContents';

const sections = ['dataCollected', 'dataUsage', 'storage', 'rights'] as const;

export function PrivacyPage() {
  const { t } = useTranslation('legal');

  return (
    <>
      <Helmet>
        <title>{t('privacy.title')} — TriageFlow</title>
      </Helmet>
      <div className="mx-auto max-w-5xl px-4 sm:px-6 lg:px-8 py-16 sm:py-24">
        <h1 className="text-3xl sm:text-4xl font-bold text-gray-900 dark:text-gray-100 font-heading">{t('privacy.title')}</h1>
        <p className="mt-2 text-sm text-gray-400 dark:text-gray-500">{t('privacy.lastUpdated')}</p>
        <p className="mt-6 text-gray-600 dark:text-gray-400 leading-relaxed">{t('privacy.intro')}</p>

        <div className="mt-12 flex gap-12">
          {/* Sticky Table of Contents sidebar (desktop only) */}
          <nav className="hidden lg:block w-56 shrink-0">
            <div className="sticky top-24 space-y-1">
              <p className="text-xs font-semibold uppercase text-gray-400 dark:text-gray-500 mb-3">On this page</p>
              {sections.map((section) => (
                <a
                  key={section}
                  href={`#${section}`}
                  className="block text-sm text-gray-500 dark:text-gray-400 hover:text-primary-600 dark:hover:text-primary-400 border-l-2 border-transparent hover:border-primary-500 pl-3 py-1 transition-colors"
                >
                  {t(`privacy.${section}.title`)}
                </a>
              ))}
            </div>
          </nav>

          {/* Content */}
          <div className="min-w-0 space-y-6">
            {sections.map((section) => (
              <section key={section} id={section} className="rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 p-6">
                <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">{t(`privacy.${section}.title`)}</h2>
                {t(`privacy.${section}.items`, { returnObjects: true }) && (
                  <ul className="mt-3 space-y-2 list-disc pl-6 text-gray-600 dark:text-gray-400">
                    {(t(`privacy.${section}.items`, { returnObjects: true }) as string[]).map((item: string, i: number) => (
                      <li key={i}>{item}</li>
                    ))}
                  </ul>
                )}
                {t(`privacy.${section}.description`, '') && (
                  <p className="mt-3 text-gray-600 dark:text-gray-400">{t(`privacy.${section}.description`, '')}</p>
                )}
              </section>
            ))}
          </div>
        </div>

        <p className="mt-10 text-sm text-gray-500 dark:text-gray-400 border-t border-gray-200 dark:border-gray-800 pt-6">
          {t('privacy.contact')}
        </p>
      </div>
    </>
  );
}
```

- [ ] **Step 2: Create TermsPage**

`frontend/src/features/marketing/pages/TermsPage.tsx`:

```tsx
import { useTranslation } from 'react-i18next';
import { Helmet } from 'react-helmet-async';
import { FlaskConical, Stethoscope, ShieldOff, Database } from 'lucide-react';

const sections = ['demoNature', 'notMedicalAdvice', 'noLiability', 'dataHandling'] as const;

const sectionIcons: Record<string, React.ComponentType<{ className?: string }>> = {
  demoNature: FlaskConical,
  notMedicalAdvice: Stethoscope,
  noLiability: ShieldOff,
  dataHandling: Database,
};

export function TermsPage() {
  const { t } = useTranslation('legal');

  return (
    <>
      <Helmet>
        <title>{t('terms.title')} — TriageFlow</title>
      </Helmet>
      <div className="mx-auto max-w-5xl px-4 sm:px-6 lg:px-8 py-16 sm:py-24">
        <h1 className="text-3xl sm:text-4xl font-bold text-gray-900 dark:text-gray-100 font-heading">{t('terms.title')}</h1>
        <p className="mt-2 text-sm text-gray-400 dark:text-gray-500">{t('terms.lastUpdated')}</p>
        <p className="mt-6 text-gray-600 dark:text-gray-400 leading-relaxed">{t('terms.intro')}</p>

        <div className="mt-12 flex gap-12">
          {/* Sticky Table of Contents sidebar (desktop only) */}
          <nav className="hidden lg:block w-56 shrink-0">
            <div className="sticky top-24 space-y-1">
              <p className="text-xs font-semibold uppercase text-gray-400 dark:text-gray-500 mb-3">On this page</p>
              {sections.map((section) => (
                <a
                  key={section}
                  href={`#${section}`}
                  className="block text-sm text-gray-500 dark:text-gray-400 hover:text-primary-600 dark:hover:text-primary-400 border-l-2 border-transparent hover:border-primary-500 pl-3 py-1 transition-colors"
                >
                  {t(`terms.${section}.title`)}
                </a>
              ))}
            </div>
          </nav>

          {/* Content */}
          <div className="min-w-0 space-y-6">
            {sections.map((section) => {
              const Icon = sectionIcons[section];
              return (
                <section key={section} id={section} className="rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 p-6">
                  <div className="flex items-center gap-2 mb-2">
                    {Icon && <Icon className="w-5 h-5 text-primary-600 dark:text-primary-400 shrink-0" />}
                    <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">{t(`terms.${section}.title`)}</h2>
                  </div>
                  <p className="text-gray-600 dark:text-gray-400 leading-relaxed">{t(`terms.${section}.description`)}</p>
                </section>
              );
            })}
          </div>
        </div>
      </div>
    </>
  );
}
```

- [ ] **Step 3: Create CookiesPage**

`frontend/src/features/marketing/pages/CookiesPage.tsx`:

```tsx
import { useTranslation } from 'react-i18next';
import { Helmet } from 'react-helmet-async';
import { HardDrive, Layers, EyeOff } from 'lucide-react';

const sections = ['localStorage', 'sessionStorage', 'noTracking'] as const;

const sectionIcons: Record<string, React.ComponentType<{ className?: string }>> = {
  localStorage: HardDrive,
  sessionStorage: Layers,
  noTracking: EyeOff,
};

export function CookiesPage() {
  const { t } = useTranslation('legal');

  return (
    <>
      <Helmet>
        <title>{t('cookies.title')} — TriageFlow</title>
      </Helmet>
      <div className="mx-auto max-w-5xl px-4 sm:px-6 lg:px-8 py-16 sm:py-24">
        <h1 className="text-3xl sm:text-4xl font-bold text-gray-900 dark:text-gray-100 font-heading">{t('cookies.title')}</h1>
        <p className="mt-2 text-sm text-gray-400 dark:text-gray-500">{t('cookies.lastUpdated')}</p>
        <p className="mt-6 text-gray-600 dark:text-gray-400 leading-relaxed">{t('cookies.intro')}</p>

        <div className="mt-12 flex gap-12">
          {/* Sticky Table of Contents sidebar (desktop only) */}
          <nav className="hidden lg:block w-56 shrink-0">
            <div className="sticky top-24 space-y-1">
              <p className="text-xs font-semibold uppercase text-gray-400 dark:text-gray-500 mb-3">On this page</p>
              {sections.map((section) => (
                <a
                  key={section}
                  href={`#${section}`}
                  className="block text-sm text-gray-500 dark:text-gray-400 hover:text-primary-600 dark:hover:text-primary-400 border-l-2 border-transparent hover:border-primary-500 pl-3 py-1 transition-colors"
                >
                  {t(`cookies.${section}.title`)}
                </a>
              ))}
            </div>
          </nav>

          {/* Content */}
          <div className="min-w-0 space-y-6">
            {sections.map((section) => {
              const Icon = sectionIcons[section];
              return (
                <section key={section} id={section} className="rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 p-6">
                  <div className="flex items-center gap-2 mb-2">
                    {Icon && <Icon className="w-5 h-5 text-primary-600 dark:text-primary-400 shrink-0" />}
                    <h2 className="text-xl font-semibold text-gray-900 dark:text-gray-100">{t(`cookies.${section}.title`)}</h2>
                  </div>
                  {(t(`cookies.${section}.items`, { returnObjects: true }) as string[] | undefined) && (
                    <ul className="space-y-2 list-disc pl-6 text-gray-600 dark:text-gray-400">
                      {(t(`cookies.${section}.items`, { returnObjects: true }) as string[]).map((item: string, i: number) => (
                        <li key={i}>{item}</li>
                      ))}
                    </ul>
                  )}
                  {t(`cookies.${section}.description`, '') && (
                    <p className="text-gray-600 dark:text-gray-400">{t(`cookies.${section}.description`, '')}</p>
                  )}
                </section>
              );
            })}
          </div>
        </div>
      </div>
    </>
  );
}
```

- [ ] **Step 4: Verify TypeScript compiles**

```bash
cd frontend && npx tsc --noEmit
```

Expected: no errors (allow `any` from i18n array returns if needed — add `// eslint-disable-next-line @typescript-eslint/no-explicit-any` on the cast lines).

- [ ] **Step 5: Commit**

```bash
cd frontend && git add src/features/marketing/pages/PrivacyPage.tsx src/features/marketing/pages/TermsPage.tsx src/features/marketing/pages/CookiesPage.tsx
git commit -m "feat: add Privacy, Terms of Service, and Cookie Policy pages"
```

---

## Task 10: Wire Providers — App.tsx + main.tsx Refactor

**Files:**
- Modify: `frontend/src/App.tsx`
- Modify: `frontend/src/main.tsx`

- [ ] **Step 1: Update main.tsx — import i18n before App renders**

Read current `frontend/src/main.tsx`, then modify to import i18n:

```tsx
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { HelmetProvider } from 'react-helmet-async';
import { App } from './App';
import { ToastProvider } from './components/ui/ToastProvider';
import './styles/index.css';
import './i18n'; // Must import before App renders

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      refetchOnWindowFocus: true,
      retry: 1,
    },
  },
});

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <HelmetProvider>
      <QueryClientProvider client={queryClient}>
        <ToastProvider>
          <App />
        </ToastProvider>
      </QueryClientProvider>
    </HelmetProvider>
  </StrictMode>
);
```

- [ ] **Step 2: Update App.tsx — add ThemeProvider (dark mode init on mount)**

Read current `frontend/src/App.tsx`, then ensure dark mode is initialized before render. Add an effect in App or a small ThemeInit wrapper:

```tsx
import { useEffect } from 'react';
import { RouterProvider } from 'react-router-dom';
import { AuthProvider } from './components/auth/AuthProvider';
import { router } from './routes';

function ThemeInit() {
  useEffect(() => {
    // Apply saved or system dark mode preference on mount
    const stored = localStorage.getItem('theme');
    if (stored === 'dark') {
      document.documentElement.classList.add('dark');
    } else if (stored === 'light') {
      document.documentElement.classList.remove('dark');
    } else if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
      document.documentElement.classList.add('dark');
    }
  }, []);

  return null;
}

export function App() {
  return (
    <AuthProvider>
      <ThemeInit />
      <RouterProvider router={router} />
    </AuthProvider>
  );
}
```

- [ ] **Step 3: Verify build**

```bash
cd frontend && pnpm build
```

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
cd frontend && git add src/App.tsx src/main.tsx
git commit -m "feat: wire HelmetProvider, i18n init, and dark mode ThemeInit into app bootstrap"
```

---

## Task 11: Routes — Add Public Routes and MarketingLayout

**Files:**
- Modify: `frontend/src/routes.tsx`
- Modify: `frontend/index.html`

- [ ] **Step 1: Read current routes.tsx, then rewrite with public routes**

`frontend/src/routes.tsx` — rewrite to add MarketingLayout and public routes:

```tsx
import { createBrowserRouter, Navigate } from 'react-router-dom';
import { Suspense, lazy } from 'react';
import { MarketingLayout } from './components/layout/MarketingLayout';
import { AppLayout } from './components/layout/AppLayout';
import { ProtectedRoute } from './components/layout/ProtectedRoute';
import { AdminRoute } from './components/layout/AdminRoute';
import { Loader } from './components/shared/Loader';
import { NotFoundPage } from './components/shared/NotFoundPage';
import { RouteErrorFallback } from './components/shared/RouteErrorFallback';

// Public pages
import { LandingPage } from './features/marketing/pages/LandingPage';
import { AboutPage } from './features/marketing/pages/AboutPage';
import { HowItWorksPage } from './features/marketing/pages/HowItWorksPage';
import { PrivacyPage } from './features/marketing/pages/PrivacyPage';
import { TermsPage } from './features/marketing/pages/TermsPage';
import { CookiesPage } from './features/marketing/pages/CookiesPage';
import { ContactPage } from './features/marketing/pages/ContactPage';

// Auth pages (eager — needed immediately after login)
import { VerifyEmailPage } from './features/auth/pages/VerifyEmailPage';
import { TriagePage } from './features/triage/pages/TriagePage';
import { TriageResultPage } from './features/triage/pages/TriageResultPage';
import { MySubmissionsPage } from './features/submissions/pages/MySubmissionsPage';

// Admin pages (lazy — only admin users need them)
const LoginPage = lazy(() =>
  import('./features/auth/pages/LoginPage').then((m) => ({ default: m.LoginPage }))
);
const RegisterPage = lazy(() =>
  import('./features/auth/pages/RegisterPage').then((m) => ({ default: m.RegisterPage }))
);
const DashboardPage = lazy(() =>
  import('./features/admin/pages/DashboardPage').then((m) => ({ default: m.DashboardPage }))
);
const SubmissionDetailPage = lazy(() =>
  import('./features/admin/pages/SubmissionDetailPage').then((m) => ({ default: m.SubmissionDetailPage }))
);
const UsersPage = lazy(() =>
  import('./features/admin/pages/UsersPage').then((m) => ({ default: m.UsersPage }))
);

function SuspenseFallback() {
  return <Loader message="" />;
}

export const router = createBrowserRouter([
  // ---- Public Marketing Pages (MarketingLayout) ----
  {
    element: <MarketingLayout />,
    errorElement: <RouteErrorFallback />,
    children: [
      { index: true, element: <LandingPage /> },
      { path: 'about', element: <AboutPage /> },
      { path: 'how-it-works', element: <HowItWorksPage /> },
      { path: 'privacy', element: <PrivacyPage /> },
      { path: 'terms', element: <TermsPage /> },
      { path: 'cookies', element: <CookiesPage /> },
      { path: 'contact', element: <ContactPage /> },
    ],
  },

  // ---- Authenticated App Pages (AppLayout) ----
  {
    element: (
      <ProtectedRoute>
        <AppLayout />
      </ProtectedRoute>
    ),
    errorElement: <RouteErrorFallback />,
    children: [
      { path: 'triage', element: <TriagePage /> },
      { path: 'triage/:id/result', element: <TriageResultPage /> },
      { path: 'submissions', element: <MySubmissionsPage /> },
    ],
  },

  // ---- Admin Pages (lazy loaded) ----
  {
    element: (
      <ProtectedRoute>
        <AdminRoute>
          <Suspense fallback={<SuspenseFallback />}>
            <AppLayout />
          </Suspense>
        </AdminRoute>
      </ProtectedRoute>
    ),
    errorElement: <RouteErrorFallback />,
    children: [
      { path: 'admin', element: <DashboardPage /> },
      { path: 'admin/submissions/:id', element: <SubmissionDetailPage /> },
      { path: 'admin/users', element: <UsersPage /> },
    ],
  },

  // ---- Unauth Pages (no layout wrapper — use their own design) ----
  {
    errorElement: <RouteErrorFallback />,
    children: [
      {
        path: 'login',
        element: (
          <Suspense fallback={<SuspenseFallback />}>
            <LoginPage />
          </Suspense>
        ),
      },
      {
        path: 'register',
        element: (
          <Suspense fallback={<SuspenseFallback />}>
            <RegisterPage />
          </Suspense>
        ),
      },
      { path: 'verify-email', element: <VerifyEmailPage /> },
    ],
  },

  // ---- Catch-all ----
  { path: '*', element: <NotFoundPage /> },
]);
```

- [ ] **Step 2: Update index.html title**

Read `frontend/index.html`, change `<title>frontend</title>` to:

```html
<title>TriageFlow — AI-Powered Patient Pre-Screening Demo</title>
```

And set lang attribute:

```html
<html lang="en">
```

- [ ] **Step 3: Verify TypeScript + build**

```bash
cd frontend && npx tsc --noEmit && pnpm build
```

Expected: clean compile and build.

- [ ] **Step 4: Commit**

```bash
cd frontend && git add src/routes.tsx index.html
git commit -m "feat: add public routes with MarketingLayout, restructure router for dual-layer site"
```

---

## Task 12: i18n Migration — Existing Auth Pages

**Files:**
- Modify: `frontend/src/features/auth/pages/LoginPage.tsx`
- Modify: `frontend/src/features/auth/pages/RegisterPage.tsx`
- Modify: `frontend/src/features/auth/pages/VerifyEmailPage.tsx`
- Modify: `frontend/src/components/layout/Header.tsx`

- [ ] **Step 1: Read current LoginPage.tsx, then wrap strings in useTranslation()**

The approach for each existing page: import `useTranslation`, destructure `{ t }`, replace all hardcoded English strings with `t()` calls from the `auth` namespace.

Example key replacements for LoginPage:

| Current string | Replace with |
|---|---|
| `"Log In"` / page title | `t('login.title')` |
| `"Email"` (label) | `t('login.email')` |
| `"you@example.com"` (placeholder) | `t('login.emailPlaceholder')` |
| `"Password"` (label) | `t('login.password')` |
| `"Enter your password"` | `t('login.passwordPlaceholder')` |
| `"Log In"` (button) | `t('login.submit')` |
| `"Logging in..."` | `t('login.submitting')` |
| `"Don't have an account?"` | `t('login.noAccount')` |
| `"Register"` (link) | `t('login.registerLink')` |
| `"Invalid email or password."` | `t('login.invalidCredentials')` |
| `"Please verify your email..."` | `t('login.unverified')` |
| `"Account created!..."` | `t('login.registrationSuccess')` |
| `"In development: check Mailpit..."` | `t('login.checkMailpit')` |

Also wrap the LoginPage with `<Helmet>`:

```tsx
<Helmet>
  <title>{t('login.title')} — TriageFlow</title>
</Helmet>
```

- [ ] **Step 2: Repeat for RegisterPage — same pattern, use `register.*` keys**

- [ ] **Step 3: Repeat for VerifyEmailPage — use `verifyEmail.*` keys**

- [ ] **Step 4: Update Header.tsx — swap hardcoded nav strings for `t('common:nav.*')` calls**

- [ ] **Step 5: Run tests to verify no regressions**

```bash
cd frontend && pnpm test
```

Expected: all 95 tests pass (i18n wraps don't change component behavior — they change displayed text).

- [ ] **Step 6: Commit**

```bash
cd frontend && git add src/features/auth/pages/ src/components/layout/Header.tsx
git commit -m "feat(i18n): migrate auth pages and Header to useTranslation"
```

---

## Task 13: i18n Migration — Triage + Submissions Pages

**Files:**
- Modify: `frontend/src/features/triage/pages/TriagePage.tsx`
- Modify: `frontend/src/features/triage/pages/TriageResultPage.tsx`
- Modify: `frontend/src/features/triage/components/SymptomInput.tsx`
- Modify: `frontend/src/features/triage/components/AnswerInput.tsx`
- Modify: `frontend/src/features/triage/components/ConversationBubble.tsx`
- Modify: `frontend/src/features/triage/components/OutcomeCard.tsx`
- Modify: `frontend/src/features/triage/components/UrgencyBadge.tsx`
- Modify: `frontend/src/features/submissions/pages/MySubmissionsPage.tsx`
- Modify: `frontend/src/features/submissions/components/SubmissionsList.tsx`

- [ ] **Step 1: Migrate TriagePage — use `triage.*` keys**
- [ ] **Step 2: Migrate TriageResultPage — use `triage.result.*` and `triage.urgencyLabels.*` keys**
- [ ] **Step 3: Migrate triage components — SymptomInput, AnswerInput, ConversationBubble, OutcomeCard, UrgencyBadge**
- [ ] **Step 4: Migrate MySubmissionsPage + SubmissionsList — use `triage.submissions.*` keys**

Note: UrgencyBadge currently maps urgency strings to colors via a lookup object. The display label should now come from `t(`triage:urgencyLabels.${urgency}`, urgency)`.

- [ ] **Step 5: Run tests**

```bash
cd frontend && pnpm test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
cd frontend && git add src/features/triage/ src/features/submissions/
git commit -m "feat(i18n): migrate triage and submissions pages/components to useTranslation"
```

---

## Task 14: i18n Migration — Admin Pages + Remaining Shared Components

**Files:**
- Modify: `frontend/src/features/admin/pages/DashboardPage.tsx`
- Modify: `frontend/src/features/admin/pages/SubmissionDetailPage.tsx`
- Modify: `frontend/src/features/admin/pages/UsersPage.tsx`
- Modify: `frontend/src/features/admin/components/StatsGrid.tsx`
- Modify: `frontend/src/features/admin/components/SubmissionsTable.tsx`
- Modify: `frontend/src/features/admin/components/UsersTable.tsx`
- Modify: `frontend/src/features/admin/components/FailedMessagesTable.tsx`
- Modify: `frontend/src/features/admin/components/ImpersonateButton.tsx`
- Modify: `frontend/src/components/layout/ImpersonationBanner.tsx`
- Modify: `frontend/src/components/shared/ErrorFallback.tsx`
- Modify: `frontend/src/components/shared/NotFoundPage.tsx`
- Modify: `frontend/src/components/shared/EmptyState.tsx`
- Modify: `frontend/src/components/shared/Loader.tsx`

- [ ] **Step 1: Migrate DashboardPage + all admin components — use `admin.*` keys**
- [ ] **Step 2: Migrate ImpersonationBanner — use `admin.impersonation.*` keys**
- [ ] **Step 3: Migrate shared components (ErrorFallback, NotFoundPage, EmptyState, Loader) — use `common.*` keys**
- [ ] **Step 4: Run tests**

```bash
cd frontend && pnpm test
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
cd frontend && git add src/features/admin/ src/components/
git commit -m "feat(i18n): migrate admin pages and shared components to useTranslation"
```

---

## Task 15: Add Footer to AppLayout

**Files:**
- Modify: `frontend/src/components/layout/AppLayout.tsx`

- [ ] **Step 1: Update AppLayout to include Footer**

Read current `frontend/src/components/layout/AppLayout.tsx`, then add Footer import and render:

```tsx
import { Outlet } from 'react-router-dom';
import { Header } from './Header';
import { Footer } from './Footer';
import { ImpersonationBanner } from './ImpersonationBanner';
import { CookieBanner } from '../shared/CookieBanner';
import { useAuth } from '../../hooks/useAuth';

export function AppLayout() {
  const { isImpersonating } = useAuth();

  return (
    <div className="flex min-h-screen flex-col">
      <Header />
      {isImpersonating && <ImpersonationBanner />}
      <main className="flex-1">
        <Outlet />
      </main>
      <Footer />
      <CookieBanner />
    </div>
  );
}
```

- [ ] **Step 2: Verify build**

```bash
cd frontend && npx tsc --noEmit && pnpm build
```

- [ ] **Step 3: Commit**

```bash
cd frontend && git add src/components/layout/AppLayout.tsx
git commit -m "feat: add Footer and CookieBanner to AppLayout"
```

---

## Task 16: Integration Verification — Full Build + Test Suite

- [ ] **Step 1: Full TypeScript check**

```bash
cd frontend && npx tsc --noEmit
```

Expected: zero errors. Fix any type issues found.

- [ ] **Step 2: Run all tests**

```bash
cd frontend && pnpm test
```

Expected: all existing 95 tests pass plus any new tests added in earlier tasks.

- [ ] **Step 3: Production build**

```bash
cd frontend && pnpm build
```

Expected: build succeeds, no warnings.

- [ ] **Step 4: ESLint check**

```bash
cd frontend && pnpm lint
```

Expected: clean (0 errors). Fix any lint issues found.

- [ ] **Step 5: Visual verification checklist** (manual — run `pnpm dev` and check):

- [ ] `http://localhost:5173/` → Landing page with hero, features, CTA buttons
- [ ] `/about` → About page with disclaimer
- [ ] `/how-it-works` → Step-by-step explanation
- [ ] `/privacy` → Privacy policy content
- [ ] `/terms` → Terms of service content
- [ ] `/cookies` → Cookie policy content
- [ ] `/contact` → Link to piotrswiderski.dev
- [ ] `/login` → Login form in EN, switch to PL → form in Polish
- [ ] `/register` → Registration form with translations
- [ ] Dark mode toggle → switches theme, persists on reload
- [ ] Language switcher → switches EN↔PL, persists on reload
- [ ] Cookie banner → appears on first visit, dismissed on "OK"
- [ ] Footer → visible on all pages, legal links work, toggle works

- [ ] **Step 6: Commit any fixes**

```bash
cd frontend && git add -A && git commit -m "chore: integration fixes and verification"
```

---

## Task 17: Backend — Localized Email Templates (PL)

**Files:**
- Modify: `backend/src/User/Infrastructure/Controller/RegistrationController.php`

- [ ] **Step 1: Accept Accept-Language header, choose template language**

In `RegistrationController`, after registration succeeds and before sending email, detect locale from request headers:

```php
$locale = $request->getPreferredLanguage(['en', 'pl']) ?? 'en';
```

Pass the locale to the email subject/body. The simplest approach: use an if/else in the controller to pick the template strings (no need for a full template engine for two locales).

```php
if ($locale === 'pl') {
    $subject = 'Zweryfikuj swój adres email — TriageFlow';
    $body = sprintf(
        "Witaj!\n\nKliknij poniższy link, aby zweryfikować swój adres email:\n\n%s/verify-email?token=%s\n\nTen link wygaśnie za 24 godziny.\n\n— TriageFlow",
        $defaultUri,
        $user->getEmailVerificationToken()
    );
} else {
    $subject = 'Verify your email address — TriageFlow';
    $body = sprintf(
        "Hello!\n\nClick the link below to verify your email address:\n\n%s/verify-email?token=%s\n\nThis link expires in 24 hours.\n\n— TriageFlow",
        $defaultUri,
        $user->getEmailVerificationToken()
    );
}

$email = (new Email())
    ->from('noreply@triageflow.local')
    ->to($user->getEmail())
    ->subject($subject)
    ->text($body);

$mailer->send($email);
```

- [ ] **Step 2: Verify with phpunit**

```bash
cd backend && php bin/phpunit tests/User/
```

Expected: all auth tests still pass.

- [ ] **Step 3: Commit**

```bash
cd backend && git add src/User/Infrastructure/Controller/RegistrationController.php
git commit -m "feat: send localized verification email based on Accept-Language header"
```

---

## Self-Review Checklist

**1. Spec coverage:**
- [x] Landing page (Task 7)
- [x] About page (Task 8)
- [x] How It Works page (Task 8)
- [x] Privacy Policy page (Task 9)
- [x] Terms of Service page (Task 9)
- [x] Cookie Policy page (Task 9)
- [x] Contact page (Task 8)
- [x] Dark mode toggle (Task 4)
- [x] Cookie consent banner (Task 5)
- [x] Language switcher (Task 5)
- [x] i18n EN + PL (Tasks 2, 3, 12-14)
- [x] SEO meta tags (Tasks 7-11 via Helmet)
- [x] Footer component (Task 6)
- [x] MarketingLayout + MarketingHeader (Task 6)
- [x] Design tokens expansion (Task 1)
- [x] Backend localized email (Task 17)
- [x] Route restructuring (Task 11)
- [x] Integration verification (Task 16)

**2. Placeholder scan:** No TBD, TODO, or "implement later" found. All tasks have concrete code.

**3. Type consistency:** All component imports match the file paths defined in the File Structure Map. i18n namespace keys match across locale files. Hook names (`useDarkMode`, `useTranslation`) are consistent across tasks.

---

## Dependencies & Parallel Execution

```
Task 1 (deps + tokens) ─────────────────────────────────────────────────────┐
                                                                             │
Task 2 (i18n EN) ──────────┐                                                │
Task 3 (i18n PL) ──────────┤─── Can run parallel with 4, 5 ─────┐            │
                            │                                     │            │
Task 4 (dark mode) ────────┤                                     │            │
Task 5 (cookie + lang) ────┘                                     │            │
                                                                  │            │
Task 6 (MarketingLayout) ─── depends on 4, 5 ────────────────────┤            │
                                                                  │            │
Task 7 (Landing) ─────────── depends on 2, 3, 6 ─────────────────┤            │
Task 8 (About+How+Contact) ─ depends on 2, 3, 6 ─────────────────┤            │
Task 9 (Legal pages) ─────── depends on 2, 3, 6 ─────────────────┤            │
                                                                  │            │
Task 10 (Providers) ──────── depends on 1, 2, 4 ─────────────────┤            │
Task 11 (Routes) ─────────── depends on 6, 7, 8, 9, 10 ──────────┤            │
                                                                  │            │
Task 12 (i18n Auth) ──────── depends on 2, 3 ────────────────────┤            │
Task 13 (i18n Triage) ────── depends on 2, 3 ────────────────────┤            │
Task 14 (i18n Admin) ─────── depends on 2, 3 ────────────────────┤            │
                                                                  │            │
Task 15 (Footer in AppLayout) ─ depends on 6, 11 ────────────────┤            │
                                                                  │            │
Task 16 (Verification) ────── depends on ALL above ──────────────┘            │
                                                                             │
Task 17 (Backend email) ──── independent ────────────────────────────────────┘
```

**Parallel batch strategy:**
- **Batch 1:** Tasks 1, 2, 3 — foundation (can run 2+3 in parallel)
- **Batch 2:** Tasks 4, 5 — dark mode + cookie/lang (parallel)
- **Batch 3:** Task 6 — MarketingLayout (depends on 4, 5)
- **Batch 4:** Tasks 7, 8, 9, 10 — pages + providers (parallel)
- **Batch 5:** Task 11 — routes (depends on 6, 7, 8, 9, 10)
- **Batch 6:** Tasks 12, 13, 14, 17 — i18n migration (parallel, 17 is independent)
- **Batch 7:** Task 15 — AppLayout footer
- **Batch 8:** Task 16 — verification
