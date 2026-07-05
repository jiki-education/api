class AddReceiveOnboardingEmailsToUserData < ActiveRecord::Migration[8.1]
  def up
    # default: true applies to all existing rows too, so every user — existing
    # and new — has the onboarding preference on. (Existing users still won't
    # receive the cadence unless something anchors it for them, since
    # CreateDueNotifications only looks at users created in the last few days.)
    add_column :user_data, :receive_onboarding_emails, :boolean, default: true, null: false
  end

  def down
    remove_column :user_data, :receive_onboarding_emails
  end
end
