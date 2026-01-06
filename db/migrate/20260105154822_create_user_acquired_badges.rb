class CreateUserAcquiredBadges < ActiveRecord::Migration[8.1]
  def change
    create_table :user_acquired_badges do |t|
      t.references :user, null: false, foreign_key: true
      t.references :badge, null: false, foreign_key: true
      t.boolean :revealed, default: false, null: false

      t.timestamps
    end

    add_index :user_acquired_badges, [:user_id, :badge_id], unique: true
  end
end
