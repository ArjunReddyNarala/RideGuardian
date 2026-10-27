import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { InjectRepository } from '@nestjs/typeorm';
import { randomBytes } from 'node:crypto';
import { Brackets, DataSource, Repository } from 'typeorm';

import { GuardianRelationshipsService } from '../guardian-relationships/guardian-relationships.service.js';
import { GuardianRiderRelationship } from '../guardian-relationships/entities/guardian-rider-relationship.entity.js';
import { UsersService } from '../users/users.service.js';

import { Invitation } from './entities/invitation.entity.js';
import { CreateInvitationDto } from './dto/create-invitation.dto.js';
import { InvitationRelationshipType } from './enums/invitation-relationship-type.enum.js';

export interface InvitationResponse {
  id: string;
  inviterId: string;
  inviteeEmail: string | null;
  inviteePhone: string | null;
  relationshipType: InvitationRelationshipType;
  status: string;
  expiresAt: Date;
  acceptedAt: Date | null;
  createdAt: Date;
}

@Injectable()
export class InvitationsService {
  constructor(
    @InjectRepository(Invitation)
    private readonly invitationRepository: Repository<Invitation>,

    private readonly usersService: UsersService,

    private readonly guardianRelationshipsService: GuardianRelationshipsService,

    private readonly dataSource: DataSource,
  ) {}

  async createInvitation(
    inviterId: string,
    dto: CreateInvitationDto,
  ): Promise<InvitationResponse & { token: string }> {
    const normalizedEmail = this.normalizeEmail(dto.inviteeEmail);
    const normalizedPhone = this.normalizePhone(dto.inviteePhone);
    // Exactly one contact method must be supplied.
    if (
      (!normalizedEmail && !normalizedPhone) ||
      (normalizedEmail && normalizedPhone)
    ) {
      throw new BadRequestException(
        'Provide either an invitee email or phone number, but not both',
      );
    }
    if (
      !Object.values(InvitationRelationshipType).includes(dto.relationshipType)
    ) {
      throw new BadRequestException('Invalid invitation relationship type');
    }
    const inviter = await this.usersService.getUserById(inviterId);
    if (!inviter) {
      throw new NotFoundException('Inviter not found');
    }
    let recipient: Awaited<ReturnType<UsersService['getUserByEmail']>> | null =
      null;
    if (normalizedEmail) {
      recipient = await this.usersService.getUserByEmail(normalizedEmail);
      if (recipient?.id === inviterId) {
        throw new BadRequestException('You cannot invite yourself');
      }
    } else if (normalizedPhone) {
      if (
        inviter.phone &&
        this.normalizePhone(inviter.phone) === normalizedPhone
      ) {
        throw new BadRequestException('You cannot invite yourself');
      }
      // If phone-based invitations should resolve registered users,
      // add a phone lookup here when that method is available.
    }
    if (recipient) {
      const relationships =
        await this.guardianRelationshipsService.getRelationships(inviterId);
      // Check only the requested direction.
      // The reverse relationship must remain independent.
      const existingRelationship = relationships.some((relationship) => {
        if (
          dto.relationshipType === InvitationRelationshipType.I_MONITOR_THEM
        ) {
          // The inviter wants to monitor the recipient.
          return (
            relationship.guardianId === inviterId &&
            relationship.riderId === recipient!.id
          );
        }
        // The recipient will monitor the inviter.
        return (
          relationship.guardianId === recipient!.id &&
          relationship.riderId === inviterId
        );
      });
      if (existingRelationship) {
        throw new ConflictException(
          'A guardian-rider relationship already exists in this direction',
        );
      }
    }
    // Check for duplicate pending invitations according to the
    // requested relationship direction.
    await this.assertNoPendingInvitation(
      inviterId,
      normalizedEmail,
      normalizedPhone,
      dto.relationshipType,
      recipient?.id,
    );
    const invitation = this.invitationRepository.create({
      inviterId,
      inviteeEmail: normalizedEmail,
      inviteePhone: normalizedPhone,
      relationshipType: dto.relationshipType,
      token: randomBytes(32).toString('hex'),
      status: 'PENDING',
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      acceptedAt: null,
    });
    const saved = await this.invitationRepository.save(invitation);
    // Return the token only when creating an invitation.
    return {
      ...this.toResponse(saved),
      token: saved.token,
    };
  }

  async getInvitations(userId: string): Promise<InvitationResponse[]> {
    const user = await this.usersService.getUserById(userId);

    if (!user) {
      throw new NotFoundException('User not found');
    }

    const query = this.invitationRepository
      .createQueryBuilder('invitation')
      .where('invitation.inviter_id = :userId', {
        userId,
      });

    const email = this.normalizeEmail(user.email);
    const phone = this.normalizePhone(user.phone);

    if (email || phone) {
      query.orWhere(
        new Brackets((qb) => {
          if (email) {
            qb.where('LOWER(invitation.invitee_email) = :email', { email });
          }

          if (phone) {
            const condition = 'invitation.invitee_phone = :phone';

            if (email) {
              qb.orWhere(condition, { phone });
            } else {
              qb.where(condition, { phone });
            }
          }
        }),
      );
    }

    const invitations = await query
      .orderBy('invitation.created_at', 'DESC')
      .getMany();

    return invitations.map((invitation) => this.toResponse(invitation));
  }

