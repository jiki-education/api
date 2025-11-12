# AWS ECS Deployment Plan for Jiki API

## Overview
Deploy Jiki API (Rails 8.1) to AWS ECS using Terraform, following Exercism patterns with cost-optimized configuration for startup phase.

**Target Domain**: `api.jiki.io`
**AWS Region**: `eu-west-1` (Ireland)
**Deployment Method**: Terraform + ECS Fargate

## Cost-Optimized Configuration
- **Aurora Serverless v2**: 0-1 ACU (scales to zero when idle)
- **ElastiCache Serverless**: Auto-scaling Redis
- **ECS Services**: 1 task each (web + Sidekiq)
- **No private subnets/NAT**: Use public subnets only (save ~$32/month)
- **Estimated cost**: ~$85-110/month for low traffic

---

## Phase 1: Application Preparation

### 1.1 Add Migration Concurrent Guard

**Why**: Prevents race conditions when multiple containers start simultaneously during rolling deployments.

**Implementation**:
```ruby
# lib/run_migrations_with_concurrent_guard.rb
# This file runs Rails migrations with a retry guard for any concurrent failures

begin
  # Offset all the different containers against each other over 30secs
  # Put it in this begin so it keeps on happening on each retry.
  sleep(rand * 30)

  migrations = ActiveRecord::Migration.new.migration_context.migrations
  ActiveRecord::Migrator.new(
    :up,
    migrations,
    ActiveRecord::Base.connection.schema_migration,
    ActiveRecord::Base.connection.internal_metadata
  ).migrate

  Rails.logger.info "Migrations ran cleanly"
rescue ActiveRecord::ConcurrentMigrationError
  # If another service is running the migrations, then
  # we wait until it's finished. There's no timeout here
  # because eventually Fargate will just time the machine out.

  Rails.logger.info "Concurrent migration detected. Waiting to try again."
  retry
end
```

**Update entrypoint**:
```bash
# bin/docker-entrypoint
#!/bin/bash -e

# Enable jemalloc for reduced memory usage and latency.
if [ -z "${LD_PRELOAD+x}" ]; then
    LD_PRELOAD=$(find /usr/lib -name libjemalloc.so.2 -print -quit)
    export LD_PRELOAD
fi

# If running the rails server, run migrations with concurrent guard
if [ "${@: -2:1}" == "./bin/rails" ] && [ "${@: -1:1}" == "server" ]; then
  ./bin/rails runner lib/run_migrations_with_concurrent_guard.rb
fi

exec "${@}"
```

### 1.2 Dockerfile Enhancements

**Add HEALTHCHECK**:
```dockerfile
# Add after EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost/up || exit 1
```

**Verify jemalloc** (already installed at line 19):
- ✅ `libjemalloc2` installed in base packages
- ✅ `LD_PRELOAD` set in entrypoint

### 1.3 Puma Configuration Updates

**Current state** (`config/puma.rb`):
- ❌ Port: 3060 (should be 3000 for container)
- ❌ No workers configuration for production
- ❌ No `preload_app!` for memory efficiency

**Add production configuration**:
```ruby
# config/puma.rb

# Workers configuration for production
workers_count = ENV.fetch("WEB_CONCURRENCY") { 2 }
workers workers_count.to_i if workers_count.to_i > 1

# Threads configuration (already exists)
threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
threads threads_count, threads_count

# Port - change from 3060 to 3000
port ENV.fetch("PORT", 3000)

# Preload app for worker efficiency
if workers_count.to_i > 1
  preload_app!

  before_fork do
    # Close database connections before forking
    ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)

    # Close Redis connections if using Sidekiq
    Sidekiq.configure_client do |config|
      config.redis = { size: 1 }
    end if defined?(Sidekiq)
  end

  on_worker_boot do
    # Reconnect to database after fork
    ActiveRecord::Base.establish_connection if defined?(ActiveRecord)

    # Reconnect to Redis after fork
    Sidekiq.configure_client do |config|
      config.redis = { size: 1 }
    end if defined?(Sidekiq)
  end
end

# Graceful shutdown (important for ECS task replacement)
on_worker_shutdown do
  Puma.gracefully_shutdown_workers
end

# Allow puma to be restarted by `bin/rails restart` command
plugin :tmp_restart
```

