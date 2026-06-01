class AddUuidToCurriculumTables < ActiveRecord::Migration[8.1]
  TABLES = %i[levels lessons concepts projects].freeze

  def up
    TABLES.each do |table|
      add_column table, :uuid, :string

      # Backfill existing rows with random uuids. Records managed by the curriculum
      # JSON files are re-stamped with their canonical uuids on the next db:seed
      # (matched by slug), so these are only permanent for non-curriculum records.
      execute "UPDATE #{table} SET uuid = gen_random_uuid()"

      change_column_null table, :uuid, false
      add_index table, :uuid, unique: true
    end
  end

  def down
    TABLES.each do |table|
      remove_column table, :uuid
    end
  end
end
