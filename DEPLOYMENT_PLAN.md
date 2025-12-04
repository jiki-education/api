# Jiki API - Deployment Status

## Current State: Production-Ready Infrastructure & Application

**Last Updated**: 2025-11-26
**Status**: ✅ Infrastructure deployed, application feature-complete, ready for production secrets
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
- **Storage**: S3 (`jiki-active-storage` + `jiki-video-production`) + Cloudflare R2 (`assets`)
- **Email**: AWS SES (3 domains: `mail.jiki.io`, `notifications.jiki.io`, `hello.jiki.io`)
- **Config**: DynamoDB (`config` table) + AWS Secrets Manager
- **Cache**: Memory store (no Redis)
- **Jobs**: Solid Queue (database-backed, no Redis/Sidekiq)

**Monthly Cost**: ~$95-134 (startup configuration)

---

## ✅ Infrastructure Status - All Deployed

All infrastructure is created and configured via Terraform:

### Networking
- ✅ VPC: `10.1.0.0/16` with public subnets across multiple AZs
- ✅ Internet gateway and routing tables
- ✅ No NAT Gateway (cost optimization: saves $32/month)

### Compute (ECS)
- ✅ **Cluster**: `jiki-production` with Container Insights
- ✅ **Web Service**: `jiki-api-web`
  - 512 CPU / 1024 MB memory
  - Auto-scaling: 1-4 tasks based on CPU
  - Port 3000 (Thruster → Puma 3001)
  - Health check: `/health-check` every 30s (Docker: 5s)
  - Grace period: 300s for migrations
  - Lifecycle: Ignores task_definition (GitHub Actions manages deployments)

- ✅ **Worker Service**: `jiki-api-solid-queue`
  - 256 CPU / 512 MB memory
  - 1 task (no auto-scaling currently)
  - Command: `bundle exec rake solid_queue:start`
  - Lifecycle: Ignores task_definition

- ✅ **Bastion Host**: On-demand secure access
  - MFA required via aws-vault
  - IP-restricted (whitelisted IPs only)
  - Auto-cleanup or keep-alive modes
  - ~$0.01-0.02/month usage cost

### Database
- ✅ **Aurora Serverless v2**: PostgreSQL 16.6
  - Min capacity: 0 ACU (scales to zero when idle)
  - Max capacity: 1 ACU (cost-optimized)
  - Endpoint: Stored in DynamoDB `config` table
  - Password: **"temporary-change-me-immediately"** (⚠️ needs rotation)
  - Backup retention: 10 days
  - Performance Insights: enabled
  - Deletion protection: enabled
  - Single-AZ (for production: consider Multi-AZ)

### Storage
- ✅ **S3**: `jiki-active-storage`
  - Public access: blocked
  - Versioning: enabled
  - Encryption: AES256
  - Lifecycle: 90-day version expiration
  - Used for: Exercise submissions, user uploads

- ✅ **S3**: `jiki-video-production`
  - Video generation assets

- ✅ **Cloudflare R2**: `assets` bucket with CDN
  - Static assets served via CDN

### Email (AWS SES)
- ✅ **3 Email Domains** with managed dedicated IPs:
  - `mail.jiki.io` - Transactional emails (auth, payments)
  - `notifications.jiki.io` - Learning notifications
  - `hello.jiki.io` - Marketing newsletters
- ✅ **DKIM**: AWS-managed 2048-bit RSA keys
- ✅ **Custom MAIL FROM**: `bounce.{subdomain}`
- ✅ **Configuration Sets**: For tracking and metrics
- ✅ **Event Destinations**:
  - SNS topics for bounces/complaints → `/webhooks/ses`
  - CloudWatch metrics for monitoring
- ✅ **Cloudflare DNS**: All TXT, MX, CNAME records configured

### Container Registry
- ✅ **ECR**: `jiki/api`
  - Image scanning: enabled
  - Lifecycle: Keep last 10 images (protects buildcache)

### Load Balancer
- ✅ **ALB**: `jiki-api-alb`
  - HTTPS only (port 443) with Cloudflare Origin Certificate
  - Target group: port 3000, health check `/health-check`
  - SSL policy: TLS 1.3
  - Deletion protection: enabled

