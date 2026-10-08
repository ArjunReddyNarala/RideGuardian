import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { randomBytes } from 'node:crypto';
import { Repository } from 'typeorm';

import { GuardianRelationshipsService } from '../guardian-relationships/guardian-relationships.service.js';
import { UsersService } from '../users/users.service.js';

import { Invitation } from './entities/invitation.entity.js';

@Injectable()
export class InvitationsService {
  constructor(
    @InjectRepository(Invitation)
    private readonly invitationRepository: Repository<Invitation>,

    private readonly usersService: UsersService,

    private readonly guardianRelationshipsService: GuardianRelationshipsService,
  ) {}

  /**
   * Creates an invitation using either an email address or phone number.
   *
   * Exactly one recipient identifier must be provided.
   */
  async createInvitation(
    inviterId: string,
    inviteeEmail?: string,
    inviteePhone?: string,
  ): Promise<Invitation> {
    const normalizedEmail = this.normalizeEmail(inviteeEmail);
    const normalizedPhone = this.normalizePhone(inviteePhone);

    // Exactly one of email or phone must be provided.
    if (
      (!normalizedEmail && !normalizedPhone) ||
      (normalizedEmail && normalizedPhone)
    ) {
      throw new BadRequestException(
        'Provide either an invitee email or phone number, but not both',
      );
    }

    // Make sure the inviter exists.
    const inviter = await this.usersService.getUserById(inviterId);

    if (!inviter) {
      throw new NotFoundException('Inviter not found');
    }

    // Prevent inviting yourself.
    if (normalizedEmail) {
      const existingUser =
        await this.usersService.getUserByEmail(normalizedEmail);

      if (existingUser?.id === inviterId) {
        throw new BadRequestException(
          'You cannot invite yourself',
        );
      }
    }

    if (normalizedPhone && inviter.phone === normalizedPhone) {
      throw new BadRequestException(
        'You cannot invite yourself',
      );
    }

    // Check whether a pending invitation already exists
    // for this inviter and recipient.
    const existingInvitation = await this.findPendingInvitation(
      inviterId,
      normalizedEmail,
      normalizedPhone,
    );

    if (existingInvitation) {
      throw new ConflictException(
        'A pending invitation already exists for this user',
      );
    }

    const token = randomBytes(32).toString('hex');

    const invitation = this.invitationRepository.create({
      inviterId,
      inviteeEmail: normalizedEmail,
      inviteePhone: normalizedPhone,
      token,
      status: 'PENDING',
      expiresAt: new Date(
        Date.now() + 7 * 24 * 60 * 60 * 1000,
      ),
      acceptedAt: null,
    });

    return this.invitationRepository.save(invitation);
  }

  /**
   * Returns invitations where the user is either:
   * - the inviter, or
   * - the recipient by email, or
   * - the recipient by phone.
   */
  async getInvitations(
    userId: string,
  ): Promise<Invitation[]> {
    const user = await this.usersService.getUserById(userId);

    if (!user) {
      throw new NotFoundException('User not found');
    }

    const query = this.invitationRepository
      .createQueryBuilder('invitation')
      .where(
        'invitation.inviter_id = :userId',
        { userId },
      );

    if (user.email) {
      query.orWhere(
        'LOWER(invitation.invitee_email) = :email',
        {
          email: this.normalizeEmail(user.email),
        },
      );
    }

    if (user.phone) {
      query.orWhere(
        'invitation.invitee_phone = :phone',
        {
          phone: this.normalizePhone(user.phone),
        },
      );
    }

    return query
      .orderBy(
        'invitation.created_at',
        'DESC',
      )
      .getMany();
  }

  /**
   * Accepts an invitation and creates the corresponding
   * guardian-rider relationship.
   */
  async acceptInvitation(
    token: string,
    riderId: string,
  ): Promise<Invitation> {
    const invitation =
      await this.getInvitationByToken(token);

    // Invitation must still be pending.
    if (invitation.status !== 'PENDING') {
      throw new BadRequestException(
        `Invitation cannot be accepted. Current status: ${invitation.status}`,
      );
    }

    // Check expiration.
    if (invitation.expiresAt <= new Date()) {
      invitation.status = 'EXPIRED';

      await this.invitationRepository.save(
        invitation,
      );

      throw new BadRequestException(
        'Invitation has expired',
      );
    }

    // The inviter cannot accept their own invitation.
    if (invitation.inviterId === riderId) {
      throw new BadRequestException(
        'You cannot accept your own invitation',
      );
    }

    const rider =
      await this.usersService.getUserById(riderId);

    if (!rider) {
      throw new NotFoundException('Rider not found');
    }

    // Verify that the logged-in rider is the intended recipient.
    this.validateInvitationRecipient(
      invitation,
      rider.email,
      rider.phone,
    );

    // Create the accepted guardian-rider relationship.
    await this.guardianRelationshipsService.createRelationship(
      invitation.inviterId,
      riderId,
    );

    // Mark invitation as accepted.
    invitation.status = 'ACCEPTED';
    invitation.acceptedAt = new Date();

    return this.invitationRepository.save(
      invitation,
    );
  }

