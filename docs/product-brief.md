# ConnectMe — Product & UI/UX Design Brief

## Product Name

**ConnectMe**

## Product Overview

ConnectMe is a modern mobile communication application built with **Flutter and Dart**.

The core purpose of ConnectMe is to help people stay connected with the people they actually know and care about.

The application combines:

* Private messaging
* Voice and video calls
* Contacts
* Online presence
* Photo and video sharing
* Voice messages
* Disappearing / view-once media
* Daily stories
* Location sharing
* Interactive maps
* Privacy controls

ConnectMe should feel like a **personal communication space**, not like a public social network.

The product should prioritize **people, relationships, communication, privacy, and presence**.

---

## Backend / Infrastructure Decision (added post-brief)

The backend will be built entirely on **Supabase**:

* **Database** — Postgres (users, contacts, messages, calls metadata, stories, location shares)
* **Auth** — Supabase Auth (email/password to start; social providers can follow)
* **Storage** — Supabase Storage (avatars, chat media, voice messages, story media, disappearing/view-once media)
* **Realtime** — Supabase Realtime (presence, typing indicators, live message delivery, call signaling support, story view updates)
* **API** — Supabase auto-generated REST/PostgREST + RPC (Postgres functions) for business logic, secured with Row Level Security

This is a backend decision only — the current phase of work is still **frontend-only with mock/local data**. The frontend's data/repository layer should be written against abstract interfaces so the Supabase implementation can be dropped in later without reshaping the UI layer.

---

# 1. Product Philosophy

The central idea behind ConnectMe is:

> **People first. Communication second.**

ConnectMe should feel like a place where users communicate with their real-world contacts.

It should NOT feel like:

* A public social network
* A content feed
* A professional communication platform
* A Discord clone
* A WhatsApp clone
* A Telegram clone
* A Snapchat clone
* An Instagram clone

The application may use familiar interaction patterns where appropriate, but the visual identity, UX, navigation, and overall experience should feel like an original product.

The product should feel:

* Modern
* Premium
* Personal
* Friendly
* Intimate
* Fast
* Simple
* Polished
* Trustworthy

---

# 2. Target Experience

When a user opens ConnectMe, the application should immediately communicate:

> "These are my people."

The user should quickly be able to:

1. See their conversations
2. See which contacts are online
3. Start a conversation
4. Start a voice/video call
5. Share something
6. View stories
7. Share their location
8. Find and add new contacts

The most common actions should require minimal interaction.

The application should feel fast and lightweight even though it contains many features.

---

# 3. User Accounts & Identity

Users should be able to:

* Create an account
* Log in
* Log out
* Create a profile
* Set a profile picture
* Set their display name
* Have an email associated with their account
* Search for other users by name
* Search for other users by email
* Add users to contacts
* Remove contacts
* View contact profiles
* Edit their own profile

The identity system should feel personal rather than corporate.

Profiles should focus on the person rather than statistics.

Avoid follower counts, likes, popularity scores, or similar social-network mechanics.

---

# 4. Contacts

Contacts are one of the core parts of ConnectMe.

Users should be able to:

* Search for people
* Add contacts
* Remove contacts
* View contacts
* Open a contact's profile
* Start a chat
* Start a call
* View presence status

Presence states can include:

* Online
* Offline
* Last seen
* Typing
* In a voice call
* In a video call

Presence indicators should be subtle and elegant.

---

# 5. Private Messaging

ConnectMe should provide a polished one-to-one messaging experience.

Messages should support:

* Text
* Emojis
* Reactions
* Images
* Videos
* Voice messages
* Replying to messages
* Message timestamps
* Read receipts
* Delivery status
* Typing indicators
* Message deletion
* Copy/share actions where appropriate

The chat experience should be one of the strongest parts of the application.

Pay special attention to:

* Message bubbles
* Message grouping
* Avatars
* Message timestamps
* Media previews
* Full-screen media viewing
* Voice message controls
* Keyboard behavior
* Scrolling
* Sending states
* Failed messages
* Empty states
* Loading states
* Conversation header
* Context menus
* Long messages

The chat should feel extremely natural and responsive.

---

# 6. Disappearing / View-Once Media

Users should be able to send temporary photos and videos.

The sender should be able to mark media as temporary.

Possible modes:

* View once
* View twice
* Expiring after a specific period

The receiver should clearly understand that the media is temporary.

The UI should communicate:

* Whether the media has been opened
* Whether it is still available
* Whether it has expired

