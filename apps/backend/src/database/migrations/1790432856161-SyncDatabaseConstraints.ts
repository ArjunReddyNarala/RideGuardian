import { MigrationInterface, QueryRunner } from "typeorm";

export class SyncDatabaseConstraints1790432856161 implements MigrationInterface {
    name = 'SyncDatabaseConstraints1790432856161'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE UNIQUE INDEX "IDX_4f74c7ad23919317e003ed5edd" ON "guardian_rider_relationships"  ("guardian_id", "rider_id") `);
        await queryRunner.query(`CREATE UNIQUE INDEX "IDX_055ee7c6fc18acd0fd4546ac5f" ON "ride_guardians"  ("ride_id", "guardian_id") `);
        await queryRunner.query(`CREATE UNIQUE INDEX "IDX_30f0d46e62723bd45ed3df4374" ON "rider_safety_settings"  ("guardian_id", "rider_id") `);
        await queryRunner.query(`ALTER TABLE "devices" ADD CONSTRAINT "CHK_66ebdd939cf0394a20a804d249" CHECK ("platform" IN ('IOS', 'ANDROID'))`);
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" ADD CONSTRAINT "CHK_509841b918c1123322b771de58" CHECK ("status" IN ('PENDING', 'ACCEPTED', 'DECLINED', 'REVOKED'))`);
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" ADD CONSTRAINT "CHK_5dae18a43133eec8e856e91e57" CHECK ("guardian_id" <> "rider_id")`);
        await queryRunner.query(`ALTER TABLE "invitations" ADD CONSTRAINT "CHK_7b21c69eb284b2b70e50d34739" CHECK ("status" IN ('PENDING', 'ACCEPTED', 'DECLINED', 'EXPIRED', 'CANCELLED'))`);
        await queryRunner.query(`ALTER TABLE "invitations" ADD CONSTRAINT "CHK_524e34fda87008891bd9a953c6" CHECK ("invitee_email" IS NOT NULL OR "invitee_phone" IS NOT NULL)`);
        await queryRunner.query(`ALTER TABLE "rides" ADD CONSTRAINT "CHK_b388544df2d8e7882858a917a0" CHECK ("status" IN ('ACTIVE', 'COMPLETED', 'CANCELLED'))`);
        await queryRunner.query(`ALTER TABLE "safety_alerts" ADD CONSTRAINT "CHK_aa062058d27adbdd1d4881890c" CHECK ("status" IN ('ACTIVE', 'ACKNOWLEDGED', 'RESOLVED'))`);
        await queryRunner.query(`ALTER TABLE "safety_alerts" ADD CONSTRAINT "CHK_d725293871f7266bf4b5085015" CHECK ("severity" IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL'))`);
        await queryRunner.query(`ALTER TABLE "safety_alerts" ADD CONSTRAINT "CHK_c2a00964ee64c6d8b655a3e4eb" CHECK ("type" IN ('SPEED_LIMIT_EXCEEDED', 'SOS', 'CRASH_DETECTED', 'ROUTE_DEVIATION', 'PROLONGED_STOP'))`);
        await queryRunner.query(`ALTER TABLE "rider_safety_settings" ADD CONSTRAINT "CHK_bec1cda447ee28d5734fb5e212" CHECK ("speed_alert_cooldown_seconds" >= 0)`);
        await queryRunner.query(`ALTER TABLE "rider_safety_settings" ADD CONSTRAINT "CHK_bf9e0d76615db89e99a4cae3c5" CHECK ("max_speed_kmh" IS NULL OR "max_speed_kmh" > 0)`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "rider_safety_settings" DROP CONSTRAINT "CHK_bf9e0d76615db89e99a4cae3c5"`);
        await queryRunner.query(`ALTER TABLE "rider_safety_settings" DROP CONSTRAINT "CHK_bec1cda447ee28d5734fb5e212"`);
        await queryRunner.query(`ALTER TABLE "safety_alerts" DROP CONSTRAINT "CHK_c2a00964ee64c6d8b655a3e4eb"`);
        await queryRunner.query(`ALTER TABLE "safety_alerts" DROP CONSTRAINT "CHK_d725293871f7266bf4b5085015"`);
        await queryRunner.query(`ALTER TABLE "safety_alerts" DROP CONSTRAINT "CHK_aa062058d27adbdd1d4881890c"`);
        await queryRunner.query(`ALTER TABLE "rides" DROP CONSTRAINT "CHK_b388544df2d8e7882858a917a0"`);
        await queryRunner.query(`ALTER TABLE "invitations" DROP CONSTRAINT "CHK_524e34fda87008891bd9a953c6"`);
        await queryRunner.query(`ALTER TABLE "invitations" DROP CONSTRAINT "CHK_7b21c69eb284b2b70e50d34739"`);
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" DROP CONSTRAINT "CHK_5dae18a43133eec8e856e91e57"`);
        await queryRunner.query(`ALTER TABLE "guardian_rider_relationships" DROP CONSTRAINT "CHK_509841b918c1123322b771de58"`);
        await queryRunner.query(`ALTER TABLE "devices" DROP CONSTRAINT "CHK_66ebdd939cf0394a20a804d249"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_30f0d46e62723bd45ed3df4374"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_055ee7c6fc18acd0fd4546ac5f"`);
        await queryRunner.query(`DROP INDEX "public"."IDX_4f74c7ad23919317e003ed5edd"`);
    }

}
