# Jiki API - Deployment Status

## Current State: Infrastructure Complete, Ready for Production

**Last Updated**: 2025-11-19
**Status**: ✅ All infrastructure deployed and production-ready
**Domain**: `api.jiki.io`
**Region**: `eu-west-1` (Ireland)

---

## Architecture Overview

### Current Production Setup

```
Internet → Cloudflare (HTTPS) → ALB (port 443) → ECS Tasks (port 3000)
                                                    ↓ Thruster → Puma (3001)
                                                    ↓
                                                  Aurora (0-1 ACU)
                                                    ↑
                                ECS Worker Tasks ──┘
                              (Solid Queue workers)
```

**Key Components**:
- **Web Service**: 1-4 tasks (512 CPU / 1024 MB) - Thruster + Puma
- **Worker Service**: 1 task (256 CPU / 512 MB) - Solid Queue
- **Database**: Aurora Serverless v2 PostgreSQL 16.6 (0-1 ACU, scales to zero)
- **Storage**: S3 (`jiki-active-storage`) + Cloudflare R2 (`assets`)
- **Config**: DynamoDB (`config` table) + AWS Secrets Manager
- **Cache**: Memory store (no Redis)
- **Jobs**: Solid Queue (database-backed, no Redis/Sidekiq)

**Monthly Cost**: ~$40-65 (startup configuration)

---

## Infrastructure Status

### ✅ Deployed (Terraform Branch: `add-workers-deployment-infrastructure`)

All infrastructure is created and configured:

#### Networking
- VPC: `10.1.0.0/16` with public subnets across multiple AZs
- Internet gateway and routing tables
- No NAT Gateway (cost optimization: saves $32/month)

#### Compute (ECS)
- **Cluster**: `jiki-production` with Container Insights
- **Web Service**: `jiki-api-web`
  - 512 CPU / 1024 MB memory
  - Auto-scaling: 1-4 tasks based on CPU
  - Port 3000 (Thruster → Puma 3001)
  - Health check: `/health-check` every 30s (Docker: 5s)
  - Grace period: 300s for migrations
  - **Lifecycle**: Ignores task_definition (GitHub Actions manages deployments)

- **Worker Service**: `jiki-api-solid-queue`
  - 256 CPU / 512 MB memory
  - 1 task (no auto-scaling currently)
  - Command: `bundle exec rake solid_queue:start`
  - **Lifecycle**: Ignores task_definition

#### Database
- **Aurora Serverless v2**: PostgreSQL 16.6
  - Min capacity: 0 ACU (scales to zero when idle)
  - Max capacity: 1 ACU (cost-optimized)
  - Endpoint: Stored in DynamoDB `config` table
  - Password: **"temporary-change-me-immediately"** (⚠️ needs rotation)
  - Backup retention: 10 days
  - Performance Insights: enabled
  - Single-AZ (for production: enable Multi-AZ)

#### Storage
- **S3**: `jiki-active-storage`
  - Public access: blocked
  - Versioning: enabled
  - Encryption: AES256
  - Lifecycle: 90-day version expiration

- **S3**: `jiki-video-production` (video generation)

- **Cloudflare R2**: `assets` bucket with CDN

#### Container Registry
- **ECR**: `jiki/api`
  - Image scanning: enabled
  - Lifecycle: Keep last 10 images (protects buildcache)

#### Load Balancer
- **ALB**: `jiki-api-alb`
  - HTTPS only (port 443) with Cloudflare Origin Certificate
  - Target group: port 3000, health check `/health-check`
  - SSL policy: TLS 1.3
  - Deletion protection: ⚠️ **disabled** (enable for production)

#### Security Groups
- **ALB**: 80, 443 from internet
- **ECS**: 3000 from ALB
- **RDS**: 5432 from ECS

#### IAM Roles
- **Task Execution Role**: ECR pull, CloudWatch logs, Secrets Manager
- **Task Role**: S3 Active Storage, DynamoDB config, Secrets Manager
- **GitHub Actions**: OIDC provider, ECR push, ECS deploy

#### Configuration
- **DynamoDB**: `config` table with 14+ items
  - Domain configuration
  - Database endpoints
  - Cloudflare R2 credentials
  - **⚠️ Stripe placeholders** (TODO: update before production)

