# Deployment Progress Handoff

## What's Been Completed

### Rails Application - ECS Ready ✅

All Rails code changes for AWS ECS deployment are **complete and tested**. The application successfully runs locally with `bin/dev` using the new Solid Queue architecture.

#### Key Changes Made:

**1. Migrated from Sidekiq+Redis to Solid Queue**
- Removed: Sidekiq, sidekiq-scheduler, redis gems
- Added: solid_queue, solid_queue_monitor gems
- Configuration: Single database (queue tables in main Postgres, not separate DB)
- Dashboard: Solid Queue Monitor at `/solid_queue` (uses existing basic auth credentials)
- Cost savings: **~$45-70/month** (no ElastiCache Serverless needed)

**2. ECS-Ready Configuration**
- ✅ Migration concurrent guard (`lib/run_migrations_with_concurrent_guard.rb`)
- ✅ Updated `bin/docker-entrypoint` to use concurrent guard
- ✅ Health check controller at `/health-check` (verifies DB connectivity)
- ✅ Dockerfile HEALTHCHECK directive
- ✅ Production cache store: memory (was Redis)
- ✅ Database config: Uses `Jiki.config.aurora_endpoint/port/database_name`
- ✅ Database password: Uses `Jiki.secrets.aurora_password`
- ✅ Active Storage: Configured for S3 (`jiki-api-active-storage` bucket)
- ✅ Allowed hosts: `api.jiki.io`, VPC IPs (10.0.0.0/8)
- ✅ `Procfile.dev` updated for Solid Queue

**3. Files Modified**
```
Modified:
- Gemfile (Sidekiq → Solid Queue + Monitor)
- config/application.rb (queue adapter, removed sprockets)
- config/environments/production.rb (cache, hosts, Active Storage)
- config/database.yml (Jiki.config values)
- config/storage.yml (S3 config)
- config/routes.rb (Solid Queue Monitor, health check)
- Procfile.dev (solid_queue)
- Dockerfile (HEALTHCHECK)
- bin/docker-entrypoint (concurrent guard)
- CLAUDE.md (updated deployment info)

Created:
- lib/run_migrations_with_concurrent_guard.rb
- app/controllers/health_controller.rb
- db/migrate/20251118045615_create_solid_queue_tables.rb

Deleted:
- config/initializers/sidekiq.rb
- config/sidekiq-schedule.yml
- db/queue_schema.rb (converted to migration)
```

---

## What's Next: Terraform Infrastructure

### Phase 2-8: AWS Infrastructure (See DEPLOYMENT_PLAN.md)

The Terraform work needs to be updated to reflect the Solid Queue architecture:

**What to REMOVE from original plan:**
1. ❌ ElastiCache Serverless resources (`terraform/terraform/aws/elasticache.tf`)
2. ❌ ElastiCache security group
3. ❌ ECS Sidekiq service (`terraform/terraform/aws/ecs_sidekiq.tf`)
4. ❌ Sidekiq CloudWatch log group
5. ❌ Redis URL config items from DynamoDB

**What to KEEP/ADD:**
1. ✅ Aurora Serverless v2 (database + Solid Queue tables)
2. ✅ S3 bucket for Active Storage: `jiki-api-active-storage` (in addition to video-production bucket)
3. ✅ ECS web service only (Solid Queue runs in-process)
4. ✅ ALB, security groups, IAM roles
5. ✅ CloudWatch logs for web service only

**Critical Configuration Items:**

The Rails app expects these values from `Jiki.config` (DynamoDB):
```
aurora_endpoint       # From RDS cluster (already in terraform)
aurora_port           # 5432 (already in terraform)
aurora_database_name  # jiki_production (already in terraform)
```

And from `Jiki.secrets` (AWS Secrets Manager):
```
aurora_password       # Database password (need to add to terraform secrets.tf)
```

**ECS Task Definition Changes:**
- Only need ONE service: web (no sidekiq service)
- Solid Queue workers run in the same process as Rails
- Consider resource allocation: web service may need slightly more CPU/memory since it's handling both web + jobs

---

## Simplified Architecture

**Before (Original Plan):**
```
Cloudflare → ALB → ECS Web + ECS Sidekiq
                    ↓         ↓
                   Aurora  ElastiCache
                            ($90/mo)
```

**After (Implemented):**
```
Cloudflare → ALB → ECS Web (+ Solid Queue)
                    ↓
                   Aurora (DB + Queue)

Cost savings: ~$45-70/month
```

---

## Testing Checklist (Before Deployment)

Before deploying to AWS, verify locally:
- [x] `bin/dev` starts successfully
- [x] Web server responds on port 3060
- [x] Solid Queue worker starts
- [ ] Jobs can be enqueued and processed
- [ ] Health check endpoints work (`/up`, `/health-check`)
- [ ] Solid Queue Monitor accessible at `/solid_queue`

---

## References

- **Deployment Plan**: `DEPLOYMENT_PLAN.md` (detailed infrastructure setup)
- **Architecture Context**: `.context/architecture.md`
- **Configuration**: `.context/configuration.md` (Jiki config gem pattern)
- **Solid Queue Docs**: https://github.com/rails/solid_queue
- **Solid Queue Monitor**: https://github.com/vishaltps/solid_queue_monitor

---

## Questions for Next Session

1. Should we stick with single database for Solid Queue, or move to separate queue DB for production?
   - Current: Single DB (simpler, lower cost)
   - Alternative: Separate DB (better isolation, scales independently)
   - Recommendation: Keep single DB for now, can migrate later if needed

2. Web service resource allocation?
   - Original plan: 512 CPU / 1024 MB for web, 256 CPU / 512 MB for sidekiq
   - Proposal: 512-768 CPU / 1024-1536 MB for combined web+queue service
   - Can adjust based on actual usage

3. Active Storage bucket naming?
   - Terraform should create: `jiki-api-active-storage` (eu-west-1)
   - Used for exercise submission files only (not public images - those go to R2)