  async acceptInvitation(
    token: string,
    acceptingUserId: string,
  ): Promise<InvitationResponse> {
    const result = await this.dataSource.transaction(async (manager) => {
      const invitationRepository = manager.getRepository(Invitation);

      const relationshipRepository = manager.getRepository(
        GuardianRiderRelationship,
      );

      const invitation = await invitationRepository
        .createQueryBuilder('invitation')
        .setLock('pessimistic_write')
        .where('invitation.token = :token', { token })
        .getOne();

      if (!invitation) {
        throw new NotFoundException('Invitation not found');
      }

      if (invitation.status !== 'PENDING') {
        throw new BadRequestException(
          `Invitation cannot be accepted. Current status: ${invitation.status}`,
        );
      }

      if (invitation.expiresAt <= new Date()) {
        invitation.status = 'EXPIRED';
        await invitationRepository.save(invitation);

        // Return a result rather than throwing inside the transaction,
        // otherwise the EXPIRED status update would be rolled back.
        return {
          expired: true as const,
        };
      }

      if (invitation.inviterId === acceptingUserId) {
        throw new BadRequestException('You cannot accept your own invitation');
      }

      const acceptingUser =
        await this.usersService.getUserById(acceptingUserId);

      if (!acceptingUser) {
        throw new NotFoundException('Accepting user not found');
      }

      this.validateInvitationRecipient(
        invitation,
        acceptingUser.email,
        acceptingUser.phone,
      );

      let guardianId: string;
      let riderId: string;

      if (
        invitation.relationshipType ===
        InvitationRelationshipType.I_MONITOR_THEM
      ) {
        // Sender is guardian; accepting user is rider.
        guardianId = invitation.inviterId;
        riderId = acceptingUser.id;
      } else if (
        invitation.relationshipType ===
        InvitationRelationshipType.THEY_MONITOR_ME
      ) {
        // Sender is rider; accepting user is guardian.
        guardianId = acceptingUser.id;
        riderId = invitation.inviterId;
      } else {
        throw new BadRequestException('Invalid invitation relationship type');
      }

      // Prevent duplicate relationships in either direction.
      const existingRelationship = await relationshipRepository
        .createQueryBuilder('relationship')
        .where(
          new Brackets((qb) => {
            qb.where(
              'relationship.guardian_id = :guardianId AND relationship.rider_id = :riderId',
              { guardianId, riderId },
            ).orWhere(
              'relationship.guardian_id = :riderId AND relationship.rider_id = :guardianId',
              { guardianId, riderId },
            );
          }),
        )
        .getOne();

      if (existingRelationship) {
        throw new ConflictException(
          'A guardian-rider relationship already exists between these users',
        );
      }

      const relationship = relationshipRepository.create({
        guardianId,
        riderId,
        status: 'ACCEPTED',
        acceptedAt: new Date(),
      });

      await relationshipRepository.save(relationship);

      invitation.status = 'ACCEPTED';
      invitation.acceptedAt = new Date();

      await invitationRepository.save(invitation);

      return {
        expired: false as const,
        invitation: this.toResponse(invitation),
      };
    });

    if (result.expired) {
      throw new BadRequestException('Invitation has expired');
    }

    return result.invitation;
  }

  async declineInvitation(
    token: string,
    acceptingUserId: string,
  ): Promise<InvitationResponse> {
    const invitation = await this.getInvitationByToken(token);

    if (invitation.status !== 'PENDING') {
      throw new BadRequestException(
        `Invitation cannot be declined. Current status: ${invitation.status}`,
      );
    }

    if (invitation.inviterId === acceptingUserId) {
      throw new ForbiddenException(
        'The inviter cannot decline their own invitation',
      );
    }

    const acceptingUser = await this.usersService.getUserById(acceptingUserId);

    if (!acceptingUser) {
      throw new NotFoundException('User not found');
    }

    this.validateInvitationRecipient(
      invitation,
      acceptingUser.email,
      acceptingUser.phone,
    );

    if (invitation.expiresAt <= new Date()) {
      invitation.status = 'EXPIRED';
      await this.invitationRepository.save(invitation);

      throw new BadRequestException('Invitation has expired');
    }

    invitation.status = 'DECLINED';

    return this.toResponse(await this.invitationRepository.save(invitation));
  }

  async cancelInvitation(
    invitationId: string,
    inviterId: string,
  ): Promise<InvitationResponse> {
    const invitation = await this.getInvitationOrThrow(invitationId);

    if (invitation.inviterId !== inviterId) {
      throw new ForbiddenException(
        'Only the inviter can cancel this invitation',
      );
    }

    if (invitation.status !== 'PENDING') {
      throw new BadRequestException(
        `Invitation cannot be cancelled. Current status: ${invitation.status}`,
      );
    }

    invitation.status = 'CANCELLED';

    return this.toResponse(await this.invitationRepository.save(invitation));
  }

