class PremiumMailerPreview < ActionMailer::Preview
  def welcome_to_premium
    PremiumMailer.welcome_to_premium(preview_user)
  end

  def subscription_ended
    PremiumMailer.subscription_ended(preview_user)
  end

  private
  def preview_user = FactoryBot.build(:user)
end