**Update database pool calculation**:
```yaml
# config/database.yml
production:
  <<: *default
  database: jiki_production
  # Pool should be: WEB_CONCURRENCY × RAILS_MAX_THREADS
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 3).to_i * ENV.fetch("WEB_CONCURRENCY", 2).to_i %>
```

### 1.4 Production Environment Configuration

**Update `config/environments/production.rb`**:

**1. Configure cache store**:
```ruby
# Line 47 - Replace in-process cache with Redis
config.cache_store = :redis_cache_store, { url: Jiki.config.redis_url }
```

**2. Update Active Storage** (Line 22):
```ruby
# Change from :local to :amazon for production
config.active_storage.service = :amazon
```

**3. Add allowed hosts** (Lines 79-85):
```ruby
# Enable DNS rebinding protection and other `Host` header attacks.
config.hosts = [
  "api.jiki.io",                    # Production domain
  /.*\.jiki\.io/,                   # Subdomains
  IPAddr.new("10.0.0.0/8"),         # VPC private IPs (ECS tasks)
]

# Or exclude health check from host checking
config.host_authorization = {
  exclude: ->(request) {
    request.path == "/up" || request.path == "/health" || request.path == "/health/ready"
  }
}
```

**4. Add comprehensive health check controller**:
```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :authenticate_user!, only: [:show, :ready], if: -> { defined?(:authenticate_user!) }

  # Liveness probe - is the app running?
  def show
    render json: { status: 'ok' }, status: :ok
  end

  # Readiness probe - can the app serve traffic?
  def ready
    checks = {
      database: check_database,
      redis: check_redis
    }

    if checks.values.all?
      render json: { status: 'ready', checks: checks }, status: :ok
    else
      render json: { status: 'not_ready', checks: checks }, status: :service_unavailable
    end
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    true
  rescue => e
    Rails.logger.error("Database health check failed: #{e.message}")
    false
  end

  def check_redis
    redis_url = Jiki.config.sidekiq_redis_url
    Redis.new(url: redis_url).ping == 'PONG'
    true
  rescue => e
    Rails.logger.error("Redis health check failed: #{e.message}")
    false
  end
end
```

**Add routes**:
```ruby
# config/routes.rb
get "health" => "health#show"           # Liveness
get "health/ready" => "health#ready"    # Readiness
```

**5. Configure storage.yml for S3**:
```yaml
# config/storage.yml
amazon:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: eu-west-1
  bucket: jiki-api-storage
```

---

## Phase 2: Core Infrastructure (Terraform)

### 2.1 Networking

**Current state**:
- ✅ VPC exists (`terraform/terraform/aws/vpc.tf`) - 10.1.0.0/16
- ✅ Internet gateway exists
- ✅ Public subnets exist (one per AZ)
- ✅ Route table configured

**No changes needed** - we'll use public subnets for ECS tasks (cost optimization).

**Future optimizations** (skip for now):
- Private subnets + NAT Gateway (adds ~$32/month)
- VPC endpoints for DynamoDB/S3 (cost optimization at scale)

### 2.2 Security Groups

**Create new file**: `terraform/terraform/aws/security_groups.tf`

```hcl
# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "jiki-alb"
  description = "Security group for Jiki API load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jiki-alb"
  }
}

# ECS Tasks Security Group
resource "aws_security_group" "ecs_tasks" {
  name        = "jiki-ecs-tasks"
  description = "Security group for Jiki ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jiki-ecs-tasks"
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "jiki-rds"
  description = "Security group for Jiki RDS database"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from ECS tasks"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jiki-rds"
  }
}

# ElastiCache Security Group
resource "aws_security_group" "elasticache" {
  name        = "jiki-elasticache"
  description = "Security group for Jiki ElastiCache"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis from ECS tasks"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jiki-elasticache"
  }
}
```

