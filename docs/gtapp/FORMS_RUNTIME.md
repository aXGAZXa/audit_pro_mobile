# GTApp Forms Runtime – APM Guide (DEV / NOT FOR ACTIVE USE)

APM is **not** shipping the JSON-driven declarative forms system right now.

This document is kept for historical/reference purposes only. Do not build new
Audit Pro Mobile features on:
- `GTDeclarativeFormView`
- `FormPackage` / JSON-driven form packages
- `registerFormComponents()` / `registerQuestionWidgets()` / `registerFormWidgets()`

Why:
- The declarative engine/builder is not considered production-ready for APM.
- We need delivery certainty: hard-coded screens are faster to ship and easier
  to reason about.

## What to use instead (APM supported approach)

Build hard-coded, strongly-typed screens from reusable components, and submit
explicit, versioned payloads to the portal APIs.

Reference implementation:
- The Heat Network Assessment (HNA) flow vendored into APM under:
  - `lib/apm/forms/heat_network_assessment/`
  - `lib/apm/forms/heat_network_assessment/services/`

Key properties of this approach:
- Stable submission schema via a payload builder (`HnaSubmissionPayloadBuilder`).
- Uses the existing HNA portal endpoints (`/api/hna/*`).
- Supports dynamic client list sync from `/api/hna/clients`.

