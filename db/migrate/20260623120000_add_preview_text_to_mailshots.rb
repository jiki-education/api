class AddPreviewTextToMailshots < ActiveRecord::Migration[8.1]
  def change
    add_column :mailshots, :preview_text, :string, null: false, default: ""
  end
end
