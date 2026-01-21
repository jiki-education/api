class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :user, null: false, foreign_key: true
      t.string :payment_processor_id, null: false
      t.integer :amount_in_cents, null: false
      t.string :currency, null: false
      t.string :product, null: false
      t.string :external_receipt_url
      t.jsonb :data, default: {}, null: false

      t.timestamps
    end

    add_index :payments, :payment_processor_id, unique: true
    add_index :payments, [:user_id, :created_at]
    add_index :payments, :data, using: :gin
  end
end
