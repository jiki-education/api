class AddWalkthroughVideoWatchedPercentageToUserLessons < ActiveRecord::Migration[8.1]
  def change
    add_column :user_lessons, :walkthrough_video_watched_percentage, :integer
  end
end
