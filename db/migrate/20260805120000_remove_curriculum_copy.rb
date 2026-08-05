class RemoveCurriculumCopy < ActiveRecord::Migration[8.1]
  # Irreversible: the copy these columns held is authored in the front-end
  # curriculum repo now, so there is nothing to restore them from. (Re-adding
  # NOT NULL columns to populated tables would fail anyway.)
  def up
    # Screen-rendered copy is authored in the front-end curriculum repo
    # (curriculum/src/**). Only email copy stays here.
    remove_column :lessons, :title
    remove_column :lessons, :description

    remove_column :levels, :title
    remove_column :levels, :description
    remove_column :levels, :milestone_summary
    remove_column :levels, :milestone_content

    remove_column :concepts, :title
    remove_column :concepts, :description

    remove_column :courses, :title
    remove_column :courses, :description

    # Level::Translation is now purely an email-copy table.
    remove_column :level_translations, :title
    remove_column :level_translations, :description
    remove_column :level_translations, :milestone_summary
    remove_column :level_translations, :milestone_content

    # Lesson had no email copy, so its translations table has nothing left.
    drop_table :lesson_translations

    # Exercise lessons now carry no data at all. Rails' serialized type writes
    # NULL for a value matching the coder's default ({}), so the column has to
    # accept it; Lesson#data still reads it back as {}.
    change_column_null :lessons, :data, true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
