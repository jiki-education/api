class User::SendWelcomeEmail
  include Mandate

  queue_as :mailers

  initialize_with :user

  def call
    AccountMailer.welcome(user, login_url:).deliver_now
  end

  private
  def login_url
    # In production, this should come from configuration
    # For now, generate environment-appropriate URL
    if Rails.env.production?
      "https://jiki.io/login"
    elsif Rails.env.development?
      "http://localhost:3000/login"
    else
      "http://test.host/login"
    end
  end
end
