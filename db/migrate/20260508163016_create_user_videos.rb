class CreateUserVideos < ActiveRecord::Migration[8.1]
  def change
    create_table :user_videos do |t|
      t.references :user, null: false, foreign_key: true
      t.string :slug, null: false
      t.integer :watched_percentage, null: false, default: 0
      t.datetime :completed_at
      t.timestamps
    end

    add_index :user_videos, [:user_id, :slug], unique: true
  end
end
