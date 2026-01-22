class AddParentConceptToConcepts < ActiveRecord::Migration[8.1]
  def change
    add_column :concepts, :parent_concept_id, :bigint
    add_column :concepts, :children_count, :integer, default: 0, null: false

    add_index :concepts, :parent_concept_id
    add_foreign_key :concepts, :concepts, column: :parent_concept_id, on_delete: :nullify
  end
end
