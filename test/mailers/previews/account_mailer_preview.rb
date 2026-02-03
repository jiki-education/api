class AccountMailerPreview < ActionMailer::Preview
  def welcome
    AccountMailer.welcome(preview_user, login_url: "https://jiki.dev/login")
  end

  def account_deletion_confirmation
    AccountMailer.account_deletion_confirmation(preview_user, confirmation_url: "https://jiki.dev/confirm-delete?token=abc123")
  end

  private
  def preview_user = FactoryBot.build(:user)
end
