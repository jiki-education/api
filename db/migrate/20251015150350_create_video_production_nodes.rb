class CreateVideoProductionNodes < ActiveRecord::Migration[8.0]
  def change
    create_table :video_production_nodes do |t|
      t.string :uuid, null: false
      t.references :pipeline, null: false, foreign_key: { to_table: :video_production_pipelines, on_delete: :cascade }
      t.string :title, null: false

      # Structure (Next.js writes)
      t.string :type, null: false
      t.jsonb :inputs, null: false, default: {}
      t.jsonb :config, null: false, default: {}
      t.jsonb :asset

      # Execution state (Rails writes)
      t.string :status, null: false, default: 'pending'
      t.jsonb :metadata
      t.jsonb :output

      # Validation state (Rails writes)
      t.boolean :is_valid, null: false, default: false
      t.jsonb :validation_errors, null: false, default: {}

      t.timestamps
    end

    add_index :video_production_nodes, :uuid, unique: true
    add_index :video_production_nodes, :type
    add_index :video_production_nodes, :status
    add_index :video_production_nodes, %i[pipeline_id status]
  end
end
