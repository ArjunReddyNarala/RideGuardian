-- Ride Guardian: fresh Supabase PostgreSQL database setup
--
-- Run once against an EMPTY production project using Supabase SQL Editor.
-- This is the complete schema bootstrap for the NestJS/TypeORM backend.
-- TypeORM synchronize is disabled; do not run the historical migrations on
-- top of this script. Keep future schema changes in new migrations.
--
-- The backend authenticates requests with Firebase and connects to PostgreSQL
-- server-side. RLS is enabled with no client policies so Supabase anon and
-- authenticated API roles cannot query these tables directly. Do not ship a
-- Supabase service key or database password in the mobile app.

BEGIN;

SET LOCAL search_path = public;

-- gen_random_uuid() is built into supported Supabase PostgreSQL versions.

CREATE TABLE public.users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    firebase_uid varchar(128) NOT NULL,
    name varchar(100) NOT NULL,
    email varchar(255),
    phone varchar(20),
    profile_image_url text,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_users_firebase_uid UNIQUE (firebase_uid),
    CONSTRAINT uq_users_email UNIQUE (email),
    CONSTRAINT uq_users_phone UNIQUE (phone)
);

CREATE TABLE public.guardian_rider_relationships (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    guardian_id uuid NOT NULL,
    rider_id uuid NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'PENDING',
    invited_at timestamptz NOT NULL DEFAULT now(),
    accepted_at timestamptz,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_relationship_guardian
        FOREIGN KEY (guardian_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT fk_relationship_rider
        FOREIGN KEY (rider_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT uq_guardian_rider UNIQUE (guardian_id, rider_id),
    CONSTRAINT chk_guardian_not_rider CHECK (guardian_id <> rider_id),
    CONSTRAINT chk_relationship_status
        CHECK (status IN ('PENDING', 'ACCEPTED', 'DECLINED', 'REVOKED'))
);

CREATE TABLE public.invitations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    inviter_id uuid NOT NULL,
    invitee_email varchar(255),
    invitee_phone varchar(20),
    relationship_type varchar(30) NOT NULL DEFAULT 'I_MONITOR_THEM',
    token varchar(100) NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'PENDING',
    expires_at timestamptz NOT NULL,
    accepted_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_invitation_inviter
        FOREIGN KEY (inviter_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT uq_invitations_token UNIQUE (token),
    CONSTRAINT chk_invitation_recipient
        CHECK (invitee_email IS NOT NULL OR invitee_phone IS NOT NULL),
    CONSTRAINT chk_invitation_relationship_type
        CHECK (relationship_type IN ('I_MONITOR_THEM', 'THEY_MONITOR_ME')),
    CONSTRAINT chk_invitation_status
        CHECK (status IN ('PENDING', 'ACCEPTED', 'DECLINED', 'EXPIRED', 'CANCELLED'))
);

CREATE TABLE public.rider_safety_settings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    guardian_id uuid NOT NULL,
    rider_id uuid NOT NULL,
    max_speed_kmh numeric(5,2),
    speed_alert_enabled boolean NOT NULL DEFAULT true,
    speed_alert_cooldown_seconds integer NOT NULL DEFAULT 60,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_safety_guardian
        FOREIGN KEY (guardian_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT fk_safety_rider
        FOREIGN KEY (rider_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT uq_safety_guardian_rider UNIQUE (guardian_id, rider_id),
    CONSTRAINT chk_safety_max_speed CHECK (max_speed_kmh IS NULL OR max_speed_kmh > 0),
    CONSTRAINT chk_safety_alert_cooldown CHECK (speed_alert_cooldown_seconds >= 0)
);

CREATE TABLE public.rides (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_code varchar(20) NOT NULL,
    rider_id uuid NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'ACTIVE',
    started_at timestamptz NOT NULL DEFAULT now(),
    ended_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uq_rides_ride_code UNIQUE (ride_code),
    CONSTRAINT fk_ride_rider
        FOREIGN KEY (rider_id) REFERENCES public.users(id),
    CONSTRAINT chk_ride_status CHECK (status IN ('ACTIVE', 'COMPLETED', 'CANCELLED')),
    CONSTRAINT chk_ride_end_after_start CHECK (ended_at IS NULL OR ended_at >= started_at)
);

CREATE TABLE public.ride_guardians (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id uuid NOT NULL,
    guardian_id uuid NOT NULL,
    added_at timestamptz NOT NULL DEFAULT now(),
    removed_at timestamptz,
    CONSTRAINT fk_ride_guardian_ride
        FOREIGN KEY (ride_id) REFERENCES public.rides(id) ON DELETE CASCADE,
    CONSTRAINT fk_ride_guardian_user
        FOREIGN KEY (guardian_id) REFERENCES public.users(id),
    CONSTRAINT uq_ride_guardian UNIQUE (ride_id, guardian_id)
);

CREATE TABLE public.ride_locations (
    id bigserial PRIMARY KEY,
    ride_id uuid NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    speed_kmh double precision,
    heading double precision,
    accuracy double precision,
    altitude double precision,
    recorded_at timestamptz NOT NULL,
    CONSTRAINT fk_location_ride
        FOREIGN KEY (ride_id) REFERENCES public.rides(id) ON DELETE CASCADE,
    CONSTRAINT chk_location_latitude CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_location_longitude CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT chk_location_speed CHECK (speed_kmh IS NULL OR speed_kmh >= 0),
    CONSTRAINT chk_location_heading CHECK (heading IS NULL OR heading BETWEEN 0 AND 360),
    CONSTRAINT chk_location_accuracy CHECK (accuracy IS NULL OR accuracy >= 0)
);

CREATE TABLE public.ride_events (
    id bigserial PRIMARY KEY,
    ride_id uuid NOT NULL,
    event_type varchar(50) NOT NULL,
    latitude double precision,
    longitude double precision,
    metadata jsonb,
    occurred_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_event_ride
        FOREIGN KEY (ride_id) REFERENCES public.rides(id) ON DELETE CASCADE,
    CONSTRAINT chk_event_latitude CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_event_longitude CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);

CREATE TABLE public.safety_alerts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    ride_id uuid NOT NULL,
    rider_id uuid NOT NULL,
    guardian_id uuid,
    type varchar(30) NOT NULL,
    severity varchar(20) NOT NULL DEFAULT 'HIGH',
    current_speed_kmh double precision,
    configured_speed_limit_kmh double precision,
    latitude double precision,
    longitude double precision,
    triggered_at timestamptz NOT NULL DEFAULT now(),
    status varchar(20) NOT NULL DEFAULT 'ACTIVE',
    acknowledged_at timestamptz,
    resolved_at timestamptz,
    CONSTRAINT fk_alert_ride
        FOREIGN KEY (ride_id) REFERENCES public.rides(id) ON DELETE CASCADE,
    CONSTRAINT fk_alert_rider
        FOREIGN KEY (rider_id) REFERENCES public.users(id),
    CONSTRAINT fk_alert_guardian
        FOREIGN KEY (guardian_id) REFERENCES public.users(id),
    CONSTRAINT chk_alert_type CHECK (
        type IN ('SPEED_LIMIT_EXCEEDED', 'SOS', 'CRASH_DETECTED', 'ROUTE_DEVIATION', 'PROLONGED_STOP')
    ),
    CONSTRAINT chk_alert_severity CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    CONSTRAINT chk_alert_status CHECK (status IN ('ACTIVE', 'ACKNOWLEDGED', 'RESOLVED')),
    CONSTRAINT chk_alert_latitude CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
    CONSTRAINT chk_alert_longitude CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);

CREATE TABLE public.notifications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    safety_alert_id uuid,
    type varchar(40) NOT NULL,
    title varchar(200) NOT NULL,
    body text NOT NULL,
    is_read boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    read_at timestamptz,
    CONSTRAINT fk_notification_user
        FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT fk_notification_alert
        FOREIGN KEY (safety_alert_id) REFERENCES public.safety_alerts(id) ON DELETE CASCADE
);

CREATE TABLE public.devices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    device_identifier varchar(255),
    platform varchar(20) NOT NULL,
    push_token text,
    app_version varchar(30),
    is_active boolean NOT NULL DEFAULT true,
    last_seen_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_device_user
        FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT chk_device_platform CHECK (platform IN ('IOS', 'ANDROID'))
);

