class UserLevelMailer < ApplicationMailer
  # Sends a level completion email to a user
  #
  # @param user_level [UserLevel] The user_level record that was completed
  def completed(user_level)
    @user = user_level.user
    return unless @user.data.receive_milestone_emails?

    @unsubscribe_key = :milestone_emails

    mail_template_with_locale(
      @user,
      :level_completion,
      user_level.level.slug,
      { level: LevelDrop.new(user_level.level) }
    )
  end
end
