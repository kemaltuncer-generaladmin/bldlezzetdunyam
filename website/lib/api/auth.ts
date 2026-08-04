import 'server-only';

import { apiFetch } from './client';
import type { AuthResponse, Customer, LoginRequest, RegisterRequest } from './types';

export async function login(payload: LoginRequest): Promise<AuthResponse> {
  return apiFetch<AuthResponse>('/auth/login', { method: 'POST', body: payload });
}

export async function register(payload: RegisterRequest): Promise<AuthResponse> {
  return apiFetch<AuthResponse>('/auth/register', { method: 'POST', body: payload });
}

export async function fetchMe(token: string): Promise<Customer> {
  return apiFetch<Customer>('/auth/me', { token });
}

export async function logout(token: string): Promise<void> {
  await apiFetch<void>('/auth/logout', { method: 'POST', token });
}
