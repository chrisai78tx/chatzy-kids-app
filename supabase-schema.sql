-- Chatzy real-time backend starter schema.
-- Run in a new Supabase project after reviewing privacy and retention settings.

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (char_length(username) between 3 and 16),
  friend_code text unique not null,
  avatar_letter text not null,
  avatar_color text not null,
  status text default 'Available',
  created_at timestamptz default now()
);

create table friendships (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references profiles(id) on delete cascade,
  receiver_id uuid not null references profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','blocked')),
  created_at timestamptz default now(),
  unique(requester_id, receiver_id)
);

create table conversations (
  id uuid primary key default gen_random_uuid(),
  name text,
  is_group boolean not null default false,
  created_by uuid not null references profiles(id),
  created_at timestamptz default now()
);

create table conversation_members (
  conversation_id uuid references conversations(id) on delete cascade,
  profile_id uuid references profiles(id) on delete cascade,
  joined_at timestamptz default now(),
  primary key(conversation_id, profile_id)
);

create table messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  body text check (char_length(body) <= 500),
  media_url text,
  created_at timestamptz default now()
);

create table reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles(id),
  reported_profile_id uuid references profiles(id),
  message_id uuid references messages(id),
  reason text,
  status text default 'open',
  created_at timestamptz default now()
);

alter table profiles enable row level security;
alter table friendships enable row level security;
alter table conversations enable row level security;
alter table conversation_members enable row level security;
alter table messages enable row level security;
alter table reports enable row level security;

create policy "profiles visible to signed in users" on profiles for select to authenticated using (true);
create policy "users update own profile" on profiles for update to authenticated using (auth.uid() = id);
create policy "friendships visible to participants" on friendships for select to authenticated using (auth.uid() in (requester_id, receiver_id));
create policy "members see conversations" on conversations for select to authenticated using (exists (select 1 from conversation_members m where m.conversation_id=id and m.profile_id=auth.uid()));
create policy "members see messages" on messages for select to authenticated using (exists (select 1 from conversation_members m where m.conversation_id=conversation_id and m.profile_id=auth.uid()));
create policy "members send messages" on messages for insert to authenticated with check (sender_id=auth.uid() and exists (select 1 from conversation_members m where m.conversation_id=conversation_id and m.profile_id=auth.uid()));
create policy "users create reports" on reports for insert to authenticated with check (reporter_id=auth.uid());
