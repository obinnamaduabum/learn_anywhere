# Security and privacy

Learn Anywhere is a local proof of concept. Production staff authentication, cross-device recovery, and secure high-stakes assessment are not implemented.

## Handling sensitive information

- Keep admin tokens and environment secrets out of source control, logs, screenshots, and documentation.
- Store mobile installation tokens in platform secure storage. The backend stores token hashes.
- Collect only the anonymous identity and learning activity needed for progress synchronization. Avoid adding personal information without a clear requirement.
- Keep local development services bound to local interfaces. Development database credentials are not suitable for a public deployment.
- Preserve idempotency checks and transaction boundaries when changing synchronization or point calculation.

Content approval addresses publication and review; it does not establish that material has undergone security, factual, or bilingual expert certification.

## Reporting a problem

Share sensitive findings privately with the repository maintainer using an agreed private channel. A dedicated security reporting address has not been configured. Include the affected component, reproduction steps, and likely impact; omit real tokens and learner records. Do not publish working credentials or private data in a public issue.

### Optional local learner profile

Age, gender, learning interest and engagement preferences are optional local settings. Learners can skip profile setup and later clear age/gender in Profile. These fields are saved in the existing device database snapshot and are not added to backend API payloads or LAN pack sharing. Recommendation ranking uses interest and preferred content language, not demographic fields. Checkpoint practice does not send assessment-answer events or award points.

Adaptive-coaching activity and feedback remain local and can be disabled or forgotten in Profile. The optional Ask ChatGPT flow previews a limited aggregate summary, copies only on user action, and opens the fixed HTTPS ChatGPT website without learner data in its URL. Sharing requires the user to paste/send it separately; the app does not automate sign-in, send tokens, scrape ChatGPT, or add an API provider for coaching.

The learning companion uses an authenticated backend endpoint, retrieves published lesson context server-side, and excludes assessment questions and learner history from provider input. No API key is stored in Flutter. Only an explicit user action sends course content to Groq. Provider retention policies apply. Supplementary output may be inaccurate and is labeled as AI help. Development per-process quotas are not sufficient distributed production abuse protection.
