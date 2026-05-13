# Ticket Checklist

| # | Title | Phase | Status |
|---|-------|-------|--------|
| 001 | App title + stale bodyweight after reset | Phase 1 — Quick wins | ✅ Complete |
| 002 | Fix height & goal weight not loading in imperial | Phase 1 — Quick wins | ✅ Complete |
| 003 | Create global unit preference provider | Phase 2 — Unit infrastructure | ❌ Pending |
| 004 | Bodyweight imperial + authoritative unit + 2dp rounding | Phase 2 — Unit infrastructure | ❌ Pending |
| 005 | Serving units: schema migration + API parsing | Phase 3 — Serving units | ❌ Pending |
| 006 | Serving units: UI | Phase 3 — Serving units | ❌ Pending |
| 007 | Log tab rework: recent foods + today's entries with delete | Phase 4 — Log tab | ❌ Pending |

### Phase ordering

The phases are designed to be worked in order (each depends on the previous), except:
- **Phase 1 tickets** (001, 002) are independent — can be done in any order or parallel
- **Phase 2** requires 003 before 004
- **Phase 3** requires 005 before 006
- **Phase 4** (007) is independent of Phases 2-3

### Status key

| Symbol | Meaning |
|--------|---------|
| ❌ Pending | Not started |
| 🔄 In progress | Currently being worked |
| ✅ Complete | Acceptance criteria met, tested |
