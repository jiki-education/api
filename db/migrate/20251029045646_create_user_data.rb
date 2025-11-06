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
      t.datetime :subscription_current_period_end
      t.datetime :payment_failed_at

      t.timestamps
    end

    add_index :user_data, :unlocked_concept_ids, using: :gin
    add_index :user_data, :membership_type
    add_index :user_data, :stripe_customer_id, unique: true
    add_index :user_data, :stripe_subscription_id
    add_index :user_data, :payment_failed_at
  end
end
