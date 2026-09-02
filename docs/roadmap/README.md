# Implementation Roadmap

The implementation plan for PC Usage Intelligence is maintained in [`implementation-roadmap.md`](implementation-roadmap.md).

## Milestones

| Milestone | Outcome |
|---|---|
| M0 | Engineering foundation |
| M1 | Deterministic tracking kernel |
| M2 | Durable background tracker |
| M3 | First useful local product |
| M4 | Intelligent history + browser analytics |
| M5 | Encrypted sync + device continuity |
| M6 | Release candidate |

## Guiding rule

Implementation proceeds from the smallest trustworthy tracking kernel outward. Do not begin with the dashboard or cloud sync before the underlying history model is proven by deterministic replay fixtures.
