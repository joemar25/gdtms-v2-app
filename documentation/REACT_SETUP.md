# GDTMS Courier Mobile - React + Inertia Migration Guide

## Overview

This codebase has been successfully transformed from a Laravel Blade-based frontend to a modern **React + Inertia + TypeScript + shadcn UI** stack.

## What's Been Done

### 1. ✅ Framework Migration

- **Removed**: Laravel Blade templates
- **Added**: Inertia.js (React adapter)
- **Stack**: React 19 + TypeScript + Tailwind CSS + shadcn UI

### 2. ✅ File Structure

All files follow **kebab-case lowercase** naming convention:

- ✅ `button.tsx` (not Button.tsx)
- ✅ `app-layout.tsx` (not AppLayout.tsx)
- ✅ `auth-layout.tsx` (not AuthLayout.tsx)
- ✅ `api-client.ts` (not ApiClient.ts)

### 3. ✅ Project Structure

```md
resources/js/
├── app.tsx # Inertia app entry
├── bootstrap.ts # HTTP client setup
├── components/
│ ├── ui/ # shadcn components
│ └── common/ # Reusable app components
├── hooks/ # Custom React hooks
├── layouts/ # Page layouts
├── lib/ # Utilities (cn, etc)
├── pages/ # Inertia pages
├── types/ # TypeScript definitions
└── utils/ # Helper functions
```

### 4. ✅ Components Ready

- **UI Components**: Button, Input, Card (with subcomponents)
- **Layouts**: AppLayout (authenticated), AuthLayout (public)
- **Pages**: Dashboard, Login, Register, Deliveries, Dispatch, Profile, Wallet
- **Hooks**: useAuth(), useApi()

### 5. ✅ Development Tools

- **ESLint**: Code quality checking
- **Prettier**: Code formatting
- **TypeScript**: Full type safety
- **Vite**: Lightning-fast builds

## Getting Started

### Installation

```bash
# Install dependencies
npm install
composer install

# Setup environment
cp .env.example .env
php artisan key:generate
```

### Development

```bash
# Start development server (runs all services concurrently)
composer run dev

# Or run services individually:
php artisan serve                  # Laravel server
php artisan queue:listen           # Queue worker
npm run dev                        # Vite dev server
```

### Building

```bash
# Production build
npm run build

# Code quality checks
npm run lint         # Run ESLint
npm run format       # Format with Prettier
```

## File Naming Conventions

### Components

```typescript
// ✅ CORRECT
// File: resources/js/components/ui/button.tsx
export default function Button() {}

// File: resources/js/layouts/app-layout.tsx
export default function AppLayout() {}

// ❌ INCORRECT
// DO NOT use PascalCase for filenames
// Button.tsx, AppLayout.tsx, etc.
```

### Imports

```typescript
// ✅ Correct
import { Button } from '@/components/ui/button';
import AppLayout from '@/layouts/app-layout';
import apiClient from '@/utils/api-client';
import { useAuth } from '@/hooks';

// ❌ Incorrect
import { Button } from '@/components/ui/Button';
import AppLayout from '@/layouts/AppLayout';
```

## Project Configuration Files

### `tsconfig.json`

Configured with path aliases for clean imports:

```typescript
'@/*': ['resources/js/*']
'@components/*': ['resources/js/components/*']
'@pages/*': ['resources/js/pages/*']
'@layouts/*': ['resources/js/layouts/*']
'@hooks/*': ['resources/js/hooks/*']
'@utils/*': ['resources/js/utils/*']
'@types/*': ['resources/js/types/*']
```

### `vite.config.js`

- React plugin enabled
- Tailwind v4 support
- Same path aliases as TypeScript config
- Optimal build performance

### `.eslintrc.json`

- React best practices enforced
- TypeScript support
- No console.log warnings in production
- React Hooks rules enabled

### `.prettierrc`