### Security Groups
- ✅ **ALB**: 80, 443 from internet
- ✅ **ECS**: 3000 from ALB
- ✅ **RDS**: 5432 from ECS + Bastion
- ✅ **Bastion**: Egress only (no inbound)

### IAM Roles
- ✅ **Task Execution Role**: ECR pull, CloudWatch logs, Secrets Manager
- ✅ **Task Role**: S3 Active Storage, DynamoDB config, Secrets Manager
- ✅ **Bastion IP Restriction**: IP-whitelisted IAM policy
- ✅ **GitHub Actions**: OIDC provider, ECR push, ECS deploy

### Configuration
- ✅ **DynamoDB**: `config` table with 14+ items
  - Domain configuration
  - Database endpoints
  - Cloudflare R2 credentials
  - **⚠️ Stripe placeholders** (TODO: update before production)

- ✅ **Secrets Manager**: `config` secret (structure defined)
  - **⚠️ Needs population** with real secrets:
    - `secret_key_base`
    - `aurora_password`
    - `hmac_secret`
    - `jwt_secret`
    - API keys (Google, ElevenLabs, HeyGen, Stripe, etc.)

### DNS & SSL
- ✅ **Cloudflare**: `api.jiki.io` → ALB (proxied)
- ✅ **Origin Certificate**: 15-year Cloudflare → ALB encryption
- ✅ **SSL Mode**: Full (strict), TLS 1.3 enabled
- ✅ **Email DNS**: All SES verification, DKIM, SPF records

### Monitoring
- ✅ **CloudWatch Logs**: 7-day retention for ECS services
- ✅ **CloudWatch Metrics**: SES email tracking
- ✅ **CloudWatch Alarms**: 3 critical alarms
  - ALB no healthy targets (site down)
  - RDS high CPU (database overloaded)
  - Worker service no tasks (jobs stopped)
- ✅ **CloudTrail**: Audit logging (management events + DynamoDB config)
- ✅ **SNS Alerts**: Email + SMS notifications configured

---

## ✅ Application Status - Feature Complete

All core features implemented and working:

### Authentication & Authorization
- ✅ **User Model**: Email/password + Google OAuth
- ✅ **JWT Authentication**: Access tokens (15 min) + Refresh tokens (30 days)
- ✅ **Token Cleanup Job**: Scheduled cleanup of expired tokens
- ✅ **Password Reset**: Full flow implemented
- ✅ **Email Verification**: Token-based verification
- ✅ **Admin System**: Admin flag for privileged access

### Learning Platform
- ✅ **Levels**: Linear progression system (position-ordered)
- ✅ **Lessons**: Two types - coding exercises + informational
  - Position-based ordering within levels
  - Slug-based routing
  - Rich data field (JSON)
- ✅ **User Progression**:
  - `UserLevel` - Level progress tracking
  - `UserLesson` - Lesson completion tracking
  - Current position tracking
- ✅ **Exercise Submissions**:
  - Polymorphic (works with Lessons + Projects)
  - File uploads via Active Storage
  - UUID-based identification

### Projects
- ✅ **Project Model**: Standalone exercises unlocked by lessons
- ✅ **User Projects**: Progress tracking (started/completed)
- ✅ **Exercise Submissions**: Same system as lessons

### Concepts (Learn Mode)
- ✅ **Concept Model**: Educational content with markdown/HTML
- ✅ **Video Support**: Premium + Standard video providers
- ✅ **Unlocking System**: Unlocked by completing specific lessons
- ✅ **User Tracking**: Unlocked concepts stored in `user_data`

### Email System
- ✅ **3 Mailers**: Transactional, Notifications, Marketing
- ✅ **Email Templates**: Database-stored with MJML + plain text
- ✅ **SES Integration**: `aws-actionmailer-ses` gem configured
- ✅ **Bounce/Complaint Handling**: Webhook endpoint `/webhooks/ses`
- ✅ **Email Tracking**: Opens, bounces, complaints in `user_data`
- ✅ **Unsubscribe System**: Token-based unsubscribe

### Payment System (Stripe)
- ✅ **Stripe Integration**: Checkout session creation
- ✅ **Subscription Management**: Status tracking in `user_data`
- ✅ **Webhook Handler**: `/webhooks/stripe` for events
- ✅ **PPP Pricing**: Geographic-based pricing (config in DynamoDB)
- ⚠️ **Stripe Config**: Using placeholder keys (TODO: update)