- **Secrets Manager**: `config` secret
  - **⚠️ Needs population** with:
    - `secret_key_base`
    - `aurora_password`
    - `hmac_secret`
    - `jwt_secret`
    - API keys (Google, ElevenLabs, HeyGen, Stripe, etc.)

#### DNS & SSL
- **Cloudflare**: `api.jiki.io` → ALB (proxied)
- **Origin Certificate**: 15-year Cloudflare → ALB encryption
- **SSL Mode**: Full (strict), TLS 1.3 enabled

---

## Application Configuration

### Port Architecture

**Request Flow**:
```
ALB:443 → ECS:3000 → Thruster:3000 → Puma:3001 → Rails
```

**Key Settings**:
- `THRUSTER_HTTP_PORT=3000` - External port (ALB target)
- `TARGET_PORT=3001` - Thruster backend target
- `PUMA_PORT=3001` - Puma bind port
- `WEB_CONCURRENCY=2` - Puma workers
- `RAILS_MAX_THREADS=5` - Thread pool size

### Solid Queue Architecture

**Components**:
- **Gem**: `solid_queue` (database-backed jobs)
- **Monitor**: `/solid_queue` (Basic Auth protected)
- **Tables**: Created via migration in main database
- **Workers**: Separate ECS service (`jiki-api-solid-queue`)
- **Cost Savings**: ~$45-70/month (no ElastiCache/Redis)

### Health Checks

1. **Container Health** (Docker): `http://localhost:3000/health-check` (5s interval)
2. **ALB Health**: `http://{ip}:3000/health-check` (30s interval)
3. **Endpoint**: `app/controllers/external/health_controller.rb`
   - Checks database connectivity
   - Returns 200 if healthy, 503 if not

### Migrations

**Concurrent Guard Pattern** (Exercism):
- Runs in `bin/docker-entrypoint` before server start
- Random 0-30s sleep to prevent thundering herd
- Retries on `ActiveRecord::ConcurrentMigrationError`
- File: `lib/run_migrations_with_concurrent_guard.rb`

**How It Works**:
1. ECS deploys new tasks with rolling deployment
2. Each task runs migrations on startup
3. First task acquires lock and runs migrations
4. Other tasks retry and succeed after lock is released
5. Grace period (300s) allows migrations to complete

---

## Deployment Process

### Automated (GitHub Actions)

**Triggers**:
- Push to `main` branch (auto-deploy)
- Push to `deployment` branch (auto-deploy)
- Manual trigger from any branch

**Workflow** (`.github/workflows/deploy.yml`):
1. Checkout code
2. Configure AWS credentials
3. Login to ECR
4. **Set up Docker Buildx** (for caching)
5. Run Zeitwerk validation
6. **Build with layer cache** (ECR buildcache)
7. Push image with git SHA tag + `:latest`
8. Update `jiki-api-web` task definition
9. Deploy web service (wait for stability)
10. Update `jiki-api-solid-queue` task definition
11. Deploy worker service (wait for stability)

**Build Performance**:
- First build (cold cache): ~8-12 minutes
- Subsequent builds (warm cache): ~1-2 minutes
- Cache stored in ECR with `:buildcache` tag

**Image Tagging**:
- Each deployment: `<git-sha>` (unique, immutable)
- Latest: `:latest` tag (mutable, for convenience)
- Cache: `:buildcache` tag (protected by lifecycle policy)

### Manual Deployment

```bash
# 1. Trigger GitHub Actions
git push origin main

# 2. Or manually via AWS CLI
aws ecs update-service \
  --cluster jiki-production \
  --service jiki-api-web \
  --force-new-deployment \
  --region eu-west-1 --profile jiki

aws ecs update-service \
  --cluster jiki-production \
  --service jiki-api-solid-queue \
  --force-new-deployment \
  --region eu-west-1 --profile jiki
```

### Monitoring Deployment

