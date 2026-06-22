class CreateMailshots < ActiveRecord::Migration[8.1]
  def change
    create_table :mailshots do |t|
      t.string :slug, null: false
      t.string :subject, null: false
      t.text :body_markdown, null: false
      t.string :email_communication_preferences_key, null: false, default: "newsletters"
      t.jsonb :sent_to_audiences, null: false, default: []

      t.timestamps
    end

    add_index :mailshots, :slug, unique: true
  end
end
