class RenameUserVideosSlugToUuid < ActiveRecord::Migration[8.1]
  def change
    rename_column :user_videos, :slug, :uuid
  end
end
