import { z } from 'zod';
import { Role } from '@prisma/client';

// Phone format regex: E.164 or common 10-15 digit phone with optional + and formatting
const phoneRegex = /^\+?[0-9\s\-()]{10,15}$/;

export const registerSchema = z.object({
  name: z
    .string({ required_error: 'Full name is required' })
    .trim()
    .min(2, 'Name must be at least 2 characters')
    .max(100, 'Name cannot exceed 100 characters'),
  email: z
    .string({ required_error: 'Email address is required' })
    .trim()
    .email('Invalid email address format'),
  phone: z
    .string({ required_error: 'Phone number is required' })
    .trim()
    .regex(phoneRegex, 'Invalid phone number format. Must be 10-15 digits'),
  password: z
    .string({ required_error: 'Password is required' })
    .min(8, 'Password must be at least 8 characters')
    .max(100, 'Password cannot exceed 100 characters'),
  role: z
    .enum([Role.CLIENT, Role.ODUVAR, Role.ADMIN], {
      errorMap: () => ({ message: 'Role must be either CLIENT or ODUVAR' }),
    })
    .refine((val) => val === Role.CLIENT || val === Role.ODUVAR, {
      message: 'Admin registration is restricted. Only CLIENT and ODUVAR roles are allowed for public registration',
    }),
});

export const loginSchema = z.object({
  email: z
    .string({ required_error: 'Email is required' })
    .trim()
    .email('Invalid email address format'),
  password: z
    .string({ required_error: 'Password is required' })
    .min(1, 'Password is required'),
});

export const refreshSchema = z.object({
  refreshToken: z
    .string({ required_error: 'Refresh token is required' })
    .min(1, 'Refresh token cannot be empty'),
});

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type RefreshInput = z.infer<typeof refreshSchema>;