```bash
# Watch ECS service status
aws ecs describe-services \
  --cluster jiki-production \
  --services jiki-api-web jiki-api-solid-queue \
  --region eu-west-1 --profile jiki

# Watch CloudWatch logs
aws logs tail /ecs/jiki-api-web --follow --region eu-west-1 --profile jiki
aws logs tail /ecs/jiki-api-solid-queue --follow --region eu-west-1 --profile jiki

# Check health
curl https://api.jiki.io/health-check
```

---

## Configuration Sources

### DynamoDB (`config` table)

Application reads configuration from DynamoDB via `jiki-config` gem:

```ruby
Jiki.config.aurora_endpoint          # Database endpoint
Jiki.config.aurora_port              # 5432
Jiki.config.aurora_database_name     # jiki_production
Jiki.config.frontend_base_url        # https://jiki.io
Jiki.config.r2_account_id            # Cloudflare account
Jiki.config.assets_cdn_url           # https://assets.jiki.io
```

**⚠️ TODO Items** (replace before production):
- `stripe_publishable_key` → Real `pk_live_*` key
- `stripe_premium_price_id` → Real price ID
- `stripe_max_price_id` → Real price ID

### AWS Secrets Manager (`config` secret)

Application reads secrets via `jiki-config` gem:

```ruby
Jiki.secrets.secret_key_base         # Rails encrypted credentials
Jiki.secrets.aurora_password         # Database password
Jiki.secrets.jwt_secret              # JWT signing key
Jiki.secrets.hmac_secret             # HMAC key
Jiki.secrets.stripe_secret_key       # Stripe API key
Jiki.secrets.google_api_key          # Gemini API
# ... and more
```

**⚠️ Needs Population**:
All secrets need to be added to AWS Secrets Manager (JSON format).

---

## Terraform Repository Status

**Branch**: `add-workers-deployment-infrastructure`
**Status**: All committed and applied

**Terraform Files**:
```
terraform/
├── aws/
│   ├── vpc.tf                    # VPC, subnets, IGW
│   ├── security_groups.tf        # ALB, ECS, RDS
│   ├── rds.tf                    # Aurora Serverless v2
│   ├── s3.tf                     # Active Storage bucket
│   ├── ecr.tf                    # Container registry
│   ├── ecs_cluster.tf            # ECS cluster
│   ├── ecs_web.tf                # Web service
│   ├── ecs_solid_queue.tf        # Worker service
│   ├── alb.tf                    # Load balancer
│   ├── dynamodb.tf               # Config table
│   ├── secrets.tf                # Secrets Manager
│   ├── iam.tf                    # IAM roles/policies
│   ├── iam_github_actions.tf    # GitHub OIDC
│   └── cloudwatch.tf             # Logging
│
└── cloudflare/
    ├── dns.tf                    # DNS records
    ├── origin_certificate.tf    # Cloudflare → ALB cert
    ├── r2.tf                     # Assets bucket
    └── workers.tf                # Edge workers
```

---

## What's Next

### Immediate (Before Production Users)

1. **Populate AWS Secrets Manager**
   ```bash
   # Generate Rails secrets
   SECRET_KEY_BASE=$(bundle exec rails secret)
   HMAC_SECRET=$(bundle exec rails secret)
   JWT_SECRET=$(bundle exec rails secret)

   # Create JSON secret
   aws secretsmanager put-secret-value \
     --secret-id config \
     --secret-string '{
       "secret_key_base": "'$SECRET_KEY_BASE'",
       "aurora_password": "STRONG_PASSWORD_HERE",
       "hmac_secret": "'$HMAC_SECRET'",
       "jwt_secret": "'$JWT_SECRET'",
       "google_api_key": "...",
       "elevenlabs_api_key": "...",
       "heygen_api_key": "...",
       "stripe_secret_key": "sk_live_...",
       "stripe_webhook_secret": "whsec_...",
       "r2_access_key_id": "...",
       "r2_secret_access_key": "...",
       "google_oauth_client_id": "...",
       "google_oauth_client_secret": "..."
     }' \
     --region eu-west-1 --profile jiki
   ```

2. **Rotate Database Password**
   - Change from "temporary-change-me-immediately"
   - Update in RDS console
   - Update in Secrets Manager
   - Redeploy ECS tasks

