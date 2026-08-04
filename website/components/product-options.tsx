import { formatPriceDelta } from '@/lib/format';
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
            <legend className="text-sm font-semibold text-neutral-900">
              {option.name}
              {option.required ? (
                <span className="ml-2 text-xs font-medium text-danger">Zorunlu</span>
              ) : (
                <span className="ml-2 text-xs font-normal text-neutral-600">İsteğe bağlı</span>
              )}
            </legend>
            <p id={descriptionId} className="mt-0.5 text-xs text-neutral-600">
              {multi ? 'Birden fazla seçebilirsiniz.' : 'Bir seçenek seçin.'}
            </p>

            <div className="mt-2 space-y-2">
              {option.values.map((value, index) => {
                const inputId = `secenek-${option.id}-${value.id}`;
                const delta = formatPriceDelta(value.price_delta);
                return (
                  <label
                    key={value.id}
                    htmlFor={inputId}
                    className="flex cursor-pointer items-center gap-3 rounded-lg border border-neutral-200 bg-neutral-0 px-3 py-2.5 text-sm hover:border-brand-300 has-[:checked]:border-brand-600 has-[:checked]:bg-brand-50"
                  >
                    <input
                      id={inputId}
                      type={multi ? 'checkbox' : 'radio'}
                      name={groupName}
                      value={value.id}
                      aria-describedby={descriptionId}
                      defaultChecked={!multi && option.required && index === 0}
                      className="h-4 w-4 shrink-0 accent-brand-600"
                    />
                    <span className="flex-1 text-neutral-900">{value.name}</span>
                    {delta && <span className="text-neutral-600">{delta}</span>}
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
