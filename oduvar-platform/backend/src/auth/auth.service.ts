import { usersRepository } from '../users/users.repository';
import { RegisterInput, LoginInput } from './auth.dto';
import { hashPassword, comparePassword } from '../common/utils/password';
import {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
} from '../common/utils/jwt';
import { AppError } from '../common/dto/api-response';
import { Role } from '@prisma/client';

export interface UserResponse {
  id: string;
  name: string;
  email: string;
  phone: string;
  role: Role;
  profilePhoto: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface AuthSuccessResult {
  user: UserResponse;
  accessToken: string;
  refreshToken: string;
}

export interface TokenRefreshResult {
  accessToken: string;
  refreshToken: string;
}

export class AuthService {
  async register(input: RegisterInput): Promise<AuthSuccessResult> {
    const existing = await usersRepository.findByEmail(input.email);
    if (existing) {
      throw new AppError(
        'AUTH_EMAIL_EXISTS',
        'A user with this email address already exists',
        409
      );
    }

    const passwordHash = await hashPassword(input.password);

    const user = await usersRepository.create({
      name: input.name,
      email: input.email,
      phone: input.phone,
      passwordHash,
      role: input.role,
    });

    const accessToken = signAccessToken({
      userId: user.id,
      role: user.role,
      tokenVersion: user.tokenVersion,
    });

    const refreshToken = signRefreshToken({
      userId: user.id,
      tokenVersion: user.tokenVersion,
    });

    return {
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        profilePhoto: user.profilePhoto,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      accessToken,
      refreshToken,
    };
  }

  async login(input: LoginInput): Promise<AuthSuccessResult> {
    const user = await usersRepository.findByEmail(input.email);
    if (!user) {
      throw new AppError(
        'AUTH_INVALID_CREDENTIALS',
        'Invalid email or password',
        401
      );
    }

    const isMatch = await comparePassword(input.password, user.passwordHash);
    if (!isMatch) {
      throw new AppError(
        'AUTH_INVALID_CREDENTIALS',
        'Invalid email or password',
        401
      );
    }

    const accessToken = signAccessToken({
      userId: user.id,
      role: user.role,
      tokenVersion: user.tokenVersion,
    });

    const refreshToken = signRefreshToken({
      userId: user.id,
      tokenVersion: user.tokenVersion,
    });

    return {
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        profilePhoto: user.profilePhoto,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
      accessToken,
      refreshToken,
    };
  }

  async refreshTokens(refreshToken: string): Promise<TokenRefreshResult> {
    let payload;
    try {
      payload = verifyRefreshToken(refreshToken);
    } catch (err: any) {
      if (err.name === 'TokenExpiredError') {
        throw new AppError('AUTH_TOKEN_EXPIRED', 'Refresh token has expired. Please log in again', 401);
      }
      throw new AppError('AUTH_INVALID_TOKEN', 'Invalid refresh token', 401);
    }

    const user = await usersRepository.findById(payload.userId);
    if (!user) {
      throw new AppError('AUTH_USER_NOT_FOUND', 'User does not exist', 401);
    }

    if (user.tokenVersion !== payload.tokenVersion) {
      throw new AppError(
        'AUTH_TOKEN_REVOKED',
        'Refresh token has been revoked. Please log in again',
        401
      );
    }

    const newAccessToken = signAccessToken({
      userId: user.id,
      role: user.role,
      tokenVersion: user.tokenVersion,
    });

    const newRefreshToken = signRefreshToken({
      userId: user.id,
      tokenVersion: user.tokenVersion,
    });

    return {
      accessToken: newAccessToken,
      refreshToken: newRefreshToken,
    };
  }

  async logout(userId: string): Promise<{ message: string }> {
    await usersRepository.incrementTokenVersion(userId);
    return { message: 'Logged out successfully' };
  }

  async getMe(userId: string): Promise<UserResponse> {
    const user = await usersRepository.findById(userId);
    if (!user) {
      throw new AppError('AUTH_USER_NOT_FOUND', 'User does not exist', 404);
    }

    return {
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      profilePhoto: user.profilePhoto,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    };
  }
}

export const authService = new AuthService();
