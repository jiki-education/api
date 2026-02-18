class AddSubscriptionIntervalToUserData < ActiveRecord::Migration[8.1]
  def change
    add_column :user_data, :subscription_interval, :string, default: "monthly", null: false
  end
end
