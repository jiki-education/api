class CreateUserMailshots < ActiveRecord::Migration[8.1]
  def change
    create_table :user_mailshots do |t|
      t.references :user, null: false, foreign_key: true
      t.references :mailshot, null: false, foreign_key: true
      t.integer :email_status, null: false, default: 0

      t.timestamps
    end

    add_index :user_mailshots, %i[user_id mailshot_id], unique: true
  end
end
