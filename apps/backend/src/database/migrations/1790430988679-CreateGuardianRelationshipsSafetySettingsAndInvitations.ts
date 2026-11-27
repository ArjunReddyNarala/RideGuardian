import { MigrationInterface, QueryRunner } from "typeorm";

export class CreateGuardianRelationshipsSafetySettingsAndInvitations1790430988679 implements MigrationInterface {
    name = 'CreateGuardianRelationshipsSafetySettingsAndInvitations1790430988679'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TABLE "guardian_rider_relationships" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "guardian_id" uuid NOT NULL, "rider_id" uuid NOT NULL, "status" character varying(20) NOT NULL DEFAULT 'PENDING', "invited_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), "accepted_at" TIMESTAMP WITH TIME ZONE, "revoked_at" TIMESTAMP WITH TIME ZONE, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_bf4cd9d9c06d8eb2386f87881a3" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "invitations" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "inviter_id" uuid NOT NULL, "invitee_email" character varying(255), "invitee_phone" character varying(20), "token" character varying(100) NOT NULL, "status" character varying(20) NOT NULL DEFAULT 'PENDING', "expires_at" TIMESTAMP WITH TIME ZONE NOT NULL, "accepted_at" TIMESTAMP WITH TIME ZONE, "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "UQ_e577dcf9bb6d084373ed3998509" UNIQUE ("token"), CONSTRAINT "PK_5dec98cfdfd562e4ad3648bbb07" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "rider_safety_settings" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "guardian_id" uuid NOT NULL, "rider_id" uuid NOT NULL, "max_speed_kmh" numeric(5,2), "speed_alert_enabled" boolean NOT NULL DEFAULT true, "speed_alert_cooldown_seconds" integer NOT NULL DEFAULT '60', "created_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), "updated_at" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(), CONSTRAINT "PK_048c28ba6a00062166666d4d94b" PRIMARY KEY ("id"))`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`DROP TABLE "rider_safety_settings"`);
        await queryRunner.query(`DROP TABLE "invitations"`);
        await queryRunner.query(`DROP TABLE "guardian_rider_relationships"`);
    }

}
