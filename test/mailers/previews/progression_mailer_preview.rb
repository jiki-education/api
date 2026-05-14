class ProgressionMailerPreview < ActionMailer::Preview
  def level_completed
    ProgressionMailer.level_completed(preview_user_level)
  end

  private
  def preview_user_level
    UserLevel.new(user: FactoryBot.build(:user), level: FactoryBot.build(:level))
  end
end
