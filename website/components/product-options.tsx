import { Money } from '@/components/money';
import type { MenuItem, MenuOption } from '@/lib/api/types';

/**
 * `MenuOption.type` kapalı bir enum değildir (`docs/openapi.yaml` notu).
 * `checkbox` çok seçim, diğer her şey (bilinmeyenler dâhil) tek seçimdir.
 */
function isMultiSelect(option: MenuOption): boolean {
  return option.type === 'checkbox';
}

export function ProductOptions({ item }: { item: MenuItem }) {
  const options = item.options ?? [];
  if (options.length === 0) return null;

  return (
    <div className="space-y-5">
      {options.map((option) => {
        const multi = isMultiSelect(option);
        const groupName = multi ? 'option_value_ids' : `option_${option.id}`;
        const descriptionId = `secenek-${option.id}-aciklama`;

        return (
          <fieldset key={option.id} className="border-0 p-0">
            <legend className="text-label">
              {option.name}
              {option.required ? (
                <span className="ml-2 text-caption font-medium text-danger">Zorunlu</span>
              ) : (
                <span className="ml-2 text-caption font-normal text-muted-foreground">
                  İsteğe bağlı
                </span>
              )}
            </legend>
            <p id={descriptionId} className="mt-0.5 text-caption text-muted-foreground">
              {multi ? 'Birden fazla seçebilirsiniz.' : 'Bir seçenek seçin.'}
            </p>

            <div className="mt-2 space-y-2">
              {option.values.map((value, index) => {
                const inputId = `secenek-${option.id}-${value.id}`;
                return (
                  <label
                    key={value.id}
                    htmlFor={inputId}
                    className="flex min-h-11 cursor-pointer items-center gap-3 rounded-sm border border-input bg-card px-3 py-2.5 text-body hover:border-brand-300 has-checked:border-ring has-checked:bg-accent"
                  >
                    <input
                      id={inputId}
                      type={multi ? 'checkbox' : 'radio'}
                      name={groupName}
                      value={value.id}
                      aria-describedby={descriptionId}
                      defaultChecked={!multi && option.required && index === 0}
                      className="size-4 shrink-0 accent-primary"
                    />
                    <span className="flex-1">{value.name}</span>
                    <Money kurus={value.price_delta} size="sm" signed />
                  </label>
                );
              })}
            </div>
          </fieldset>
        );
      })}
    </div>
  );
}
