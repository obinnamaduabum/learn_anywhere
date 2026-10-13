# Learn Anywhere — five-minute project video transcript

A ready-to-narrate capstone walkthrough: 15 chapters of 20 seconds, exactly 5:00 on the edited timeline. Narration word count: 724. Match voice speed to each chapter; the word count alone does not guarantee recorded duration.

## Recording context

The video uses the installed Debug app on an iPhone 17 simulator after the local learning directory was backed up and cleared. It does not show a completed reinstall. Only local simulator learning state was reset; the backend and physical phone were preserved. Setup downloads an available pack; choosing a course is separate. No real personal details are entered. Quiz submission/results and a network-disabled offline test are not demonstrated. Database architecture is explanatory narration over app footage, not a recording of a database interface.

## 0:00–0:20 · Welcome to Learn Anywhere

Hi, I’m Obinna. Welcome to Learn Anywhere, an app for learning with limited connectivity. We begin with fresh local learning state on the iPhone simulator. We will choose preferences, find a course, read its lessons, try explanations, and explore the tools that help learners continue.

**On screen:** Offline-first learning; First launch on iPhone.

**Suggested raw source:** 12–53 seconds. 42 spoken words.

## 0:20–0:40 · Choose a language

The first step is language selection. Learn Anywhere supports English, French, Portuguese, Arabic, Hausa, Yoruba, and Igbo. I select English for this demonstration and apply the choice. Available learning content can download during setup, so setup uses a connection.

**On screen:** Seven supported languages; English for this walkthrough.

**Suggested raw source:** 53–110 seconds. 39 spoken words.

## 0:40–1:00 · Set optional preferences

Next comes the optional learner profile. You can personalize the experience and choose whether lessons should start with the shorter explained version. No email, password, or real personal information is required for this walkthrough. I leave the optional details empty and skip ahead to the main app.

**On screen:** No learner account required; Profile details are optional.

**Suggested raw source:** 110–133 seconds. 47 spoken words.

## 1:00–1:20 · Start from Home

Home is the starting point for learning. It combines course access and reading progress. Setup may already have saved an available pack, but choosing a course is a separate action. Opening a lesson alone does not mean that its reading or assessment is complete.

**On screen:** Choose a course; Track reading separately from quizzes.

**Suggested raw source:** 133–156 seconds. 44 spoken words.

## 1:20–1:40 · Explore Discover

Discover is where learners find published courses. Each card introduces the subject and offers a way to open its contents. This demonstration uses the original AI for Everyday Tasks course. New discovery and missing downloads need a connection; the saved library gives us a separate place to return later.

**On screen:** Browse published courses; Fetch new content while connected.

**Suggested raw source:** 166–191 seconds. 49 spoken words.

## 1:40–2:00 · Open the course contents

The course contents provide an ordered path through the material. Here we can see six lessons, their reading state, and the language saved on this device. Opening a course fetches a missing language pack when needed. Choose a lesson and begin at the top.

**On screen:** Six lessons in this course; Saved language shown.

**Suggested raw source:** 191–205 seconds. 44 spoken words.

## 2:00–2:20 · Read and listen

The regular lesson combines readable text with practical activities. Its reading estimate and Ready offline status help explain what is available. Read aloud offers another way to engage using an available device voice, with a speed control nearby. Playback starts in this demo; I pause and stop it before continuing.

**On screen:** Ready offline status; Read-aloud and speed controls.

**Suggested raw source:** 205–224 seconds. 49 spoken words.

## 2:20–2:40 · Switch to an explanation

The teal lightbulb switches the same page to its explained version. This substitutes a shorter, simpler explanation for the regular lesson body. It does not open a different course or change the final assessment. A learner can use this view to grasp the main idea, then return to the fuller teaching.

**On screen:** Tap the teal lightbulb; Shorter explanation on the same page.

**Suggested raw source:** 224–250 seconds. 51 spoken words.

## 2:40–3:00 · Read at your own pace

Both versions support learning at your own pace. The explanation is saved content rather than a fresh response generated for every tap. Switching views starts reading at the top again, while progress stays separate. The bookmark icon also offers a quick way to keep a lesson for a later visit.

**On screen:** Saved explained content; Bookmark a lesson for later.

**Suggested raw source:** 250–312 seconds. 50 spoken words.

## 3:00–3:20 · Try the final quiz

Back at the course contents, I open the final quiz. A question presents four answer choices. Selecting one enables the next question, and answers are saved locally as the learner proceeds. This walkthrough stops before submission: we are demonstrating the assessment flow, without claiming a completed course, final score, or result.

**On screen:** Select one answer; Next question · no submission shown.

**Suggested raw source:** 319–360 seconds. 51 spoken words.

## 3:20–3:40 · Change the course language

Language can also be changed after setup using the globe control. Here I select French and apply it. A missing published translation downloads before it is used. The course can retain both English and French on this device, so choosing another language does not mean discarding the first saved pack.

**On screen:** Open the globe control; English and French saved.

**Suggested raw source:** 360–390 seconds. 50 spoken words.

## 3:40–4:00 · Return to saved learning

Downloads organizes the local course library. Its readiness labels and saved-language details make it easier to know what is stored. Learners can open a course or manage its languages from here. We show saved text readiness in this recording; we have not switched off the network to perform an offline test.

**On screen:** Open a saved course; Manage saved languages.

**Suggested raw source:** 445–458 seconds. 51 spoken words.

## 4:00–4:20 · Adjust the experience

Profile and settings let learners revisit their preferences. They can adjust the reading experience and choose whether explained lessons should be their starting view. These choices support different learning needs without requiring a learner account. The app remains a working proof of concept, with further translation review and deployment hardening still needed.

**On screen:** Language and reading preferences; Optional explained-content preference.

**Suggested raw source:** 458–470 seconds. 52 spoken words.

## 4:20–4:40 · How saved learning works

Behind the interface, Flutter runs the app and SQLite stores downloaded packs and pending activity on the phone. A Quarkus backend serves published content from PostgreSQL. When synchronization succeeds, acknowledged event identifiers help avoid duplicate rewards. This architecture connects a local learning experience with centrally managed content and confirmed progress.

**On screen:** Flutter + phone SQLite; Quarkus + PostgreSQL.

**Suggested raw source:** 470–485 seconds. 50 spoken words.

## 4:40–5:00 · What comes next

Codex helped develop the app and backend, inspect learning flows, and produce documentation and demonstration materials. The next steps are learner testing, bilingual review, and a stronger production deployment. Learn Anywhere aims to make useful learning easier to return to: choose a course, save it, and continue at your own pace.

**On screen:** Implementation and verification support; Learner testing and translation review.

**Suggested raw source:** 485–500 seconds. 51 spoken words.

## Evidence and editing notes

Feature claims checked against the project README and the current database explanation at `outputs/database-explanation/README.md`. Raw timing references come from the parent agent’s live capture. Preserve action order when trimming. Avoid suggesting that explanation toggling changes quiz answers, that opening marks a lesson read, or that this recording proves all translations have been reviewed. The optional backend chapter should use a clear explanatory overlay.
