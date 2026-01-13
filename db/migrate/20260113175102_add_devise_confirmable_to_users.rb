class AddDeviseConfirmableToUsers < ActiveRecord::Migration[8.1]
  def up
    # Add Devise confirmable columns
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string

    add_index :users, :confirmation_token, unique: true

    # Migrate existing email_verified data to confirmed_at
    User.reset_column_information
    User.where(email_verified: true).update_all(confirmed_at: Time.current)

    # Remove old email_verified column
    remove_index :users, :email_verified
    remove_column :users, :email_verified
  end

  def down
    # Restore email_verified column
    add_column :users, :email_verified, :boolean, default: false, null: false
    add_index :users, :email_verified

    # Migrate confirmed_at back to email_verified
    User.reset_column_information
    User.where.not(confirmed_at: nil).update_all(email_verified: true)

    # Remove Devise confirmable columns
    remove_index :users, :confirmation_token
    remove_column :users, :confirmation_token
    remove_column :users, :confirmed_at
    remove_column :users, :confirmation_sent_at
    remove_column :users, :unconfirmed_email
  end
end
