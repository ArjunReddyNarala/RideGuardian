import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddRidePaginationIndexes1793520000000
  implements MigrationInterface
{
  name = 'AddRidePaginationIndexes1793520000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'CREATE INDEX "IDX_rides_rider_started_at" ON "rides" ("rider_id", "started_at" DESC, "id" DESC)',
    );
    await queryRunner.query(
      'CREATE INDEX "IDX_ride_guardians_guardian_ride" ON "ride_guardians" ("guardian_id", "ride_id")',
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'DROP INDEX "public"."IDX_ride_guardians_guardian_ride"',
    );
    await queryRunner.query(
      'DROP INDEX "public"."IDX_rides_rider_started_at"',
    );
  }
}
