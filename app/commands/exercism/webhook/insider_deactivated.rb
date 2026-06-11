class Exercism::Webhook::InsiderDeactivated
  include Mandate

  initialize_with :event

  def call
    user = User.find_by(exercism_id: event["exercism_id"].to_s)
    unless user
      Rails.logger.info("Exercism insider.deactivated for unknown user #{event['exercism_id']}, ignoring")
      return
    end

    User::PremiumEntitlement::Revoke.(user, PremiumEntitlement::EXERCISM_INSIDER)
  end
end
