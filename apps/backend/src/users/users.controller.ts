import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
} from '@nestjs/common';

import { UsersService } from './users.service.js';

@Controller('api/v1/users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post()
  async createUser(
    @Body()
    body: {
      firebaseUid: string;
      name: string;
      email?: string;
      phone?: string;
      profileImageUrl?: string;
    },
  ) {
    return this.usersService.createUser(body);
  }

  @Get(':id')
  async getUser(@Param('id') id: string) {
    return this.usersService.getUserById(id);
  }

  @Patch(':id')
  async updateUser(
    @Param('id') id: string,
    @Body()
    body: {
      name?: string;
      phone?: string;
      profileImageUrl?: string;
    },
  ) {
    return this.usersService.updateUser(id, body);
  }
}