# API Implementation: httpOnly Cookie Support

## Goal
Migrate from Authorization headers to httpOnly cookies for XSS protection, while maintaining backward compatibility.

## Tasks

### Phase 1: Rails API
- [x] Create Warden JWT cookie strategy initializer
- [x] Verify the initializer loads correctly
- [x] Run tests (1551 runs, 0 failures, 0 errors)
- [x] Run linting (no offenses detected)
- [x] Run security check (no warnings found)
- [ ] Commit changes

### Testing & Deployment
- [ ] Test Rails API with cookie (manual testing required)
- [ ] Test Rails API with Authorization header (manual testing required)
- [ ] Test priority (cookie over header) (manual testing required)
- [ ] Deploy Rails API

## Notes
- Backward compatible - both cookie AND header work during migration
- Cookie checked FIRST, then falls back to Authorization header
- No changes to JWT validation logic
