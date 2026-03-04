# React Frontend Structure & Standards

This document outlines the project structure, naming conventions, and best practices for the GDTMS Courier Mobile React frontend.

## Project Structure

```
resources/js/
├── app.tsx                    # Main application entry point
├── bootstrap.ts               # Axios configuration
├── components/
│   ├── ui/                    # shadcn UI components
│   │   ├── button.tsx
│   │   ├── input.tsx
│   │   └── ...
│   └── common/                # Reusable application components
│       ├── header.tsx
│       ├── sidebar.tsx
│       └── ...
├── hooks/                     # Custom React hooks
│   ├── use-auth.ts
│   ├── use-api.ts
│   └── ...
├── layouts/                   # Layout components
│   ├── app-layout.tsx
│   ├── auth-layout.tsx
│   └── ...
├── lib/                       # Utility libraries
│   └── cn.ts                  # Tailwind class merger
├── pages/                     # Inertia page components
│   ├── dashboard.tsx
│   ├── login.tsx
│   └── ...
├── types/                     # TypeScript type definitions
│   ├── index.ts
│   └── ...
└── utils/                     # Utility functions
    ├── api-client.ts
    └── helpers.ts
```

## Naming Conventions

### File Organization

- **kebab-case** for all filenames (e.g., `auth-layout.tsx`, `api-client.ts`)
- One component per file (exception: small utility exports)
- Export names can be PascalCase (React standard)

### Examples

❌ **Incorrect:**
```
Button.tsx        (PascalCase file)
AuthLayout.tsx    (PascalCase file)
ApiClient.ts      (PascalCase file)
```

✅ **Correct:**
```
button.tsx        (kebab-case file)
auth-layout.tsx   (kebab-case file)
api-client.ts     (kebab-case file)
```

### Import Statements

```typescript
// ✅ Correct
import { Button } from '@/components/ui/button';
import AppLayout from '@/layouts/app-layout';
import apiClient from '@/utils/api-client';
import { formatCurrency } from '@/utils/helpers';

// ❌ Incorrect
import { Button } from '@/components/ui/Button';
import AppLayout from '@/layouts/AppLayout';
import apiClient from '@/utils/ApiClient';
```

## Component Patterns

### Functional Components

```typescript
import React from 'react';

interface ComponentProps {
  title: string;
  onAction?: () => void;
}

/**
 * Component Description
 * Explain what this component does
 */
export default function MyComponent({ title, onAction }: ComponentProps) {
  return <div>{title}</div>;
}
```

### Custom Hooks

```typescript
// resources/js/hooks/use-custom-hook.ts
import { useState } from 'react';

export function useCustomHook() {
  const [value, setValue] = useState('');

  return { value, setValue };
}
```

## Type Definitions

Keep types organized in `resources/js/types/`:

```typescript
// resources/js/types/index.ts
export interface User {
  id: number;
  name: string;
  email: string;
}

export interface Delivery {
  id: number;
  status: 'pending' | 'in-progress' | 'completed';
  address: string;
}
```

## Utility Functions

Place common functions in `resources/js/utils/`:

```typescript
// resources/js/utils/helpers.ts
export const formatCurrency = (value: number) => {
  // Implementation
};

export const isEmpty = (value: any) => {
  // Implementation
};
```

## Styling

- Use **Tailwind CSS** for styling
- Use **shadcn** components from `@/components/ui/`
- Use the `cn` utility for class merging:

```typescript
import { cn } from '@/lib/cn';

<button className={cn('px-4 py-2', disabled && 'opacity-50')}>
  Click me
</button>
```

## Development Standards

### ESLint

Run linting to check for code quality issues:

```bash
npm run lint
```

### Prettier

Format code for consistency:

```bash
npm run format
```

### TypeScript

All files should use proper type annotations:

```typescript
interface Props {
  title: string;
  count: number;
  isActive?: boolean;
}

export default function Component({ title, count, isActive = false }: Props) {
  // Implementation
}
```

## API Communication

Use the centralized API client:

```typescript
// resources/js/utils/api-client.ts
import apiClient from '@/utils/api-client';

const response = await apiClient.get('/deliveries');
const result = await apiClient.post('/deliveries', { data });
```

## Inertia Integration

For page components, use Inertia's helpers:

```typescript
import { Head } from '@inertiajs/react';
import { router } from '@inertiajs/react';

export default function Page() {
  return (
    <>
      <Head title="Page Title" />
      {/* Your content */}
    </>
  );
}
```

## Best Practices

1. **Keep components small and focused** - Each component should do one thing well
2. **Use TypeScript** - Ensure type safety across the application
3. **Document components** - Add JSDoc comments explaining component purpose
4. **Avoid prop drilling** - Use context or layout patterns for shared state
5. **Use absolute imports** - Leverage path aliases defined in `tsconfig.json`
6. **Optimize images** - Use appropriate formats and sizes
7. **Handle errors gracefully** - Implement proper error boundaries and messages
8. **Write tests** - Test components and utilities (future improvement)

## Configuration Files

### vite.config.js

Defines path aliases:

```javascript
alias: {
  '@': path.resolve(__dirname, './resources/js'),
  '@components': path.resolve(__dirname, './resources/js/components'),
  '@pages': path.resolve(__dirname, './resources/js/pages'),
  '@layouts': path.resolve(__dirname, './resources/js/layouts'),
  '@hooks': path.resolve(__dirname, './resources/js/hooks'),
  '@utils': path.resolve(__dirname, './resources/js/utils'),
  '@types': path.resolve(__dirname, './resources/js/types'),
}
```

### tsconfig.json

Configured to match Vite aliases and enable strict TypeScript checking.

### .eslintrc.json

Enforces code quality and React best practices.

### .prettierrc

Ensures consistent code formatting.

---

**Last Updated:** 2026-03-04
