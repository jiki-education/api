# Sentry Error Tracking

return unless Rails.env.production?

Sentry.init do |config|
  config.dsn = Jiki.config.sentry_dsn
  config.breadcrumbs_logger = %i[active_support_logger http_logger]
end