### 2.3 IAM Roles & Policies

**Create new file**: `terraform/terraform/aws/iam.tf`

```hcl
# ECS Task Execution Role (used by ECS to pull images, write logs)
resource "aws_iam_role" "ecs_task_execution" {
  name = "jiki-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "jiki-ecs-task-execution-role"
  }
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for Secrets Manager access
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  name = "jiki-ecs-task-execution-secrets"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "kms:Decrypt"
      ]
      Resource = [
        aws_secretsmanager_secret.rails_master_key.arn,
        aws_secretsmanager_secret.database_password.arn
      ]
    }]
  })
}

# ECS Task Role (used by running containers to access AWS services)
resource "aws_iam_role" "ecs_task" {
  name = "jiki-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "jiki-ecs-task-role"
  }
}

# S3 access policy
resource "aws_iam_role_policy" "ecs_task_s3" {
  name = "jiki-ecs-task-s3"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.api_storage.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.api_storage.arn
      }
    ]
  })
}

# DynamoDB config read policy
resource "aws_iam_role_policy" "ecs_task_dynamodb" {
  name = "jiki-ecs-task-dynamodb"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ]
      Resource = aws_dynamodb_table.config.arn
    }]
  })
}

# CloudWatch Logs write policy
resource "aws_iam_role_policy" "ecs_task_logs" {
  name = "jiki-ecs-task-logs"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}
```

---

## Phase 3: Data Layer

### 3.1 Aurora PostgreSQL Serverless v2

**Create new file**: `terraform/terraform/aws/rds.tf`

```hcl
# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "jiki-main"
  subnet_ids = aws_subnet.publics[*].id

  tags = {
    Name = "jiki-main-db-subnet-group"
  }
}

# Aurora Cluster (Serverless v2)
resource "aws_rds_cluster" "main" {
  cluster_identifier     = "jiki-production"
  engine                 = "aurora-postgresql"
  engine_mode            = "provisioned"
  engine_version         = "16.6"
  database_name          = "jiki_production"
  master_username        = "jiki"
  master_password        = random_password.database_password.result

  # Serverless v2 scaling
  serverlessv2_scaling_configuration {
    min_capacity = 0    # Scales to zero when idle
    max_capacity = 1    # Max 1 ACU for cost control
  }

  # Network
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Backups
  backup_retention_period = 7
  preferred_backup_window = "03:00-04:00"

  # Maintenance
  preferred_maintenance_window = "mon:04:00-mon:05:00"

  # Performance Insights
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Single-AZ for cost optimization
  # Change to true for production HA
  # availability_zones = data.aws_availability_zones.available.names

  skip_final_snapshot = false
  final_snapshot_identifier = "jiki-production-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  tags = {
    Name        = "jiki-production"
    Environment = "production"
  }
}

# Aurora Instance (Serverless v2)
resource "aws_rds_cluster_instance" "main" {
  identifier         = "jiki-production-instance-1"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  # Performance Insights
  performance_insights_enabled = true

  tags = {
    Name        = "jiki-production-instance-1"
    Environment = "production"
  }
}

# Random password for database
resource "random_password" "database_password" {
  length  = 32
  special = true
}

# Output database endpoint (for DynamoDB config)
output "database_endpoint" {
  value     = aws_rds_cluster.main.endpoint
  sensitive = false
}

output "database_url" {
  value     = "postgresql://jiki:${random_password.database_password.result}@${aws_rds_cluster.main.endpoint}:5432/jiki_production"
  sensitive = true
}
```

### 3.2 ElastiCache Serverless for Redis

**Create new file**: `terraform/terraform/aws/elasticache.tf`

