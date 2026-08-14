import * as React from 'react';
import { cva } from 'class-variance-authority';
import { NavigationMenu as NavigationMenuPrimitive } from 'radix-ui';

import { cn } from '@/lib/utils';
import { ChevronDownIcon } from 'lucide-react';

function NavigationMenu({
  className,
  children,
  viewport = true,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Root> & {
  viewport?: boolean;
}) {
  return (
    <NavigationMenuPrimitive.Root
      data-slot="navigation-menu"
      data-viewport={viewport}
      className={cn(
        'group/navigation-menu relative flex max-w-max flex-1 items-center justify-center',
        className,
      )}
      {...props}
    >
      {children}
      {viewport && <NavigationMenuViewport />}
    </NavigationMenuPrimitive.Root>
  );
}

function NavigationMenuList({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.List>) {
  return (
    <NavigationMenuPrimitive.List
      data-slot="navigation-menu-list"
      className={cn('group flex flex-1 list-none items-center justify-center gap-0.5', className)}
      {...props}
    />
  );
}

function NavigationMenuItem({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Item>) {
  return (
    <NavigationMenuPrimitive.Item
      data-slot="navigation-menu-item"
      className={cn('relative', className)}
      {...props}
    />
  );
}

/**
 * Gezinme öğesi 44 px yüksekliğinde: başlıktaki bağlantılar da dokunma
 * hedefidir ve 36 px'lik satırlar mobil menüde ıskalanıyordu.
 *
 * Açık menünün zemini `--accent` (marka yüzeyi), sessiz gri değil: hangi
 * bölümde olduğunu söyleyen tek işaret bu ve nötr griyle hover'dan
 * ayırt edilemiyordu.
 */
const navigationMenuTriggerStyle = cva(
  [
    'group/navigation-menu-trigger inline-flex min-h-11 w-max items-center justify-center gap-1 rounded-sm px-3 text-label text-foreground',
    'transition-colors duration-(--duration-fast) outline-none hover:bg-muted',
    'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
    'disabled:pointer-events-none disabled:text-muted-foreground',
    'data-open:bg-accent data-open:text-accent-foreground data-popup-open:bg-accent data-popup-open:text-accent-foreground',
  ].join(' '),
);

function NavigationMenuTrigger({
  className,
  children,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Trigger>) {
  return (
    <NavigationMenuPrimitive.Trigger
      data-slot="navigation-menu-trigger"
      className={cn(navigationMenuTriggerStyle(), 'group', className)}
      {...props}
    >
      {children}
      <ChevronDownIcon
        aria-hidden="true"
        strokeWidth={1.75}
        className="relative top-px ml-0.5 size-4 transition-transform duration-(--duration-base) ease-(--ease-out-soft) group-data-popup-open/navigation-menu-trigger:rotate-180 group-data-open/navigation-menu-trigger:rotate-180"
      />
    </NavigationMenuPrimitive.Trigger>
  );
}

function NavigationMenuContent({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Content>) {
  return (
    <NavigationMenuPrimitive.Content
      data-slot="navigation-menu-content"
      className={cn(
        'top-0 left-0 w-full p-2 ease-(--ease-out-soft)',
        'group-data-[viewport=false]/navigation-menu:top-full group-data-[viewport=false]/navigation-menu:mt-2 group-data-[viewport=false]/navigation-menu:overflow-hidden group-data-[viewport=false]/navigation-menu:rounded-md group-data-[viewport=false]/navigation-menu:border group-data-[viewport=false]/navigation-menu:border-border group-data-[viewport=false]/navigation-menu:bg-popover group-data-[viewport=false]/navigation-menu:text-popover-foreground group-data-[viewport=false]/navigation-menu:shadow-overlay group-data-[viewport=false]/navigation-menu:duration-(--duration-base) dark:group-data-[viewport=false]/navigation-menu:shadow-none',
        'data-[motion=from-end]:slide-in-from-right-32 data-[motion=from-start]:slide-in-from-left-32 data-[motion=to-end]:slide-out-to-right-32 data-[motion=to-start]:slide-out-to-left-32',
        'data-[motion^=from-]:animate-in data-[motion^=from-]:fade-in data-[motion^=to-]:animate-out data-[motion^=to-]:fade-out',
        'md:absolute md:w-auto',
        'group-data-[viewport=false]/navigation-menu:data-open:animate-in group-data-[viewport=false]/navigation-menu:data-open:fade-in-0 group-data-[viewport=false]/navigation-menu:data-closed:animate-out group-data-[viewport=false]/navigation-menu:data-closed:fade-out-0',
        className,
      )}
      {...props}
    />
  );
}

function NavigationMenuViewport({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Viewport>) {
  return (
    <div className="absolute top-full left-0 isolate z-50 flex justify-center">
      <NavigationMenuPrimitive.Viewport
        data-slot="navigation-menu-viewport"
        className={cn(
          'origin-top-center relative mt-2 h-(--radix-navigation-menu-viewport-height) w-full overflow-hidden rounded-md border border-border bg-popover text-popover-foreground shadow-overlay duration-(--duration-fast) md:w-(--radix-navigation-menu-viewport-width) dark:shadow-none',
          'data-open:animate-in data-open:fade-in-0 data-closed:animate-out data-closed:fade-out-0',
          className,
        )}
        {...props}
      />
    </div>
  );
}

function NavigationMenuLink({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Link>) {
  return (
    <NavigationMenuPrimitive.Link
      data-slot="navigation-menu-link"
      className={cn(
        'flex min-h-11 items-center gap-2 rounded-xs p-2.5 text-body text-foreground',
        'transition-colors duration-(--duration-fast) outline-none hover:bg-muted',
        'focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background',
        'data-active:bg-accent data-active:text-accent-foreground',
        "[&_svg:not([class*='size-'])]:size-5",
        className,
      )}
      {...props}
    />
  );
}

function NavigationMenuIndicator({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Indicator>) {
  return (
    <NavigationMenuPrimitive.Indicator
      data-slot="navigation-menu-indicator"
      className={cn(
        'top-full z-1 flex h-2 items-end justify-center overflow-hidden data-[state=hidden]:animate-out data-[state=hidden]:fade-out data-[state=visible]:animate-in data-[state=visible]:fade-in',
        className,
      )}
      {...props}
    >
      <div className="relative top-[60%] size-2 rotate-45 rounded-tl-xs border-t border-l border-border bg-popover" />
    </NavigationMenuPrimitive.Indicator>
  );
}

export {
  NavigationMenu,
  NavigationMenuList,
  NavigationMenuItem,
  NavigationMenuContent,
  NavigationMenuTrigger,
  NavigationMenuLink,
  NavigationMenuIndicator,
  NavigationMenuViewport,
  navigationMenuTriggerStyle,
};
