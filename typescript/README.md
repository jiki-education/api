# @jiki/api-types

Auto-generated TypeScript types from Jiki Rails API schemas.

**⚠️ DO NOT EDIT FILES IN THIS PACKAGE MANUALLY**

All types are generated from Rails model schemas and constants.

## Usage

### In code-videos

```typescript
import type { TalkingHeadInputs, MergeVideosInputs } from '@jiki/api-types';
```

### In front-end

```typescript
import type { User, Course, Lesson } from '@jiki/api-types';
```

## Setup

After cloning this repo, generate the TypeScript types:

```bash
bundle exec rake typescript:generate
```

This will install dependencies and build the types in `typescript/dist/`.

## Regenerating Types

Whenever Rails schemas change:

```bash
bundle exec rake typescript:generate
```

## Publishing to npm (optional)

```bash
cd typescript
npm version patch  # or minor/major
npm publish
```
