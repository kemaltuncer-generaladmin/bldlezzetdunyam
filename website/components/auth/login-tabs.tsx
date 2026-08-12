'use client';

import { useState } from 'react';
import { LoginForm } from '@/components/auth/login-form';
import { PhoneLoginForm } from '@/components/auth/phone-login-form';
import { cn } from '@/lib/utils';

type Method = 'phone' | 'email';

/**
 * Giriş yöntemi seçici — W-11.
 *
 * TELEFON VARSAYILAN. Kurumsal müşteri haftada birkaç kez sipariş veriyor ve
 * aradaki günlerde parolayı unutuyor; telefon numarası ise her zaman elinin
 * altında. E-posta + parola kapanmıyor — yıllardır o alışkanlığı olan
 * kullanıcıyı zorla taşımak yeni bir sorun yaratırdı.
 *
 * `radiogroup` DEĞİL, `tablist` DA DEĞİL: iki ayrı formu birbirine bağlayan
 * basit bir seçim. `role="tablist"` kullanmak, ok tuşlarıyla gezinme ve
 * `aria-controls` bağlantısı gibi bir sözleşmeye girmek demekti; iki düğme
 * için gereksiz. Düğmeler `aria-pressed` ile durumlarını bildiriyor.
 */
export function LoginTabs({ next }: { next: string }) {
  const [method, setMethod] = useState<Method>('phone');

  return (
    <div className="space-y-5">
      <div className="grid grid-cols-2 gap-1 rounded-lg bg-muted p-1">
        <MethodButton
          active={method === 'phone'}
          onClick={() => setMethod('phone')}
          label="Telefon ile"
        />
        <MethodButton
          active={method === 'email'}
          onClick={() => setMethod('email')}
          label="E-posta ile"
        />
      </div>

      {/*
        Seçilmeyen form DOM'DAN ÇIKARILIYOR, gizlenmiyor. İki form birden
        dursaydı ikisinin de alanları form gönderimine dahil olur ve tarayıcı
        parola yöneticisi hangi alana yazacağını şaşırırdı.
      */}
      {method === 'phone' ? <PhoneLoginForm next={next} /> : <LoginForm next={next} />}
    </div>
  );
}

function MethodButton({
  active,
  onClick,
  label,
}: {
  active: boolean;
  onClick: () => void;
  label: string;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={active}
      className={cn(
        'min-h-11 rounded-md px-3 text-sm font-medium transition-colors',
        active
          ? 'bg-background text-foreground shadow-sm'
          : 'text-muted-foreground hover:text-foreground',
      )}
    >
      {label}
    </button>
  );
}
