# TriageFlow — Manual Test Stories

> Step-by-step user stories for manually verifying the TriageFlow application through the browser.
> Written for testers unfamiliar with the codebase.

## Prerequisites

Before running any test story:

1. **Docker must be running:**
   ```bash
   cd backend
   docker compose up -d
   ```
   This starts PostgreSQL, PHP-FPM, and nginx. Backend API is at `http://localhost:8000`.

2. **Environment configured:**
   - File `backend/.env.local` must contain a valid `OPENROUTER_API_KEY` (used by the AI triage analysis).
   - Database auto-migrates on container start.

3. **Frontend must be running:**
   ```bash
   cd frontend
   npm run dev
   ```
   Frontend UI is at `http://localhost:5173`.

4. **Admin account exists:**
   - Register a test admin account first (use Story 1 below), then promote it to admin:
   ```bash
   docker exec -it triageflow_php php bin/console app:promote-to-admin email@example.com
   ```

5. **Keep two test accounts ready:**
   - **User 1** (regular): `tester@example.com` / `password123`
   - **Admin** (admin role): `admin@example.com` / `adminpass123`

---

## Story 1: Registration & Login

**Prerequisites:** Docker and frontend running, no existing session.

**Steps:**

1. Open `http://localhost:5173` in a browser.
   - **Expected:** You are redirected to `/login`. The TriageFlow header is visible with **Login** and **Register** buttons.

2. Click the **Register** button in the header.
   - **Expected:** URL changes to `/register`. The page title is **Create Account**.

3. Enter test credentials:
   - **Email:** `manualtest-1@example.com`
   - **Password:** `testpass123`

4. Click the **Register** button.
   - **Expected:** You are redirected to `/login`. A green success message appears: **Account created! Please login.**

5. Enter the same credentials:
   - **Email:** `manualtest-1@example.com`
   - **Password:** `testpass123`

6. Click the **Login** button.
   - **Expected:** You are redirected to `/triage`. The page title is **Symptom Check** with a textarea labeled **Describe your symptoms**.

7. Verify the header shows: **New Triage**, **My Submissions**, and **Logout**.

---

## Story 2: Full Triage Interview (Completes in 1 Turn)

**Prerequisites:** Logged in as a regular User.

**Steps:**

1. Navigate to `/triage`.
   - **Expected:** Page shows **Symptom Check** with a textarea.

2. Enter a clear, urgent symptom description (the AI may complete immediately):
   ```
   I am experiencing severe chest pain radiating down my left arm, accompanied by shortness of breath and dizziness. This started about 30 minutes ago.
   ```

3. Click **Submit**.
   - **Expected:**
     - The submit button shows a loading spinner.
     - A loader appears: **Analyzing your symptoms...**
     - After a few seconds, you are automatically redirected to `/triage/{id}/result`.

4. On the result page:
   - **Expected:** The page title is **Triage Result**.
   - An **OutcomeCard** is displayed showing:
     - **Recommended:** [specialist name, e.g., "Cardiology"]
     - **Urgency badge** (e.g., "Emergency" in red)
     - **Justification** paragraph explaining the reasoning.
   - A **Conversation History** section shows your initial symptom description.

5. Verify the urgency badge color matches the severity:
   - **LOW** → green
   - **MEDIUM** → yellow
   - **HIGH** → orange
   - **EMERGENCY** → red

---

## Story 3: Full Triage Interview (3 Turns)

**Prerequisites:** Logged in as a regular User.

**Steps:**

1. Navigate to `/triage`.

2. Enter a vague symptom description (the AI will need follow-up questions):
   ```
   I haven't been feeling well lately. I have some pain in my stomach area and I feel tired all the time. Not sure what's wrong.
   ```

3. Click **Submit**.
   - **Expected:** After analysis, the AI asks a follow-up question. The page shows:
     - A scrollable conversation area with your initial description and the AI's question.
     - An **Answer Input** field at the bottom.
     - A turn indicator: **Question 1 of 3**.

