class CreateLessonTranslations < ActiveRecord::Migration[8.1]
  def change
    create_table :lesson_translations do |t|
      t.references :lesson, null: false, foreign_key: true
      t.string :locale, null: false
      t.string :title, null: false
      t.text :description, null: false

      t.timestamps
    end

    add_index :lesson_translations, [:lesson_id, :locale], unique: true
  end
end
