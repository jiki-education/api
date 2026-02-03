class AddI18nToBadges < ActiveRecord::Migration[8.1]
  def change
    add_column :badges, :fun_fact, :text
    add_column :badges, :email_subject, :text, null: false, default: ''
    add_column :badges, :email_content_markdown, :text, null: false, default: ''
    add_column :badges, :email_image_url, :string, null: false, default: ''

    create_table :badge_translations do |t|
      t.references :badge, null: false, foreign_key: true
      t.string :locale, null: false
      t.string :name, null: false
      t.text :description, null: false
      t.text :fun_fact, null: false
      t.text :email_subject, null: false
      t.text :email_content_markdown, null: false

      t.timestamps
    end

    add_index :badge_translations, [:badge_id, :locale], unique: true
  end
end
