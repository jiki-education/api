class CreateUserActivityData < ActiveRecord::Migration[8.1]
  def change
    create_table :user_activity_data do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :activity_days, default: {}, null: false
      t.integer :current_streak, default: 0, null: false
      t.integer :longest_streak, default: 0, null: false
      t.integer :total_active_days, default: 0, null: false
      t.timestamps
    end

    add_index :user_activity_data, :activity_days, using: :gin
  end
end
