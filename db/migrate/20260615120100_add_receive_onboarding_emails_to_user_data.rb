class AddReceiveOnboardingEmailsToUserData < ActiveRecord::Migration[8.1]
  def up
    add_column :user_data, :receive_onboarding_emails, :boolean, default: true, null: false

    # Existing confirmed users have missed the onboarding window — don't
    # retroactively start the cadence for them. New signups default to true.
    execute <<~SQL.squish
      UPDATE user_data
      SET receive_onboarding_emails = false
      WHERE user_id IN (SELECT id FROM users WHERE confirmed_at IS NOT NULL)
    SQL
  end

  def down
    remove_column :user_data, :receive_onboarding_emails
  end
end