### AI Features
- ✅ **Assistant Conversations**: Context-aware chat for lessons/projects
- ✅ **Google Gemini Integration**: API client configured
- ✅ **Video Production Pipeline**: Node-based video generation system
  - Pipelines with versioning
  - Nodes with validation + execution
  - Executor callback endpoint (`/spi/video_production`)

### File Storage
- ✅ **Active Storage**: S3 backend configured for production
- ✅ **Image Upload**: Admin endpoint for rich text editor images
  - Size validation (5MB max)
  - Type validation (JPEG, PNG, GIF, WebP, SVG)
  - Cloudflare R2 upload with CDN URL

### Background Jobs
- ✅ **Solid Queue**: Database-backed job system
- ✅ **Worker Service**: Dedicated ECS service for job processing
- ✅ **Recurring Jobs**: Token cleanup scheduled
- ✅ **Job Monitoring**: Mission Control UI at `/solid_queue`

### API Endpoints
- ✅ **External (Public)**:
  - `/external/health-check` - Health checks
  - `/external/concepts` - Public concept browsing

- ✅ **Auth**:
  - `/auth/sign_up` - User registration
  - `/auth/sign_in` - Login
  - `/auth/refresh` - Token refresh
  - `/auth/google` - OAuth callback
  - `/auth/password` - Reset password
  - `/auth/logout/all` - Logout all sessions

- ✅ **Internal (Authenticated)**:
  - `/internal/me` - Current user
  - `/internal/levels` - Browse levels
  - `/internal/lessons/:slug` - Lesson details
  - `/internal/projects` - Browse/view projects
  - `/internal/user_lessons` - Start/complete lessons
  - `/internal/exercise_submissions` - Submit solutions
  - `/internal/concepts` - Learn mode browsing
  - `/internal/subscriptions` - Checkout + verify
  - `/internal/assistant_conversations` - AI chat

- ✅ **Admin**:
  - Full CRUD for: levels, lessons, concepts, projects, email templates
  - `/admin/users` - User management
  - `/admin/video_production/pipelines` - Video pipeline management
  - `/admin/images` - Image upload for rich text

- ✅ **Webhooks**:
  - `/webhooks/stripe` - Stripe events
  - `/webhooks/ses` - Email bounces/complaints

- ✅ **SPI (Service-to-Service)**:
  - `/spi/video_production/executor_callback` - Node execution results

- ✅ **Dev**:
  - `/dev/users/:handle/clear_stripe_history` - Dev utility

### Testing
- ✅ **Minitest**: Test framework configured
- ✅ **Test Coverage**: Controllers, models, commands
- ✅ **CI Validation**: Zeitwerk test in GitHub Actions

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
4. Set up Docker Buildx (for caching)
5. Run Zeitwerk validation
6. **Build with layer cache** (ECR buildcache)
7. Push image with git SHA tag + `:latest`
8. Update `jiki-api-web` task definition
9. Deploy web service (parallel)
10. Update `jiki-api-solid-queue` task definition
11. Deploy worker service (parallel)
12. Update `jiki-bastion` task definition (no deploy)
13. Wait for both services to stabilize

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

**Branch**: `add-workers-deployment-infrastructure` (or later)
**Status**: All committed and applied

**Terraform Files**:
```
terraform/terraform/
├── aws/
│   ├── vpc.tf                        # VPC, subnets, IGW
│   ├── security_group_*.tf           # ALB, ECS, RDS, Bastion
│   ├── rds.tf                        # Aurora Serverless v2
│   ├── s3.tf                         # Active Storage bucket
│   ├── ecr.tf                        # Container registry
│   ├── ecs_cluster.tf                # ECS cluster with Exec
│   ├── ecs_web.tf                    # Web service
│   ├── ecs_solid_queue.tf            # Worker service
│   ├── ecs_bastion.tf                # Bastion task definition
│   ├── alb.tf                        # Load balancer
│   ├── dynamodb.tf                   # Config table
│   ├── secrets.tf                    # Secrets Manager
│   ├── ses.tf                        # Email infrastructure
│   ├── iam.tf                        # IAM roles/policies
│   ├── iam_bastion_ip_restriction.tf # Bastion IP whitelist
│   ├── iam_github_actions.tf         # GitHub OIDC
│   ├── cloudwatch.tf                 # Logging
│   └── video-production.tf           # Video S3 bucket
│
└── cloudflare/
    ├── dns.tf                        # API DNS + Email DNS
    ├── dns_ses.tf                    # SES verification records
    ├── origin_certificate.tf         # Cloudflare → ALB cert
    ├── r2.tf                         # Assets bucket
    ├── workers.tf                    # Edge workers
    ├── zone_settings.tf              # SSL/TLS settings
    ├── cdn.tf                        # CDN configuration
    ├── cache_rules.tf                # Cache rules
    └── redirects.tf                  # URL redirects
```

