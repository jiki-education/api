# Configure AWS SES delivery method for ActionMailer
# The aws-sdk-rails gem automatically registers the :aws_sdk delivery method
# Uses IAM role authentication (no credentials needed in ECS)

# AWS SDK automatically uses ECS task role credentials
# The delivery method is configured via production.rb:
# config.action_mailer.delivery_method = :aws_sdk
# config.action_mailer.asset_host = Jiki.config.assets_cdn_url

# SES region is configured via the AWS_REGION environment variable
# or can be set explicitly if needed:
# Aws.config.update(region: Jiki.config.ses_region)
