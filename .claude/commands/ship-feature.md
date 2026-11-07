---
description: Ship a whole feature end-to-end (spec → api → app → qa → stats), one gated commit per layer, via the driver skill
argument-hint: <feature description or name>
---

Use the Skill tool to load the `driver` skill, then run it for this feature: $ARGUMENTS

Follow the driver skill's workflow exactly — resume check, then layers spec → api → app → qa → stats in order, one commit per layer, running the gate before advancing between api/app/qa/stats. Do not skip layer 1, 4, or 5. Finish with `git push-pr`.