---

## 🎯 What's Left

### 1. Immediate (Before Production Users)

**Required for launch:**

- [x] **Populate AWS Secrets Manager** - ✅ Complete
- [x] **Rotate Database Password** - ✅ Complete
- [x] **Update Stripe Config in DynamoDB** - ✅ Complete
- [x] **Confirm SNS Subscriptions for SES** - ✅ Complete
- [x] **Test Email Sending** - ✅ Complete (all 3 domains working)
- [ ] **Test Full Deployment** - Final end-to-end verification
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

### 2. Security Hardening (Before Public Launch)

- [x] Enable ALB deletion protection
- [x] Enable RDS deletion protection
- [x] Rotate database password from temporary value
- [x] **Set up AWS CloudTrail** - ✅ Complete
- [x] **Set up CloudWatch alarms** - ✅ Complete (3 critical alarms)
- [x] **Configure SNS for alert notifications** - ✅ Complete
- [ ] **Confirm SNS email subscription** (check email inbox)
- [ ] **Subscribe SMS alerts** (see command above with your phone number)
- [ ] Review all security group rules for least privilege
- [ ] Review IAM policies for least privilege

### 3. Scalability (Before High Traffic)

**Current Auto-Scaling Configuration:**
- **Web Service**: ✅ Enabled (1-4 tasks, CPU target 70%)
  - Scale out cooldown: 60s
  - Scale in cooldown: 300s
  - ⚠️ Min capacity 1 (consider increasing to 2 for HA)
- **Worker Service**: ❌ No auto-scaling (fixed at 1 task)
  - Should add queue-depth based scaling

**TODO:**
- [ ] **Increase web service min capacity** (1 → 2) for high availability
- [ ] **Configure worker auto-scaling** based on Solid Queue depth
  - Target: ~1000 jobs per worker or queue age metric
  - Min: 1, Max: 4
- [ ] Increase Aurora max capacity (1 → 4+ ACU for testing, 20 ACU for production)
- [ ] Enable Aurora Multi-AZ for high availability
- [ ] Review and tune database connection pool settings
- [ ] Load test under expected traffic (use tools like k6, Locust)
- [ ] Test Solid Queue under load
- [ ] Optimize slow queries identified in RDS Performance Insights

### 4. Optional Enhancements

- [ ] Private subnets + NAT Gateway (adds ~$32/month for security)
- [ ] VPC endpoints for DynamoDB/S3 (cost optimization at scale)
- [ ] CloudWatch dashboard for operations
- [ ] Enhanced monitoring with Datadog/New Relic
- [ ] WAF rules for API protection
- [ ] Rate limiting middleware
- [ ] Request/response caching strategy
- [ ] Database read replicas (if needed)

---

## Cost Breakdown

### Current (Startup Configuration)

| Service | Configuration | Monthly Cost |
|---------|---------------|--------------|
| Aurora Serverless v2 | 0-1 ACU (scales to zero) | $20-40 |
| ECS Web | 1 task (512/1024) | ~$15 |
| ECS Worker | 1 task (256/512) | ~$8 |
| ALB | Standard | ~$20 |
| S3 | Active Storage + Video + CloudTrail | ~$5-12 |
| ECR | Image storage | ~$1 |
| CloudWatch | 7-day logs + 3 alarms | ~$3.30 |
| CloudTrail | Audit logging | ~$2 |
| DynamoDB | Config table | ~$0.01 |
| SES | 3 domains + managed IPs | ~$20-30 |
| SNS | Email + SMS (optional) | ~$0 (+$0.65/100 texts) |
| **Total** | | **$95-134/month** |

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
| SES | 3 domains + managed IPs | ~$30-50 |
| **Total** | | **$361-696/month** |

