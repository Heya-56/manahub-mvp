# ManaHub — MVP plan and architecture

## Product intent
ManaHub is a social-commerce network for Polynesian creators, artisans, merchants, organisations and customers. A profile doubles as a storefront; posts can introduce a story, a product or an announcement; social discovery should lead to contact and, later, an order.

## Current state
The existing `Manahub/index.html` is a rich static prototype. Its account/session and checkout interactions are client-side simulations. They must not be represented as real authentication, persistent social activity, or payment processing. Preserve the design and content where possible, but progressively replace simulation logic with real services.

## MVP architecture
- Frontend: existing mobile-first PWA under `Manahub/`, deployed on Cloudflare Pages.
- Source of truth: GitHub repository and small reviewed commits/PRs.
- Identity and persistence: a dedicated Supabase project for ManaHub (EU region preferred), using Supabase Auth, Postgres and Storage.
- Access control: PostgreSQL Row Level Security (RLS) on every user-owned table; never place service-role credentials in browser code.
- Payments: OSB PayZen integration only after the provider's API/contract details are validated. Browser UI must never claim payment succeeded based on a local click. Payment confirmation must come from a trusted server-side callback/webhook and be idempotent.
- Observability and privacy: collect only required data, publish a privacy notice, define retention and deletion procedures, and document processors/subprocessors.

## Core MVP scope
1. Real signup/login/logout and profile creation/editing.
2. Public profile pages with handle, biography, location and account type.
3. Feed with persisted posts, optional media, likes, comments and follow/unfollow.
4. Seller catalogue with XPF-priced products and public active listings.
5. Clear contact/request-to-buy flow before online payment is enabled.
6. Basic reporting/moderation path and user data deletion process.
7. Installable PWA and mobile smoke tests.

## Deliberately not claimed yet
- No live payment processing or verified orders.
- No secure production checkout until OSB integration and server-side verification are implemented.
- No production-ready moderation, analytics or large-scale recommendation engine.
- No guarantee of security merely because Cloudflare or Supabase is used.

## Implementation sequence
- Phase 1: schema and RLS foundation; use a dedicated ManaHub Supabase project, never the Academy project.
- Phase 2: wire auth and profiles to the existing frontend.
- Phase 3: implement feed, follows, likes and comments.
- Phase 4: implement seller catalogue and contact/request flow.
- Phase 5: integrate and test OSB PayZen server-side; then deploy a pilot and verify privacy/security.
