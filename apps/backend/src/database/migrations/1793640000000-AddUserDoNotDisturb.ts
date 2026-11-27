import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddUserDoNotDisturb1793640000000 implements MigrationInterface {
  name = 'AddUserDoNotDisturb1793640000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      'ALTER TABLE "users" ADD "do_not_disturb" boolean NOT NULL DEFAULT false',
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query('ALTER TABLE "users" DROP COLUMN "do_not_disturb"');
  }
}
