import { MigrationInterface, QueryRunner } from "typeorm";

export class CreateUserSettings1792692463430 implements MigrationInterface {
    name = 'CreateUserSettings1792692463430'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "devices" DROP CONSTRAINT "FK_device_user"`);
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" DROP CONSTRAINT "FK_relationship_guardian"`);
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" DROP CONSTRAINT "FK_relationship_rider"`);
        await queryRunner.query(`ALTER TABLE "notifications" DROP CONSTRAINT "FK_notification_user"`);
        await queryRunner.query(`ALTER TABLE "notifications" DROP CONSTRAINT "FK_notification_alert"`);
        await queryRunner.query(`ALTER TABLE "ride_events" DROP CONSTRAINT "FK_event_ride"`);
        await queryRunner.query(`ALTER TABLE "ride_guardians" DROP CONSTRAINT "FK_ride_guardian_ride"`);
        await queryRunner.query(`ALTER TABLE "ride_guardians" DROP CONSTRAINT "FK_ride_guardian_user"`);
        await queryRunner.query(`ALTER TABLE "invitations" DROP CONSTRAINT "FK_invitation_inviter"`);
        await queryRunner.query(`ALTER TABLE "ride_locations" DROP CONSTRAINT "FK_location_ride"`);
        await queryRunner.query(`ALTER TABLE "rider_safety_settings" DROP CONSTRAINT "FK_safety_rider"`);
        await queryRunner.query(`ALTER TABLE "rider_safety_settings" DROP CONSTRAINT "FK_safety_guardian"`);
        await queryRunner.query(`ALTER TABLE "rides" DROP CONSTRAINT "FK_ride_rider"`);
        await queryRunner.query(`ALTER TABLE "safety_alerts" DROP CONSTRAINT "FK_alert_ride"`);
        await queryRunner.query(`ALTER TABLE "safety_alerts" DROP CONSTRAINT "FK_alert_rider"`);
        await queryRunner.query(`ALTER TABLE "safety_alerts" DROP CONSTRAINT "FK_alert_guardian"`);
        await queryRunner.query(`CREATE TABLE "user_settings" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "user_id" uuid NOT NULL, "notifications_enabled" boolean NOT NULL DEFAULT true, "push_notifications_enabled" boolean NOT NULL DEFAULT true, "ride_updates_enabled" boolean NOT NULL DEFAULT true, "speed_alerts_enabled" boolean NOT NULL DEFAULT true, "sound_enabled" boolean NOT NULL DEFAULT true, "language" character varying(10) NOT NULL DEFAULT 'en', "distance_unit" character varying(5) NOT NULL DEFAULT 'KM', "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_00f004f5922a0744d174530d639" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE UNIQUE INDEX "IDX_4ed056b9344e6f7d8d46ec4b30" ON "user_settings"  ("user_id") `);
        await queryRunner.query(`CREATE INDEX "IDX_85db3b739df7316709f4965988" ON "ride_locations"  ("ride_id", "recorded_at") `);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`DROP INDEX "public"."IDX_85db3b739df7316709f4965988"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_4ed056b9344e6f7d8d46ec4b30"`);
        await queryRunner.query(`DROP TABLE "user_settings"`);
        await queryRunner.query(`ALTER TABLE "safety_alerts" ADD CONSTRAINT "FK_alert_guardian" FOREIGN KEY ("guardian_id") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "safety_alerts" ADD CONSTRAINT "FK_alert_rider" FOREIGN KEY ("rider_id") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "safety_alerts" ADD CONSTRAINT "FK_alert_ride" FOREIGN KEY ("ride_id") REFERENCES "rides"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "rides" ADD CONSTRAINT "FK_ride_rider" FOREIGN KEY ("rider_id") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "rider_safety_settings" ADD CONSTRAINT "FK_safety_guardian" FOREIGN KEY ("guardian_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "rider_safety_settings" ADD CONSTRAINT "FK_safety_rider" FOREIGN KEY ("rider_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "ride_locations" ADD CONSTRAINT "FK_location_ride" FOREIGN KEY ("ride_id") REFERENCES "rides"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "invitations" ADD CONSTRAINT "FK_invitation_inviter" FOREIGN KEY ("inviter_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "ride_guardians" ADD CONSTRAINT "FK_ride_guardian_user" FOREIGN KEY ("guardian_id") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "ride_guardians" ADD CONSTRAINT "FK_ride_guardian_ride" FOREIGN KEY ("ride_id") REFERENCES "rides"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "ride_events" ADD CONSTRAINT "FK_event_ride" FOREIGN KEY ("ride_id") REFERENCES "rides"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "notifications" ADD CONSTRAINT "FK_notification_alert" FOREIGN KEY ("safety_alert_id") REFERENCES "safety_alerts"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "notifications" ADD CONSTRAINT "FK_notification_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" ADD CONSTRAINT "FK_relationship_rider" FOREIGN KEY ("rider_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" ADD CONSTRAINT "FK_relationship_guardian" FOREIGN KEY ("guardian_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "devices" ADD CONSTRAINT "FK_device_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
    }

}
