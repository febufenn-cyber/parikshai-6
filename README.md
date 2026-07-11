# Parikshai

> an AI tutor that generates unlimited vernacular mock questions and explains every wrong answer for state exams.

**Alternative to the product-shape pioneered by Entri (YC S20)** — rank #6 of 500 in the [YC-500 Fable 5 Venture Blueprint](https://github.com/) (score 7.35/10).

## Why this exists
Government-exam aspirants want cheap vernacular practice and doubt-solving. The buildable wedge: an ai vernacular doubt-solver and mock-test generator for one exam.

## MVP scope
- [ ] Syllabus-based question gen
- [ ] vernacular explanations
- [ ] timed mocks
- [ ] weak-topic tracking
- [ ] daily practice reminders

## Architecture
`Workers+Supabase+Claude` — Cloudflare Workers + Hono API, Supabase (Postgres + RLS + Auth + pgvector), Claude API via Agent SDK (claude-fable-5 for agent reasoning, claude-haiku-4-5 for volume), wrangler deploys.

**Integrations:** Claude; TTS for audio explanations
**Data:** Syllabus, question bank, attempt logs, weak topics
**Agent core:** Agent generates fresh questions and tutors each wrong answer in the learner's language.

## Business
| | |
|---|---|
| Monetization | $2-5/mo subscription |
| First customer | State government-exam aspirants in tier-2/3 India |
| GTM wedge | YouTube and Telegram exam-prep communities, regional SEO. |
| Competition risk | High: Entri and coaching apps |
| Regulatory/trust risk | Low |
| India angle | Regional-language mock tests for Indian state and central exams. |
| Difficulty / build time | Low / 2-3 weeks |

## 30-day plan
- **W1:** core loop — Syllabus-based question gen + vernacular explanations
- **W2:** timed mocks + weak-topic tracking + daily practice reminders + auth + billing
- **W3:** polish, instrument events, seed first users via: YouTube and Telegram exam-prep communities, regional SEO.
- **W4:** launch + first revenue; kill/scale decision

---
*Built with Fable 5 (Claude Code). Blueprint row: inspired by Entri — "Vernacular exam-prep and skilling app in eight Indian languages."*