-- Apply once to an existing Ride Guardian Supabase/PostgreSQL database.
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS do_not_disturb boolean NOT NULL DEFAULT false;
