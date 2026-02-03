class CreateLevelTranslations < ActiveRecord::Migration[8.1]
  def change
    create_table :level_translations do |t|
      t.references :level, null: false, foreign_key: true
      t.string :locale, null: false
      t.string :title, null: false
      t.text :description, null: false
      t.text :milestone_summary, null: false
      t.text :milestone_content, null: false
      t.text :milestone_email_subject, null: false
      t.text :milestone_email_content_markdown, null: false

      t.timestamps
    end

    add_index :level_translations, [:level_id, :locale], unique: true
  end
end