**Cost Optimization**:
- Aurora scales to zero when idle (saves $43/month during off-hours)
- No Redis/ElastiCache (saves $45-70/month vs Sidekiq)
- Single-AZ database (saves ~50% vs Multi-AZ)
- No NAT Gateway (saves $32/month vs private subnets)

---

## AWS CloudTrail & CloudWatch Alarms

### ✅ AWS CloudTrail (DEPLOYED)

**Deployed Configuration:**
- **S3 Bucket**: `jiki-cloudtrail-logs`
- **Trail**: `jiki-production-trail` (multi-region, log validation enabled)
- **Events Logged**: All management events + DynamoDB `config` table data events
- **Lifecycle**: 90 days → Glacier, 365 days → delete
- **Cost**: ~$2.50/month
- **File**: `../terraform/terraform/aws/cloudtrail.tf`

**What it is:**
AWS CloudTrail is an audit logging service that records all AWS API calls made to AWS services in your account. It's essential for security, compliance, and operational troubleshooting.

**Why you need it:**
- **Security**: Detect unauthorized access attempts, unusual API activity, or compromised credentials
- **Compliance**: Meet audit requirements (SOC 2, GDPR, etc.)
- **Troubleshooting**: Understand "who did what, when" when investigating issues
- **Forensics**: Investigate security incidents with detailed logs

**What it logs:**
- IAM user/role activity (who accessed what)
- ECS task launches, stops, updates
- RDS changes (password rotations, parameter changes)
- S3 bucket access (who uploaded/downloaded files)
- DynamoDB table operations
- Secrets Manager access (who read which secrets)
- ALB, security group, and VPC changes
- And 100+ other AWS services

**Setup Options:**

**Option 1: Organization Trail (Recommended for multi-account)**
- Logs all accounts in your AWS Organization
- Centralized logging to a single S3 bucket
- ~$2/month per account + storage costs

**Option 2: Single Account Trail (Good for now)**
- Logs just your production account
- Stores logs in S3 bucket
- ~$2/month + storage (~$0.50-2/month)

**How to set up:**

```bash
# 1. Create S3 bucket for logs
aws s3 mb s3://jiki-cloudtrail-logs-eu-west-1 --region eu-west-1 --profile jiki

# 2. Create trail via AWS Console or Terraform
# Console: CloudTrail → Trails → Create trail
# - Name: jiki-production-trail
# - Log events: Management events + Data events (S3, DynamoDB)
# - Enable log file validation (for tamper-proofing)
# - Enable CloudWatch Logs (for real-time alerting)
# - Optionally enable SNS notifications

# 3. Or use Terraform (recommended)
```

**Terraform example:**

```hcl
# terraform/aws/cloudtrail.tf
resource "aws_cloudtrail" "main" {
  name                          = "jiki-production-trail"
  s3_bucket_name               = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_log_file_validation   = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    # Log S3 data events (who accessed which files)
    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.active_storage.arn}/"]
    }

    # Log DynamoDB data events
    data_resource {
      type   = "AWS::DynamoDB::Table"
      values = ["${aws_dynamodb_table.config.arn}"]
    }
  }

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cloudwatch.arn
}

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "jiki-cloudtrail-logs-eu-west-1"
}

# Lifecycle rule to reduce costs
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365  # Keep logs for 1 year
    }
  }
}
```

**Cost:**
- **Trail**: $2/month for first 1M events
- **S3 Storage**: ~$0.50-2/month (with lifecycle to Glacier after 90 days)
- **CloudWatch Logs** (optional): ~$5-10/month for real-time alerting
- **Total**: ~$2.50-14/month depending on options

**What to monitor:**
Once enabled, set up CloudWatch alarms for:
- Root account usage (should never happen)
- IAM policy changes
- Security group changes
- Failed console login attempts
- API calls from unknown IP addresses
- Secrets Manager access outside business hours

---

### ✅ CloudWatch Alarms (DEPLOYED)

