# Content generation and publication review

Generated lessons and translations are drafts until explicitly approved. Approval of an earlier batch does not authorize later batches or changed material.

## Prepare a draft

Specify the topic, intended learners, language, learning outcomes, prerequisites, and practical completion task. Use short text-first lessons suitable for limited data. Provide clear source attribution with credible HTTPS references. Do not claim source verification unless it has actually been performed.

The current pack contract requires five ordered lessons. Include practice questions with unique identifiers, at least two options, a valid correct option index, and an explanation. The app presents these questions as one assessment at the end of the part.

For a series, plan the parent and ordered parts separately. Downloadable content belongs to each part's stable ID. The current admin API publishes packs; it does not provide a series-management endpoint.

## Review checklist

- Check factual accuracy, reading level, learning outcomes, examples, and explanations.
- Check that references support the lesson and are traceable.
- Check that lesson and question IDs are unique and stable, and answers match the explanations.
- For translations, preserve lesson order, question IDs, option order, and correct option indices. Review language quality and Arabic directionality where applicable.
- Distinguish translation from local relevance. Verify country-specific curricula, credentials, institutions, and opportunities before including them.
- Check accessibility, readable text, small downloads, and an experience that remains useful without optional media.
- State who reviewed the material, when, what scope they reviewed, and any limitations. Owner demo approval is not bilingual expert certification.

## Approval and publication

1. Import through `POST /api/v1/admin/drafts` using an administrator session obtained from `/api/v1/admin/auth/login`. The configured `ADMIN_TOKEN` only authorizes first-login administrator creation.
2. Inspect the saved draft through `GET /api/v1/admin/drafts/{id}` and prepare a human-readable review document.
3. Obtain explicit approval for the named course, versions, and languages.
4. Publish only approved drafts through `POST /api/v1/admin/drafts/{id}/approve`, recording the reviewer information required by the API.
5. Verify catalog visibility, each published language download, and the stable lesson/question identities.

Keep credentials private throughout this process. Do not embed tokens in review documents. Do not overwrite published packs: use a new content version for corrections and preserve progress compatibility.

## Current demo approval

The owner approved the existing Understanding AI English course and the French, Portuguese, Arabic, Hausa, Yorùbá, and Igbo translations for the local demo. The translation review record is [multilingual-review.md](../frontend/assets/course-drafts/understanding-ai-languages/multilingual-review.md). These records do not grant approval for future generated content.
