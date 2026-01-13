class AddNotificationPreferencesToUserData < ActiveRecord::Migration[8.1]
  def change
    add_column :user_data, :receive_product_updates, :boolean, default: true, null: false
    add_column :user_data, :receive_event_emails, :boolean, default: true, null: false
    add_column :user_data, :receive_milestone_emails, :boolean, default: true, null: false
    add_column :user_data, :receive_activity_emails, :boolean, default: true, null: false
  end
end
