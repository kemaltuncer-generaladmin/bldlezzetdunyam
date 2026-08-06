'use client';

import { ThemeProvider as NextThemesProvider } from 'next-themes';
import type { ComponentProps } from 'react';

/**
 * Tema sağlayıcı.
 *
 * `next-themes` sınıfı `<html>` üzerine yazar (`.dark`), çünkü shadcn/ui'ın
 * karanlık varyantı `&:is(.dark *)` seçicisine bağlı — salt CSS
 * `prefers-color-scheme` ile kullanıcıya tercih değiştirme imkânı kalmazdı.
 *
 * `disableTransitionOnChange`, tema değişiminde tüm renk geçişlerini bir kare
 * boyunca kapatır; onsuz sayfadaki her öğe aynı anda 200 ms boyunca renk
 * değiştirip gözle görülür bir dalgalanma yaratıyor.
 */
export function ThemeProvider({ children, ...props }: ComponentProps<typeof NextThemesProvider>) {
  return (
    <NextThemesProvider
      attribute="class"
      defaultTheme="light"
      enableSystem
      disableTransitionOnChange
      {...props}
    >
      {children}
    </NextThemesProvider>
  );
}
