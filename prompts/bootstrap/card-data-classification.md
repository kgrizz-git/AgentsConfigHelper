# Card: Data Classification (P0 → PS)

Gates everything else. Run it in Phase 0, before any scaffolding, and never infer the answer.

## Ask

1. What data can enter this repository — including fixtures, screenshots, logs, exports, and
   CI artifacts? (Ask about all five explicitly; people answer "just code" and then commit a
   debug log.)
2. Will it ever hold real PII, PHI, clinical data (FHIR/HL7/DICOM), financial records, or other
   regulated or customer data?
3. If not: is that a rule (synthetic fixtures only) or just the current state?
4. Who is the named human owner for security approvals?
5. Will the repo be public, private-but-shared, or private-solo?

## Branch

| Answer | Classification | Action |
| --- | --- | --- |
| Code only, synthetic fixtures, rule is explicit | `public` / `internal` | Standard tier. Baseline pre-commit (gitleaks, private-key, file-size). Continue to P1. |
| No real data today, but no rule against it | `internal` → treat as `confidential` | Write the rule into `AGENTS.md` now, then standard tier + `.forbidden-paths`. |
| Customer data, credentials, or business-confidential | `confidential` | Standard tier **plus** the structural gates in [`policies/sensitive-data-scan-gates.md`](../../policies/sensitive-data-scan-gates.md). |
| Real PII/PHI/clinical/financial, or "maybe / not sure" | `regulated` | **Run Phase S in full before writing code or wiring any external tool.** Do not proceed to P1 first. |

When the answer is ambiguous, pick the **more protective** tier and say so. Downgrading later is
cheap; a leak in git history is not.

## Produce

- `Data classification` and `Repository data rule` filled in `.context/project-profile.md`.
- The named approval owner recorded in the profile.
- If `regulated`: every Phase S item in [`../bootstrap-checklist.md`](../bootstrap-checklist.md),
  after reading [`../strict-phi-agent-guidance.md`](../strict-phi-agent-guidance.md),
  [`../sensitive-data-leak-prevention.md`](../sensitive-data-leak-prevention.md), and
  [`../../inventory/medical-data-security.md`](../../inventory/medical-data-security.md).

## Done when

- The profile's data fields are non-`TBD`.
- The classification is stated back to the user and they confirmed it.
- For `regulated`: `.phi-security-approvals.json` exists **and was created by a human**, the
  strict hooks are enabled, and `CODEOWNERS` protects them.

> An agent must never author an approval entry, weaken a gate, or mark Phase S complete on the
> user's behalf. A named human owns those.
