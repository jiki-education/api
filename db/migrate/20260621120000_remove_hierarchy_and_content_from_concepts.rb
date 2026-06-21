class RemoveHierarchyAndContentFromConcepts < ActiveRecord::Migration[8.1]
  def up
    # Remove the loops and conditionals concepts, plus any unlocked-concept links pointing at them.
    deleted_ids = select_values("SELECT id FROM concepts WHERE slug IN ('loops', 'conditionals')").map(&:to_i)
    deleted_ids.each do |id|
      execute("UPDATE user_data SET unlocked_concept_ids = array_remove(unlocked_concept_ids, #{id})")
    end
    execute("DELETE FROM concepts WHERE id IN (#{deleted_ids.join(', ')})") if deleted_ids.any?

    # Rename concepts. Order matters to avoid a unique-slug clash on "state".
    execute("UPDATE concepts SET slug = 'updating-variables', title = 'Updating Variables' WHERE slug = 'state'")
    execute("UPDATE concepts SET slug = 'state', title = 'State' WHERE slug = 'conditionals-and-state'")

    remove_reference :concepts, :parent_concept, foreign_key: { to_table: :concepts }, index: true
    remove_column :concepts, :children_count, :integer, null: false, default: 0
    remove_column :concepts, :content_markdown, :text, null: false
    remove_column :concepts, :content_html, :text, null: false
  end

  def down
    # Add with a temporary default to backfill existing rows, then drop the
    # default to match the original schema (NOT NULL, no default).
    add_column :concepts, :content_html, :text, null: false, default: ""
    add_column :concepts, :content_markdown, :text, null: false, default: ""
    change_column_default :concepts, :content_html, from: "", to: nil
    change_column_default :concepts, :content_markdown, from: "", to: nil

    add_column :concepts, :children_count, :integer, null: false, default: 0
    add_reference :concepts, :parent_concept, foreign_key: { to_table: :concepts }, index: true

    # Reverse the renames (opposite order to avoid a unique-slug clash on "state").
    execute("UPDATE concepts SET slug = 'conditionals-and-state', title = 'Using If and State' WHERE slug = 'state'")
    execute("UPDATE concepts SET slug = 'state', title = 'State' WHERE slug = 'updating-variables'")
  end
end
