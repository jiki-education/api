class CreateUserNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :user_notifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :type, null: false
      t.string :uniqueness_key, null: false, default: ""
      t.integer :status, null: false, default: 0
      t.integer :email_status, null: false, default: 0
      t.jsonb :params
      t.datetime :read_at
      t.timestamps
    end

    add_index :user_notifications, %i[user_id uniqueness_key], unique: true,
      name: "index_user_notifications_on_user_and_uniqueness_key"
    add_index :user_notifications, %i[user_id type]
  end
end
