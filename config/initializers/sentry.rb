# Sentry Error Tracking

Sentry.init do |config|
  config.dsn = "https://a87c60043a482b1aaed9c720b2b21da4@o4510766458601472.ingest.de.sentry.io/4510766634172496"
  config.environment = Rails.env
  config.breadcrumbs_logger = %i[active_support_logger http_logger]
  config.send_default_pii = true
end
