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

import { Invitation } from './entities/invitation.entity.js';
import { UsersService } from '../users/users.service.js';
import { GuardianRelationshipsService } from '../guardian-relationships/guardian-relationships.service.js';

@Injectable()
export class InvitationsService {
  constructor(
    @InjectRepository(Invitation)
    private readonly invitationRepository: Repository<Invitation>,

    private readonly usersService: UsersService,

    private readonly guardianRelationshipsService: GuardianRelationshipsService,
  ) {}

  async createInvitation(
    inviterId: string,
    inviteeEmail?: string,
    inviteePhone?: string,
  ): Promise<Invitation> {
    if (!inviteeEmail && !inviteePhone) {
      throw new BadRequestException(
        'Either invitee email or phone is required',
      );
    }

    if (inviteeEmail) {
      const existingUser =
        await this.usersService.getUserByEmail(inviteeEmail);

      if (existingUser?.id === inviterId) {
        throw new BadRequestException(
          'You cannot invite yourself',
        );
      }
    }

    const existingInvitation =
      await this.invitationRepository.findOne({
        where: {
          inviterId,
          inviteeEmail: inviteeEmail ?? undefined,
          inviteePhone: inviteePhone ?? undefined,
          status: 'PENDING',
        },
      });

    if (existingInvitation) {
      throw new ConflictException(
        'A pending invitation already exists for this user',
      );
    }

    const token = randomBytes(32).toString('hex');

    const invitation = this.invitationRepository.create({
      inviterId,
      inviteeEmail: inviteeEmail ?? null,
      inviteePhone: inviteePhone ?? null,
      token,
      status: 'PENDING',
      expiresAt: new Date(
        Date.now() + 7 * 24 * 60 * 60 * 1000,
      ),
      acceptedAt: null,
    });

    return this.invitationRepository.save(invitation);
  }

  async getInvitations(userId: string): Promise<Invitation[]> {
    const user = await this.usersService.getUserById(userId);

    if (!user) {
      throw new NotFoundException('User not found');
    }

    return this.invitationRepository
      .createQueryBuilder('invitation')
      .where('invitation.inviter_id = :userId', {
        userId,
      })
      .orWhere(
        `invitation.invitee_email = :email`,
        {
          email: user.email,
        },
      )
      .orWhere(
        `invitation.invitee_phone = :phone`,
        {
          phone: user.phone,
        },
      )
      .orderBy('invitation.created_at', 'DESC')
      .getMany();
  }

  async acceptInvitation(
    token: string,
    riderId: string,
  ): Promise<Invitation> {
    const invitation = await this.getInvitationByToken(token);

    if (invitation.status !== 'PENDING') {
      throw new BadRequestException(
        `Invitation cannot be accepted. Current status: ${invitation.status}`,
      );
    }

    if (invitation.expiresAt < new Date()) {
      invitation.status = 'EXPIRED';

      await this.invitationRepository.save(invitation);

      throw new BadRequestException('Invitation has expired');
    }

    if (invitation.inviterId === riderId) {
      throw new BadRequestException(
        'You cannot accept your own invitation',
      );
    }

    const rider = await this.usersService.getUserById(riderId);

    if (!rider) {
      throw new NotFoundException('Rider not found');
    }

    if (
      invitation.inviteeEmail &&
      rider.email?.toLowerCase() !==
        invitation.inviteeEmail.toLowerCase()
    ) {
      throw new ForbiddenException(
        'This invitation was not sent to your email',
      );
    }

    if (
      invitation.inviteePhone &&
      rider.phone !== invitation.inviteePhone
    ) {
      throw new ForbiddenException(
        'This invitation was not sent to your phone',
      );
    }

    await this.guardianRelationshipsService.createRelationship(
      invitation.inviterId,
      riderId,
    );

    invitation.status = 'ACCEPTED';
    invitation.acceptedAt = new Date();

    return this.invitationRepository.save(invitation);
  }

  async declineInvitation(
    token: string,
    riderId: string,
  ): Promise<Invitation> {
    const invitation = await this.getInvitationByToken(token);

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

    const rider = await this.usersService.getUserById(riderId);

    if (!rider) {
      throw new NotFoundException('Rider not found');
    }

    this.validateInvitationRecipient(invitation, rider.email, rider.phone);

    invitation.status = 'DECLINED';

    return this.invitationRepository.save(invitation);
  }

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

    return this.invitationRepository.save(invitation);
  }

  private async getInvitationByToken(
    token: string,
  ): Promise<Invitation> {
    const invitation = await this.invitationRepository.findOne({
      where: { token },
    });

    if (!invitation) {
      throw new NotFoundException('Invitation not found');
    }

    return invitation;
  }

  private async getInvitationOrThrow(
    id: string,
  ): Promise<Invitation> {
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
    email: string | null,
    phone: string | null,
  ): void {
    if (
      invitation.inviteeEmail &&
      email?.toLowerCase() !==
        invitation.inviteeEmail.toLowerCase()
    ) {
      throw new ForbiddenException(
        'This invitation was not sent to your email',
      );
    }

    if (
      invitation.inviteePhone &&
      phone !== invitation.inviteePhone
    ) {
      throw new ForbiddenException(
        'This invitation was not sent to your phone',
      );
    }
  }
}