```hcl
# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name       = "jiki-main"
  subnet_ids = aws_subnet.publics[*].id

  tags = {
    Name = "jiki-elasticache-subnet-group"
  }
}

# ElastiCache Serverless for Redis
resource "aws_elasticache_serverless_cache" "main" {
  engine = "redis"
  name   = "jiki-redis"

  cache_usage_limits {
    data_storage {
      maximum = 10
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = 5000  # Auto-scales up to this
    }
  }

  # Network
  subnet_ids         = aws_subnet.publics[*].id
  security_group_ids = [aws_security_group.elasticache.id]

  tags = {
    Name        = "jiki-redis"
    Environment = "production"
  }
}

# Output Redis endpoint
output "redis_endpoint" {
  value = aws_elasticache_serverless_cache.main.endpoint[0].address
}

output "redis_url" {
  value = "redis://${aws_elasticache_serverless_cache.main.endpoint[0].address}:${aws_elasticache_serverless_cache.main.endpoint[0].port}/0"
}
```

### 3.3 S3 Bucket for Active Storage

**Create new file**: `terraform/terraform/aws/s3.tf`

```hcl
# S3 bucket for Active Storage uploads
resource "aws_s3_bucket" "api_storage" {
  bucket = "jiki-api-storage"

  tags = {
    Name        = "Jiki API Storage"
    Environment = "production"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "api_storage" {
  bucket = aws_s3_bucket.api_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "api_storage" {
  bucket = aws_s3_bucket.api_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "api_storage" {
  bucket = aws_s3_bucket.api_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle rule to clean up old versions
resource "aws_s3_bucket_lifecycle_configuration" "api_storage" {
  bucket = aws_s3_bucket.api_storage.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Output bucket name
output "s3_bucket_name" {
  value = aws_s3_bucket.api_storage.bucket
}
```

---

## Phase 4: Configuration Management

### 4.1 DynamoDB Config Table ✅ COMPLETED

**Status**: ✅ Deployed to production

**File**: `terraform/terraform/aws/dynamodb.tf`

**What was created**:
- DynamoDB table `jiki-config` with provisioned capacity (1 read/1 write)
- 14 configuration items populated from Terraform
- IAM policy `jiki-read-dynamodb-config` for ECS task access

**Configuration items**:
- **Hardcoded production values**:
  - `frontend_base_url` → `https://jiki.io`
  - `admin_base_url` → `https://admin.jiki.io`
  - `spi_base_url` → `https://spi.jiki.io`
  - `llm_proxy_url` → `https://llm.jiki.io/exec`
  - `aurora_port` → `5432`
  - `aurora_database_name` → `jiki_production`

- **Dynamic from Cloudflare**:
  - `r2_account_id` → From Cloudflare account
  - `r2_bucket_assets` → `assets`
  - `assets_cdn_url` → `https://assets.jiki.io`

- **Dynamic from AWS**:
  - `s3_bucket_video_production` → `jiki-video-production`

- **TODO placeholders** (update before production):
  - `stripe_publishable_key` → Replace with `pk_live_*`
  - `stripe_premium_price_id` → Replace with production price ID
  - `stripe_max_price_id` → Replace with production price ID

**Cost**: ~$0.01/month (effectively free with minimal reads/writes)

**Next steps**:
- ✅ Integrate with jiki-config gem to read from DynamoDB in production
- ⚠️ Update Stripe values before going live
- 📝 Uncomment `aurora_endpoint` item after RDS is created

### 4.2 AWS Secrets Manager

**Create new file**: `terraform/terraform/aws/secrets.tf`

