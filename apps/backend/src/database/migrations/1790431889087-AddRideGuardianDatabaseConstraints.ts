import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddRideGuardianDatabaseConstraints1790431889087 implements MigrationInterface {
  name = 'AddRideGuardianDatabaseConstraints1790431889087';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // guardian_rider_relationships
    await queryRunner.query(`
      ALTER TABLE "guardian_rider_relationships"
      ADD CONSTRAINT "FK_relationship_guardian"
      FOREIGN KEY ("guardian_id") REFERENCES "users"("id")
      ON DELETE CASCADE
    `);

    await queryRunner.query(`
      ALTER TABLE "guardian_rider_relationships"
      ADD CONSTRAINT "FK_relationship_rider"
      FOREIGN KEY ("rider_id") REFERENCES "users"("id")
      ON DELETE CASCADE
    `);

    await queryRunner.query(`
      ALTER TABLE "guardian_rider_relationships"
      ADD CONSTRAINT "UQ_guardian_rider"
      UNIQUE ("guardian_id", "rider_id")
    `);

    await queryRunner.query(`
      ALTER TABLE "guardian_rider_relationships"
      ADD CONSTRAINT "CHK_guardian_not_rider"
      CHECK ("guardian_id" <> "rider_id")
    `);

    await queryRunner.query(`
      ALTER TABLE "guardian_rider_relationships"
      ADD CONSTRAINT "CHK_relationship_status"
      CHECK ("status" IN ('PENDING', 'ACCEPTED', 'DECLINED', 'REVOKED'))
    `);

    // rider_safety_settings
    await queryRunner.query(`
      ALTER TABLE "rider_safety_settings"
      ADD CONSTRAINT "FK_safety_guardian"
      FOREIGN KEY ("guardian_id") REFERENCES "users"("id")
      ON DELETE CASCADE
    `);

    await queryRunner.query(`
      ALTER TABLE "rider_safety_settings"
      ADD CONSTRAINT "FK_safety_rider"
      FOREIGN KEY ("rider_id") REFERENCES "users"("id")
      ON DELETE CASCADE
    `);

    await queryRunner.query(`
      ALTER TABLE "rider_safety_settings"
      ADD CONSTRAINT "UQ_safety_guardian_rider"
      UNIQUE ("guardian_id", "rider_id")
    `);

    // invitations
    await queryRunner.query(`
      ALTER TABLE "invitations"
      ADD CONSTRAINT "FK_invitation_inviter"
      FOREIGN KEY ("inviter_id") REFERENCES "users"("id")
      ON DELETE CASCADE
    `);

    await queryRunner.query(`
      ALTER TABLE "invitations"
      ADD CONSTRAINT "CHK_invitation_recipient"
      CHECK ("invitee_email" IS NOT NULL OR "invitee_phone" IS NOT NULL)
    `);

    await queryRunner.query(`
      ALTER TABLE "invitations"
      ADD CONSTRAINT "CHK_invitation_status"
      CHECK ("status" IN ('PENDING', 'ACCEPTED', 'DECLINED', 'EXPIRED', 'CANCELLED'))
    `);

    // rides
    await queryRunner.query(`
      ALTER TABLE "rides"
      ADD CONSTRAINT "FK_ride_rider"
      FOREIGN KEY ("rider_id") REFERENCES "users"("id")
    `);

    await queryRunner.query(`
      ALTER TABLE "rides"
      ADD CONSTRAINT "CHK_ride_status"
      CHECK ("status" IN ('ACTIVE', 'COMPLETED', 'CANCELLED'))
    `);

    // ride_guardians
    await queryRunner.query(`
      ALTER TABLE "ride_guardians"
      ADD CONSTRAINT "FK_ride_guardian_ride"
      FOREIGN KEY ("ride_id") REFERENCES "rides"("id")
      ON DELETE CASCADE
    `);

    await queryRunner.query(`
      ALTER TABLE "ride_guardians"
      ADD CONSTRAINT "FK_ride_guardian_user"
      FOREIGN KEY ("guardian_id") REFERENCES "users"("id")
    `);

    await queryRunner.query(`
      ALTER TABLE "ride_guardians"
      ADD CONSTRAINT "UQ_ride_guardian"
      UNIQUE ("ride_id", "guardian_id")
    `);

    // ride_locations
    await queryRunner.query(`
      ALTER TABLE "ride_locations"
      ADD CONSTRAINT "FK_location_ride"
      FOREIGN KEY ("ride_id") REFERENCES "rides"("id")
      ON DELETE CASCADE
    `);

    // ride_events
    await queryRunner.query(`
      ALTER TABLE "ride_events"
      ADD CONSTRAINT "FK_event_ride"
      FOREIGN KEY ("ride_id") REFERENCES "rides"("id")
      ON DELETE CASCADE
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
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
      DROP CONSTRAINT "UQ_ride_guardian"
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
      DROP CONSTRAINT "CHK_ride_status"
    `);

    await queryRunner.query(`
      ALTER TABLE "rides"
      DROP CONSTRAINT "FK_ride_rider"
    `);

    await queryRunner.query(`
      ALTER TABLE "invitations"
      DROP CONSTRAINT "CHK_invitation_status"
    `);

    await queryRunner.query(`
      ALTER TABLE "invitations"
      DROP CONSTRAINT "CHK_invitation_recipient"
    `);

    await queryRunner.query(`
      ALTER TABLE "invitations"
      DROP CONSTRAINT "FK_invitation_inviter"
    `);

    await queryRunner.query(`
      ALTER TABLE "rider_safety_settings"
      DROP CONSTRAINT "UQ_safety_guardian_rider"
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
      DROP CONSTRAINT "CHK_relationship_status"
    `);

    await queryRunner.query(`
      ALTER TABLE "guardian_rider_relationships"
      DROP CONSTRAINT "CHK_guardian_not_rider"
    `);

    await queryRunner.query(`
      ALTER TABLE "guardian_rider_relationships"
      DROP CONSTRAINT "UQ_guardian_rider"
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