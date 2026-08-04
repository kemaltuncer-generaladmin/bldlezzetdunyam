import type { Config } from 'tailwindcss';

/**
 * Renk paleti `packages/design_system/lib/src/colors.dart` içindeki
 * `BldColors` sınıfının birebir karşılığıdır. Orada bir değer değişirse
 * burada da değişmeli — tek kaynak Dart dosyasıdır (BILINMEYENLER #11:
 * palet yer tutucudur, Gün 6'da kesinleşir).
 */
const config: Config = {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}', './lib/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#FFF7ED',
          100: '#FFEDD5',
          200: '#FED7AA',
          300: '#FDBA74',
          400: '#FB923C',
          500: '#F97316',
          600: '#EA580C',
          700: '#C2410C',
          800: '#9A3412',
          900: '#7C2D12',
        },
        neutral: {
          0: '#FFFFFF',
          50: '#FAFAF9',
          100: '#F5F5F4',
          200: '#E7E5E4',
          400: '#A8A29E',
          600: '#57534E',
          800: '#292524',
          900: '#1C1917',
        },
        success: '#16A34A',
        warning: '#CA8A04',
        danger: '#DC2626',
        info: '#2563EB',
      },
      fontFamily: {
        sans: ['var(--font-inter)', 'system-ui', 'sans-serif'],
      },
      borderRadius: {
        card: '0.75rem',
      },
      maxWidth: {
        content: '72rem',
      },
    },
  },
  plugins: [],
};

export default config;