```hcl
# Secret for Rails master key
resource "aws_secretsmanager_secret" "rails_master_key" {
  name        = "jiki/production/rails-master-key"
  description = "Rails master key for encrypted credentials"

  tags = {
    Name        = "jiki-rails-master-key"
    Environment = "production"
  }
}

# Secret for database password
resource "aws_secretsmanager_secret" "database_password" {
  name        = "jiki/production/database-password"
  description = "Aurora PostgreSQL master password"

  tags = {
    Name        = "jiki-database-password"
    Environment = "production"
  }
}

# Store the generated password
resource "aws_secretsmanager_secret_version" "database_password" {
  secret_id     = aws_secretsmanager_secret.database_password.id
  secret_string = random_password.database_password.result
}

# Note: Rails master key should be set manually:
# aws secretsmanager put-secret-value \
#   --secret-id jiki/production/rails-master-key \
#   --secret-string "$(cat config/master.key)"

# Outputs for reference
output "rails_master_key_secret_arn" {
  value = aws_secretsmanager_secret.rails_master_key.arn
}

output "database_password_secret_arn" {
  value = aws_secretsmanager_secret.database_password.arn
}
```

---

## Phase 5: Container Registry

### 5.1 ECR Repository

**Create new file**: `terraform/terraform/aws/ecr.tf`

```hcl
# ECR repository for API images
resource "aws_ecr_repository" "api" {
  name                 = "jiki/api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "jiki-api"
    Environment = "production"
  }
}

# Lifecycle policy to keep only last 10 images
resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# Output repository URL
output "ecr_repository_url" {
  value = aws_ecr_repository.api.repository_url
}
```

---

## Phase 6: ECS Services

### 6.1 ECS Cluster

**Create new file**: `terraform/terraform/aws/ecs_cluster.tf`

```hcl
# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "jiki-production"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "jiki-production"
    Environment = "production"
  }
}

# Output cluster name
output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}
```

### 6.2 Web Service

**Create new file**: `terraform/terraform/aws/ecs_web.tf`

```hcl
# Task definition for web service
resource "aws_ecs_task_definition" "web" {
  family                   = "jiki-api-web"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "web"
    image     = "${aws_ecr_repository.api.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]

    environment = [
      { name = "RAILS_ENV", value = "production" },
      { name = "RAILS_LOG_TO_STDOUT", value = "true" },
      { name = "RAILS_SERVE_STATIC_FILES", value = "false" },
      { name = "WEB_CONCURRENCY", value = "2" },
      { name = "RAILS_MAX_THREADS", value = "5" }
    ]

    secrets = [
      {
        name      = "RAILS_MASTER_KEY"
        valueFrom = aws_secretsmanager_secret.rails_master_key.arn
      }
    ]

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost/up || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.web.name
        "awslogs-region"        = "eu-west-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = {
    Name        = "jiki-api-web"
    Environment = "production"
  }
}

# ECS Service for web
resource "aws_ecs_service" "web" {
  name            = "jiki-api-web"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.publics[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = "web"
    container_port   = 80
  }

  health_check_grace_period_seconds = 300  # 5 minutes for migrations

  # Deployment configuration
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  depends_on = [
    aws_lb_listener.https,
    aws_iam_role_policy.ecs_task_s3,
    aws_iam_role_policy.ecs_task_dynamodb
  ]

  tags = {
    Name        = "jiki-api-web"
    Environment = "production"
  }
}

# Auto-scaling target
resource "aws_appautoscaling_target" "web" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto-scaling policy (CPU)
resource "aws_appautoscaling_policy" "web_cpu" {
  name               = "jiki-web-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.web.resource_id
  scalable_dimension = aws_appautoscaling_target.web.scalable_dimension
  service_namespace  = aws_appautoscaling_target.web.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
```

### 6.3 Sidekiq Service

**Create new file**: `terraform/terraform/aws/ecs_sidekiq.tf`