**Deployed Configuration:**
- **SNS Topic**: `jiki-critical-alerts`
- **Email**: Configured (requires confirmation)
- **SMS**: Manual subscription with command below
- **Cost**: ~$0.30/month + SMS costs
- **File**: `../terraform/terraform/aws/cloudwatch_alarms.tf`

**3 Critical Alarms:**

1. **jiki-api-no-healthy-targets**
   - Metric: `HealthyHostCount` < 1 for 2 minutes
   - Severity: CRITICAL
   - Means: API is completely down (no healthy ECS tasks)

2. **jiki-rds-high-cpu**
   - Metric: `CPUUtilization` > 90% for 15 minutes
   - Severity: CRITICAL
   - Means: Database is overloaded, queries are slow

3. **jiki-ecs-worker-no-running-tasks**
   - Metric: `RunningTaskCount` < 1 for 2 minutes
   - Severity: CRITICAL
   - Means: Background job processing stopped

All alarms notify on both alarm and OK (recovery) states.

**Add SMS Alerts:**
```bash
# After terraform apply, get the SNS topic ARN
cd ../terraform/terraform
terraform output critical_alerts_topic_arn

# Subscribe your phone
aws sns subscribe \
  --topic-arn <arn-from-output> \
  --protocol sms \
  --notification-endpoint +447743078349 \
  --region eu-west-1 --profile jiki
```

---

### ⏸️ AWS Config (SKIPPED FOR NOW)

**What it is:**
AWS Config continuously monitors and records your AWS resource configurations. It tracks changes over time and evaluates compliance against rules.

**Why you need it:**
- **Configuration History**: See how resources changed over time ("Was the security group open to the internet last week?")
- **Compliance**: Automatically check if resources meet security standards
- **Change Management**: Understand what changed before an outage
- **Drift Detection**: Detect manual changes that violate your Terraform config

**What it tracks:**
- Security group rules (did someone accidentally open port 22 to 0.0.0.0/0?)
- IAM policies and roles
- ECS task definitions and services
- RDS instance configurations
- S3 bucket policies and encryption
- ALB settings and SSL policies
- VPC configurations

**Managed Rules** (pre-built compliance checks):
- `encrypted-volumes` - Ensure EBS volumes are encrypted
- `rds-encryption-enabled` - Ensure RDS encryption is on
- `s3-bucket-public-read-prohibited` - No public S3 buckets
- `iam-password-policy` - Strong password requirements
- `cloudtrail-enabled` - CloudTrail must be running
- `vpc-sg-open-only-to-authorized-ports` - Security group validation
- 200+ more rules available

**Setup:**

```bash
# Via AWS Console:
# 1. AWS Config → Get started
# 2. Select all resource types (or specific ones)
# 3. Create S3 bucket for config snapshots
# 4. Create IAM role (auto-created)
# 5. Add managed rules you want
# 6. Enable SNS notifications for compliance violations

# Or via Terraform (recommended)
```

**Terraform example:**

```hcl
# terraform/aws/config.tf
resource "aws_config_configuration_recorder" "main" {
  name     = "jiki-production-config"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "jiki-production-config"
  s3_bucket_name = aws_s3_bucket.config_logs.id

  snapshot_delivery_properties {
    delivery_frequency = "Six_Hours"
  }
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}

# Example managed rule: Ensure RDS encryption
resource "aws_config_config_rule" "rds_encryption" {
  name = "rds-encryption-enabled"

  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Example: No public S3 buckets
resource "aws_config_config_rule" "s3_public_read" {
  name = "s3-bucket-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Example: Security groups shouldn't allow 0.0.0.0/0 on risky ports
resource "aws_config_config_rule" "restricted_ssh" {
  name = "restricted-ssh"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}
```

**Cost:**
- **Configuration Items**: $0.003 per item recorded (~$5-15/month for typical setup)
- **Rule Evaluations**: $0.001 per evaluation (~$2-5/month for 5-10 rules)
- **S3 Storage**: ~$1-3/month
- **Total**: ~$8-23/month depending on resources tracked

**Recommended for Jiki:**

**Start Simple (Lower Cost):**
1. Enable Config for critical resources only:
   - EC2 instances (none currently)
   - RDS databases
   - Security groups
   - IAM policies
   - S3 buckets
2. Add 5-10 managed rules:
   - `rds-encryption-enabled`
   - `s3-bucket-public-read-prohibited`
   - `cloudtrail-enabled`
   - `vpc-sg-open-only-to-authorized-ports`
   - `iam-password-policy`

