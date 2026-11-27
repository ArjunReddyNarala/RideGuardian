import { MigrationInterface, QueryRunner } from "typeorm";

export class CreateRideTables1790431772198 implements MigrationInterface {
    name = 'CreateRideTables1790431772198'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TABLE "ride_events" ("id" BIGSERIAL NOT NULL, "ride_id" uuid NOT NULL, "event_type" character varying(50) NOT NULL, "latitude" double precision, "longitude" double precision, "metadata" jsonb, "occurred_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_a408fbed7f187bf7e160bf19155" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "ride_guardians" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "ride_id" uuid NOT NULL, "guardian_id" uuid NOT NULL, "added_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), "removed_at" TIMESTAMP WITH TIME ZONE, CONSTRAINT "PK_1981528952b404cd355f24d9318" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "ride_locations" ("id" BIGSERIAL NOT NULL, "ride_id" uuid NOT NULL, "latitude" double precision NOT NULL, "longitude" double precision NOT NULL, "speed_kmh" double precision, "heading" double precision, "accuracy" double precision, "altitude" double precision, "recorded_at" TIMESTAMP WITH TIME ZONE NOT NULL, CONSTRAINT "PK_6b68748f1a28173c3d23cc45542" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "rides" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "ride_code" character varying(20) NOT NULL, "rider_id" uuid NOT NULL, "status" character varying(20) NOT NULL DEFAULT 'ACTIVE', "started_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), "ended_at" TIMESTAMP WITH TIME ZONE, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "UQ_95056db561b15de53c5ec2f801c" UNIQUE ("ride_code"), CONSTRAINT "PK_ca6f62fc1e999b139c7f28f07fd" PRIMARY KEY ("id"))`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`DROP TABLE "rides"`);
        await queryRunner.query(`DROP TABLE "ride_locations"`);
        await queryRunner.query(`DROP TABLE "ride_guardians"`);
        await queryRunner.query(`DROP TABLE "ride_events"`);
    }

}