- 2-space indentation
- Single quotes
- Trailing commas (ES5)
- 80-character line width

## Creating New Components

### UI Component (shadcn style)

```typescript
// resources/js/components/ui/my-component.tsx
import React from 'react';
import { cn } from '@/lib/cn';

export interface MyComponentProps {
  className?: string;
}

export function MyComponent({ className }: MyComponentProps) {
  return <div className={cn('base-styles', className)}>Content</div>;
}
```

### Page Component (Inertia)

```typescript
// resources/js/pages/my-page.tsx
import { Head } from '@inertiajs/react';
import AppLayout from '@/layouts/app-layout';

export default function MyPage() {
  return (
    <AppLayout>
      <Head title="My Page" />
      {/* Your content */}
    </AppLayout>
  );
}
```

### Custom Hook

```typescript
// resources/js/hooks/use-my-hook.ts
import { useState } from 'react';

export function useMyHook() {
    const [state, setState] = useState(false);
    return { state, setState };
}
```

## API Integration

### Using the API Client

```typescript
import apiClient from '@/utils/api-client';

// Inside a component or hook
const response = await apiClient.get('/api/deliveries');
const result = await apiClient.post('/api/deliveries', { data });
```

### Using the useApi Hook

```typescript
import { useApi } from '@/hooks';

export function MyComponent() {
  const { get, loading, error } = useApi();

  const fetchData = async () => {
    const data = await get('/api/deliveries');
  };

  return <div>{loading ? 'Loading...' : 'Done'}</div>;
}
```

## Inertia Routes

Routes are defined in `routes/web.php`:

```php
// Protected route with data
Route::get('/dashboard', function () {
    return Inertia::render('dashboard', [
        'user' => auth()->user(),
    ]);
})->middleware('auth');

// Guest route
Route::get('/login', function () {
    return Inertia::render('login');
})->middleware('guest');
```

## Frontend Routes

Navigation is handled via `Link` component from Inertia:

```typescript
import { Link } from '@inertiajs/react';

<Link href="/dashboard">Go to Dashboard</Link>
```

## Tailwind CSS

Using Tailwind v4 with improved performance. Classes available:

```html
<!-- Spacing -->
<div className="p-4 m-2 gap-3"></div>

<!-- Colors -->
<div className="bg-blue-500 text-white border-gray-300"></div>

<!-- Responsive -->
<div className="md:grid-cols-2 lg:grid-cols-3"></div>

<!-- Utilities -->
<div className="flex items-center justify-between rounded-lg shadow"></div>
```

## shadcn UI Components

Pre-installed and ready to use:

- Button
- Input
- Card (with Header, Title, Description, Content, Footer)
- (More can be added as needed)

Usage:

```typescript
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';

<Button>Click me</Button>
<Input placeholder="Enter text" />
```

## TypeScript Types

Organize types in `resources/js/types/`:

```typescript
// resources/js/types/user.ts
export interface User {
    id: number;
    name: string;
    email: string;
}

// resources/js/types/index.ts
export type { User } from './user';
```

Usage:

```typescript
import type { User } from '@/types';

interface PageProps {
    user: User;
}
```

## Routing Conventions

This project uses **Ziggy** to expose all named Laravel routes to the frontend. Never hardcode URL strings — always use `route()`.

### Backend (Laravel) — `Inertia::render()` + `to_route()`

```php
// ✅ CORRECT — Inertia page render (page name = kebab-case path under resources/js/pages/)
return Inertia::render('login');
return Inertia::render('dashboard', ['courier' => $courier]);
return Inertia::render('deliveries/detail', ['delivery' => $delivery]);

// ✅ CORRECT — named route redirect (no hardcoded strings)
return to_route('dashboard');
return to_route('login')->with('message', 'Logged out.');
return to_route('wallet.detail', ['id' => $newId]);

// ❌ INCORRECT
return view('auth.login');          // Blade view — never use for Inertia pages
return redirect('/login');          // hardcoded URL string
return redirect("/wallet/{$id}");   // interpolated URL string
```