```hcl
# Task definition for Sidekiq workers
resource "aws_ecs_task_definition" "sidekiq" {
  family                   = "jiki-api-sidekiq"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "sidekiq"
    image     = "${aws_ecr_repository.api.repository_url}:latest"
    essential = true

    command = ["bundle", "exec", "sidekiq"]

    environment = [
      { name = "RAILS_ENV", value = "production" },
      { name = "RAILS_LOG_TO_STDOUT", value = "true" }
    ]

    secrets = [
      {
        name      = "RAILS_MASTER_KEY"
        valueFrom = aws_secretsmanager_secret.rails_master_key.arn
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.sidekiq.name
        "awslogs-region"        = "eu-west-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = {
    Name        = "jiki-api-sidekiq"
    Environment = "production"
  }
}

# ECS Service for Sidekiq
resource "aws_ecs_service" "sidekiq" {
  name            = "jiki-api-sidekiq"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.sidekiq.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.publics[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  depends_on = [
    aws_iam_role_policy.ecs_task_s3,
    aws_iam_role_policy.ecs_task_dynamodb
  ]

  tags = {
    Name        = "jiki-api-sidekiq"
    Environment = "production"
  }
}
```

---

## Phase 7: Load Balancer & DNS

### 7.1 Application Load Balancer

**Create new file**: `terraform/terraform/aws/alb.tf`

```hcl
# Application Load Balancer
resource "aws_lb" "main" {
  name               = "jiki-api-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.publics[*].id

  enable_deletion_protection = false  # Change to true for production
  enable_http2               = true

  tags = {
    Name        = "jiki-api-alb"
    Environment = "production"
  }
}

# Target group for web service
resource "aws_lb_target_group" "web" {
  name        = "jiki-api-web"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health/ready"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "jiki-api-web-tg"
  }
}

# HTTP listener (redirect to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.api.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# ACM Certificate for api.jiki.io
resource "aws_acm_certificate" "api" {
  domain_name       = "api.jiki.io"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "api.jiki.io"
  }
}

# Output ALB DNS name
output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "acm_certificate_validation_records" {
  value = {
    for dvo in aws_acm_certificate.api.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      value  = dvo.resource_record_value
    }
  }
}
```

### 7.2 DNS Configuration

