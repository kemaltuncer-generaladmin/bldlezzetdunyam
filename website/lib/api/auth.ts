import 'server-only';

import { apiFetch } from './client';
import type {
  AuthResponse,
  Customer,
  LoginRequest,
  OtpRequestResponse,
  RegisterRequest,
} from './types';

export async function login(payload: LoginRequest): Promise<AuthResponse> {
  return apiFetch<AuthResponse>('/auth/login', { method: 'POST', body: payload });
}

export async function register(payload: RegisterRequest): Promise<AuthResponse> {
  return apiFetch<AuthResponse>('/auth/register', { method: 'POST', body: payload });
}

/**
 * Telefona giriş kodu gönderir (W-11).
 *
 * SUNUCU KAYITLI/KAYITSIZ AYRIMI YAPMIYOR ve bu kasıtlı — numara sayımına
 * kapı bırakmamak için (`docs/openapi.yaml` `requestOtp`). Arayüz de bu
 * ayrımı yapmamalı: "kod gönderildi" ekranı her iki durumda da aynı
 * görünür.
 */
export async function requestOtp(phone: string): Promise<OtpRequestResponse> {
  return apiFetch<OtpRequestResponse>('/auth/otp/request', {
    method: 'POST',
    body: { phone },
  });
}

export async function verifyOtp(phone: string, code: string): Promise<AuthResponse> {
  return apiFetch<AuthResponse>('/auth/otp/verify', {
    method: 'POST',
    body: { phone, code },
  });
}

export async function fetchMe(token: string): Promise<Customer> {
  return apiFetch<Customer>('/auth/me', { token });
}

export async function logout(token: string): Promise<void> {
  await apiFetch<void>('/auth/logout', { method: 'POST', token });
}
