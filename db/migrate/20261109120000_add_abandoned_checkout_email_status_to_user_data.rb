class AddAbandonedCheckoutEmailStatusToUserData < ActiveRecord::Migration[8.1]
  def change
    add_column :user_data, :abandoned_checkout_email_status, :integer, default: 0, null: false
  end
end
