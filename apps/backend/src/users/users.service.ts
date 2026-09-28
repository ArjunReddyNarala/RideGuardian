import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity.js';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
  ) {}

  async createUser(data: {
    firebaseUid: string;
    name: string;
    email?: string;
    phone?: string;
    profileImageUrl?: string;
  }): Promise<User> {
    const user = this.userRepository.create({
      firebaseUid: data.firebaseUid,
      name: data.name,
      email: data.email ?? null,
      phone: data.phone ?? null,
      profileImageUrl: data.profileImageUrl ?? null,
    });

    return this.userRepository.save(user);
  }

  async getUserById(id: string): Promise<User | null> {
    return this.userRepository.findOne({
      where: { id },
    });
  }

  async updateUser(
    id: string,
    data: {
      name?: string;
      phone?: string;
      profileImageUrl?: string;
    },
  ): Promise<User | null> {
    const user = await this.getUserById(id);

    if (!user) {
      return null;
    }

    Object.assign(user, data);

    return this.userRepository.save(user);
  }

  async getUserByFirebaseUid(firebaseUid: string): Promise<User | null> {
    return this.userRepository.findOne({
      where: { firebaseUid },
    });
  }

  async getUserByEmail(email: string): Promise<User | null> {
    return this.userRepository.findOne({
      where: { email },
    });
  }
}