class CreateUserSeenFlags < ActiveRecord::Migration[8.1]
  def change
    create_table :user_seen_flags do |t|
      t.references :user, null: false, foreign_key: true
      t.string :key, null: false
      t.timestamps
    end

    add_index :user_seen_flags, %i[user_id key], unique: true
  end
end
