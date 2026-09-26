import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddForeignKeyConstraints1790433312443
  implements MigrationInterface
{
  name = 'AddForeignKeyConstraints1790433312443';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // guardian_rider_relationships
    await queryRunner.query(`
      ALTER TABLE "guardian_rider_relationships"
      ADD CONSTRAINT "FK_relationship_guardian"
      FOREIGN KEY ("guardian_id")
      REFERENCES "users"("id")
      ON DELETE CASCADE
    `);

    await queryRunner.query(`
      ALTER TABLE "guardian_rider_relationships"
      ADD CONSTRAINT "FK_relationship_rider"
      FOREIGN KEY ("rider_id")
      REFERENCES "users"("id")
      ON DELETE CASCADE
    `);

    // rider_safety_settings
    await queryRunner.query(`
      ALTER TABLE "rider_safety_settings"
      ADD CONSTRAINT "FK_safety_guardian"
      FOREIGN KEY ("guardian_id")
      REFERENCES "users"("id")
      ON DELETE CASCADE
    `);

    await queryRunner.query(`
      ALTER TABLE "rider_safety_settings"
      ADD CONSTRAINT "FK_safety_rider"
      FOREIGN KEY ("rider_id")
      REFERENCES "users"("id")
      ON DELETE CASCADE
    `);

    // invitations
    await queryRunner.query(`
      ALTER TABLE "invitations"
      ADD CONSTRAINT "FK_invitation_inviter"
      FOREIGN KEY ("inviter_id")
      REFERENCES "users"("id")
      ON DELETE CASCADE
    `);

    // rides
    await queryRunner.query(`
      ALTER TABLE "rides"
      ADD CONSTRAINT "FK_ride_rider"
      FOREIGN KEY ("rider_id")
      REFERENCES "users"("id")
    `);

    // ride_guardians
    await queryRunner.query(`
      ALTER TABLE "ride_guardians"
      ADD CONSTRAINT "FK_ride_guardian_ride"
      FOREIGN KEY ("ride_id")
      REFERENCES "rides"("id")
      ON DELETE CASCADE
    `);

    await queryRunner.query(`
      ALTER TABLE "ride_guardians"
      ADD CONSTRAINT "FK_ride_guardian_user"
      FOREIGN KEY ("guardian_id")
      REFERENCES "users"("id")
    `);

    // ride_locations
    await queryRunner.query(`
      ALTER TABLE "ride_locations"
      ADD CONSTRAINT "FK_location_ride"
      FOREIGN KEY ("ride_id")
      REFERENCES "rides"("id")
      ON DELETE CASCADE
    `);

    // ride_events
    await queryRunner.query(`
      ALTER TABLE "ride_events"
      ADD CONSTRAINT "FK_event_ride"
      FOREIGN KEY ("ride_id")
      REFERENCES "rides"("id")
      ON DELETE CASCADE
    `);

    // safety_alerts
    await queryRunner.query(`
      ALTER TABLE "safety_alerts"
      ADD CONSTRAINT "FK_alert_ride"
      FOREIGN KEY ("ride_id")
      REFERENCES "rides"("id")
      ON DELETE CASCADE
    `);

    await queryRunner.query(`
      ALTER TABLE "safety_alerts"
      ADD CONSTRAINT "FK_alert_rider"
      FOREIGN KEY ("rider_id")
      REFERENCES "users"("id")
    `);

    await queryRunner.query(`
      ALTER TABLE "safety_alerts"
      ADD CONSTRAINT "FK_alert_guardian"
      FOREIGN KEY ("guardian_id")
      REFERENCES "users"("id")
    `);

    // notifications
    await queryRunner.query(`
      ALTER TABLE "notifications"
      ADD CONSTRAINT "FK_notification_user"
      FOREIGN KEY ("user_id")
      REFERENCES "users"("id")
      ON DELETE CASCADE
    `);

    await queryRunner.query(`
      ALTER TABLE "notifications"
      ADD CONSTRAINT "FK_notification_alert"
      FOREIGN KEY ("safety_alert_id")
      REFERENCES "safety_alerts"("id")
      ON DELETE CASCADE
    `);

    // devices
    await queryRunner.query(`
      ALTER TABLE "devices"
      ADD CONSTRAINT "FK_device_user"
      FOREIGN KEY ("user_id")
      REFERENCES "users"("id")
      ON DELETE CASCADE
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "devices"
      DROP CONSTRAINT "FK_device_user"
    `);

    await queryRunner.query(`
      ALTER TABLE "notifications"
      DROP CONSTRAINT "FK_notification_alert"
    `);

    await queryRunner.query(`
      ALTER TABLE "notifications"
      DROP CONSTRAINT "FK_notification_user"
    `);

    await queryRunner.query(`
      ALTER TABLE "safety_alerts"
      DROP CONSTRAINT "FK_alert_guardian"
    `);

    await queryRunner.query(`
      ALTER TABLE "safety_alerts"
      DROP CONSTRAINT "FK_alert_rider"
    `);

    await queryRunner.query(`
      ALTER TABLE "safety_alerts"
      DROP CONSTRAINT "FK_alert_ride"
    `);

    await queryRunner.query(`
      ALTER TABLE "ride_events"
      DROP CONSTRAINT "FK_event_ride"
    `);

    await queryRunner.query(`
      ALTER TABLE "ride_locations"
      DROP CONSTRAINT "FK_location_ride"
    `);

    await queryRunner.query(`
      ALTER TABLE "ride_guardians"
      DROP CONSTRAINT "FK_ride_guardian_user"
    `);

    await queryRunner.query(`
      ALTER TABLE "ride_guardians"
      DROP CONSTRAINT "FK_ride_guardian_ride"
    `);

    await queryRunner.query(`
      ALTER TABLE "rides"
      DROP CONSTRAINT "FK_ride_rider"
    `);

    await queryRunner.query(`
      ALTER TABLE "invitations"
      DROP CONSTRAINT "FK_invitation_inviter"
    `);

    await queryRunner.query(`
      ALTER TABLE "rider_safety_settings"
      DROP CONSTRAINT "FK_safety_rider"
    `);

    await queryRunner.query(`
      ALTER TABLE "rider_safety_settings"
      DROP CONSTRAINT "FK_safety_guardian"
    `);

    await queryRunner.query(`
      ALTER TABLE "guardian_rider_relationships"
      DROP CONSTRAINT "FK_relationship_rider"
    `);

    await queryRunner.query(`
      ALTER TABLE "guardian_rider_relationships"
      DROP CONSTRAINT "FK_relationship_guardian"
    `);
  }
}