import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';

import { SafetyAlert } from './entities/safety-alert.entity.js';
import { UsersService } from '../users/users.service.js';

@Injectable()
export class SafetyAlertsService {
  constructor(
    @InjectRepository(SafetyAlert)
    private readonly safetyAlertRepository: Repository<SafetyAlert>,

    private readonly usersService: UsersService,
  ) {}

  /**
   * Resolve the authenticated Firebase user to our database user.
   */
  private async getDatabaseUser(firebaseUid: string) {
    const user =
      await this.usersService.getUserByFirebaseUid(firebaseUid);

    if (!user) {
      throw new NotFoundException(
        'User profile not found. Please register first.',
      );
    }

    return user;
  }

  /**
   * A rider can access their own alerts.
   * A guardian can access only alerts assigned to them.
   */
  private canAccessAlert(
    alert: SafetyAlert,
    userId: string,
  ): boolean {
    return (
      alert.riderId === userId ||
      alert.guardianId === userId
    );
  }

  /**
   * GET /api/v1/alerts
   *
   * Returns alerts where the user is either the rider
   * or the guardian assigned to the alert.
   */
  async getAlerts(firebaseUid: string) {
    const user = await this.getDatabaseUser(firebaseUid);

    return this.safetyAlertRepository.find({
      where: [
        { riderId: user.id },
        { guardianId: user.id },
      ],
      order: {
        triggeredAt: 'DESC',
      },
    });
  }

  /**
   * GET /api/v1/alerts/active
   *
   * Returns only active alerts relevant to the user.
   */
  async getActiveAlerts(firebaseUid: string) {
    const user = await this.getDatabaseUser(firebaseUid);

    return this.safetyAlertRepository.find({
      where: [
        {
          riderId: user.id,
          status: 'ACTIVE',
        },
        {
          guardianId: user.id,
          status: 'ACTIVE',
        },
      ],
      order: {
        triggeredAt: 'DESC',
      },
    });
  }

  /**
   * GET /api/v1/alerts/:alertId
   *
   * Returns one alert after checking authorization.
   */
  async getAlertById(
    firebaseUid: string,
    alertId: string,
  ) {
    const user = await this.getDatabaseUser(firebaseUid);

    const alert = await this.safetyAlertRepository.findOne({
      where: {
        id: alertId,
      },
    });

    if (!alert) {
      throw new NotFoundException('Alert not found.');
    }

    if (!this.canAccessAlert(alert, user.id)) {
      throw new ForbiddenException(
        'You are not authorized to access this alert.',
      );
    }

    return alert;
  }

  /**
   * POST /api/v1/alerts/:alertId/acknowledge
   *
   * Marks an active alert as acknowledged.
   */
  async acknowledgeAlert(
    firebaseUid: string,
    alertId: string,
  ) {
    const alert = await this.getAlertById(
      firebaseUid,
      alertId,
    );

    if (alert.status === 'RESOLVED') {
      throw new ForbiddenException(
        'A resolved alert cannot be acknowledged.',
      );
    }

    if (alert.status === 'ACTIVE') {
      alert.status = 'ACKNOWLEDGED';
      alert.acknowledgedAt = new Date();

      await this.safetyAlertRepository.save(alert);
    }

    // Repeated acknowledgement is idempotent.
    return alert;
  }

  /**
   * POST /api/v1/alerts/:alertId/resolve
   *
   * Marks an active or acknowledged alert as resolved.
   */
  async resolveAlert(
    firebaseUid: string,
    alertId: string,
  ) {
    const alert = await this.getAlertById(
      firebaseUid,
      alertId,
    );

    if (alert.status !== 'RESOLVED') {
      alert.status = 'RESOLVED';
      alert.resolvedAt = new Date();

      await this.safetyAlertRepository.save(alert);
    }

    // Repeated resolution is idempotent.
    return alert;
  }
}