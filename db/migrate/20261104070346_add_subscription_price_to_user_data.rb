class AddSubscriptionPriceToUserData < ActiveRecord::Migration[8.1]
  def change
    add_column :user_data, :subscription_amount_in_cents, :integer
    add_column :user_data, :subscription_currency, :string
  end
end
