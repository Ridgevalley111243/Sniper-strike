-- Trutech Business website: portfolio, settings and client work.
-- Everything is prefixed site_ and kept apart from the dues system's tables.

-- Admins of the website (not dues admins).
create table public.site_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  must_change_password boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.site_admins enable row level security;
create policy "site admin reads own row" on public.site_admins
  for select to authenticated using (user_id = (select auth.uid()));

create function private.is_site_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.site_admins where user_id = (select auth.uid()));
$$;
revoke all on function private.is_site_admin() from public;
grant execute on function private.is_site_admin() to authenticated;

create function public.site_password_changed() returns void
language sql security definer set search_path = '' as $$
  update public.site_admins set must_change_password = false where user_id = (select auth.uid());
$$;
revoke all on function public.site_password_changed() from public, anon;
grant execute on function public.site_password_changed() to authenticated;

create function private.site_touch() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- Portfolio projects shown on the Work page.
create table public.site_projects (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and length(slug) <= 80),
  title text not null check (length(title) between 1 and 160),
  client text not null default '',
  category text not null default '',
  year int not null default extract(year from now())::int check (year between 1990 and 2100),
  status text not null default 'Completed' check (status in ('Live', 'Completed', 'In development', 'Planned')),
  summary text not null default '',
  cover text,
  gallery jsonb not null default '[]'::jsonb check (jsonb_typeof(gallery) = 'array'),
  services text[] not null default '{}',
  link text check (link is null or link ~ '^https?://'),
  featured boolean not null default false,
  sort_order int not null default 10,
  body text not null default '',
  published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger site_projects_touch before update on public.site_projects
  for each row execute function private.site_touch();
alter table public.site_projects enable row level security;
create policy "published projects are public" on public.site_projects
  for select to anon using (published);
create policy "admin reads all projects" on public.site_projects
  for select to authenticated using (published or (select private.is_site_admin()));
create policy "admin inserts projects" on public.site_projects
  for insert to authenticated with check ((select private.is_site_admin()));
create policy "admin updates projects" on public.site_projects
  for update to authenticated using ((select private.is_site_admin())) with check ((select private.is_site_admin()));
create policy "admin deletes projects" on public.site_projects
  for delete to authenticated using ((select private.is_site_admin()));

-- Name, contact details and social links (one row).
create table public.site_settings (
  id smallint primary key default 1 check (id = 1),
  data jsonb not null default '{}'::jsonb check (jsonb_typeof(data) = 'object'),
  updated_at timestamptz not null default now()
);
create trigger site_settings_touch before update on public.site_settings
  for each row execute function private.site_touch();
alter table public.site_settings enable row level security;
create policy "settings are public" on public.site_settings for select to anon, authenticated using (true);
create policy "admin updates settings" on public.site_settings
  for update to authenticated using ((select private.is_site_admin())) with check ((select private.is_site_admin()));

-- Changes whenever anything public changes; the site redeploys when it does.
create function public.site_content_version() returns text
language sql stable set search_path = '' as $$
  select md5(
    coalesce((select string_agg(id::text || '@' || updated_at::text, ',' order by id)
              from public.site_projects where published), '')
    || '|' || coalesce((select updated_at::text from public.site_settings where id = 1), '')
  );
$$;
grant execute on function public.site_content_version() to anon, authenticated;

-- Client work: each row is one private link for a client.
create function private.site_token() returns text
language sql volatile set search_path = '' as $$
  select translate(encode(extensions.gen_random_bytes(18), 'base64'), '+/', '-_');
$$;

create table public.site_deliveries (
  id uuid primary key default gen_random_uuid(),
  token text not null unique default private.site_token(),
  client_name text not null check (length(client_name) between 1 and 120),
  client_phone text,
  title text not null check (length(title) between 1 and 160),
  message text not null default '',
  kind text not null default 'review' check (kind in ('review', 'delivery')),
  status text not null default 'awaiting_review'
    check (status in ('awaiting_review', 'changes_requested', 'approved', 'delivered')),
  allow_download boolean not null default true,
  active boolean not null default true,
  expires_at timestamptz,
  viewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger site_deliveries_touch before update on public.site_deliveries
  for each row execute function private.site_touch();

create table public.site_delivery_files (
  id uuid primary key default gen_random_uuid(),
  delivery_id uuid not null references public.site_deliveries (id) on delete cascade,
  path text not null unique,
  name text not null,
  size bigint not null default 0,
  mime text not null default 'application/octet-stream',
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index on public.site_delivery_files (delivery_id);

create table public.site_delivery_reviews (
  id uuid primary key default gen_random_uuid(),
  delivery_id uuid not null references public.site_deliveries (id) on delete cascade,
  reviewer_name text not null default '' check (length(reviewer_name) <= 120),
  decision text not null check (decision in ('approve', 'changes', 'feedback')),
  rating smallint check (rating between 1 and 5),
  comment text not null default '' check (length(comment) <= 4000),
  created_at timestamptz not null default now()
);
create index on public.site_delivery_reviews (delivery_id);

-- Only the admin reads or writes client work directly; clients go through
-- the client-portal edge function, which checks the link's token.
alter table public.site_deliveries enable row level security;
alter table public.site_delivery_files enable row level security;
alter table public.site_delivery_reviews enable row level security;
create policy "admin manages deliveries" on public.site_deliveries
  for all to authenticated using ((select private.is_site_admin())) with check ((select private.is_site_admin()));
create policy "admin manages delivery files" on public.site_delivery_files
  for all to authenticated using ((select private.is_site_admin())) with check ((select private.is_site_admin()));
create policy "admin manages reviews" on public.site_delivery_reviews
  for all to authenticated using ((select private.is_site_admin())) with check ((select private.is_site_admin()));

-- Storage: public portfolio images, private client files.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('site-media', 'site-media', true, 15728640, array['image/webp', 'image/jpeg', 'image/png', 'image/gif', 'image/avif', 'image/svg+xml']),
  ('client-files', 'client-files', false, 52428800, null);

create policy "site admin manages site media" on storage.objects
  for all to authenticated
  using (bucket_id = 'site-media' and (select private.is_site_admin()))
  with check (bucket_id = 'site-media' and (select private.is_site_admin()));
create policy "site admin manages client files" on storage.objects
  for all to authenticated
  using (bucket_id = 'client-files' and (select private.is_site_admin()))
  with check (bucket_id = 'client-files' and (select private.is_site_admin()));
