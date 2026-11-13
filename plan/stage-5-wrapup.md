# Stage 5: Wrap-up (weeks 49-52, about 40 hours)

---
## Week 49: Get to know Multigres
**Tasks**
- [ ] Clone `multigres/multigres`; read the contributing guide and developer docs; build and run it locally the documented way.
- [ ] Read the architecture documentation and a handful of recent merged pull requests to learn the code style and review habits.
- [ ] Look through open issues for small, well-scoped items (docs gaps, flaky tests, unclear errors, small bugs).
- [ ] `docs/multigres-notes.md`: what you learned, plus five ranked candidate fixes. Do not copy code into your own project.

**Done when:** Multigres runs locally; the notes file exists with five candidates.

## Week 50: Upstream
**Tasks**
- [ ] Open an issue first if scope is unclear. Pick one or two items and follow the project's process and conventions.
- [ ] Keep each PR small, with tests, and respond to review promptly.
- [ ] Record outcomes in `PROGRESS.md`.

**Done when:** one or two PRs or detailed issues are submitted. (At the time of planning, only minor fixes were being accepted from outside contributors; check the repo's current guidance.)

## Week 51: Polish
**Tasks**
- [ ] A top-level README that tells the story: what it is, what it proves, how to reproduce it; an architecture diagram; an index of decision records.
- [ ] `make demo`: a five-minute demo (kill a primary under load, then a live reshard); record it as a terminal recording.
- [ ] Fresh-host reproducibility check; pin versions; remove secrets; add a license.

**Done when:** a stranger can clone the repo, run `make demo`, and see it work.

## Week 52: Apply
**Tasks**
- [ ] A one-page "what I built and what it shows" that maps your work to the role's areas: consensus, routing, materialization, scale. Name the limits honestly.
- [ ] A short, specific cover note linking the write-ups, the TLA+ spec, test results and PRs.
- [ ] Interview preparation: be able to explain your failover protocol and the TLA+ invariants, the cutover steps, and every trade-off in the decision records. Ask Claude to quiz you.
- [ ] Apply, and share your write-ups.

**Done when:** the application is sent.
