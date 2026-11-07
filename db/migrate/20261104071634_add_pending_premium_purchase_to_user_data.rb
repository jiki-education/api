class AddPendingPremiumPurchaseToUserData < ActiveRecord::Migration[8.1]
  def change
    add_column :user_data, :pending_premium_purchase_payment_intent_id, :string
    add_column :user_data, :pending_premium_purchase_at, :datetime
  end
end
