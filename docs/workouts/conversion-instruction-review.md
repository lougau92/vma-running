# Conversion instruction review

Evidence: the three generated JSON files, decoded source emails, the agents’
visible completion reports, the parent’s task/follow-up messages and validation,
and Louis’s exported review notes. This assesses observable work and decisions,
not private internal reasoning.

## What needed intervention

| Observation | Instruction change |
| --- | --- |
| Initial assignments said to preserve notes/context without a relevance boundary; Fallon included changing rooms, bags and refreshments. | Keep only notes affecting workout execution. Explicitly exclude club administration and signatures. |
| Tuesday’s first output inferred passive movement for duration-only recoveries. The parent corrected it and warned the track agent. | Bare duration means unspecified movement. Reserve passive for explicit wording such as “pause sèche”. |
| The parent reminded both track/Tuesday agents about lighter variants, warmup budgets and final passive rests; Tuesday initially lacked the structured main budget. | Require complete versions, separate stated budgets from calculated durations, and check every section/final rest. |
| Fallon’s final two-minute recovery was flagged as blocking although Louis confirmed its placement. | Follow the written repeated block; flag actual competing prescriptions rather than hypothetical alternatives. Preserve reviewer resolutions. |
| An unseen relay conversion retained team lap stages without flagging the unclear individual recovery mapping. | Retain turn-taking and block unresolved team-to-individual work/rest mapping. |
| A later unseen conversion omitted the supplied Garmin route link. | Explicitly retain supplied route/GPX links as useful route instructions. |
| Track and Tuesday are very similar emails. | Convert each source fully; never use similarity as permission to omit content. |

The finished track/Tuesday artifacts preserve all three versions and the full
interval/recovery sequences. Louis reviewed both positively. Fallon now excludes
administrative notes and its existing issue records Louis’s recovery decision.
The original exported review is retained in `review-feedback.json`.

## Operational entrypoint

Use [the conversion skill](../../.agents/skills/convert-workout-email/SKILL.md).
`README.md` remains the detailed contract reference, not the agent’s task prompt.
The skill provides a short read → extract → source cross-check → validate flow;
its helper handles MIME decoding, typed-model/schema validation, duplicate IDs
and stale issue pointers. Structural validation cannot detect an omitted source
instruction or an unsupported interpretation.

## Evaluation

Two fresh GPT Luna agents ran the skill on Fallon and the track email without
parent corrections. Both passed validation and reported no unclear instructions;
both consulted existing reviewed outputs, so these are regression checks rather
than blind conversion tests. A fresh Luna run on the previously unconverted November 12 email correctly
excluded club announcements and retained the groups, warmup distance, budgets and
lap stages, but missed the unresolved relay work/rest mapping. After adding a
short relay rule, another fresh Luna run flagged that mapping without corrective
messages. Both outputs remained isolated in `/tmp`. The second run omitted the
Garmin route link; the instruction now explicitly includes supplied route/GPX
links. That final wording clarification has not had another blind conversion run.

Helper checks passed on all seven existing examples, rejection of a stale issue
pointer, and an HTML-only email retaining workout text. Skill metadata validation
also passed. This evidence supports the specific fixes; it does not establish
that future conversions will be error-free.
