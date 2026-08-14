'use client';

import * as React from 'react';
import { Select as SelectPrimitive } from 'radix-ui';

import { cn } from '@/lib/utils';
import { ChevronDownIcon, CheckIcon, ChevronUpIcon } from 'lucide-react';

function Select({ ...props }: React.ComponentProps<typeof SelectPrimitive.Root>) {
  return <SelectPrimitive.Root data-slot="select" {...props} />;
}

function SelectGroup({ className, ...props }: React.ComponentProps<typeof SelectPrimitive.Group>) {
  return (
    <SelectPrimitive.Group
      data-slot="select-group"
      className={cn('scroll-my-1 p-1', className)}
      {...props}
    />
  );
}

function SelectValue({ ...props }: React.ComponentProps<typeof SelectPrimitive.Value>) {
  return <SelectPrimitive.Value data-slot="select-value" {...props} />;
}

/**
 * Tetikleyici bir FORM ALANI'dır: yüksekliği, yarıçapı, kenarlığı ve odak
 * halkası `Input` ile aynı olmak zorunda — yan yana duran iki alandan birinin
 * 32, diğerinin 44 px olması formu bozuk gösteriyordu.
 *
 * `w-fit` yerine `w-full`: alanın genişliği seçili metnin uzunluğuna göre
 * değişince form her seçimde yeniden yerleşiyor.
 */
function SelectTrigger({
  className,
  size = 'default',
  children,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Trigger> & {
  size?: 'sm' | 'default';
}) {
  return (
    <SelectPrimitive.Trigger
      data-slot="select-trigger"
      data-size={size}
      className={cn(
        'flex w-full items-center justify-between gap-2 rounded-sm border border-input bg-card px-3 py-2 text-body-lg whitespace-nowrap text-foreground md:text-body',
        'transition-colors duration-(--duration-fast) outline-none select-none',
        'data-[size=default]:h-11 data-[size=sm]:h-9',
        'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
        'disabled:cursor-not-allowed disabled:bg-muted disabled:text-muted-foreground',
        'aria-invalid:border-danger aria-invalid:bg-danger-surface',
        'data-placeholder:text-placeholder',
        '*:data-[slot=select-value]:line-clamp-1 *:data-[slot=select-value]:flex *:data-[slot=select-value]:items-center *:data-[slot=select-value]:gap-2',
        "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-5",
        className,
      )}
      {...props}
    >
      {children}
      <SelectPrimitive.Icon asChild>
        <ChevronDownIcon
          strokeWidth={1.75}
          className="pointer-events-none size-5 text-muted-foreground"
        />
      </SelectPrimitive.Icon>
    </SelectPrimitive.Trigger>
  );
}

/**
 * Açılır katman `--surface-2` üstünde ve `shadow-overlay` ile yükseltiliyor.
 * Koyu temada gölge görünmediği için ayrım yüzeyin AÇIKLIĞINDAN geliyor
 * (`--popover` zeminden iki adım açık) — bu yüzden koyu temada gölge kapalı.
 */
function SelectContent({
  className,
  children,
  position = 'item-aligned',
  align = 'center',
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Content>) {
  return (
    <SelectPrimitive.Portal>
      <SelectPrimitive.Content
        data-slot="select-content"
        data-align-trigger={position === 'item-aligned'}
        className={cn(
          'relative z-50 max-h-(--radix-select-content-available-height) min-w-40 origin-(--radix-select-content-transform-origin) overflow-x-hidden overflow-y-auto',
          'rounded-md border border-border bg-popover text-popover-foreground shadow-overlay dark:shadow-none',
          'duration-(--duration-fast) data-[align-trigger=true]:animate-none',
          'data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2',
          'data-open:animate-in data-open:fade-in-0 data-closed:animate-out data-closed:fade-out-0',
          position === 'popper' &&
            'data-[side=bottom]:translate-y-1 data-[side=left]:-translate-x-1 data-[side=right]:translate-x-1 data-[side=top]:-translate-y-1',
          className,
        )}
        position={position}
        align={align}
        {...props}
      >
        <SelectScrollUpButton />
        <SelectPrimitive.Viewport
          data-position={position}
          className="data-[position=popper]:h-(--radix-select-trigger-height) data-[position=popper]:w-full data-[position=popper]:min-w-(--radix-select-trigger-width)"
        >
          {children}
        </SelectPrimitive.Viewport>
        <SelectScrollDownButton />
      </SelectPrimitive.Content>
    </SelectPrimitive.Portal>
  );
}

function SelectLabel({ className, ...props }: React.ComponentProps<typeof SelectPrimitive.Label>) {
  return (
    <SelectPrimitive.Label
      data-slot="select-label"
      className={cn('px-2 py-1.5 text-overline text-muted-foreground', className)}
      {...props}
    />
  );
}

/** Satır yüksekliği 40 px: listede parmakla seçim yapılabilmesi için. */
function SelectItem({
  className,
  children,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Item>) {
  return (
    <SelectPrimitive.Item
      data-slot="select-item"
      className={cn(
        'relative flex min-h-10 w-full cursor-default items-center gap-2 rounded-xs py-1.5 pr-9 pl-2 text-body outline-hidden select-none',
        'focus:bg-accent focus:text-accent-foreground',
        'data-disabled:pointer-events-none data-disabled:text-muted-foreground',
        "[&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-5",
        '*:[span]:last:flex *:[span]:last:items-center *:[span]:last:gap-2',
        className,
      )}
      {...props}
    >
      <span className="pointer-events-none absolute right-2 flex size-5 items-center justify-center">
        <SelectPrimitive.ItemIndicator>
          <CheckIcon strokeWidth={1.75} className="pointer-events-none" />
        </SelectPrimitive.ItemIndicator>
      </span>
      <SelectPrimitive.ItemText>{children}</SelectPrimitive.ItemText>
    </SelectPrimitive.Item>
  );
}

function SelectSeparator({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Separator>) {
  return (
    <SelectPrimitive.Separator
      data-slot="select-separator"
      className={cn('pointer-events-none -mx-1 my-1 h-px bg-border', className)}
      {...props}
    />
  );
}

function SelectScrollUpButton({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.ScrollUpButton>) {
  return (
    <SelectPrimitive.ScrollUpButton
      data-slot="select-scroll-up-button"
      className={cn(
        'z-10 flex cursor-default items-center justify-center bg-popover py-1',
        className,
      )}
      {...props}
    >
      <ChevronUpIcon strokeWidth={1.75} className="size-4" />
    </SelectPrimitive.ScrollUpButton>
  );
}

function SelectScrollDownButton({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.ScrollDownButton>) {
  return (
    <SelectPrimitive.ScrollDownButton
      data-slot="select-scroll-down-button"
      className={cn(
        'z-10 flex cursor-default items-center justify-center bg-popover py-1',
        className,
      )}
      {...props}
    >
      <ChevronDownIcon strokeWidth={1.75} className="size-4" />
    </SelectPrimitive.ScrollDownButton>
  );
}

export {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectScrollDownButton,
  SelectScrollUpButton,
  SelectSeparator,
  SelectTrigger,
  SelectValue,
};
