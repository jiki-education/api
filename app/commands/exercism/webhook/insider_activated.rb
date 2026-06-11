class Exercism::Webhook::InsiderActivated
  include Mandate

  initialize_with :event

  def call
    user = User.find_by(exercism_id: event["exercism_id"].to_s)
    unless user
      Rails.logger.info("Exercism insider.activated for unknown user #{event['exercism_id']}, ignoring")
      return
    end

    User::PremiumEntitlement::Grant.(user, PremiumEntitlement::EXERCISM_INSIDER)
  end
end
