# AWS SES Email Infrastructure - Implementation Plan

**Status**: Terraform infrastructure complete, API changes pending
**Last Updated**: 2025-11-19
**Timeline**: December 2025 → March 2026 (4 months)
**Architecture**: AWS SES Managed Dedicated IPs with 3 subdomains

---

## ✅ Implementation Progress

### Completed (2025-11-19)

**Terraform Infrastructure** ([PR #5](https://github.com/jiki-education/terraform/pull/5)):
- ✅ AWS SES domain identities (3 subdomains)
- ✅ Easy DKIM configuration (AWS-managed keys)
- ✅ Custom MAIL FROM domains
- ✅ Configuration sets with SNS event destinations
- ✅ CloudWatch alarms (6 total: bounce + complaint rate monitoring)
- ✅ IAM permissions for ECS tasks to send emails
- ✅ DynamoDB configuration items (8 SES config values)
- ✅ Cloudflare DNS records (18 total: DKIM, MX, SPF, DMARC)
- ✅ Automatic DKIM token passing between AWS and Cloudflare modules

**What's Left**:
- ⏳ Manual AWS Console steps (production access, managed IPs, SNS confirmations)
- ⏳ API implementation (mailers, webhook handlers, email templates)
- ⏳ Testing and verification

---

## Overview

### Email Infrastructure Design

**3 Subdomains with Managed Dedicated IPs**:

| Subdomain | Purpose | Volume (March) | Volume (Month 6) |
|-----------|---------|----------------|------------------|
| `mail.jiki.io` | Auth, payments (transactional) | ~70k/month (2,300/day) | ~70k/month |
| `notifications.jiki.io` | Learning notifications | ~600k/month (20,000/day) | ~3.6M/month |
| `hello.jiki.io` | Marketing newsletters | ~60k/month (2,000/day) | ~360k/month |
| **Total** | | **~730k/month** | **~4M/month** |

**Why Managed Dedicated IPs?**
- AWS auto-warms IPs over 45 days (aligns with Jan-Feb 2026 soft launch)
- Auto-scales IP count as volume grows
- Cheaper than shared IPs at scale (break-even: ~850k/month)
- Full reputation control with zero DevOps burden
- One-time setup, no future migrations

**Cost**:
- Month 1 (70k emails): ~$21/month
- Month 3 (840k emails): ~$85/month
- Month 6 (4M emails): ~$353/month
- Savings vs shared IPs at scale: ~$50-145/month

---

## Launch Timeline

### December 2025 (Setup)
- Configure Terraform infrastructure
- Request SES production access
- Enable Managed Dedicated IPs
- Set up DNS records
- Deploy API changes
- **AWS begins automatic IP warm-up**

### January 2026 (5k users, ~70k emails)
- Soft launch to 5k Exercism users
- AWS warm-up in progress (week 1-4 of 45 days)
- Low volume naturally aligns with warm-up
- Monitor bounce/complaint rates

### February 2026 (20k users, ~280k emails)
- Expand to 20k users
- AWS warm-up completing (week 5-8 of 45 days)
- Volume ramping naturally

### March 2026 (60k+ users, ~840k emails)
- Public launch
- **IPs fully warmed and ready**
- Full production monitoring
- Infrastructure ready for millions of emails/month

---

## Implementation Sections

This plan is divided into three parts:

1. **[AWS (Terraform)](#aws-terraform)** - Infrastructure as code (`../terraform/terraform/aws/`)
2. **[AWS (Manual)](#aws-manual)** - Console/CLI operations that can't be automated
3. **[API Changes](#api-changes)** - Rails application code (`/Users/iHiD/Code/jiki/api/`)

---

## AWS (Terraform)

All Terraform files are in `../terraform/terraform/aws/`

### 1. SES Domain Identities and Configuration

**File**: `ses.tf` (new file)

```hcl
# ============================================================================
# AWS SES Email Infrastructure
# ============================================================================
#
# Architecture: 3 subdomains with Managed Dedicated IPs
# - mail.jiki.io: Transactional emails (auth, payments)
# - notifications.jiki.io: Learning notifications
# - hello.jiki.io: Marketing newsletters
#
# Note: Managed Dedicated IPs enabled manually via AWS Console
# (no Terraform resource available as of Dec 2025)

locals {
  email_domains = {
    mail = {
      domain      = "mail.jiki.io"
      description = "Transactional emails (auth, payments)"
      from_email  = "noreply@mail.jiki.io"
    }
    notifications = {
      domain      = "notifications.jiki.io"
      description = "Learning notifications"
      from_email  = "notifications@notifications.jiki.io"
    }
    marketing = {
      domain      = "hello.jiki.io"
      description = "Marketing newsletters"
      from_email  = "hello@hello.jiki.io"
    }
  }
}

# ----------------------------------------------------------------------------
# SES Domain Identities
# ----------------------------------------------------------------------------

resource "aws_ses_domain_identity" "email_domains" {
  for_each = local.email_domains
  domain   = each.value.domain
}

# ----------------------------------------------------------------------------
# Easy DKIM (AWS-managed 2048-bit RSA keys)
# ----------------------------------------------------------------------------

resource "aws_ses_domain_dkim" "email_domains" {
  for_each = local.email_domains
  domain   = aws_ses_domain_identity.email_domains[each.key].domain
}

# ----------------------------------------------------------------------------
# Custom MAIL FROM Domains
# ----------------------------------------------------------------------------
# Allows using bounce.{subdomain} instead of amazonses.com
# Improves deliverability and SPF alignment

resource "aws_ses_domain_mail_from" "email_domains" {
  for_each = local.email_domains

  domain           = aws_ses_domain_identity.email_domains[each.key].domain
  mail_from_domain = "bounce.${each.value.domain}"
}

# ----------------------------------------------------------------------------
# Configuration Sets (for tracking and event publishing)
# ----------------------------------------------------------------------------

resource "aws_ses_configuration_set" "email_domains" {
  for_each = local.email_domains

  name = replace(each.value.domain, ".", "-")

  delivery_options {
    tls_policy = "Require"
  }

  reputation_metrics_enabled = true
  sending_enabled            = true

  # Note: Managed Dedicated IP pool assignment done manually via Console
  # No Terraform resource available for managed dedicated IPs
}

# ----------------------------------------------------------------------------
# Event Destinations - Bounces
# ----------------------------------------------------------------------------

resource "aws_ses_event_destination" "bounce" {
  for_each = local.email_domains

  name                   = "${replace(each.value.domain, ".", "-")}-bounces"
  configuration_set_name = aws_ses_configuration_set.email_domains[each.key].name
  enabled                = true
  matching_types         = ["bounce"]

  sns_destination {
    topic_arn = aws_sns_topic.ses_bounces[each.key].arn
  }
}

# ----------------------------------------------------------------------------
# Event Destinations - Complaints
# ----------------------------------------------------------------------------

resource "aws_ses_event_destination" "complaint" {
  for_each = local.email_domains

  name                   = "${replace(each.value.domain, ".", "-")}-complaints"
  configuration_set_name = aws_ses_configuration_set.email_domains[each.key].name
  enabled                = true
  matching_types         = ["complaint"]

  sns_destination {
    topic_arn = aws_sns_topic.ses_complaints[each.key].arn
  }
}

# ----------------------------------------------------------------------------
# Event Destinations - CloudWatch Metrics
# ----------------------------------------------------------------------------

resource "aws_ses_event_destination" "cloudwatch" {
  for_each = local.email_domains

  name                   = "${replace(each.value.domain, ".", "-")}-metrics"
  configuration_set_name = aws_ses_configuration_set.email_domains[each.key].name
  enabled                = true
  matching_types         = ["send", "delivery", "open", "click", "bounce", "complaint"]

  cloudwatch_destination {
    default_value_source = "emailHeader"

    dimension_configuration {
      dimension_name         = "ses:configuration-set"
      dimension_value_source = "emailHeader"
      default_value          = aws_ses_configuration_set.email_domains[each.key].name
    }
  }
}

# ----------------------------------------------------------------------------
# SNS Topics - Bounces
# ----------------------------------------------------------------------------

resource "aws_sns_topic" "ses_bounces" {
  for_each = local.email_domains

  name         = "jiki-ses-bounces-${each.key}"
  display_name = "SES Bounces - ${each.value.domain}"
}

resource "aws_sns_topic_subscription" "ses_bounces" {
  for_each = local.email_domains

  topic_arn = aws_sns_topic.ses_bounces[each.key].arn
  protocol  = "https"
  endpoint  = "https://api.jiki.io/webhooks/ses"

  # SNS will send confirmation request to this endpoint
  # Must be confirmed manually or via webhook handler
}

# ----------------------------------------------------------------------------
# SNS Topics - Complaints
# ----------------------------------------------------------------------------

resource "aws_sns_topic" "ses_complaints" {
  for_each = local.email_domains

  name         = "jiki-ses-complaints-${each.key}"
  display_name = "SES Complaints - ${each.value.domain}"
}

resource "aws_sns_topic_subscription" "ses_complaints" {
  for_each = local.email_domains

  topic_arn = aws_sns_topic.ses_complaints[each.key].arn
  protocol  = "https"
  endpoint  = "https://api.jiki.io/webhooks/ses"
}

# ----------------------------------------------------------------------------
# Outputs (for debugging and manual verification)
# ----------------------------------------------------------------------------

output "ses_domain_identities" {
  description = "SES domain identities and their verification status"
  value = {
    for k, v in aws_ses_domain_identity.email_domains : k => {
      domain             = v.domain
      verification_token = v.verification_token
      arn                = v.arn
    }
  }
}

output "ses_dkim_tokens" {
  description = "DKIM tokens for DNS configuration (use these in Cloudflare)"
  value = {
    for k, v in aws_ses_domain_dkim.email_domains : k => {
      domain       = v.domain
      dkim_tokens  = v.dkim_tokens
    }
  }
}

output "ses_mail_from_domains" {
  description = "Custom MAIL FROM domains for MX/SPF DNS records"
  value = {
    for k, v in aws_ses_domain_mail_from.email_domains : k => {
      domain           = v.domain
      mail_from_domain = v.mail_from_domain
    }
  }
}

output "ses_configuration_sets" {
  description = "SES configuration sets"
  value = {
    for k, v in aws_ses_configuration_set.email_domains : k => {
      name = v.name
      arn  = v.arn
    }
  }
}
```

### 2. IAM Permissions for ECS Tasks

**File**: `iam.tf` (append to existing task role)

```hcl
# ----------------------------------------------------------------------------
# SES Sending Permissions for ECS Tasks
# ----------------------------------------------------------------------------

resource "aws_iam_policy" "ecs_ses_sending" {
  name        = "jiki-ecs-ses-sending"
  description = "Allow ECS tasks to send emails via SES"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail",
          "ses:SendTemplatedEmail"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ses:GetAccount",
          "ses:GetConfigurationSet"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_ses" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_ses_sending.arn
}
```

### 3. DynamoDB Configuration Items

**File**: `dynamodb.tf` (append to existing config table)

```hcl
# ----------------------------------------------------------------------------
# SES Configuration in DynamoDB
# ----------------------------------------------------------------------------

resource "aws_dynamodb_table_item" "config_ses_region" {
  table_name = aws_dynamodb_table.config.name
  hash_key   = aws_dynamodb_table.config.hash_key

  item = jsonencode({
    key = { S = "ses_region" }
    value = { S = var.aws_region }
  })
}

resource "aws_dynamodb_table_item" "config_mail_configuration_set" {
  table_name = aws_dynamodb_table.config.name
  hash_key   = aws_dynamodb_table.config.hash_key

  item = jsonencode({
    key = { S = "ses_mail_configuration_set" }
    value = { S = "mail-jiki-io" }
  })
}

resource "aws_dynamodb_table_item" "config_notifications_configuration_set" {
  table_name = aws_dynamodb_table.config.name
  hash_key   = aws_dynamodb_table.config.hash_key

  item = jsonencode({
    key = { S = "ses_notifications_configuration_set" }
    value = { S = "notifications-jiki-io" }
  })
}

resource "aws_dynamodb_table_item" "config_marketing_configuration_set" {
  table_name = aws_dynamodb_table.config.name
  hash_key   = aws_dynamodb_table.config.hash_key

  item = jsonencode({
    key = { S = "ses_marketing_configuration_set" }
    value = { S = "hello-jiki-io" }
  })
}

resource "aws_dynamodb_table_item" "config_mail_from_email" {
  table_name = aws_dynamodb_table.config.name
  hash_key   = aws_dynamodb_table.config.hash_key

  item = jsonencode({
    key = { S = "mail_from_email" }
    value = { S = "noreply@mail.jiki.io" }
  })
}

resource "aws_dynamodb_table_item" "config_notifications_from_email" {
  table_name = aws_dynamodb_table.config.name
  hash_key   = aws_dynamodb_table.config.hash_key

  item = jsonencode({
    key = { S = "notifications_from_email" }
    value = { S = "notifications@notifications.jiki.io" }
  })
}

resource "aws_dynamodb_table_item" "config_marketing_from_email" {
  table_name = aws_dynamodb_table.config.name
  hash_key   = aws_dynamodb_table.config.hash_key

  item = jsonencode({
    key = { S = "marketing_from_email" }
    value = { S = "hello@hello.jiki.io" }
  })
}

resource "aws_dynamodb_table_item" "config_support_email" {
  table_name = aws_dynamodb_table.config.name
  hash_key   = aws_dynamodb_table.config.hash_key

  item = jsonencode({
    key = { S = "support_email" }
    value = { S = "support@jiki.io" }
  })
}
```

### 4. CloudWatch Alarms for Email Monitoring

**File**: `cloudwatch.tf` (append to existing alarms)

```hcl
# ----------------------------------------------------------------------------
# SES Monitoring Alarms
# ----------------------------------------------------------------------------

# Bounce Rate Alarms (one per subdomain)

resource "aws_cloudwatch_metric_alarm" "ses_bounce_rate_mail" {
  alarm_name          = "jiki-ses-high-bounce-rate-mail"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Reputation.BounceRate"
  namespace           = "AWS/SES"
  period              = 300
  statistic           = "Average"
  threshold           = 0.05  # 5% bounce rate
  alarm_description   = "SES bounce rate exceeded 5% for mail.jiki.io"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "ses:configuration-set" = "mail-jiki-io"
  }

  alarm_actions = [aws_sns_topic.production_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "ses_bounce_rate_notifications" {
  alarm_name          = "jiki-ses-high-bounce-rate-notifications"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Reputation.BounceRate"
  namespace           = "AWS/SES"
  period              = 300
  statistic           = "Average"
  threshold           = 0.05
  alarm_description   = "SES bounce rate exceeded 5% for notifications.jiki.io"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "ses:configuration-set" = "notifications-jiki-io"
  }

  alarm_actions = [aws_sns_topic.production_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "ses_bounce_rate_marketing" {
  alarm_name          = "jiki-ses-high-bounce-rate-marketing"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Reputation.BounceRate"
  namespace           = "AWS/SES"
  period              = 300
  statistic           = "Average"
  threshold           = 0.05
  alarm_description   = "SES bounce rate exceeded 5% for hello.jiki.io"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "ses:configuration-set" = "hello-jiki-io"
  }

  alarm_actions = [aws_sns_topic.production_alerts.arn]
}

# Complaint Rate Alarms (one per subdomain)

resource "aws_cloudwatch_metric_alarm" "ses_complaint_rate_mail" {
  alarm_name          = "jiki-ses-high-complaint-rate-mail"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Reputation.ComplaintRate"
  namespace           = "AWS/SES"
  period              = 300
  statistic           = "Average"
  threshold           = 0.001  # 0.1% complaint rate
  alarm_description   = "SES complaint rate exceeded 0.1% for mail.jiki.io"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "ses:configuration-set" = "mail-jiki-io"
  }

  alarm_actions = [aws_sns_topic.production_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "ses_complaint_rate_notifications" {
  alarm_name          = "jiki-ses-high-complaint-rate-notifications"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Reputation.ComplaintRate"
  namespace           = "AWS/SES"
  period              = 300
  statistic           = "Average"
  threshold           = 0.001
  alarm_description   = "SES complaint rate exceeded 0.1% for notifications.jiki.io"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "ses:configuration-set" = "notifications-jiki-io"
  }

  alarm_actions = [aws_sns_topic.production_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "ses_complaint_rate_marketing" {
  alarm_name          = "jiki-ses-high-complaint-rate-marketing"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Reputation.ComplaintRate"
  namespace           = "AWS/SES"
  period              = 300
  statistic           = "Average"
  threshold           = 0.001
  alarm_description   = "SES complaint rate exceeded 0.1% for hello.jiki.io"
  treat_missing_data  = "notBreaching"

  dimensions = {
    "ses:configuration-set" = "hello-jiki-io"
  }

  alarm_actions = [aws_sns_topic.production_alerts.arn]
}

# Production Alerts SNS Topic (if not already created)

resource "aws_sns_topic" "production_alerts" {
  name         = "jiki-production-alerts"
  display_name = "Jiki Production Alerts"
}

resource "aws_sns_topic_subscription" "production_alerts_email" {
  topic_arn = aws_sns_topic.production_alerts.arn
  protocol  = "email"
  endpoint  = "ops@jiki.io"  # Change to actual ops email
}
```

### 5. Cloudflare DNS Configuration

**File**: `../terraform/terraform/cloudflare/dns.tf` (append)

```hcl
# ============================================================================
# SES Email DNS Records
# ============================================================================
#
# Required DNS records for 3 email subdomains:
# - Domain verification (TXT)
# - DKIM signing (3 CNAMEs per domain = 9 total)
# - Custom MAIL FROM - MX records (3 total)
# - Custom MAIL FROM - SPF records (3 total)
# - DMARC policies (3 total)
#
# Total: 21 DNS records

locals {
  # These values will be output by terraform apply in aws/ses.tf
  # Update these after initial apply to get actual DKIM tokens
  ses_dkim_tokens = {
    mail = [
      "token1-mail",
      "token2-mail",
      "token3-mail"
    ]
    notifications = [
      "token1-notifications",
      "token2-notifications",
      "token3-notifications"
    ]
    marketing = [
      "token1-marketing",
      "token2-marketing",
      "token3-marketing"
    ]
  }
}

# ----------------------------------------------------------------------------
# DKIM Records (3 per subdomain = 9 total)
# ----------------------------------------------------------------------------
# AWS provides 3 DKIM tokens per domain for redundancy
# These MUST be created as CNAMEs pointing to amazonses.com

# mail.jiki.io DKIM records
resource "cloudflare_record" "ses_dkim_mail_1" {
  zone_id = var.cloudflare_zone_id
  name    = "${local.ses_dkim_tokens.mail[0]}._domainkey.mail"
  type    = "CNAME"
  value   = "${local.ses_dkim_tokens.mail[0]}.dkim.amazonses.com"
  ttl     = 1  # Automatic TTL
  proxied = false
}

resource "cloudflare_record" "ses_dkim_mail_2" {
  zone_id = var.cloudflare_zone_id
  name    = "${local.ses_dkim_tokens.mail[1]}._domainkey.mail"
  type    = "CNAME"
  value   = "${local.ses_dkim_tokens.mail[1]}.dkim.amazonses.com"
  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "ses_dkim_mail_3" {
  zone_id = var.cloudflare_zone_id
  name    = "${local.ses_dkim_tokens.mail[2]}._domainkey.mail"
  type    = "CNAME"
  value   = "${local.ses_dkim_tokens.mail[2]}.dkim.amazonses.com"
  ttl     = 1
  proxied = false
}

# notifications.jiki.io DKIM records
resource "cloudflare_record" "ses_dkim_notifications_1" {
  zone_id = var.cloudflare_zone_id
  name    = "${local.ses_dkim_tokens.notifications[0]}._domainkey.notifications"
  type    = "CNAME"
  value   = "${local.ses_dkim_tokens.notifications[0]}.dkim.amazonses.com"
  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "ses_dkim_notifications_2" {
  zone_id = var.cloudflare_zone_id
  name    = "${local.ses_dkim_tokens.notifications[1]}._domainkey.notifications"
  type    = "CNAME"
  value   = "${local.ses_dkim_tokens.notifications[1]}.dkim.amazonses.com"
  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "ses_dkim_notifications_3" {
  zone_id = var.cloudflare_zone_id
  name    = "${local.ses_dkim_tokens.notifications[2]}._domainkey.notifications"
  type    = "CNAME"
  value   = "${local.ses_dkim_tokens.notifications[2]}.dkim.amazonses.com"
  ttl     = 1
  proxied = false
}

# hello.jiki.io DKIM records
resource "cloudflare_record" "ses_dkim_marketing_1" {
  zone_id = var.cloudflare_zone_id
  name    = "${local.ses_dkim_tokens.marketing[0]}._domainkey.hello"
  type    = "CNAME"
  value   = "${local.ses_dkim_tokens.marketing[0]}.dkim.amazonses.com"
  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "ses_dkim_marketing_2" {
  zone_id = var.cloudflare_zone_id
  name    = "${local.ses_dkim_tokens.marketing[1]}._domainkey.hello"
  type    = "CNAME"
  value   = "${local.ses_dkim_tokens.marketing[1]}.dkim.amazonses.com"
  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "ses_dkim_marketing_3" {
  zone_id = var.cloudflare_zone_id
  name    = "${local.ses_dkim_tokens.marketing[2]}._domainkey.hello"
  type    = "CNAME"
  value   = "${local.ses_dkim_tokens.marketing[2]}.dkim.amazonses.com"
  ttl     = 1
  proxied = false
}

# ----------------------------------------------------------------------------
# Custom MAIL FROM - MX Records (3 total)
# ----------------------------------------------------------------------------
# Allows bounces to come from bounce.{subdomain} instead of amazonses.com

resource "cloudflare_record" "ses_mail_from_mx_mail" {
  zone_id  = var.cloudflare_zone_id
  name     = "bounce.mail"
  type     = "MX"
  value    = "feedback-smtp.eu-west-1.amazonses.com"
  priority = 10
  ttl      = 1
  proxied  = false
}

resource "cloudflare_record" "ses_mail_from_mx_notifications" {
  zone_id  = var.cloudflare_zone_id
  name     = "bounce.notifications"
  type     = "MX"
  value    = "feedback-smtp.eu-west-1.amazonses.com"
  priority = 10
  ttl      = 1
  proxied  = false
}

resource "cloudflare_record" "ses_mail_from_mx_marketing" {
  zone_id  = var.cloudflare_zone_id
  name     = "bounce.hello"
  type     = "MX"
  value    = "feedback-smtp.eu-west-1.amazonses.com"
  priority = 10
  ttl      = 1
  proxied  = false
}

# ----------------------------------------------------------------------------
# Custom MAIL FROM - SPF Records (3 total)
# ----------------------------------------------------------------------------

resource "cloudflare_record" "ses_mail_from_spf_mail" {
  zone_id = var.cloudflare_zone_id
  name    = "bounce.mail"
  type    = "TXT"
  value   = "v=spf1 include:amazonses.com ~all"
  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "ses_mail_from_spf_notifications" {
  zone_id = var.cloudflare_zone_id
  name    = "bounce.notifications"
  type    = "TXT"
  value   = "v=spf1 include:amazonses.com ~all"
  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "ses_mail_from_spf_marketing" {
  zone_id = var.cloudflare_zone_id
  name    = "bounce.hello"
  type    = "TXT"
  value   = "v=spf1 include:amazonses.com ~all"
  ttl     = 1
  proxied = false
}

# ----------------------------------------------------------------------------
# DMARC Policy Records (3 total)
# ----------------------------------------------------------------------------
# Tells receiving servers how to handle emails that fail SPF/DKIM
# p=quarantine: Put suspicious emails in spam folder
# rua: Aggregate reports sent to this email
# ruf: Forensic (detailed) reports sent to this email
# fo=1: Send reports if either SPF or DKIM fails

resource "cloudflare_record" "dmarc_mail" {
  zone_id = var.cloudflare_zone_id
  name    = "_dmarc.mail"
  type    = "TXT"
  value   = "v=DMARC1; p=quarantine; rua=mailto:dmarc@jiki.io; ruf=mailto:dmarc@jiki.io; fo=1; adkim=s; aspf=s"
  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "dmarc_notifications" {
  zone_id = var.cloudflare_zone_id
  name    = "_dmarc.notifications"
  type    = "TXT"
  value   = "v=DMARC1; p=quarantine; rua=mailto:dmarc@jiki.io; ruf=mailto:dmarc@jiki.io; fo=1; adkim=s; aspf=s"
  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "dmarc_marketing" {
  zone_id = var.cloudflare_zone_id
  name    = "_dmarc.hello"
  type    = "TXT"
  value   = "v=DMARC1; p=quarantine; rua=mailto:dmarc@jiki.io; ruf=mailto:dmarc@jiki.io; fo=1; adkim=s; aspf=s"
  ttl     = 1
  proxied = false
}

# ----------------------------------------------------------------------------
# DMARC Reports Inbox (Optional but Recommended)
# ----------------------------------------------------------------------------
# Create dmarc@jiki.io as an alias to ops@jiki.io or dedicated inbox
# This will receive aggregate and forensic reports from ISPs
```

**Important**: After applying the AWS Terraform, you'll get DKIM tokens in the output. Update the `ses_dkim_tokens` local variable in this file with the actual values, then apply Cloudflare Terraform.

### Terraform Apply Steps

```bash
# 1. Navigate to Terraform directory
cd ../terraform/terraform

# 2. Apply AWS infrastructure first (to get DKIM tokens)
terraform apply -target=module.aws.aws_ses_domain_identity.email_domains
terraform apply -target=module.aws.aws_ses_domain_dkim.email_domains

# 3. Get DKIM tokens from output
terraform output ses_dkim_tokens

# 4. Update cloudflare/dns.tf with actual DKIM tokens

# 5. Apply all AWS infrastructure
terraform apply

# 6. Apply Cloudflare DNS
terraform apply -target=module.cloudflare

# 7. Verify DNS propagation (wait 5-10 minutes)
dig +short mail.jiki.io TXT
dig +short _dmarc.mail.jiki.io TXT
```

---

## AWS (Manual)

These steps must be done via AWS Console or CLI (not available in Terraform as of Dec 2025).

### 1. Request SES Production Access

**When**: December 2025 (before Jan 2026 launch)

**Steps**:
1. Go to AWS Console → Amazon SES → Account dashboard
2. Click **"Request production access"**
3. Fill out form:
   - **Mail type**: Transactional
   - **Website URL**: https://jiki.io
   - **Use case description**:
     ```
     Jiki is an educational platform teaching coding to beginners. We send:

     1. Transactional emails (signup verification, password resets, payment receipts)
        - User-initiated only
        - Expected by users
        - ~70,000/month

     2. Learning notifications (lesson completion, progress updates, streak reminders)
        - Triggered by user actions in the app
        - Helps users track their learning progress
        - ~600,000/month, scaling to 3.6M by mid-2025

     3. Marketing newsletters (monthly updates, feature announcements)
        - Sent to opted-in users only
        - One-click unsubscribe implemented
        - ~60,000/month

     All emails are sent to users who have created accounts and expect to receive them.
     We have bounce/complaint handling via SNS webhooks to maintain list hygiene.

     Estimated total volume: 730,000 emails/month at launch, scaling to 4M/month by mid-2026.
     ```
   - **Process compliance**: Describe how you handle bounces/complaints (SNS webhooks)
   - **Mailing list source**: Users who create accounts on jiki.io

4. Submit request
5. **Expected approval**: 24-48 hours

**After approval**:
- Your account will move from "Sandbox" to "Production" mode
- Sending quota will increase from 200/day to 50,000/day (or higher)
- You can send to any email address (not just verified ones)

### 2. Enable Managed Dedicated IPs

**When**: December 2025 (after production access approved)

**Steps**:
1. Go to AWS Console → Amazon SES → Dedicated IPs
2. Click **"Request dedicated IPs"**
3. Select **"Managed dedicated IPs"**
4. Review pricing: $15/month subscription + $0.08 per 1,000 emails
5. Click **"Subscribe"**
6. Wait for confirmation (immediate)

**What happens next**:
- AWS will automatically provision dedicated IPs as your volume grows
- First IP typically assigned within hours
- Warm-up starts automatically (45-day process)
- AWS manages everything (scaling, ISP optimization, warm-up)

### 3. Assign Configuration Sets to Managed IP Pool

**When**: December 2025 (after managed IPs enabled)

**Steps**:
1. Go to AWS Console → Amazon SES → Configuration sets
2. For each configuration set (`mail-jiki-io`, `notifications-jiki-io`, `hello-jiki-io`):
   - Click on the configuration set name
   - Go to **"Sending IP pool"** tab
   - Click **"Edit"**
   - Select **"Dedicated IP pool: Managed"**
   - Save changes

**Result**: All emails using these configuration sets will now send via managed dedicated IPs.

### 4. Verify Domain Identities

**When**: December 2025 (after Terraform apply and DNS propagation)

**Steps**:
1. Go to AWS Console → Amazon SES → Verified identities
2. Check that all 3 domains show **"Verified"** status:
   - `mail.jiki.io` ✅
   - `notifications.jiki.io` ✅
   - `hello.jiki.io` ✅

3. Click each domain and verify:
   - **DKIM status**: "Successful" ✅
   - **Custom MAIL FROM status**: "Successful" ✅
   - **DMARC**: Check via DNS lookup (not shown in console)

**If verification fails**:
```bash
# Check DNS propagation
dig +short mail.jiki.io TXT
dig +short <dkim-token>._domainkey.mail.jiki.io CNAME
dig +short bounce.mail.jiki.io MX
dig +short bounce.mail.jiki.io TXT
dig +short _dmarc.mail.jiki.io TXT

# Wait 5-60 minutes for DNS propagation, then retry verification
```

### 5. Confirm SNS Subscriptions

**When**: December 2025 (after API deployment)

**Steps**:
1. Deploy API with SNS webhook handler (see [API Changes](#api-changes))
2. Terraform creates SNS subscriptions, AWS sends confirmation requests to `https://api.jiki.io/webhooks/ses`
3. Your webhook handler should auto-confirm (see `Webhooks::SesController#confirm_subscription`)
4. Verify subscriptions confirmed:
   - AWS Console → SNS → Subscriptions
   - Check all 6 subscriptions show **"Confirmed"** status:
     - `jiki-ses-bounces-mail` → https://api.jiki.io/webhooks/ses ✅
     - `jiki-ses-bounces-notifications` → https://api.jiki.io/webhooks/ses ✅
     - `jiki-ses-bounces-marketing` → https://api.jiki.io/webhooks/ses ✅
     - `jiki-ses-complaints-mail` → https://api.jiki.io/webhooks/ses ✅
     - `jiki-ses-complaints-notifications` → https://api.jiki.io/webhooks/ses ✅
     - `jiki-ses-complaints-marketing` → https://api.jiki.io/webhooks/ses ✅

**If auto-confirmation fails**:
```bash
# Manual confirmation via CLI
aws sns confirm-subscription \
  --topic-arn arn:aws:sns:eu-west-1:ACCOUNT_ID:jiki-ses-bounces-mail \
  --token <TOKEN_FROM_SNS_MESSAGE> \
  --region eu-west-1 --profile jiki
```

### 6. Monitor VDM Dashboard (Virtual Deliverability Manager)

**When**: Ongoing (daily during launch, weekly after stable)

**Steps**:
1. Go to AWS Console → Amazon SES → Reputation metrics
2. Check **"Virtual Deliverability Manager"** dashboard:
   - **Bounce rate**: Must be <5% (target <2%)
   - **Complaint rate**: Must be <0.1%
   - **Deliverability by ISP**: Gmail, Outlook, Yahoo, etc.
   - **Engagement metrics**: Open rate, click rate

3. Set up CloudWatch dashboard (optional but recommended):
   - Create custom dashboard with SES metrics
   - Add graphs for bounce/complaint rates per subdomain
   - Add alarms (already configured in Terraform)

**Alert thresholds** (configured in Terraform):
- Bounce rate >5%: CloudWatch alarm fires
- Complaint rate >0.1%: CloudWatch alarm fires
- SNS alerts sent to ops@jiki.io

### 7. Test Email Sending

**When**: December 2025 (after all setup complete)

**Test checklist**:

```bash
# 1. SSH into ECS task or use Rails console
aws ecs execute-command \
  --cluster jiki-production \
  --task <TASK_ID> \
  --container api \
  --command "/bin/bash" \
  --interactive \
  --region eu-west-1 --profile jiki

# 2. Open Rails console
bundle exec rails console -e production

# 3. Test transactional email (mail.jiki.io)
TransactionalMailer.test_email('your-email@example.com').deliver_now

# 4. Test notification email (notifications.jiki.io)
NotificationsMailer.test_email('your-email@example.com').deliver_now

# 5. Test marketing email (hello.jiki.io)
MarketingMailer.test_email('your-email@example.com').deliver_now

# 6. Check CloudWatch logs for delivery
aws logs tail /ecs/jiki-api-web --follow --region eu-west-1 --profile jiki

# 7. Check received emails for:
# - Correct From address
# - DKIM signature present (view email headers)
# - SPF passing (view email headers)
# - Not in spam folder
```

**Email header checks** (critical for deliverability):

Open received email → View original/raw → Check headers:

```
From: noreply@mail.jiki.io
DKIM-Signature: v=1; a=rsa-sha256; d=mail.jiki.io; ...
SPF: PASS with IP xxx.xxx.xxx.xxx
DMARC: PASS
X-SES-CONFIGURATION-SET: mail-jiki-io
```

All should show PASS/valid status. If not, troubleshoot DNS records.

---

## API Changes

All changes in `/Users/iHiD/Code/jiki/api/`

### 1. Add AWS SES SDK Gem

**File**: `Gemfile`

```ruby
# Email sending via AWS SES
gem 'aws-sdk-ses', '~> 1.0'
```

```bash
bundle install
```

### 2. Configure ActionMailer for SES

**File**: `config/environments/production.rb`

```ruby
# Email configuration
config.action_mailer.delivery_method = :aws_sdk
config.action_mailer.perform_deliveries = true
config.action_mailer.raise_delivery_errors = true
config.action_mailer.default_url_options = {
  host: 'jiki.io',
  protocol: 'https'
}

# Asset host for email images (if needed)
config.action_mailer.asset_host = Jiki.config.assets_cdn_url
```

### 3. ActionMailer AWS SDK Initializer

**File**: `config/initializers/action_mailer.rb` (new file)

```ruby
require 'aws-sdk-ses'

# Configure AWS SES delivery method for ActionMailer
# Uses IAM role authentication (no credentials needed)
ActionMailer::Base.add_delivery_method(
  :aws_sdk,
  AWS::SES::Base,
  region: Jiki.config.ses_region
)

# AWS SDK automatically uses ECS task role credentials
# No need to configure access keys
```

### 4. Base Mailer Class

**File**: `app/mailers/application_mailer.rb`

```ruby
class ApplicationMailer < ActionMailer::Base
  layout 'mailer'

  # Default from address (override in subclasses)
  default from: -> { Jiki.config.mail_from_email }

  private

  # Override in subclasses to specify SES configuration set
  def configuration_set
    Jiki.config.ses_mail_configuration_set
  end

  # Override in subclasses to customize reply-to
  def reply_to_email
    Jiki.config.support_email
  end

  # Add SES configuration set header to all emails
  def mail(**args)
    # Set SES configuration set for tracking and dedicated IP routing
    headers['X-SES-CONFIGURATION-SET'] = configuration_set if configuration_set

    # Set reply-to if different from from address
    args[:reply_to] ||= reply_to_email if reply_to_email

    super(**args)
  end
end
```

### 5. Transactional Mailer

**File**: `app/mailers/transactional_mailer.rb` (new file)

```ruby
# Transactional emails sent via mail.jiki.io
# - User signup verification
# - Password resets
# - Payment receipts
# - Security alerts
#
# These are critical path emails that MUST be delivered.
# Uses dedicated IP and strict configuration.

class TransactionalMailer < ApplicationMailer
  default from: -> { Jiki.config.mail_from_email }

  # Example: Signup verification email
  def signup_verification(user)
    @user = user
    @verification_url = verify_email_url(token: user.email_verification_token)

    mail(
      to: user.email,
      subject: 'Verify your Jiki account'
    )
  end

  # Example: Password reset email
  def password_reset(user)
    @user = user
    @reset_url = reset_password_url(token: user.password_reset_token)

    mail(
      to: user.email,
      subject: 'Reset your Jiki password'
    )
  end

  # Example: Payment receipt email
  def payment_receipt(user, payment)
    @user = user
    @payment = payment

    mail(
      to: user.email,
      subject: "Payment receipt - Jiki #{payment.plan_name}"
    )
  end

  # Test email for verification
  def test_email(to)
    mail(
      to: to,
      subject: '[TEST] Transactional email from mail.jiki.io'
    ) do |format|
      format.html { render html: '<p>This is a test transactional email.</p>'.html_safe }
      format.text { render plain: 'This is a test transactional email.' }
    end
  end

  private

  def configuration_set
    Jiki.config.ses_mail_configuration_set
  end
end
```

### 6. Notifications Mailer

**File**: `app/mailers/notifications_mailer.rb` (new file)

```ruby
# Learning notifications sent via notifications.jiki.io
# - Lesson completed
# - Achievement unlocked
# - Progress milestones
# - Streak reminders
#
# High volume (~600k/month → 3.6M/month)
# Users can unsubscribe from these in preferences

class NotificationsMailer < ApplicationMailer
  default from: -> { Jiki.config.notifications_from_email }

  # Example: Lesson completed notification
  def lesson_completed(user, lesson)
    return unless user.notifications_enabled?

    @user = user
    @lesson = lesson
    @next_lesson = lesson.next_lesson

    mail(
      to: user.email,
      subject: "🎉 You completed #{lesson.title}!"
    )
  end

  # Example: Achievement unlocked
  def achievement_unlocked(user, achievement)
    return unless user.notifications_enabled?

    @user = user
    @achievement = achievement

    mail(
      to: user.email,
      subject: "🏆 Achievement unlocked: #{achievement.title}"
    )
  end

  # Example: Daily streak reminder
  def streak_reminder(user)
    return unless user.notifications_enabled?
    return unless user.streak_reminders_enabled?

    @user = user
    @streak_days = user.current_streak

    mail(
      to: user.email,
      subject: "🔥 Keep your #{@streak_days}-day streak going!"
    )
  end

  # Test email for verification
  def test_email(to)
    mail(
      to: to,
      subject: '[TEST] Notification email from notifications.jiki.io'
    ) do |format|
      format.html { render html: '<p>This is a test notification email.</p>'.html_safe }
      format.text { render plain: 'This is a test notification email.' }
    end
  end

  private

  def configuration_set
    Jiki.config.ses_notifications_configuration_set
  end
end
```

### 7. Marketing Mailer

**File**: `app/mailers/marketing_mailer.rb` (new file)

```ruby
# Marketing emails sent via hello.jiki.io
# - Monthly newsletters
# - Feature announcements
# - Product updates
#
# Low volume (~60k/month → 360k/month)
# Users can unsubscribe via one-click unsubscribe

class MarketingMailer < ApplicationMailer
  default from: -> { Jiki.config.marketing_from_email },
          reply_to: -> { Jiki.config.support_email }

  # Example: Monthly newsletter
  def monthly_newsletter(user)
    return unless user.marketing_emails_enabled?

    @user = user
    @unsubscribe_url = unsubscribe_url(token: user.unsubscribe_token)

    mail(
      to: user.email,
      subject: "What's new at Jiki - #{Date.current.strftime('%B %Y')}"
    )
  end

  # Example: Feature announcement
  def feature_announcement(user, feature)
    return unless user.marketing_emails_enabled?

    @user = user
    @feature = feature
    @unsubscribe_url = unsubscribe_url(token: user.unsubscribe_token)

    mail(
      to: user.email,
      subject: "New feature: #{feature.title}"
    )
  end

  # Test email for verification
  def test_email(to)
    mail(
      to: to,
      subject: '[TEST] Marketing email from hello.jiki.io'
    ) do |format|
      format.html { render html: '<p>This is a test marketing email.</p>'.html_safe }
      format.text { render plain: 'This is a test marketing email.' }
    end
  end

  private

  def configuration_set
    Jiki.config.ses_marketing_configuration_set
  end

  def reply_to_email
    Jiki.config.support_email
  end

  # Add RFC 8058 one-click unsubscribe headers
  def mail(**args)
    if defined?(@user) && @user
      headers['List-Unsubscribe'] = "<#{unsubscribe_url(token: @user.unsubscribe_token)}>"
      headers['List-Unsubscribe-Post'] = 'List-Unsubscribe=One-Click'
    end

    super(**args)
  end
end
```

### 8. SNS Webhook Controller

**File**: `app/controllers/webhooks/ses_controller.rb` (new file)

```ruby
# SNS webhook handler for SES bounce and complaint notifications
#
# AWS SNS sends notifications to this endpoint when:
# - Emails bounce (permanent or transient)
# - Users mark emails as spam (complaints)
#
# This controller handles:
# 1. SNS subscription confirmation (auto-confirm)
# 2. Bounce processing (mark invalid emails)
# 3. Complaint processing (unsubscribe from marketing)

module Webhooks
  class SesController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :authenticate_user! # Public endpoint for SNS

    def create
      # Verify SNS message signature
      unless valid_sns_message?
        Rails.logger.warn("Invalid SNS signature from #{request.remote_ip}")
        render json: { error: 'Invalid signature' }, status: :unauthorized
        return
      end

      message_type = request.headers['x-amz-sns-message-type']

      case message_type
      when 'SubscriptionConfirmation'
        confirm_subscription
      when 'Notification'
        handle_notification
      else
        Rails.logger.warn("Unknown SNS message type: #{message_type}")
      end

      head :ok
    rescue StandardError => e
      Rails.logger.error("SES webhook error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      head :ok # Always return 200 to prevent SNS retries
    end

    private

    def valid_sns_message?
      # TODO: Implement proper SNS signature verification
      # https://docs.aws.amazon.com/sns/latest/dg/sns-verify-signature-of-message.html
      #
      # For now, accept all messages (SNS endpoint is not publicly advertised)
      # In production, should verify:
      # 1. SigningCertURL is from amazonaws.com
      # 2. Download certificate from SigningCertURL
      # 3. Verify signature using certificate and message body
      true
    end

    def confirm_subscription
      body = JSON.parse(request.body.read)
      subscribe_url = body['SubscribeURL']

      if subscribe_url
        # Auto-confirm SNS subscription
        uri = URI.parse(subscribe_url)
        Net::HTTP.get(uri)
        Rails.logger.info("SNS subscription confirmed: #{body['TopicArn']}")
      end
    end

    def handle_notification
      body = JSON.parse(request.body.read)
      message = JSON.parse(body['Message'])

      event_type = message['eventType']
      Rails.logger.info("SES event: #{event_type}")

      case event_type
      when 'Bounce'
        HandleEmailBounce.call(message)
      when 'Complaint'
        HandleEmailComplaint.call(message)
      when 'Delivery'
        # Optional: track successful deliveries
        Rails.logger.debug("Email delivered: #{message['mail']['messageId']}")
      else
        Rails.logger.warn("Unknown SES event type: #{event_type}")
      end
    end
  end
end
```

**File**: `config/routes.rb` (append)

```ruby
namespace :webhooks do
  post 'ses', to: 'ses#create'
end
```

### 9. Bounce Handler Command

**File**: `app/commands/handle_email_bounce.rb` (new file)

```ruby
# Handles email bounce notifications from SES via SNS
#
# Bounce types:
# - Permanent: Email address doesn't exist, mailbox full (terminal)
# - Transient: Temporary issue, may resolve (retry)
#
# For permanent bounces, we mark the email as invalid to prevent
# future sending and protect sender reputation.

class HandleEmailBounce
  include Mandate

  def initialize(event)
    @event = event
  end

  def call
    bounce = event['bounce']
    bounced_recipients = bounce['bouncedRecipients']
    bounce_type = bounce['bounceType'] # Permanent or Transient

    Rails.logger.info("Processing #{bounce_type} bounce for #{bounced_recipients.count} recipients")

    bounced_recipients.each do |recipient|
      email = recipient['emailAddress']
      diagnostic_code = recipient['diagnosticCode']

      if bounce_type == 'Permanent'
        handle_permanent_bounce(email, diagnostic_code)
      else
        handle_transient_bounce(email, diagnostic_code)
      end
    end
  end

  private

  attr_reader :event

  def handle_permanent_bounce(email, diagnostic_code)
    Rails.logger.warn("Hard bounce: #{email} - #{diagnostic_code}")

    # TODO: Mark email as invalid in User model
    # user = User.find_by(email: email)
    # if user
    #   user.update!(
    #     email_valid: false,
    #     email_bounce_reason: diagnostic_code,
    #     email_bounced_at: Time.current
    #   )
    # end

    # For now, just log
    Rails.logger.warn("TODO: Mark #{email} as invalid in database")
  end

  def handle_transient_bounce(email, diagnostic_code)
    Rails.logger.info("Soft bounce: #{email} - #{diagnostic_code}")

    # Soft bounces may resolve (mailbox full, temporary server issue)
    # Log but don't disable email
    # Could track bounce count and disable after X soft bounces
  end
end
```

### 10. Complaint Handler Command

**File**: `app/commands/handle_email_complaint.rb` (new file)

```ruby
# Handles spam complaint notifications from SES via SNS
#
# When a user marks an email as spam, ISPs notify SES via feedback loop.
# We must immediately stop sending marketing emails to that address to
# protect sender reputation.
#
# Complaint rate must stay below 0.1% or AWS may suspend sending.

class HandleEmailComplaint
  include Mandate

  def initialize(event)
    @event = event
  end

  def call
    complaint = event['complaint']
    complained_recipients = complaint['complainedRecipients']
    complaint_feedback_type = complaint['complaintFeedbackType'] # abuse, fraud, etc

    Rails.logger.warn("Processing spam complaint (#{complaint_feedback_type}) for #{complained_recipients.count} recipients")

    complained_recipients.each do |recipient|
      email = recipient['emailAddress']
      handle_complaint(email, complaint_feedback_type)
    end
  end

  private

  attr_reader :event

  def handle_complaint(email, feedback_type)
    Rails.logger.warn("Spam complaint: #{email} - #{feedback_type}")

    # TODO: Immediately unsubscribe from marketing emails
    # user = User.find_by(email: email)
    # if user
    #   user.update!(
    #     marketing_emails_enabled: false,
    #     email_complaint_at: Time.current,
    #     email_complaint_type: feedback_type
    #   )
    # end

    # For now, just log
    Rails.logger.warn("TODO: Unsubscribe #{email} from marketing in database")

    # Critical: DO NOT send marketing emails to this address again
    # Transactional emails (auth, payments) can still be sent
  end
end
```

### 11. Email Layout Template

**File**: `app/views/layouts/mailer.html.erb` (update/create)

```erb
<!DOCTYPE html>
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <style>
      /* Email-safe CSS */
      body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
        font-size: 16px;
        line-height: 1.6;
        color: #333;
        background-color: #f5f5f5;
        margin: 0;
        padding: 0;
      }

      .email-container {
        max-width: 600px;
        margin: 20px auto;
        background-color: #ffffff;
        border-radius: 8px;
        overflow: hidden;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      }

      .email-header {
        background-color: #6366f1;
        color: #ffffff;
        padding: 30px 40px;
        text-align: center;
      }

      .email-header h1 {
        margin: 0;
        font-size: 24px;
        font-weight: 600;
      }

      .email-body {
        padding: 40px;
      }

      .email-footer {
        background-color: #f9fafb;
        padding: 30px 40px;
        text-align: center;
        font-size: 14px;
        color: #6b7280;
        border-top: 1px solid #e5e7eb;
      }

      .button {
        display: inline-block;
        padding: 12px 24px;
        background-color: #6366f1;
        color: #ffffff !important;
        text-decoration: none;
        border-radius: 6px;
        font-weight: 500;
        margin: 20px 0;
      }

      .button:hover {
        background-color: #4f46e5;
      }

      a {
        color: #6366f1;
        text-decoration: none;
      }

      a:hover {
        text-decoration: underline;
      }
    </style>
  </head>
  <body>
    <div class="email-container">
      <div class="email-header">
        <h1>Jiki</h1>
      </div>

      <div class="email-body">
        <%= yield %>
      </div>

      <div class="email-footer">
        <p>
          <strong>Jiki</strong> - Learn to Code
          <br>
          <a href="https://jiki.io">jiki.io</a>
        </p>

        <% if defined?(@unsubscribe_url) %>
          <p style="margin-top: 20px;">
            <a href="<%= @unsubscribe_url %>">Unsubscribe from marketing emails</a>
          </p>
        <% end %>
      </div>
    </div>
  </body>
</html>
```

**File**: `app/views/layouts/mailer.text.erb` (create)

```erb
<%= yield %>

---
Jiki - Learn to Code
https://jiki.io

<% if defined?(@unsubscribe_url) %>
Unsubscribe: <%= @unsubscribe_url %>
<% end %>
```

### 12. Example Email View Templates

**File**: `app/views/transactional_mailer/signup_verification.html.erb` (example)

```erb
<h2>Welcome to Jiki!</h2>

<p>Hi <%= @user.first_name || 'there' %>,</p>

<p>
  Thanks for signing up! Please verify your email address to get started.
</p>

<p style="text-align: center;">
  <a href="<%= @verification_url %>" class="button">Verify Email Address</a>
</p>

<p>
  Or copy and paste this link into your browser:
  <br>
  <%= @verification_url %>
</p>

<p>
  This link expires in 24 hours.
</p>

<p>
  If you didn't create a Jiki account, you can safely ignore this email.
</p>
```

**File**: `app/views/transactional_mailer/signup_verification.text.erb` (example)

```erb
Welcome to Jiki!

Hi <%= @user.first_name || 'there' %>,

Thanks for signing up! Please verify your email address to get started.

Verify your email: <%= @verification_url %>

This link expires in 24 hours.

If you didn't create a Jiki account, you can safely ignore this email.
```

### 13. User Model Email Preferences (TODO)

**File**: `app/models/user.rb` (future addition)

```ruby
# Email preference columns to add in future migration:
#
# t.boolean :notifications_enabled, default: true, null: false
# t.boolean :streak_reminders_enabled, default: true, null: false
# t.boolean :marketing_emails_enabled, default: true, null: false
# t.boolean :email_valid, default: true, null: false
# t.string :email_bounce_reason
# t.datetime :email_bounced_at
# t.datetime :email_complaint_at
# t.string :email_complaint_type
# t.datetime :last_email_opened_at
# t.string :unsubscribe_token, null: false, index: { unique: true }
# t.string :email_verification_token
# t.datetime :email_verified_at

# Methods to add:
# - before_create: generate unsubscribe_token
# - notifications_enabled?
# - marketing_emails_enabled?
# - email_valid?
```

### 14. Unsubscribe Controller (TODO)

**File**: `app/controllers/unsubscribes_controller.rb` (future addition)

```ruby
# One-click unsubscribe endpoint (RFC 8058 compliance)
#
# GET /unsubscribe/:token - Show unsubscribe page
# POST /unsubscribe/:token - Process one-click unsubscribe

class UnsubscribesController < ApplicationController
  skip_before_action :authenticate_user!

  def show
    @user = User.find_by(unsubscribe_token: params[:token])

    if @user.nil?
      render plain: 'Invalid unsubscribe link', status: :not_found
    end
  end

  def create
    user = User.find_by(unsubscribe_token: params[:token])

    if user
      user.update!(marketing_emails_enabled: false)
      render plain: 'You have been unsubscribed from marketing emails. You will still receive important account and learning notifications.'
    else
      render plain: 'Invalid unsubscribe link', status: :not_found
    end
  end
end
```

---

## Testing Checklist

### After Terraform Apply

- [ ] All 3 SES domain identities show "Verified" in AWS Console
- [ ] DKIM status shows "Successful" for all 3 domains
- [ ] Custom MAIL FROM status shows "Successful" for all 3 domains
- [ ] All 6 SNS topics created
- [ ] All 6 SNS subscriptions created (pending confirmation)
- [ ] CloudWatch alarms created (6 total: 3 bounce + 3 complaint)
- [ ] DynamoDB config items added (8 total for SES)

### After DNS Propagation

- [ ] DNS verification passes for all domains:
  ```bash
  dig +short mail.jiki.io TXT
  dig +short _dmarc.mail.jiki.io TXT
  dig +short bounce.mail.jiki.io MX
  dig +short bounce.mail.jiki.io TXT
  # Repeat for notifications.jiki.io and hello.jiki.io
  ```

### After API Deployment

- [ ] SNS subscriptions auto-confirmed (check SNS console)
- [ ] Webhook endpoint accessible: `curl https://api.jiki.io/webhooks/ses`
- [ ] Test emails send successfully from Rails console
- [ ] Test emails received with correct From addresses
- [ ] DKIM signatures present in email headers
- [ ] SPF passes in email headers
- [ ] DMARC passes in email headers

### After Managed Dedicated IPs Enabled

- [ ] Managed dedicated IPs subscription active in SES console
- [ ] Configuration sets assigned to managed IP pool
- [ ] First dedicated IP provisioned
- [ ] Warm-up status visible in VDM dashboard

### Ongoing Monitoring

- [ ] Daily: Check VDM dashboard for bounce/complaint rates
- [ ] Weekly: Review CloudWatch metrics for each subdomain
- [ ] Monthly: Clean up invalid emails and inactive users
- [ ] Monitor: CloudWatch alarms (email alerts to ops@jiki.io)

---

## Cost Breakdown

### Month 1 (January - 70k emails)

| Item | Cost |
|------|------|
| Managed dedicated IPs subscription | $15.00 |
| SES emails (70k @ $0.08/1k) | $5.60 |
| SNS notifications | $0.50 |
| CloudWatch logs/metrics | $1.00 |
| **Total** | **$22.10/month** |

### Month 3 (March - 840k emails)

| Item | Cost |
|------|------|
| Managed dedicated IPs subscription | $15.00 |
| SES emails (840k @ $0.08/1k) | $67.20 |
| SNS notifications | $1.00 |
| CloudWatch logs/metrics | $2.00 |
| **Total** | **$85.20/month** |

### Month 6 (4M emails)

| Item | Cost |
|------|------|
| Managed dedicated IPs subscription | $15.00 |
| SES emails (4M @ $0.08/1k) | $320.00 |
| SNS notifications | $2.00 |
| CloudWatch logs/metrics | $5.00 |
| **Total** | **$342.00/month** |

**Savings vs Shared IPs at 4M**: ~$58/month ($400 shared - $342 managed)

---

## Rollout Timeline

### Week 1 (Early December 2025)
- [ ] Create Terraform infrastructure (`ses.tf`)
- [ ] Apply AWS Terraform (SES domains, SNS topics)
- [ ] Get DKIM tokens from Terraform output
- [ ] Update Cloudflare DNS Terraform with DKIM tokens
- [ ] Apply Cloudflare Terraform (21 DNS records)

### Week 2 (Mid December 2025)
- [ ] Request SES production access (wait 24-48h)
- [ ] Enable Managed Dedicated IPs subscription
- [ ] Assign configuration sets to managed IP pool
- [ ] Wait for DNS propagation (5-60 minutes)
- [ ] Verify domain identities in SES console

### Week 3 (Late December 2025)
- [ ] Implement API changes (mailers, webhook handler, commands)
- [ ] Deploy to production
- [ ] Confirm SNS subscriptions
- [ ] Test email sending (all 3 subdomains)
- [ ] Verify DKIM/SPF/DMARC in email headers
- [ ] Check VDM dashboard (warm-up starting)

### Week 4 (Early January 2026)
- [ ] Production ready ✅
- [ ] Begin soft launch (5k users)
- [ ] Monitor bounce/complaint rates daily
- [ ] AWS warm-up in progress (week 1/6)

### January - February 2026 (Warm-Up Period)
- [ ] 5k → 20k users over 8 weeks
- [ ] AWS auto-warms dedicated IPs (week 1-6 complete)
- [ ] Monitor VDM dashboard weekly
- [ ] No action required (AWS manages warm-up)

### March 2026 (Public Launch)
- [ ] Dedicated IPs fully warmed ✅
- [ ] Launch to public (60k users)
- [ ] Full production monitoring
- [ ] Infrastructure ready for millions of emails/month

---

## Support & Resources

### AWS Documentation
- [SES Developer Guide](https://docs.aws.amazon.com/ses/latest/dg/)
- [Managed Dedicated IPs](https://docs.aws.amazon.com/ses/latest/dg/sending-dedicated-ip-managed.html)
- [DKIM in SES](https://docs.aws.amazon.com/ses/latest/dg/send-email-authentication-dkim.html)
- [SNS Message Verification](https://docs.aws.amazon.com/sns/latest/dg/sns-verify-signature-of-message.html)

### Email Best Practices
- [Gmail Sender Guidelines](https://support.google.com/mail/answer/81126)
- [DMARC.org](https://dmarc.org/)
- [RFC 8058: One-Click Unsubscribe](https://datatracker.ietf.org/doc/html/rfc8058)

### Monitoring Dashboards
- SES VDM Dashboard: AWS Console → SES → Reputation metrics
- CloudWatch Metrics: AWS Console → CloudWatch → Dashboards
- SNS Topics: AWS Console → SNS → Topics

### Troubleshooting
- Bounce rate >5%: Check email list quality, remove invalid addresses
- Complaint rate >0.1%: Review email content, ensure clear unsubscribe
- DKIM failures: Verify DNS records, check DKIM tokens match
- SPF failures: Verify custom MAIL FROM MX/TXT records

---

**End of SES_PLAN.md**
