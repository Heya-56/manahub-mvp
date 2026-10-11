-- ManaHub MVP — social core
-- Apply to a dedicated ManaHub Supabase project, not the Academy project.
-- No payment processing is implemented by this migration.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  handle text not null unique check (handle ~ '^[a-z0-9_]{3,30}$'),
  display_name text not null check (char_length(display_name) between 1 and 80),
  avatar_url text,
  bio text not null default '' check (char_length(bio) <= 500),
  location text not null default '' check (char_length(location) <= 120),
  account_type text not null default 'member'
    check (account_type in ('member', 'artisan', 'business', 'organization')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null default '' check (char_length(body) <= 2200),
  media_path text,
  post_type text not null default 'story'
    check (post_type in ('story', 'product', 'announcement')),
  status text not null default 'published'
    check (status in ('draft', 'published', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint posts_content_present check (char_length(trim(body)) > 0 or media_path is not null)
);

create index if not exists posts_author_created_idx on public.posts (author_id, created_at desc);
create index if not exists posts_published_created_idx on public.posts (created_at desc) where status = 'published';

create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  followed_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followed_id),
  constraint follows_no_self_follow check (follower_id <> followed_id)
);

create index if not exists follows_followed_idx on public.follows (followed_id, created_at desc);

create table if not exists public.post_likes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  post_id uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

create table if not exists public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 1000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists comments_post_created_idx on public.comments (post_id, created_at asc);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (char_length(trim(name)) between 1 and 120),
  description text not null default '' check (char_length(description) <= 3000),
  price_xpf integer check (price_xpf is null or price_xpf >= 0),
  currency text not null default 'XPF' check (currency = 'XPF'),
  image_path text,
  status text not null default 'draft' check (status in ('draft', 'active', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists products_seller_created_idx on public.products (seller_id, created_at desc);
create index if not exists products_active_created_idx on public.products (created_at desc) where status = 'active';

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.follows enable row level security;
alter table public.post_likes enable row level security;
alter table public.comments enable row level security;
alter table public.products enable row level security;

-- Profiles: public business identity; account credentials stay in Supabase Auth.
create policy "Profiles are readable by everyone"
  on public.profiles for select using (true);
create policy "Users create their own profile"
  on public.profiles for insert to authenticated
  with check (id = (select auth.uid()));
create policy "Users update their own profile"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Feed: public published content; authors manage their own posts.
create policy "Published posts are public"
  on public.posts for select
  using (status = 'published' or author_id = (select auth.uid()));
create policy "Users create their own posts"
  on public.posts for insert to authenticated
  with check (author_id = (select auth.uid()));
create policy "Users update their own posts"
  on public.posts for update to authenticated
  using (author_id = (select auth.uid()))
  with check (author_id = (select auth.uid()));
create policy "Users delete their own posts"
  on public.posts for delete to authenticated
  using (author_id = (select auth.uid()));

-- Follow graph: authenticated users can follow/unfollow only as themselves.
create policy "Follow relationships are public"
  on public.follows for select using (true);
create policy "Users follow as themselves"
  on public.follows for insert to authenticated
  with check (follower_id = (select auth.uid()));
create policy "Users unfollow as themselves"
  on public.follows for delete to authenticated
  using (follower_id = (select auth.uid()));

-- Likes: public counts/identity, but each user can manage only their own likes.
create policy "Post likes are public"
  on public.post_likes for select using (true);
create policy "Users like as themselves"
  on public.post_likes for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy "Users remove their own likes"
  on public.post_likes for delete to authenticated
  using (user_id = (select auth.uid()));

-- Comments are visible on public posts. Authors create/delete their own comments.
create policy "Comments on published posts are public"
  on public.comments for select
  using (
    exists (
      select 1 from public.posts p
      where p.id = comments.post_id
        and (p.status = 'published' or p.author_id = (select auth.uid()))
    )
  );
create policy "Users comment as themselves on visible posts"
  on public.comments for insert to authenticated
  with check (
    author_id = (select auth.uid())
    and exists (
      select 1 from public.posts p
      where p.id = comments.post_id and p.status = 'published'
    )
  );
create policy "Users delete their own comments"
  on public.comments for delete to authenticated
  using (author_id = (select auth.uid()));

-- Storefront products: active listings are public; sellers manage their own catalogue.
create policy "Active products are public"
  on public.products for select
  using (status = 'active' or seller_id = (select auth.uid()));
create policy "Sellers create their own products"
  on public.products for insert to authenticated
  with check (seller_id = (select auth.uid()));
create policy "Sellers update their own products"
  on public.products for update to authenticated
  using (seller_id = (select auth.uid()))
  with check (seller_id = (select auth.uid()));
create policy "Sellers delete their own products"
  on public.products for delete to authenticated
  using (seller_id = (select auth.uid()));

-- Intentionally no anon/authenticated grants on order, payment, or webhook tables:
-- these are not created here and must be added only with a server-side payment design.
