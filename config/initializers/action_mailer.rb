# Configure AWS SES delivery method for ActionMailer
#
# The aws-actionmailer-ses gem registers :ses and :ses_v2 delivery methods
# Production uses :ses_v2 (Amazon SESV2 API - newer, recommended)
#
# Credentials: AWS SDK automatically uses ECS task IAM role (no manual config needed)
# Region: Configured via Jiki.config.ses_region (from DynamoDB)
#
# The delivery method is configured in config/environments/production.rb:
#   config.action_mailer.delivery_method = :ses_v2
#   config.action_mailer.ses_v2_settings = { region: Jiki.config.ses_region }
#
# Asset host for email images: config.action_mailer.asset_host = Jiki.config.assets_cdn_url