**Later (Higher Confidence):**
- Enable for all resources
- Add custom rules for Jiki-specific compliance
- Integrate with AWS Security Hub for centralized view

---

### Recommendation: Start with CloudTrail, Add Config Later

**For Launch (Immediate):**
- ✅ **CloudTrail**: Set this up NOW (~$2.50/month)
  - Essential for security and compliance
  - Cannot be retroactively enabled (no logs without it)
  - Takes 15 minutes to set up
  - Critical for investigating incidents

**For Post-Launch (Optional but Recommended):**
- ⚠️ **AWS Config**: Add within first month (~$8-23/month)
  - Nice to have but not critical at launch
  - More useful once you have traffic/users
  - Helps with compliance and security posture
  - Can be enabled anytime (starts tracking from enable date)

**Priority Order:**
1. **CloudTrail** (critical) - Do before launch
2. **CloudWatch Alarms** (important) - Do first week after launch
3. **AWS Config** (recommended) - Do first month
4. **Security Hub** (optional) - Do when scaling up

---

## Bastion Host Access

### Overview

A secure bastion host provides on-demand access to the production database and Rails console via ECS Exec.

**Key Features**:
- Uses the same Docker image as the web application
- MFA authentication required (via aws-vault)
- IP-restricted access (whitelisted IPs only)
- On-demand only (no permanent cost)
- Auto-cleanup or long-running mode

### Usage

**Basic Usage** (auto-starts, auto-stops):
```bash
cd /path/to/jiki/api
./bin/bastion
# Prompts for MFA code if needed
# Connects to bastion shell
# Auto-stops task on exit
```

**Long-Running Sessions** (keep bastion running):
```bash
./bin/bastion --keep-alive
# Bastion stays running after disconnect
# Reconnect anytime without starting a new task
```

**Connecting to Existing Bastion**:
```bash
./bin/bastion
# Automatically detects and connects to existing task
# No new task started
```

### Inside the Bastion

Once connected, you have full access to the Rails application:

```bash
# Rails console
rails console

# Database console
rails dbconsole

# Run migrations
rails db:migrate

# Run arbitrary Ruby code
rails runner "puts User.count"

# Check environment
env | grep RAILS
```

### Security Model

**Authentication**:
- AWS IAM credentials required
- MFA code from Authy (via aws-vault)
- 12-hour session duration

**IP Restriction**:
- Access restricted to whitelisted IPs only
- Configure in `../terraform/terraform/aws/iam_bastion_ip_restriction.tf`
- IAM policy denies bastion access from other IPs
- Terraform operations unaffected (work from any IP)

**Network Isolation**:
- Bastion → Database: Port 5432 only
- Bastion → Internet: HTTPS (443) for AWS APIs
- No inbound connections
- All sessions logged to CloudWatch (`/ecs/exec`)

### Cost

- **On-Demand**: ~$0.01/hour (256 CPU / 512 MB Fargate)
- **Typical Usage**: 1-2 hours/month = $0.01-0.02/month
- **No Permanent Infrastructure**: $0 when not running

---

## Application Architecture

### Port Configuration

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

**Concurrent Guard Pattern** (from Exercism):
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

## References

### Key Files

**API Repository**:
- `Dockerfile` - Port configuration (3000 Thruster, 3001 Puma)
- `.github/workflows/deploy.yml` - Automated deployment
- `config/environments/production.rb` - Production settings
- `app/controllers/external/health_controller.rb` - Health endpoint
- `lib/run_migrations_with_concurrent_guard.rb` - Migration guard
- `bin/bastion` - Bastion access script
- `db/schema.rb` - Database schema

**Terraform Repository**:
- `terraform/terraform/aws/` - All AWS infrastructure
- `terraform/terraform/cloudflare/` - DNS and CDN configuration

### Documentation

- [Rails 8 Deployment Guide](https://guides.rubyonrails.org/deploying_rails_applications.html)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Aurora Serverless v2](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html)
- [Solid Queue](https://github.com/basecamp/solid_queue)
- [Thruster](https://github.com/basecamp/thruster)
- [AWS SES](https://docs.aws.amazon.com/ses/)
