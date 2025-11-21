class AddEmailTrackingToUserData < ActiveRecord::Migration[8.1]
  def change
    # Email preferences (default to enabled/valid for existing users)
    add_column :user_data, :notifications_enabled, :boolean, default: true, null: false
    add_column :user_data, :marketing_emails_enabled, :boolean, default: true, null: false
    add_column :user_data, :email_valid, :boolean, default: true, null: false

    # Bounce tracking (nullable - only populated when bounces occur)
    add_column :user_data, :email_bounce_reason, :string
    add_column :user_data, :email_bounced_at, :datetime

    # Complaint tracking (nullable - only populated when complaints occur)
    add_column :user_data, :email_complaint_at, :datetime
    add_column :user_data, :email_complaint_type, :string

    # Email engagement tracking
    add_column :user_data, :last_email_opened_at, :datetime

    # Unsubscribe token (add as nullable first, then backfill and add constraint)
    add_column :user_data, :unsubscribe_token, :string

    # Generate unsubscribe tokens for existing records
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE user_data
          SET unsubscribe_token = gen_random_uuid()::text
          WHERE unsubscribe_token IS NULL
        SQL
      end
    end

    # Now add the constraint and index
    change_column_null :user_data, :unsubscribe_token, false
    add_index :user_data, :unsubscribe_token, unique: true

    # Email verification token (nullable)
    add_column :user_data, :email_verification_token, :string
  end
end
