class AddVideoDataColumns < ActiveRecord::Migration[8.1]
  def change
    add_column :lessons, :walkthrough_video_data, :json, null: true

    add_column :concepts, :video_data, :json, null: true
    remove_column :concepts, :standard_video_provider, :string
    remove_column :concepts, :standard_video_id, :string
    remove_column :concepts, :premium_video_provider, :string
    remove_column :concepts, :premium_video_id, :string
  end
end
