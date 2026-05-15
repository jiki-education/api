class ProgressionMailerPreview < ActionMailer::Preview
  # Visit ?slug=using-functions (or any level slug) to preview that level's email.
  # Defaults to the first level. Falls back to a factory-built level if seeds haven't been run.
  def level_completed
    level = Level.find_by(slug: params[:slug]) || Level.first || FactoryBot.build(:level)
    user = User.first || FactoryBot.build(:user)
    ProgressionMailer.level_completed(UserLevel.new(user:, level:))
  end
end
