class AddBonusCompletedAtToUserLessons < ActiveRecord::Migration[8.0]
  def change
    add_column :user_lessons, :bonus_completed_at, :datetime
  end
end
