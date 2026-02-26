class RemoveVideoDataFromConcepts < ActiveRecord::Migration[8.1]
  def change
    remove_column :concepts, :video_data, :json
  end
end