CREATE TABLE public.user_settings (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    notifications_enabled boolean NOT NULL DEFAULT true,
    push_notifications_enabled boolean NOT NULL DEFAULT true,
    ride_updates_enabled boolean NOT NULL DEFAULT true,
    speed_alerts_enabled boolean NOT NULL DEFAULT true,
    sound_enabled boolean NOT NULL DEFAULT true,
    language varchar(10) NOT NULL DEFAULT 'en',
    distance_unit varchar(5) NOT NULL DEFAULT 'KM',
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT fk_user_settings_user
        FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT uq_user_settings_user UNIQUE (user_id),
    CONSTRAINT chk_user_settings_distance_unit CHECK (distance_unit IN ('KM', 'MI'))
);

-- Record the schema bootstrap as the current migration baseline. This lets
-- future TypeORM migrations run without replaying the historical CREATE TABLE
-- migrations against tables that this script has already created.
CREATE TABLE public.migrations (
    id serial PRIMARY KEY,
    timestamp bigint NOT NULL,
    name varchar NOT NULL
);

INSERT INTO public.migrations (timestamp, name) VALUES
    (1790271470278, 'CreateUsersTable1790271470278'),
    (1790430988679, 'CreateGuardianRelationshipsSafetySettingsAndInvitations1790430988679'),
    (1790431772198, 'CreateRideTables1790431772198'),
    (1790431889087, 'AddRideGuardianDatabaseConstraints1790431889087'),
    (1790432419479, 'CreateSafetyAlertsNotificationsAndDevices1790432419479'),
    (1790432856161, 'SyncDatabaseConstraints1790432856161'),
    (1790433312443, 'AddForeignKeyConstraints1790433312443'),
    (1792692463430, 'CreateUserSettings1792692463430'),
    (1793520000000, 'AddRidePaginationIndexes1793520000000');

