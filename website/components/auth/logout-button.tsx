'use client';

import { useTransition } from 'react';
import { logoutAction } from '@/app/actions/auth';

export function LogoutButton() {
  const [pending, startTransition] = useTransition();

  return (
    <button
      type="button"
      disabled={pending}
      onClick={() => startTransition(() => logoutAction())}
      className="rounded-lg border border-neutral-200 px-4 py-2.5 text-sm font-semibold text-neutral-900 hover:bg-neutral-100 disabled:opacity-60"
    >
      {pending ? 'Çıkış yapılıyor…' : 'Çıkış yap'}
    </button>
  );
}