  /**
   * Declines an invitation.
   */
  async declineInvitation(
    token: string,
    riderId: string,
  ): Promise<Invitation> {
    const invitation =
      await this.getInvitationByToken(token);

    if (invitation.status !== 'PENDING') {
      throw new BadRequestException(
        `Invitation cannot be declined. Current status: ${invitation.status}`,
      );
    }

    if (invitation.inviterId === riderId) {
      throw new ForbiddenException(
        'The inviter cannot decline their own invitation',
      );
    }

    const rider =
      await this.usersService.getUserById(riderId);

    if (!rider) {
      throw new NotFoundException('Rider not found');
    }

    // Verify that the logged-in rider is the intended recipient.
    this.validateInvitationRecipient(
      invitation,
      rider.email,
      rider.phone,
    );

    invitation.status = 'DECLINED';

    return this.invitationRepository.save(
      invitation,
    );
  }

  /**
   * Cancels a pending invitation.
   *
   * Only the user who created the invitation can cancel it.
   */
  async cancelInvitation(
    invitationId: string,
    inviterId: string,
  ): Promise<Invitation> {
    const invitation =
      await this.getInvitationOrThrow(invitationId);

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

    return this.invitationRepository.save(
      invitation,
    );
  }

  /**
   * Finds an existing pending invitation for the
   * specified recipient.
   */
  private async findPendingInvitation(
    inviterId: string,
    inviteeEmail: string | null,
    inviteePhone: string | null,
  ): Promise<Invitation | null> {
    const query = this.invitationRepository
      .createQueryBuilder('invitation')
      .where(
        'invitation.inviter_id = :inviterId',
        { inviterId },
      )
      .andWhere(
        'invitation.status = :status',
        { status: 'PENDING' },
      );

    if (inviteeEmail) {
      query.andWhere(
        'LOWER(invitation.invitee_email) = :email',
        {
          email: inviteeEmail,
        },
      );
    }

    if (inviteePhone) {
      query.andWhere(
        'invitation.invitee_phone = :phone',
        {
          phone: inviteePhone,
        },
      );
    }

    return query.getOne();
  }

  /**
   * Retrieves an invitation by its secure token.
   */
  private async getInvitationByToken(
    token: string,
  ): Promise<Invitation> {
    const invitation =
      await this.invitationRepository.findOne({
        where: { token },
      });

    if (!invitation) {
      throw new NotFoundException(
        'Invitation not found',
      );
    }

    return invitation;
  }

  /**
   * Retrieves an invitation by ID.
   */
  private async getInvitationOrThrow(
    id: string,
  ): Promise<Invitation> {
    const invitation =
      await this.invitationRepository.findOne({
        where: { id },
      });

    if (!invitation) {
      throw new NotFoundException(
        'Invitation not found',
      );
    }

    return invitation;
  }

  /**
   * Validates that the logged-in user is the
   * intended invitation recipient.
   */
  private validateInvitationRecipient(
    invitation: Invitation,
    email: string | null,
    phone: string | null,
  ): void {
    if (invitation.inviteeEmail) {
      const normalizedUserEmail =
        this.normalizeEmail(email);

      if (
        normalizedUserEmail !==
        invitation.inviteeEmail
      ) {
        throw new ForbiddenException(
          'This invitation was not sent to your email',
        );
      }

      return;
    }

    if (invitation.inviteePhone) {
      const normalizedUserPhone =
        this.normalizePhone(phone);

      if (
        normalizedUserPhone !==
        invitation.inviteePhone
      ) {
        throw new ForbiddenException(
          'This invitation was not sent to your phone',
        );
      }

      return;
    }

    throw new BadRequestException(
      'Invitation has no valid recipient',
    );
  }

  /**
   * Normalizes an email address for consistent
   * storage and comparison.
   */
  private normalizeEmail(
    email?: string | null,
  ): string | null {
    if (!email) {
      return null;
    }

    const normalized = email.trim().toLowerCase();

    return normalized || null;
  }

  /**
   * Normalizes a phone number.
   *
   * For now we trim whitespace. A proper E.164
   * normalization can be added later using a
   * phone-number library.
   */
  private normalizePhone(
    phone?: string | null,
  ): string | null {
    if (!phone) {
      return null;
    }

    const normalized = phone.trim();

    return normalized || null;
  }
}