### Frontend (React) — `route()` + `useForm`

The `route()` helper is available **globally** (no import needed). It mirrors Laravel's `route()` blade helper exactly, powered by Ziggy.

```typescript
// ✅ CORRECT — use route() for all URLs
post(route('login'));
router.visit(route('dashboard'));
<Link href={route('profile')}>Profile</Link>
<Link href={route('logout')} method="post" as="button">Logout</Link>

// ✅ CORRECT — use useForm for all form submissions (handles errors, loading, CSRF)
const { data, setData, post, processing, errors } = useForm({
    phone_number: '',
    password: '',
});

const submit = (e: React.FormEvent) => {
    e.preventDefault();
    post(route('login'));
};

// ✅ CORRECT — PATCH/PUT with files: use transform() + post() with forceFormData
const { data, setData, post, transform } = useForm({ name: '', _method: '' });

const submit = (e: React.FormEvent) => {
    e.preventDefault();
    transform((d) => ({ ...d, _method: 'PATCH' }));
    post(route('profile.update'), { forceFormData: true });
};

// ❌ INCORRECT
router.post('/login', data);                    // hardcoded URL
fetch('/api/profile', { method: 'PATCH' });     // raw fetch — use useApi hook
const [loading, setLoading] = useState(false);  // manual loading state — use useForm's processing
const [errors, setErrors] = useState({});       // manual errors — use useForm's errors
```

> **Rule**: if the destination has a named Laravel route, use `route('name')`. If you need to navigate programmatically, use `router.visit(route('name'))`.

## Common Issues & Solutions

### Import not found

- Double-check kebab-case filenames
- Use path aliases (@/components, @/utils, etc.)
- Verify extension (.tsx, .ts) matches

### Component not rendering

- Ensure page component is default export
- Check Inertia::render() name matches file name
- Verify props are passed correctly

### Build errors

- Clear node_modules and reinstall: `rm -rf node_modules && npm install`
- Clear cache: `npm run build -- --force`
- Check TypeScript errors: All should be resolved

### Type errors

- Use `import type` for type-only imports
- Import interfaces from @/types
- Add proper type annotations to props

## Performance Tips

1. **Code Splitting**: Inertia automatically splits pages
2. **Image Optimization**: Use responsive sizes
3. **Lazy Loading**: Use React.lazy for non-critical components
4. **Component Memoization**: Use React.memo for expensive renders
5. **API Caching**: Implement caching in useApi hook

## Testing

(To be implemented)

## Documentation

- [FRONTEND_STRUCTURE.md](./FRONTEND_STRUCTURE.md) - Detailed structure guide
- [Inertia.js Docs](https://inertiajs.com/)
- [React Docs](https://react.dev/)
- [shadcn/ui](https://ui.shadcn.com/)
- [Tailwind CSS](https://tailwindcss.com/)

## Next Steps

1. **Implement Authentication Routes**
    - POST /login
    - POST /register
    - POST /logout

2. **Add More UI Components**
    - Dialog/Modal
    - Dropdown Menu
    - Tabs
    - Toast Notifications

3. **Implement Features**
    - Delivery management
    - Dispatch system
    - Wallet/Payments
    - Real-time updates (WebSocket)

4. **Setup Testing**
    - Vitest for unit tests
    - React Testing Library for components
    - MSW for API mocking

5. **Documentation**
    - API documentation
    - Component storybook
    - Architecture decision records

## Support

For issues or questions:

1. Check the FRONTEND_STRUCTURE.md
2. Review component examples
3. Check Inertia/React documentation
4. Consult TypeScript error messages

---

**Last Updated**: March 4, 2026
**Version**: 1.0.0
**React Version**: 19.2.4
**Inertia Version**: 2.0.21
**TypeScript Version**: 5.9.3
