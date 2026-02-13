class CreateUserData < ActiveRecord::Migration[8.1]
  def change
    create_table :user_data do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.bigint :unlocked_concept_ids, array: true, default: [], null: false
      t.string :membership_type, null: false, default: "standard"

      # Stripe subscription fields
      t.string :stripe_customer_id
      t.string :stripe_subscription_id
      t.string :stripe_subscription_status
      t.integer :subscription_status, default: 0, null: false
      t.datetime :subscription_valid_until
      t.jsonb :subscriptions, default: [], null: false
      t.string :timezone

      # Two-Factor Authentication
      t.string :otp_secret
      t.datetime :otp_enabled_at

      # Email tracking
      t.boolean :notifications_enabled, null: false, default: true
      t.string :email_bounce_reason
      t.datetime :email_bounced_at
      t.datetime :email_complaint_at
      t.string :email_complaint_type
      t.datetime :last_email_opened_at
      t.string :unsubscribe_token, null: false
      t.string :email_verification_token

      # Notification preferences
      t.boolean :receive_newsletters, null: false, default: true
      t.boolean :receive_event_emails, null: false, default: true
      t.boolean :receive_milestone_emails, null: false, default: true
      t.boolean :receive_activity_emails, null: false, default: true

      # Streaks
      t.boolean :streaks_enabled, null: false, default: false

      t.timestamps
    end

    add_index :user_data, :unlocked_concept_ids, using: :gin
    add_index :user_data, :membership_type
    add_index :user_data, :stripe_customer_id, unique: true
    add_index :user_data, :stripe_subscription_id
    add_index :user_data, :subscription_status
    add_index :user_data, :subscriptions, using: :gin
    add_index :user_data, :unsubscribe_token, unique: true
  end
end
