-- This project doesn't grant table access by default; RLS policies still decide which rows.
grant select on public.site_projects, public.site_settings to anon;
grant select, insert, update, delete on public.site_projects to authenticated;
grant select, update on public.site_settings to authenticated;
grant select on public.site_admins to authenticated;
grant select, insert, update, delete on public.site_deliveries, public.site_delivery_files, public.site_delivery_reviews to authenticated;
