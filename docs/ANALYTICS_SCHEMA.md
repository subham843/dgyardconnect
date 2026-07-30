# Analytics schema & KPIs

Single source of truth for Firebase Analytics event names, parameters, and how to build reports.

---

## Event naming

- Use **snake_case**: `job_posted`, `payment_completed`.
- Prefix by domain only when needed: `support_ticket_created` (no `dealer_` — role is in user properties if needed).

---

## Events and parameters

| Event name | When fired | Parameters | Type |
|------------|------------|------------|------|
| `job_posted` | Dealer successfully posts a job | `jobId` (string), `biddingEnabled` (bool), `emergency` (bool) | custom |
| `payment_completed` | Dealer completes payment (Razorpay or legacy) | `jobId` (string), `method` (string: `razorpay` \| `legacy`), `amount` (number) | custom |
| `warranty_claim_created` | Dealer submits a warranty claim | `jobId`, `claimId`, `has_photos` (bool), `has_video` (bool) | custom |
| `job_dispute_created` | Dealer raises a dispute | `jobId`, `has_photos`, `has_video` | custom |
| `support_ticket_created` | User creates a support ticket | `ticketId`, `subject_len` (number) | custom |

**Screen views** are tracked automatically via GoRouter + `FirebaseAnalyticsObserver` (screen names from route paths).

---

## Recommended KPIs (for dashboards/reports)

### Funnel: Job → Payment → Completion

| KPI | Definition | How to get (BigQuery / Analytics) |
|-----|------------|-----------------------------------|
| **Jobs posted** | Count of jobs created by dealers | Count `job_posted` events |
| **Payments completed** | Count of successful payments | Count `payment_completed` events |
| **Payment success rate** | Payments / Jobs posted (for jobs that reached payment step) | `payment_completed` / jobs that had status `payment_pending` (backend or event-based) |
| **Job conversion (post → pay)** | % of posted jobs that get paid | `payment_completed` count / `job_posted` count (over same period) |

### Trust & safety

| KPI | Definition | How to get |
|-----|------------|------------|
| **Warranty claims rate** | Warranty claims per completed job | `warranty_claim_created` count / completed jobs (from backend or completion events) |
| **Dispute rate** | Disputes per job (e.g. per paid or completed) | `job_dispute_created` count / paid or completed jobs |

### Support

| KPI | Definition | How to get |
|-----|------------|------------|
| **Support tickets created** | Volume of new tickets | Count `support_ticket_created` |
| **Tickets per active user** | Tickets / MAU or DAU | `support_ticket_created` / unique users (Analytics audience) |

### Optional future events (for richer funnel)

- `job_completed` — when dealer confirms completion (or backend marks completed).
- `bid_accepted` — when dealer accepts a bid (step between post and payment).
- `technician_rated` / `dealer_rated` — after rating screen submit.

Use these in BigQuery export or Analytics reports to build conversion funnels and cohort views.

---

## BigQuery export (Firebase)

If you enable **BigQuery linking** in Firebase Console → Project settings → Integrations:

- Events appear in `analytics_events_*` tables.
- Query by `event_name` and `event_params` to compute the KPIs above.
- Example: count payments in last 30 days  
  `SELECT COUNT(*) FROM ... WHERE event_name = 'payment_completed' AND event_timestamp BETWEEN ... AND ...`

---

## Code reference

- **Log events**: `AnalyticsService.logEvent(name, params: {...})`  
  See `lib/shared/services/analytics_service.dart`.
- **Event names in app**: Prefer constants from `lib/core/constants/analytics_events.dart` (if added) to avoid typos.
