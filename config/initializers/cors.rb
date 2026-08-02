# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # staging.jiki.io and the ngrok dev tunnel are additional frontend
    # deployments that talk to this same (production) API from the browser,
    # so their origins must be allowed alongside the canonical
    # frontend_base_url. Kept in sync with Utils::VerifyFrontendUrl.
    origins Jiki.config.frontend_base_url, Jiki.config.admin_base_url,
      *Utils::VerifyFrontendUrl::ADDITIONAL_ALLOWED_ORIGINS

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: ["Authorization"],
      credentials: true
  end
end
