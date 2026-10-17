# DECISIONS — FUSE VALLEY
Log every ambiguity resolved during the build: date, question, decision, GDD section. Locked design decisions are in GDD §2.

| Date | Question | Decision | GDD |
|---|---|---|---|
| 2026-10-17 | The 10 open questions before the GDD | The user said "go" → the recommended picks were locked (GDD §2, D1–D11) | §2 |
| 2026-10-17 | Where do Chase's Combat dive/history numbers go? | `Config.Movement` (the dive stays in MovementCore, unused by FUSE VALLEY; `HISTORY_SECONDS` raised to 6.5 for the moment replay) | §9, §10.5 |
| 2026-10-17 | Lobby techniques | Kept Chase's rule: only Dash outside a round | §9.4 |
| 2026-10-17 | P0 test flow without a round system | A temporary `Sandbox` service makes everyone an active Runner on the Meadow start strip; it gets deleted in P1 | §23.3 |
