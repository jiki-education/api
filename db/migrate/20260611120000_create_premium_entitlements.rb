class CreatePremiumEntitlements < ActiveRecord::Migration[8.1]
  def change
    create_table :premium_entitlements do |t|
      t.references :user, null: false, foreign_key: true
      t.string :source, null: false
      t.string :external_ref
      t.datetime :starts_at, null: false
      t.datetime :expires_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :premium_entitlements, %i[user_id source],
      unique: true,
      where: "revoked_at IS NULL",
      name: "index_premium_entitlements_on_user_and_source_active"
    add_index :premium_entitlements, :expires_at
  end
end
