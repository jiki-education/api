class DeleteOnboardingBuildingNotifications < ActiveRecord::Migration[8.1]
  # The User::Notifications::OnboardingBuildingNotification class no longer
  # exists, so any remaining rows of that STI type would raise
  # ActiveRecord::SubclassNotFound whenever they're loaded (e.g. when a user's
  # notifications are destroyed alongside their account). These rows were only
  # an audit record of the email send, so they're safe to drop.
  #
  # Irreversible: there is nothing to restore the rows from.
  def up
    execute <<~SQL
      DELETE FROM user_notifications
      WHERE type = 'User::Notifications::OnboardingBuildingNotification'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
