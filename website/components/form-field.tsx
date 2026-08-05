import { cn } from '@/lib/cn';

type Props = {
  id: string;
  label: string;
  error?: string;
  hint?: string;
  children: (props: {
    id: string;
    describedBy: string | undefined;
    invalid: boolean;
  }) => React.ReactNode;
};

/**
 * Etiket + alan + hata. Hata metni `aria-describedby` ile alana bağlanır
 * (`docs/06` §5 erişilebilirlik kuralı).
 */
export function FormField({ id, label, error, hint, children }: Props) {
  const errorId = `${id}-hata`;
  const hintId = `${id}-ipucu`;
  const describedBy = [hint ? hintId : null, error ? errorId : null].filter(Boolean).join(' ');

  return (
    <div>
      <label htmlFor={id} className="block text-sm font-semibold text-neutral-900">
        {label}
      </label>
      {hint && (
        <p id={hintId} className="mt-0.5 text-xs text-neutral-600">
          {hint}
        </p>
      )}
      <div className="mt-1">
        {children({
          id,
          describedBy: describedBy.length > 0 ? describedBy : undefined,
          invalid: Boolean(error),
        })}
      </div>
      {error && (
        <p id={errorId} role="alert" className="mt-1 text-sm text-danger">
          {error}
        </p>
      )}
    </div>
  );
}

export const inputClass = (invalid: boolean): string =>
  cn('bld-field', invalid && 'border-danger bg-danger/5');
