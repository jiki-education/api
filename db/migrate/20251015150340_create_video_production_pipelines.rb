class CreateVideoProductionPipelines < ActiveRecord::Migration[8.0]
  def change
    create_table :video_production_pipelines do |t|
      t.string :uuid, null: false
      t.string :version, null: false, default: '1.0'
      t.string :title, null: false
      t.jsonb :config, null: false, default: {}
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :video_production_pipelines, :uuid, unique: true
    add_index :video_production_pipelines, :updated_at
  end
end