-- Core relationship, invitation, ride history, monitoring, and timeline indexes.
CREATE INDEX idx_relationships_guardian_status
    ON public.guardian_rider_relationships (guardian_id, status);
CREATE INDEX idx_relationships_rider_status
    ON public.guardian_rider_relationships (rider_id, status);

CREATE INDEX idx_invitations_inviter_created
    ON public.invitations (inviter_id, created_at DESC);
CREATE INDEX idx_invitations_invitee_email_lower
    ON public.invitations (lower(invitee_email))
    WHERE invitee_email IS NOT NULL;
CREATE INDEX idx_invitations_invitee_phone
    ON public.invitations (invitee_phone)
    WHERE invitee_phone IS NOT NULL;
CREATE INDEX idx_invitations_status_expires
    ON public.invitations (status, expires_at);

CREATE INDEX idx_safety_settings_rider
    ON public.rider_safety_settings (rider_id);

CREATE INDEX idx_rides_rider_started_at
    ON public.rides (rider_id, started_at DESC, id DESC);
-- Enforce the product rule that one rider cannot have concurrent active rides.
CREATE UNIQUE INDEX IF NOT EXISTS uq_rides_one_active_per_rider
    ON public.rides (rider_id)
    WHERE status = 'ACTIVE';

CREATE INDEX idx_ride_guardians_guardian_ride
    ON public.ride_guardians (guardian_id, ride_id);
CREATE INDEX idx_ride_guardians_active_guardian_added
    ON public.ride_guardians (guardian_id, added_at DESC)
    WHERE removed_at IS NULL;

CREATE INDEX idx_ride_locations_ride_recorded
    ON public.ride_locations (ride_id, recorded_at DESC, id DESC);
CREATE INDEX idx_ride_events_ride_occurred
    ON public.ride_events (ride_id, occurred_at DESC, id DESC);

CREATE INDEX idx_safety_alerts_rider_triggered
    ON public.safety_alerts (rider_id, triggered_at DESC);
CREATE INDEX idx_safety_alerts_ride_triggered
    ON public.safety_alerts (ride_id, triggered_at DESC);
CREATE INDEX idx_safety_alerts_guardian_triggered
    ON public.safety_alerts (guardian_id, triggered_at DESC)
    WHERE guardian_id IS NOT NULL;
CREATE INDEX idx_safety_alerts_active_rider
    ON public.safety_alerts (rider_id, triggered_at DESC)
    WHERE status = 'ACTIVE';
CREATE INDEX idx_safety_alerts_active_guardian
    ON public.safety_alerts (guardian_id, triggered_at DESC)
    WHERE status = 'ACTIVE' AND guardian_id IS NOT NULL;

CREATE INDEX idx_notifications_user_created
    ON public.notifications (user_id, created_at DESC);
CREATE INDEX idx_notifications_alert
    ON public.notifications (safety_alert_id)
    WHERE safety_alert_id IS NOT NULL;
CREATE INDEX idx_notifications_unread_user
    ON public.notifications (user_id)
    WHERE is_read = false;
CREATE INDEX idx_devices_user_created
    ON public.devices (user_id, created_at DESC);

-- Protect application tables from direct Supabase Data API access. The NestJS
-- backend connects server-side and performs Firebase authorization itself.
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guardian_rider_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rider_safety_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_guardians ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ride_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.safety_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.migrations ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE
    public.users,
    public.guardian_rider_relationships,
    public.invitations,
    public.rider_safety_settings,
    public.rides,
    public.ride_guardians,
    public.ride_locations,
    public.ride_events,
    public.safety_alerts,
    public.notifications,
    public.devices,
    public.user_settings,
    public.migrations
FROM anon, authenticated;

REVOKE ALL PRIVILEGES ON SEQUENCE
    public.ride_locations_id_seq,
    public.ride_events_id_seq
FROM anon, authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE ALL ON TABLES FROM anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE ALL ON SEQUENCES FROM anon, authenticated;

COMMIT;

-- Quick verification after running:
-- SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;
-- SELECT tablename, rowsecurity FROM pg_tables
-- WHERE schemaname = 'public' ORDER BY tablename;