Temporary media should feel like a native part of ConnectMe rather than a separate feature.

Privacy and user expectations must be very clear.

---

# 7. Voice Messages

Users should be able to record and send voice messages.

Design a polished voice-message experience including:

* Recording state
* Recording timer
* Cancel gesture
* Waveform
* Playback
* Pause/resume
* Playback progress
* Duration
* Sending state

The interaction should be simple enough to use naturally with one hand.

---

# 8. Voice & Video Calls

ConnectMe should support:

* One-to-one voice calls
* One-to-one video calls
* Incoming calls
* Outgoing calls
* Missed calls
* Call history
* Microphone mute
* Camera enable/disable
* Camera switching
* Speaker mode
* End call
* Picture-in-picture where appropriate

The call UI should be clean and immersive.

Avoid unnecessary controls.

During a video call, the user should feel that the interface gets out of the way and the people become the focus.

---

# 9. Online Presence

Presence is an important part of ConnectMe.

Users should be able to understand whether their contacts are available.

Examples:

* Online
* Offline
* Last seen
* Typing
* Calling
* In a video call

Use subtle animations and indicators where appropriate.

Do not make presence feel like a corporate status system.

---

# 10. Location Sharing

Users should be able to voluntarily share their location with contacts.

ConnectMe should provide a beautiful, modern map experience.

Location sharing should support temporary sharing:

* 15 minutes
* 1 hour
* Until manually stopped

The recipient should be able to see:

* Contact avatar
* Contact location
* Location status
* Whether sharing is active

The map experience should feel integrated into the ConnectMe ecosystem.

Do not simply create a generic map screen.

Create a polished communication-oriented location experience.

Privacy must be extremely obvious.

Users should always know:

* Who can see their location
* How long it will be visible
* How to stop sharing

---

# 11. Daily Stories

Users should be able to publish daily stories.

Stories can contain:

* Photos
* Videos
* Text
* Emojis
* Stickers
* Simple visual elements

Stories should expire after 24 hours.

Users should be able to:

* Create a story
* View stories from contacts
* See viewed/unviewed stories
* See who viewed their own story
* Delete their story
* Control who can view their story

The story experience should feel personal and intimate.

Do NOT simply copy Instagram or Snapchat.

---

# 12. Story Privacy

Users should have control over who can see their stories.

Possible options:

* All contacts
* Close friends
* Selected contacts

Privacy controls should be simple and understandable.

Privacy should feel like part of the product experience rather than an afterthought.

---

# 13. Home Screen

The home screen should provide an immediate overview of communication.

It should potentially include:

* Recent conversations
* Unread messages
* Online contacts
* Recent calls
* Story indicators
* Quick actions

However, do not overload the home screen.

The primary purpose should remain:

> **Find a person and communicate with them.**

---

# 14. Navigation

Design a mobile-first navigation system.

Possible core areas:

* Chats
* Contacts
* Stories
* Calls
* Profile / Settings

Do not blindly use a standard five-tab navigation.

Think carefully about the relationships between these features.

The navigation must be:

* Intuitive
* Fast
* One-hand friendly
* Visually clean
* Consistent
* Easy to learn

The user should never wonder where a feature is located.

---

# 15. Profiles

Profiles should be simple and personal.

A profile can contain:

* Avatar
* Display name
* Presence
* Contact actions
* Call actions
* Location-sharing status where relevant
* Shared media
* Privacy-related actions

Avoid unnecessary social statistics.

This is a communication application, not a social ranking system.

---

# 16. Privacy & Security UX

Privacy is a fundamental part of ConnectMe.

The product contains sensitive functionality such as:

* Private conversations
* Personal photos
* Temporary media
* Location sharing
* Stories
* Video calls

Design privacy controls clearly.

Users should understand:

* Who can contact them
* Who can see their stories
* Who can see their location
* How long location sharing lasts
* When temporary media expires
* Who can see their presence

The UI should create a feeling of trust.

---

# 17. Design System

Before designing the complete application, establish a consistent design system.

Define:

### Colors

* Primary color
* Secondary colors
* Backgrounds
* Surface colors
* Text hierarchy
* Error states
* Success states
* Warning states
* Online/presence colors

### Typography

* Font family
* Display typography
* Headings
* Body
* Captions
* Labels

### Components

Create reusable components for:

* Buttons
* Inputs
* Avatars
* Message bubbles
* Cards
* Bottom sheets
* Modals
* Navigation
* Tabs
* Badges
* Chips
* Status indicators
* Story indicators
* Media previews
* Voice messages
* Call controls
* Map elements
* Lists