**Update Cloudflare module** (assuming you're using Cloudflare):

```hcl
# terraform/terraform/cloudflare/dns.tf (add to existing file)

# CNAME for api.jiki.io pointing to ALB
resource "cloudflare_record" "api" {
  zone_id = data.cloudflare_zone.jiki.id
  name    = "api"
  value   = var.alb_dns_name  # Pass from AWS module
  type    = "CNAME"
  ttl     = 1  # Auto TTL
  proxied = false  # Don't proxy through Cloudflare (use ACM cert on ALB)

  comment = "API load balancer"
}
```

**Update main.tf to pass outputs**:
```hcl
# terraform/terraform/main.tf
module "cloudflare" {
  source = "./cloudflare"

  alb_dns_name = module.aws.alb_dns_name
}
```

---

## Phase 8: Observability

### 8.1 CloudWatch Logs

**Create new file**: `terraform/terraform/aws/cloudwatch.tf`

```hcl
# Log group for web service
resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/jiki-api-web"
  retention_in_days = 7

  tags = {
    Name        = "jiki-api-web-logs"
    Environment = "production"
  }
}

# Log group for Sidekiq service
resource "aws_cloudwatch_log_group" "sidekiq" {
  name              = "/ecs/jiki-api-sidekiq"
  retention_in_days = 7

  tags = {
    Name        = "jiki-api-sidekiq-logs"
    Environment = "production"
  }
}
```

### 8.2 CloudWatch Alarms

**Add to cloudwatch.tf**:

```hcl
# SNS topic for alarms (optional - configure email subscription manually)
resource "aws_sns_topic" "alarms" {
  name = "jiki-api-alarms"

  tags = {
    Name = "jiki-api-alarms"
  }
}

# High CPU alarm for web service
resource "aws_cloudwatch_metric_alarm" "web_cpu_high" {
  alarm_name          = "jiki-web-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS web service CPU utilization"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.web.name
  }
}

# High 5xx error rate alarm
resource "aws_cloudwatch_metric_alarm" "web_5xx_errors" {
  alarm_name          = "jiki-web-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors 5xx errors from the API"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.web.arn_suffix
  }
}

# Database connection errors alarm
resource "aws_cloudwatch_metric_alarm" "database_connections" {
  alarm_name          = "jiki-database-connection-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"  # 80% of max connections
  alarm_description   = "Database connection count is high"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    DBClusterIdentifier = aws_rds_cluster.main.cluster_identifier
  }
}
```

---

## Deployment Process

### Initial Deployment

**1. Build and push Docker image**:
```bash
# Authenticate to ECR
aws ecr get-login-password --region eu-west-1 --profile jiki | docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-west-1.amazonaws.com

# Build image
docker build -t jiki/api:latest .

# Tag for ECR
docker tag jiki/api:latest <account-id>.dkr.ecr.eu-west-1.amazonaws.com/jiki/api:latest

# Push to ECR
docker push <account-id>.dkr.ecr.eu-west-1.amazonaws.com/jiki/api:latest
```

**2. Set Rails master key in Secrets Manager**:
```bash
aws secretsmanager put-secret-value \
  --secret-id jiki/production/rails-master-key \
  --secret-string "$(cat config/master.key)" \
  --profile jiki
```

**3. Apply Terraform**:
```bash
cd terraform/terraform
terraform init
terraform plan
terraform apply
```

**4. Update DNS**:
- Get ACM certificate validation records from Terraform output
- Add DNS validation records to Cloudflare
- Wait for certificate validation (~5-10 minutes)

**5. Deploy ECS services**:
```bash
# Force new deployment after image push
aws ecs update-service \
  --cluster jiki-production \
  --service jiki-api-web \
  --force-new-deployment \
  --profile jiki

aws ecs update-service \
  --cluster jiki-production \
  --service jiki-api-sidekiq \
  --force-new-deployment \
  --profile jiki
```

### Subsequent Deployments

```bash
# 1. Build and push new image
docker build -t jiki/api:$(git rev-parse --short HEAD) .
docker tag jiki/api:$(git rev-parse --short HEAD) <ecr-url>/jiki/api:latest
docker push <ecr-url>/jiki/api:latest

# 2. Update ECS services (triggers rolling deployment)
aws ecs update-service --cluster jiki-production --service jiki-api-web --force-new-deployment --profile jiki
aws ecs update-service --cluster jiki-production --service jiki-api-sidekiq --force-new-deployment --profile jiki
```

---

## Migration Strategy

### Current State → Future State

**Migrations run in entrypoint** (Exercism pattern):
- ✅ Simple, zero-config deployment
- ✅ Works with rolling deployments
- ✅ Random sleep prevents thundering herd
- ✅ Rails handles concurrent migration locking

**When to migrate to pre-deployment task**:
- Migrations regularly take >60 seconds
- Need explicit rollback protection
- Want to reduce database connection pressure

---

## Cost Breakdown (Estimated Monthly)

| Service | Configuration | Cost |
|---------|--------------|------|
| Aurora Serverless v2 | 0-1 ACU, mostly paused | $20-40 |
| ECS Fargate | 1 web (512/1024) + 1 worker (256/512) | ~$30 |
| ElastiCache Serverless | Auto-scaling, low usage | ~$10-15 |
| Application Load Balancer | Standard ALB | ~$20 |
| ECR | <50GB storage | Free |
| S3 | Storage + requests | ~$5 |
| Data Transfer | Minimal | ~$5 |
| CloudWatch Logs | 7-day retention | ~$3 |
| **Total** | | **~$93-118/month** |

**Notes**:
- Aurora scales to 0 ACU when idle (saves $43/month during off-hours)
- ECS costs based on vCPU-hours and GB-hours
- Costs increase with traffic (auto-scaling)

---

## Timeline

| Phase | Tasks | Estimated Time |
|-------|-------|----------------|
| 1 | Application preparation | 2-3 hours |
| 2 | Core infrastructure (Terraform) | 1 hour |
| 3 | Data layer (RDS, Redis, S3) | 1-2 hours |
| 4 | Configuration (DynamoDB, Secrets) | 1 hour |
| 5 | Container registry (ECR) | 30 min |
| 6 | ECS services | 2-3 hours |
| 7 | Load balancer & DNS | 1-2 hours |
| 8 | Observability | 1 hour |
| | **Total** | **9-13 hours** |

---

## Checklist

### Pre-Deployment
- [ ] Copy migration concurrent guard from Exercism
- [ ] Update `bin/docker-entrypoint` to use guard
- [ ] Add HEALTHCHECK to Dockerfile
- [ ] Update Puma configuration (workers, port, preload)
- [ ] Update database.yml pool calculation
- [ ] Configure Redis cache store in production.rb
- [ ] Change Active Storage to :amazon
- [ ] Add config.hosts for ECS IPs
- [ ] Create health check controller
- [ ] Update storage.yml for S3

### Terraform
- [ ] Create all new Terraform files
- [ ] Update aws/variables.tf with any needed variables
- [ ] Update aws/outputs.tf with new outputs
- [ ] Update aws/providers.tf if needed
- [ ] Test `terraform plan` locally

### AWS Setup
- [ ] Create ECR repository (or via Terraform)
- [ ] Build and push initial Docker image
- [ ] Set Rails master key in Secrets Manager
- [ ] Apply Terraform
- [ ] Add ACM validation records to Cloudflare
- [ ] Wait for certificate validation
- [ ] Deploy ECS services

### Post-Deployment
- [ ] Test API at https://api.jiki.io/up
- [ ] Test health endpoints (/health, /health/ready)
- [ ] Check CloudWatch logs
- [ ] Verify database connectivity
- [ ] Verify Redis connectivity
- [ ] Test Active Storage uploads
- [ ] Configure SNS email subscription for alarms
- [ ] Update jiki-config gem to read from DynamoDB

---

## Troubleshooting

### Common Issues

**1. ECS tasks fail to start**
- Check CloudWatch logs: `/ecs/jiki-api-web`
- Verify RAILS_MASTER_KEY is set correctly in Secrets Manager
- Check security groups allow ECS → RDS/ElastiCache

**2. Migrations fail with timeout**
- Increase health check grace period (currently 300s)
- Check database connectivity from ECS task
- Verify random sleep isn't too long (max 30s)

**3. Health checks fail**
- Test `/health/ready` endpoint manually
- Verify database and Redis are accessible
- Check security group rules

**4. Can't connect to database**
- Verify RDS security group allows inbound from ECS security group
- Check database endpoint in DynamoDB config table
- Ensure jiki-config gem is reading from DynamoDB

**5. High costs**
- Check Aurora isn't staying at 1 ACU constantly (should scale to 0 when idle)
- Verify ElastiCache Serverless is scaling down
- Review CloudWatch logs retention (7 days)

---

## Future Enhancements

**After initial deployment**:
- [ ] Set up CI/CD pipeline (GitHub Actions)
- [ ] Add pre-deployment migration task (if migrations get slow)
- [ ] Enable Multi-AZ for Aurora (high availability)
- [ ] Add private subnets + NAT Gateway (if needed)
- [ ] Add VPC endpoints for DynamoDB/S3 (cost optimization)
- [ ] Set up monitoring dashboard
- [ ] Configure autoscaling for Sidekiq based on queue depth
- [ ] Add staging environment
- [ ] Implement blue/green deployment strategy
- [ ] Add AWS WAF for ALB (DDoS protection)

---

## References

- [Exercism Terraform](../../exercism/terraform/terraform/)
- [Rails 8 Deployment Guide](https://guides.rubyonrails.org/deploying_rails_applications.html)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Aurora Serverless v2](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html)
- [ElastiCache Serverless](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/serverless.html)
