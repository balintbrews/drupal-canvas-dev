---
name: drupalorg-issue-writer
description: Draft a Drupal.org issue title and description in copy-paste-ready
Markdown. Use this skill when the user asks for a Drupal.org issue, issue
summary, or issue description based on a bug, feature request, diff, commit, or
discussion.
---

# Drupal.org issue writer

Use this skill when drafting a Drupal.org issue for copy-paste into drupal.org.

## Workflow

1. Gather the core facts from the current request, local changes, or nearby
   documentation.
2. Infer the issue type from context:
   - Bug report: explain the current problem and its impact.
   - Feature request: explain the missing capability and why it matters.
   - Follow-up task: explain the gap, cleanup, or next step.
3. If the problem, proposed fix, or user impact is still unclear after checking
   available context, ask one concise follow-up question. Otherwise, draft the
   issue directly.

## Output requirements

- Return raw Markdown only.
- Always wrap the output in a fenced code block so it can be copied as one
  block.
- Keep the title in imperative tense, and make it as short as the context
  allows.
- Use sentence case for the title and description text.
- Keep the description concise, concrete, and ready to paste into the issue
  body.
- Use this exact structure for the description:

Title: <short imperative issue title>

Description:

<h3 id="overview">Overview</h3>

<plain-language summary of the problem, gap, or request>

<h3 id="proposed-resolution">Proposed resolution</h3>

<plain-language summary of the recommended change>

<h3 id="ui-changes">User interface changes</h3>

<either a short description of the UI impact or `n/a`>

## Writing rules

- Do not add extra sections.
- For bug reports, include brief reproduction steps in the overview when they
  are known.
- Do not add acceptance criteria or screenshots unless the user explicitly asks
  for them.
- Prefer short paragraphs over long lists.
- Use `n/a` exactly when there are no UI changes.
- Avoid hedging and filler. State the issue directly.
