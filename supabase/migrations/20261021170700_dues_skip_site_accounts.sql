-- Accounts created for the Trutech website admin (app_metadata.trutech_site)
-- are not dues members: don't give them a profile or a roster entry.
-- app_metadata can't be set by people signing up, only by the server.
create or replace function private.handle_new_user()
 returns trigger
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
  v_name text := left(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), 120);
  v_code text := upper(trim(coalesce(new.raw_user_meta_data ->> 'member_code', '')));
  v_phone text := private.normalize_phone(new.raw_user_meta_data ->> 'phone');
  v_terms text := new.raw_user_meta_data ->> 'terms_version';
  v_linked uuid;
begin
  if coalesce(new.raw_app_meta_data ->> 'trutech_site', '') = 'true' then
    return new;
  end if;

  v_name := coalesce(case when length(v_name) >= 2 then v_name end, 'New member');
  insert into public.profiles (id, full_name, email, terms_version, terms_accepted_at)
  values (new.id, v_name, new.email,
          case when v_terms ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then v_terms end,
          case when v_terms ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then now() end);

  if v_code <> '' then
    update public.members
       set profile_id = new.id, updated_at = now()
     where member_code = v_code and profile_id is null and is_active
    returning id into v_linked;
  end if;

  if v_linked is null then
    for attempt in 1..10 loop
      begin
        insert into public.members (member_code, full_name, phone, profile_id, is_active, self_registered)
        values (private.random_code(), v_name, v_phone, new.id, false, true);
        exit;
      exception when unique_violation then
        if attempt = 10 then raise; end if;
      end;
    end loop;
  end if;
  return new;
end;
$function$;
