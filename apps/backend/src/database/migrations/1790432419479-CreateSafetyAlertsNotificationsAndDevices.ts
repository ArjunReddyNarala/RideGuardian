import { MigrationInterface, QueryRunner } from "typeorm";

export class CreateSafetyAlertsNotificationsAndDevices1790432419479 implements MigrationInterface {
    name = 'CreateSafetyAlertsNotificationsAndDevices1790432419479'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" DROP CONSTRAINT "FK_relationship_guardian"`);
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" DROP CONSTRAINT "FK_relationship_rider"`);
        await queryRunner.query(`ALTER TABLE "invitations" DROP CONSTRAINT "FK_invitation_inviter"`);
        await queryRunner.query(`ALTER TABLE "ride_events" DROP CONSTRAINT "FK_event_ride"`);
        await queryRunner.query(`ALTER TABLE "ride_guardians" DROP CONSTRAINT "FK_ride_guardian_ride"`);
        await queryRunner.query(`ALTER TABLE "ride_guardians" DROP CONSTRAINT "FK_ride_guardian_user"`);
        await queryRunner.query(`ALTER TABLE "ride_locations" DROP CONSTRAINT "FK_location_ride"`);
        await queryRunner.query(`ALTER TABLE "rides" DROP CONSTRAINT "FK_ride_rider"`);
        await queryRunner.query(`ALTER TABLE "rider_safety_settings" DROP CONSTRAINT "FK_safety_guardian"`);
        await queryRunner.query(`ALTER TABLE "rider_safety_settings" DROP CONSTRAINT "FK_safety_rider"`);
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" DROP CONSTRAINT "CHK_guardian_not_rider"`);
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" DROP CONSTRAINT "CHK_relationship_status"`);
        await queryRunner.query(`ALTER TABLE "invitations" DROP CONSTRAINT "CHK_invitation_recipient"`);
        await queryRunner.query(`ALTER TABLE "invitations" DROP CONSTRAINT "CHK_invitation_status"`);
        await queryRunner.query(`ALTER TABLE "rides" DROP CONSTRAINT "CHK_ride_status"`);
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" DROP CONSTRAINT "UQ_guardian_rider"`);
        await queryRunner.query(`ALTER TABLE "ride_guardians" DROP CONSTRAINT "UQ_ride_guardian"`);
        await queryRunner.query(`ALTER TABLE "rider_safety_settings" DROP CONSTRAINT "UQ_safety_guardian_rider"`);
        await queryRunner.query(`CREATE TABLE "devices" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" uuid NOT NULL, "device_identifier" character varying(255), "platform" character varying(20) NOT NULL, "push_token" text, "app_version" character varying(30), "is_active" boolean NOT NULL DEFAULT true, "last_seen_at" TIMESTAMP WITH TIME ZONE, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_b1514758245c12daf43486dd1f0" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "notifications" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" uuid NOT NULL, "safety_alert_id" uuid, "type" character varying(40) NOT NULL, "title" character varying(200) NOT NULL, "body" text NOT NULL, "is_read" boolean NOT NULL DEFAULT false, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), "read_at" TIMESTAMP WITH TIME ZONE, CONSTRAINT "PK_6a72c3c0f683f6462415e653c3a" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "safety_alerts" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "ride_id" uuid NOT NULL, "rider_id" uuid NOT NULL, "guardian_id" uuid, "type" character varying(30) NOT NULL, "severity" character varying(20) NOT NULL DEFAULT 'HIGH', "current_speed_kmh" double precision, "configured_speed_limit_kmh" double precision, "latitude" double precision, "longitude" double precision, "triggered_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), "status" character varying(20) NOT NULL DEFAULT 'ACTIVE', "acknowledged_at" TIMESTAMP WITH TIME ZONE, "resolved_at" TIMESTAMP WITH TIME ZONE, CONSTRAINT "PK_ae79c1d823539ee5430525f8646" PRIMARY KEY ("id"))`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`DROP TABLE "safety_alerts"`);
        await queryRunner.query(`DROP TABLE "notifications"`);
        await queryRunner.query(`DROP TABLE "devices"`);
        await queryRunner.query(`ALTER TABLE "rider_safety_settings" ADD CONSTRAINT "UQ_safety_guardian_rider" UNIQUE ("guardian_id", "rider_id")`);
        await queryRunner.query(`ALTER TABLE "ride_guardians" ADD CONSTRAINT "UQ_ride_guardian" UNIQUE ("ride_id", "guardian_id")`);
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" ADD CONSTRAINT "UQ_guardian_rider" UNIQUE ("guardian_id", "rider_id")`);
        await queryRunner.query(`ALTER TABLE "rides" ADD CONSTRAINT "CHK_ride_status" CHECK (((status)::text = ANY ((ARRAY['ACTIVE'::character varying, 'COMPLETED'::character varying, 'CANCELLED'::character varying])::text[])))`);
        await queryRunner.query(`ALTER TABLE "invitations" ADD CONSTRAINT "CHK_invitation_status" CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'ACCEPTED'::character varying, 'DECLINED'::character varying, 'EXPIRED'::character varying, 'CANCELLED'::character varying])::text[])))`);
        await queryRunner.query(`ALTER TABLE "invitations" ADD CONSTRAINT "CHK_invitation_recipient" CHECK (((invitee_email IS NOT NULL) OR (invitee_phone IS NOT NULL)))`);
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" ADD CONSTRAINT "CHK_relationship_status" CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'ACCEPTED'::character varying, 'DECLINED'::character varying, 'REVOKED'::character varying])::text[])))`);
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" ADD CONSTRAINT "CHK_guardian_not_rider" CHECK ((guardian_id <> rider_id))`);
        await queryRunner.query(`ALTER TABLE "rider_safety_settings" ADD CONSTRAINT "FK_safety_rider" FOREIGN KEY ("rider_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "rider_safety_settings" ADD CONSTRAINT "FK_safety_guardian" FOREIGN KEY ("guardian_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "rides" ADD CONSTRAINT "FK_ride_rider" FOREIGN KEY ("rider_id") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "ride_locations" ADD CONSTRAINT "FK_location_ride" FOREIGN KEY ("ride_id") REFERENCES "rides"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "ride_guardians" ADD CONSTRAINT "FK_ride_guardian_user" FOREIGN KEY ("guardian_id") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "ride_guardians" ADD CONSTRAINT "FK_ride_guardian_ride" FOREIGN KEY ("ride_id") REFERENCES "rides"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "ride_events" ADD CONSTRAINT "FK_event_ride" FOREIGN KEY ("ride_id") REFERENCES "rides"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "invitations" ADD CONSTRAINT "FK_invitation_inviter" FOREIGN KEY ("inviter_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" ADD CONSTRAINT "FK_relationship_rider" FOREIGN KEY ("rider_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" ADD CONSTRAINT "FK_relationship_guardian" FOREIGN KEY ("guardian_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
    }

}