3. **Update Stripe Config in DynamoDB**
   ```bash
   # Update these 3 items in config table:
   # - stripe_publishable_key → pk_live_...
   # - stripe_premium_price_id → price_...
   # - stripe_max_price_id → price_...
   ```

4. **Test Deployment**
   ```bash
   # Verify API is responding
   curl https://api.jiki.io/health-check

   # Check services are running
   aws ecs describe-services \
     --cluster jiki-production \
     --services jiki-api-web jiki-api-solid-queue \
     --region eu-west-1 --profile jiki

   # Monitor logs for errors
   aws logs tail /ecs/jiki-api-web --follow --region eu-west-1 --profile jiki
   ```

### Security Hardening (Before Public Launch)

- [x] Enable ALB deletion protection
- [x] Enable RDS deletion protection
- [ ] Rotate database password from temporary value
- [ ] Review all security group rules
- [ ] Set up CloudWatch alarms (CPU, 5xx errors, DB connections)
- [ ] Configure SNS for alert notifications
- [ ] Set up AWS CloudTrail for audit logging

### Scalability (Before High Traffic)

- [ ] Increase Aurora max capacity (1 → 20 ACU)
- [ ] Enable Aurora Multi-AZ for high availability
- [ ] Scale ECS to minimum 2 tasks per service
- [ ] Configure auto-scaling for worker service based on queue depth
- [ ] Review and tune database connection pool settings
- [ ] Load test under expected traffic

### Optional Enhancements

- [ ] Private subnets + NAT Gateway (adds ~$32/month for security)
- [ ] VPC endpoints for DynamoDB/S3 (cost optimization at scale)
- [ ] CloudWatch dashboard for operations
- [ ] Enhanced monitoring with Datadog/New Relic

---

## Cost Breakdown

### Current (Startup Configuration)

| Service | Configuration | Monthly Cost |
|---------|---------------|--------------|
| Aurora Serverless v2 | 0-1 ACU (scales to zero) | $20-40 |
| ECS Web | 1 task (512/1024) | ~$15 |
| ECS Worker | 1 task (256/512) | ~$8 |
| ALB | Standard | ~$20 |
| S3 | Active Storage + Video | ~$5-10 |
| ECR | Image storage | ~$1 |
| CloudWatch | 7-day logs | ~$3 |
| DynamoDB | Config table | ~$0.01 |
| **Total** | | **$71-97/month** |

### Production (Scaled Configuration)

| Service | Configuration | Monthly Cost |
|---------|---------------|--------------|
| Aurora Serverless v2 | 2-20 ACU + Multi-AZ | $180-400 |
| ECS Web | 2-4 tasks (512/1024) | ~$30-60 |
| ECS Worker | 1-2 tasks (256/512) | ~$15-30 |
| ALB | Standard | ~$20 |
| NAT Gateway | 2x Multi-AZ (optional) | ~$64 |
| S3 | Active Storage + Video | ~$20-50 |
| ECR | Image storage | ~$2 |
| CloudWatch | Logs + Alarms | ~$10-20 |
| **Total** | | **$341-646/month** |

**Cost Optimization**:
- Aurora scales to zero when idle (saves $43/month during off-hours)
- No Redis/ElastiCache (saves $45-70/month vs Sidekiq)
- Single-AZ database (saves ~50% vs Multi-AZ)
- No NAT Gateway (saves $32/month vs private subnets)

---

## References

### Key Files

**API Repository** (`deployment` branch):
- `Dockerfile` - Port configuration (3000 Thruster, 3001 Puma)
- `.github/workflows/deploy.yml` - Automated deployment
- `config/environments/production.rb` - Production settings
- `app/controllers/external/health_controller.rb` - Health endpoint
- `lib/run_migrations_with_concurrent_guard.rb` - Migration guard

**Terraform Repository** (`add-workers-deployment-infrastructure` branch):
- `terraform/aws/` - All AWS infrastructure
- `terraform/cloudflare/` - DNS and CDN configuration

### Documentation

- [Rails 8 Deployment Guide](https://guides.rubyonrails.org/deploying_rails_applications.html)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Aurora Serverless v2](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html)
- [Solid Queue](https://github.com/basecamp/solid_queue)
- [Thruster](https://github.com/basecamp/thruster)
