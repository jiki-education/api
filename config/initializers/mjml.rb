# MJML configuration for email templates
# MJML compiles responsive email markup into HTML with inlined CSS

Mjml.setup do |config|
  # Use MRML (Rust implementation) - faster and no Node.js dependency
  config.use_mrml = true

  # Use HAML as template language for cleaner syntax
  config.template_language = :haml

  # Strict validation to catch email template errors at compile time
  config.validation_level = "strict"

  # Fail fast on rendering errors
  config.raise_render_exception = true

  # Environment-specific settings
  # In development: beautified HTML for easier debugging
  # In production: minified HTML for smaller email size
  config.beautify = !Rails.env.production?
  config.minify = Rails.env.production?

  # mjml-rails 5.0.0's disk cache keys on the layout file's SHA only, so every
  # email using layouts/mailer.mjml shares one cache entry — the first render
  # poisons subsequent ones. Disable until the upstream cache is fixed.
  config.cache_mjml = false
end