  private async assertNoPendingInvitation(
    inviterId: string,
    email: string | null,
    phone: string | null,
    relationshipType: InvitationRelationshipType,
    recipientId?: string,
  ): Promise<void> {
    const oppositeRelationshipType =
      relationshipType === InvitationRelationshipType.I_MONITOR_THEM
        ? InvitationRelationshipType.THEY_MONITOR_ME
        : InvitationRelationshipType.I_MONITOR_THEM;

    // Check for an existing pending invitation in the same direction.
    const sameDirectionQuery = this.invitationRepository
      .createQueryBuilder('invitation')
      .where('invitation.status = :status', {
        status: 'PENDING',
      })
      .andWhere('invitation.inviter_id = :inviterId', {
        inviterId,
      })
      .andWhere('invitation.relationship_type = :relationshipType', {
        relationshipType,
      });

    if (email) {
      sameDirectionQuery.andWhere('LOWER(invitation.invitee_email) = :email', {
        email,
      });
    } else if (phone) {
      sameDirectionQuery.andWhere('invitation.invitee_phone = :phone', {
        phone,
      });
    }

    if (await sameDirectionQuery.getOne()) {
      throw new ConflictException(
        'A pending invitation already exists for this recipient and relationship type',
      );
    }

    // If the recipient is not registered, the reverse direction
    // cannot reliably be identified.
    if (!recipientId) {
      return;
    }

    const inviter = await this.usersService.getUserById(inviterId);

    if (!inviter) {
      throw new NotFoundException('Inviter not found');
    }

    const inviterEmail = this.normalizeEmail(inviter.email);
    const inviterPhone = this.normalizePhone(inviter.phone);

    // Check for a pending invitation from the recipient to the inviter.
    // It is a duplicate only when it requests the opposite relationship.
    const reverseQuery = this.invitationRepository
      .createQueryBuilder('invitation')
      .where('invitation.status = :status', {
        status: 'PENDING',
      })
      .andWhere('invitation.inviter_id = :recipientId', {
        recipientId,
      })
      .andWhere('invitation.relationship_type = :oppositeRelationshipType', {
        oppositeRelationshipType,
      });

    const recipientContactConditions: string[] = [];
    const recipientContactParameters: Record<string, string> = {};

    if (inviterEmail) {
      recipientContactConditions.push(
        'LOWER(invitation.invitee_email) = :inviterEmail',
      );
      recipientContactParameters.inviterEmail = inviterEmail;
    }

    if (inviterPhone) {
      recipientContactConditions.push(
        'invitation.invitee_phone = :inviterPhone',
      );
      recipientContactParameters.inviterPhone = inviterPhone;
    }

    if (recipientContactConditions.length === 0) {
      return;
    }

    reverseQuery.andWhere(
      `(${recipientContactConditions.join(' OR ')})`,
      recipientContactParameters,
    );

    if (await reverseQuery.getOne()) {
      throw new ConflictException(
        'A pending invitation already exists for this relationship direction',
      );
    }
  }

  private async getInvitationByToken(token: string): Promise<Invitation> {
    const invitation = await this.invitationRepository.findOne({
      where: { token },
    });

    if (!invitation) {
      throw new NotFoundException('Invitation not found');
    }

    return invitation;
  }

  private async getInvitationOrThrow(id: string): Promise<Invitation> {
    const invitation = await this.invitationRepository.findOne({
      where: { id },
    });

    if (!invitation) {
      throw new NotFoundException('Invitation not found');
    }

    return invitation;
  }

  private validateInvitationRecipient(
    invitation: Invitation,
    email: string | null | undefined,
    phone: string | null | undefined,
  ): void {
    if (invitation.inviteeEmail) {
      if (this.normalizeEmail(email) !== invitation.inviteeEmail) {
        throw new ForbiddenException(
          'This invitation was not sent to your email',
        );
      }

      return;
    }

    if (invitation.inviteePhone) {
      if (this.normalizePhone(phone) !== invitation.inviteePhone) {
        throw new ForbiddenException(
          'This invitation was not sent to your phone',
        );
      }

      return;
    }

    throw new BadRequestException('Invitation has no valid recipient');
  }

  private normalizeEmail(email: string | null | undefined): string | null {
    if (!email) {
      return null;
    }

    return email.trim().toLowerCase() || null;
  }

  private normalizePhone(phone: string | null | undefined): string | null {
    if (!phone) {
      return null;
    }

    return phone.trim() || null;
  }

  private toResponse(invitation: Invitation): InvitationResponse {
    return {
      id: invitation.id,
      inviterId: invitation.inviterId,
      inviteeEmail: invitation.inviteeEmail,
      inviteePhone: invitation.inviteePhone,
      relationshipType: invitation.relationshipType,
      status: invitation.status,
      expiresAt: invitation.expiresAt,
      acceptedAt: invitation.acceptedAt,
      createdAt: invitation.createdAt,
    };
  }
}
