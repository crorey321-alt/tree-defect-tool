-- ===================================================================
-- 교목 하자조사 도구 v20 — Supabase 초기 설치 스크립트
--
-- 사용법: Supabase 대시보드 → 왼쪽 메뉴 [SQL Editor] → New query →
--         이 파일 전체를 붙여넣고 [Run] 한 번만 누르면 됩니다.
--
-- 핵심: RLS(Row Level Security)로 "내 user_id 행만" 읽고 쓰게 막습니다.
--       다른 사람이 로그인해도 남의 현장은 조회 자체가 되지 않습니다.
-- ===================================================================

-- 1) 조사 자료 테이블 --------------------------------------------------
create table if not exists public.sites (
  id          text primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null default '',
  survey_date text not null default '',
  pages       integer not null default 0,
  qt          jsonb not null default '[]'::jsonb,   -- 수량표
  recs        jsonb not null default '[]'::jsonb,   -- 하자 기록(마커·인출선·항목·사진목록)
  deleted     boolean not null default false,
  updated_at  timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

create index if not exists sites_user_idx on public.sites (user_id, updated_at desc);

alter table public.sites enable row level security;

-- 기존 정책이 있으면 지우고 다시 만든다 (스크립트를 두 번 돌려도 안전)
drop policy if exists "sites_select_own" on public.sites;
drop policy if exists "sites_insert_own" on public.sites;
drop policy if exists "sites_update_own" on public.sites;
drop policy if exists "sites_delete_own" on public.sites;

create policy "sites_select_own" on public.sites
  for select using (auth.uid() = user_id);
create policy "sites_insert_own" on public.sites
  for insert with check (auth.uid() = user_id);
create policy "sites_update_own" on public.sites
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "sites_delete_own" on public.sites
  for delete using (auth.uid() = user_id);


-- 2) 도면·사진 저장소 --------------------------------------------------
-- 비공개(private) 버킷. 파일 경로는 항상  <내 user_id>/<현장id>/draw|photo/<파일명>
insert into storage.buckets (id, name, public)
values ('tds', 'tds', false)
on conflict (id) do nothing;

drop policy if exists "tds_read_own"   on storage.objects;
drop policy if exists "tds_insert_own" on storage.objects;
drop policy if exists "tds_update_own" on storage.objects;
drop policy if exists "tds_delete_own" on storage.objects;

-- 경로의 첫 번째 폴더명이 자기 user_id 인 파일만 다룰 수 있게 한다
create policy "tds_read_own" on storage.objects
  for select using (
    bucket_id = 'tds' and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "tds_insert_own" on storage.objects
  for insert with check (
    bucket_id = 'tds' and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "tds_update_own" on storage.objects
  for update using (
    bucket_id = 'tds' and (storage.foldername(name))[1] = auth.uid()::text
  ) with check (
    bucket_id = 'tds' and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy "tds_delete_own" on storage.objects
  for delete using (
    bucket_id = 'tds' and (storage.foldername(name))[1] = auth.uid()::text
  );


-- 3) 확인 -------------------------------------------------------------
-- 아래 두 줄을 따로 실행하면 정책이 제대로 걸렸는지 볼 수 있습니다.
--   select tablename, policyname from pg_policies where tablename = 'sites';
--   select id, public from storage.buckets where id = 'tds';
