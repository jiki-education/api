class RemoveCurriculumCopy < ActiveRecord::Migration[8.1]
  def change
    # Screen-rendered copy is authored in the front-end curriculum repo
    # (curriculum/src/**). Only email copy stays here.
    remove_column :lessons, :title, :string, null: false
    remove_column :lessons, :description, :text, null: false

    remove_column :levels, :title, :string, null: false
    remove_column :levels, :description, :text, null: false
    remove_column :levels, :milestone_summary, :text, null: false
    remove_column :levels, :milestone_content, :text, null: false

    remove_column :concepts, :title, :string, null: false
    remove_column :concepts, :description, :text, null: false

    remove_column :courses, :title, :string, null: false
    remove_column :courses, :description, :text, null: false

    # Level::Translation is now purely an email-copy table.
    remove_column :level_translations, :title, :string, null: false
    remove_column :level_translations, :description, :text, null: false
    remove_column :level_translations, :milestone_summary, :text, null: false
    remove_column :level_translations, :milestone_content, :text, null: false

    # Lesson had no email copy, so its translations table has nothing left.
    drop_table :lesson_translations do |t|
      t.timestamps null: false
      t.text :description, null: false
      t.bigint :lesson_id, null: false
      t.string :locale, null: false
      t.string :title, null: false
      t.index %i[lesson_id locale], unique: true
      t.index :lesson_id
    end

    # Exercise lessons now carry no data at all. Rails' serialized type writes
    # NULL for a value matching the coder's default ({}), so the column has to
    # accept it; Lesson#data still reads it back as {}.
    change_column_null :lessons, :data, true
  end
end
