class AddRatingsToUserLessons < ActiveRecord::Migration[8.1]
  def change
    add_column :user_lessons, :difficulty_rating, :integer
    add_column :user_lessons, :fun_rating, :integer
  end
end
