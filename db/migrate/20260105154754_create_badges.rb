class CreateBadges < ActiveRecord::Migration[8.1]
  def change
    create_table :badges do |t|
      t.string :type, null: false
      t.string :name, null: false
      t.string :icon, null: false
      t.text :description, null: false
      t.boolean :secret, default: false, null: false
      t.integer :num_awardees, default: 0, null: false
      t.text :fun_fact
      t.text :email_subject, null: false, default: ''
      t.text :email_content_markdown, null: false, default: ''
      t.string :email_image_url, null: false, default: ''

      t.timestamps
    end

    add_index :badges, :type, unique: true
    add_index :badges, :name, unique: true
  end
end
