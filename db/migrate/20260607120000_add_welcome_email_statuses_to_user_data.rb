class AddWelcomeEmailStatusesToUserData < ActiveRecord::Migration[8.1]
  def up
    add_column :user_data, :welcome_email_status, :integer, default: 0, null: false
    add_column :user_data, :welcome_to_premium_email_status, :integer, default: 0, null: false

    # Backfill: any user who has already confirmed their email should be
    # treated as having already received the welcome email — we don't want
    # to retroactively send it to existing users.
    execute <<~SQL.squish
      UPDATE user_data
      SET welcome_email_status = 2
      WHERE user_id IN (SELECT id FROM users WHERE confirmed_at IS NOT NULL)
    SQL

    # Backfill: existing premium users have already had their welcome-to-premium
    # email (or chose not to receive one); don't re-send.
    execute <<~SQL.squish
      UPDATE user_data
      SET welcome_to_premium_email_status = 2
      WHERE membership_type = 'premium'
    SQL
  end

  def down
    remove_column :user_data, :welcome_email_status
    remove_column :user_data, :welcome_to_premium_email_status
  end
end