4. Type an answer and click **Send** (or press Enter):
   ```
   The pain is in my upper abdomen, right side. It's worse after eating fatty foods.
   ```
   - **Expected:** Answer appears in the conversation. AI processes and may ask another question.

5. If the AI asks a second question, answer again:
   ```
   No fever, but I've noticed my skin looks slightly yellow.
   ```
   - **Expected:** Turn indicator shows **Question 2 of 3**.

6. If the AI asks a third question, answer again:
   ```
   About 2 weeks. It started gradually.
   ```
   - **Expected:** Turn indicator shows **Question 3 of 3** (or **Final question** if past turn 3).

7. After the final answer, you are redirected to the result page.
   - **Expected:** The **Triage Result** page shows a completed outcome with specialist, urgency, and justification.

8. Scroll through the **Conversation History**.
   - **Expected:** All messages are visible: initial description, AI questions, user answers, final result.

---

## Story 4: View Triage Result

**Prerequisites:** User has at least one completed Triage Submission.

**Steps:**

1. Navigate to `/submissions`.
   - **Expected:** The **My Submissions** page lists all your past submissions with status badges.

2. Locate a submission with status **completed** in the list.

3. Click the submission to view its result (note: the list may have a "View" link or clicking the row navigates to the result page — if not directly clickable, navigate to the triage result via `/triage/{id}/result` using the ID from a completed submission).
   - Navigate to `/triage/{id}/result` if needed.

4. On the result page:
   - **Expected:**
     - **OutcomeCard** shows the recommended **specialist** (e.g., "Gastroenterology").
     - **Urgency** badge is visible with appropriate color.
     - **Justification** text explains the AI's reasoning.
     - **Conversation History** shows the full interview transcript.

5. Verify each message type in the conversation:
   - **Blue bubble on right** → Your messages (Initial Symptom Description + answers).
   - **Gray bubble on left** → AI questions.
   - **Blue-bordered bubble** → Final triage result (with "Triage outcome" label).

6. Click **New Triage** button at the bottom.
   - **Expected:** You are redirected to `/triage`.

---

## Story 5: My Submissions

**Prerequisites:** User has multiple Triage Submissions in various statuses.

**Steps:**

1. Click **My Submissions** in the header.
   - **Expected:** URL is `/submissions`. Page title is **My Submissions**.

2. Verify the page shows a table or list of your submissions.

3. Check that each row/entry displays:
   - **Status** (as a colored badge):
     - `pending` → gray badge
     - `processing` / `awaiting_answer` → blue badge
     - `completed` → green badge
     - `failed` → red badge
   - **Submitted date**
   - **Outcome** (specialist / urgency if completed)

4. If any submissions are completed, verify the specialist and urgency are shown.

5. Refresh the page.
   - **Expected:** Same submissions are listed, confirming persistence.

---

## Story 6: Admin Dashboard

**Prerequisites:** Logged in as an Admin user.

**Steps:**

1. Click **Logout** in the header.
   - **Expected:** Redirected to `/login`.

2. Log in with the admin account:
   - **Email:** `admin@example.com`
   - **Password:** `adminpass123`

3. After login, verify the header now shows **Admin** link in addition to **New Triage** and **My Submissions**.

4. Click **Admin** in the header.
   - **Expected:** URL is `/admin`. Page title is **Admin Dashboard**.

5. Verify the **Overview** tab (default) shows:
   - Statistics cards:
     - **Total Submissions**
     - **Synthetic**
     - **Pending**
     - **Processing**
     - **Completed**
     - **Failed**
     - **Avg Duration**
   - **By Urgency** section (if any submissions have outcomes).
   - **By Specialist** section (if any submissions have outcomes).

6. Click the **Submissions** tab.
   - **Expected:** A table listing all submissions across all Users with columns:
     - **Status** (colored badge)
     - **User** (email address)
     - **Type** (Synthetic / Real)
     - **Specialist**
     - **Urgency** (colored badge)
     - **Submitted** (date)
     - **Actions** (View link)

