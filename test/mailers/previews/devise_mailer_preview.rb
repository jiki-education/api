class DeviseMailerPreview < ActionMailer::Preview
  def confirmation_instructions
    DeviseMailer.confirmation_instructions(preview_user, "sample-confirmation-token-abc123")
  end

  def reset_password_instructions
    DeviseMailer.reset_password_instructions(preview_user, "sample-reset-token-xyz789")
  end

  private
  def preview_user = FactoryBot.build(:user)
end