### Motion

Define subtle animations for:

* Sending messages
* Receiving messages
* Opening media
* Story transitions
* Presence changes
* Navigation
* Calls
* Bottom sheets
* Modals

Animations should enhance the experience rather than distract from it.

---

# 18. Flutter Considerations

The frontend will be implemented using:

**Flutter + Dart**

Therefore, design components that are realistic and maintainable within Flutter.

Prefer:

* Reusable components
* Clear component states
* Consistent spacing
* Predictable layouts
* Responsive behavior
* Native-feeling interactions

Avoid unnecessarily complicated visual effects that provide little UX value.

The final design should be realistically implementable as a production Flutter application.

---

# 19. Core Screens

Design the following core screens:

### Authentication

1. Splash
2. Onboarding
3. Sign up
4. Login
5. Profile setup

### Communication

6. Home / Chats
7. Chat list
8. One-to-one chat
9. Media viewer
10. Voice message interaction
11. User profile

### Contacts

12. Contacts
13. Search users
14. Contact profile
15. Add contact flow

### Calls

16. Incoming call
17. Outgoing call
18. Active voice call
19. Active video call
20. Call history

### Stories

21. Stories overview
22. Story viewer
23. Create story
24. Story viewers

### Location

25. Location sharing
26. Map view
27. Contact location
28. Location sharing controls

### Settings

29. Settings
30. Privacy
31. Notifications
32. Account

Do not attempt to design every possible edge case initially.

Establish the core product experience first.

---

# 20. UX States

For every important feature, consider:

* Empty state
* Loading state
* Success state
* Error state
* Offline state
* Permission denied state
* First-use state
* Active state
* Disabled state

Especially consider permission flows for:

* Camera
* Microphone
* Photos
* Notifications
* Location

These should feel native, clear, and non-intrusive.

---

# 21. Visual Identity

Create a distinctive visual identity for **ConnectMe**.

The name should influence the visual language.

Think about concepts such as:

* Connection
* People
* Presence
* Proximity
* Conversation
* Sharing
* Relationships

Do not use generic technology imagery.

Do not automatically default to gradients, neon colors, glassmorphism, or excessive rounded cards simply because they are currently popular.

Every visual decision should have a reason.

The result should look contemporary but should still feel good several years from now.

---

# 22. Avoid Design Clichés

Do NOT produce:

* Generic AI dashboard aesthetics
* Generic SaaS UI
* Excessive gradients
* Excessive glassmorphism
* Overuse of floating cards
* Random colorful blobs
* Excessive animations
* Excessive rounded containers
* Copycat WhatsApp layouts
* Copycat Telegram layouts
* Copycat Instagram stories
* Copycat Snapchat interfaces
* Copycat Discord navigation

Use familiar UX conventions when they make sense, but create an original visual system.

---

# 23. Product Personality

ConnectMe should feel:

**Personal, warm, confident, modern, premium, approachable and alive.**

It should not feel:

**Corporate, sterile, childish, overly futuristic, noisy or overly gamified.**

The interface should make people feel comfortable spending time communicating with people they care about.

---

# 24. Design Process

Do NOT immediately generate dozens of screens.

Follow this process:

### Phase 1 — Product Understanding

Analyze the product and identify the most important user journeys.

### Phase 2 — Information Architecture

Define:

* Navigation
* Screen hierarchy
* Feature relationships
* User flows

### Phase 3 — Visual Direction

Propose:

* Color direction
* Typography
* Icon style
* Component philosophy
* Spacing
* Shape language
* Motion principles

### Phase 4 — Design System

Create the reusable design system and core components.

### Phase 5 — Core Screens

Design the most important screens first:

1. Home
2. Contacts
3. Chat
4. Profile
5. Stories
6. Calls
7. Location

### Phase 6 — Refinement

Review the entire system for:

* Consistency
* Usability
* Accessibility
* Visual hierarchy
* Mobile ergonomics
* Flutter implementation feasibility

Only after the core system is coherent should secondary screens be designed.

---

# 25. Final Goal

The final result should feel like a **real, commercially viable mobile communication product**.

It should not look like:

> "An AI generated chat app."

It should look like:

> **ConnectMe — a communication product with a strong, recognizable identity.**

The most important goal is not to maximize the number of features.

The goal is to make the features feel like they belong to **one coherent product**.

Every screen should answer the same fundamental idea:

> **ConnectMe helps you stay connected to your people.**