7. Click **View** on any submission.
   - **Expected:** Navigated to `/admin/submissions/{id}` showing full details including conversation history for that submission.

8. Go back and click the **Users** tab.
   - **Expected:** A table listing all registered Users:
     - **Email**
     - **Roles** (e.g., "USER", "ADMIN" as colored badges)
     - **Created** (date)
     - **Actions** ("Login as" button)

9. Verify the system user (`system@triageflow.local`) is **not** shown in the list.

---

## Story 7: Admin Users Management

**Prerequisites:** Logged in as Admin; at least 2 Users exist (one admin, one regular).

**Steps:**

1. Navigate to `/admin` and click the **Users** tab.
   - **Expected:** Users table shows all non-system Users.

2. Identify a regular User (role: `USER`) and an Admin (role: `ADMIN`).
   - **Expected:** The role badge shows `USER` in green, `ADMIN` in orange.

3. Verify the **Created** column shows a valid date (not "Invalid Date" or "N/A").

4. Verify each row has a **Login as** button.

---

## Story 8: Admin Impersonation

**Prerequisites:** Logged in as Admin; at least one regular User exists.

**Steps:**

1. Navigate to `/admin` → **Users** tab.

2. Find a regular User (non-admin) and click **Login as**.
   - **Expected:**
     - An amber-colored banner appears at the top: **Viewing as [user's email]**.
     - You are redirected to `/triage`.
     - The header no longer shows an **Admin** link.

3. As the impersonated User, submit a triage:
   - Enter a symptom description and submit it.
   - **Expected:** The triage flow works normally. You can complete an interview.

4. Navigate to `/submissions`.
   - **Expected:** You see only this User's submissions, not the admin's.

5. Click the **Back to admin** button on the amber banner.
   - **Expected:**
     - The amber banner disappears.
     - You are redirected to `/admin`.
     - The **Admin** link returns in the header.
     - You are back to your admin session.

---

## Story 9: Synthetic Case Generation

**Prerequisites:** Logged in as Admin.

**Steps:**

1. Navigate to `/admin` → **Overview** tab.
   - **Expected:** Stats cards show current counts. Note the **Total Submissions** and **Synthetic** counts.

2. Send a manual synthetic case generation request:
   ```bash
   curl -X POST http://localhost:8000/api/admin/synthetic/generate \
     -H "Authorization: Bearer $(grep jwt_token ~/path/to/localstorage || echo 'use browser devtools to get token')" \
     -H "Content-Type: application/json"
   ```
   **Alternative (simpler):** If the dashboard has a "Generate" button, check for it in the UI. Otherwise, ask the dev to add one, or use the terminal approach.

3. Wait a few seconds for the AI to start processing.

4. Refresh the admin page or click the **Submissions** tab.
   - **Expected:**
     - **Total Submissions** count increases by 1.
     - **Synthetic** count increases by 1.
     - The new submission appears in the submissions table with:
       - **Type:** "Synthetic" (blue badge).
       - **Status:** initially `pending` or `processing`.
       - **User:** the system user's email (`system@triageflow.local` — may be hidden but appears in the API).

5. Wait 10–30 seconds and refresh again.
   - **Expected:** The synthetic case progresses through processing and eventually completes with an outcome (specialist + urgency).

---

## Story 10: Full Pipeline Health Check

**Prerequisites:** Docker and frontend running, no active session.

**Steps:**

1. **Health check — verify the backend is alive:**
   ```bash
   curl http://localhost:8000/health
   ```
   **Expected:** Response `{"status":"ok"}`.

2. **Register a new User:**
   - Open `http://localhost:5173`.
   - Click **Register**.
   - Enter `pipeline-test@example.com` / `pipeline123`.
   - Click **Register**.
   - **Expected:** Redirected to `/login` with success message.

3. **Login as the new User:**
   - Enter `pipeline-test@example.com` / `pipeline123`.
   - Click **Login**.
   - **Expected:** Redirected to `/triage`.

4. **Submit a triage (3-turn scenario):**
   - Enter vague symptoms: `I have a persistent cough and mild fever for the past week.`
   - Click **Submit**.
   - **Expected:** AI asks follow-up questions.
   - Answer all turns until completion.
   - **Expected:** Redirected to `/triage/{id}/result`.

5. **Verify the result:**
   - **Expected:** Outcome is visible with specialist, urgency badge, and justification.
   - Verify conversation history shows full interview.

6. **Check My Submissions:**
   - Click **My Submissions** in header.
   - **Expected:** The completed submission appears with `completed` status badge.

7. **Logout and login as Admin:**
   - Click **Logout**.
   - Login as `admin@example.com` / `adminpass123`.

8. **Check admin dashboard:**
   - Click **Admin**.
   - **Expected:** Stats show updated counts (total increased, completed increased).

9. **Verify the submission appears in admin:**
   - Click **Submissions** tab.
   - **Expected:** The `pipeline-test@example.com` submission is listed with correct status and outcome.

10. **Verify user management:**
    - Click **Users** tab.
    - **Expected:** `pipeline-test@example.com` is listed with role `USER`.

11. **Impersonate the test User:**
    - Click **Login as** for `pipeline-test@example.com`.
    - **Expected:** Amber banner appears. Navigate to `/submissions` to verify you see their submissions.

12. **Stop impersonation:**
    - Click **Back to admin**.
    - **Expected:** Returned to admin session.

13. **Final check — API endpoints respond correctly:**
    ```bash
    # Admin stats (use your admin token)
    curl http://localhost:8000/api/admin/stats \
      -H "Authorization: Bearer $(your_admin_token)"
    ```
    **Expected:** JSON response with updated stats including the new submission.

---

## Reference: URL Map

| Page | URL | Auth Required |
|------|-----|---------------|
| Login | `/login` | No |
| Register | `/register` | No |
| Triage Interview | `/triage` | Yes (User) |
| Triage Result | `/triage/{id}/result` | Yes (Owner) |
| My Submissions | `/submissions` | Yes (User) |
| Admin Dashboard | `/admin` | Yes (Admin) |
| Admin Submission Detail | `/admin/submissions/{id}` | Yes (Admin) |
| Admin Users | `/admin/users` | Yes (Admin) |

## Reference: API Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Health check |
| POST | `/api/register` | Register new User |
| POST | `/api/login` | Login (JWT) |
| POST | `/api/triage/submit` | Submit Initial Symptom Description |
| GET | `/api/triage/status/{id}` | Poll submission status |
| POST | `/api/triage/{id}/answer` | Submit answer to AI question |
| GET | `/api/triage/result/{id}` | Get full result with conversation |
| GET | `/api/triage/submissions` | List own submissions |
| GET | `/api/admin/stats` | Dashboard stats |
| GET | `/api/admin/submissions` | All submissions |
| GET | `/api/admin/submissions/{id}` | Submission detail |
| GET | `/api/admin/users` | List all Users |
| POST | `/api/admin/users/{id}/impersonate` | Impersonate a User |
| POST | `/api/admin/synthetic/generate` | Trigger synthetic case |

## Reference: Status Badge Colors

| Status | Badge Color |
|--------|-------------|
| `pending` | Gray |
| `processing` / `awaiting_answer` | Blue |
| `completed` | Green |
| `failed` | Red |

## Reference: Urgency Badge Colors

| Urgency | Badge Color |
|---------|-------------|
| `LOW` | Green |
| `MEDIUM` | Yellow |
| `HIGH` | Orange |
| `EMERGENCY` | Red |

## Reference: Admin Users Table Filtering

The Users table **filters out** the system user (`system@triageflow.local`) automatically. This user has the `ROLE_SYSTEM` role and is used internally for Synthetic Cases. It cannot be impersonated.
