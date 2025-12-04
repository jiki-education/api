class RemoveStartedAtFromUserLessonsAndUserLevels < ActiveRecord::Migration[8.1]
  def change
    remove_column :user_lessons, :started_at, :datetime
    remove_column :user_levels, :started_at, :datetime
  end
end
