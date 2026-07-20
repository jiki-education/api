class RenameProjectsToChallenges < ActiveRecord::Migration[8.1]
  def up
    # -- Backfill polymorphic type names --------------------------------------
    execute "UPDATE assistant_conversations SET context_type = 'Challenge' WHERE context_type = 'Project'"
    execute "UPDATE exercise_submissions SET context_type = 'UserChallenge' WHERE context_type = 'UserProject'"
    execute "UPDATE friendly_id_slugs SET sluggable_type = 'Challenge' WHERE sluggable_type = 'Project'"

    # -- Rename the tables -----------------------------------------------------
    rename_column :user_projects, :project_id, :challenge_id
    rename_table :projects, :challenges
    rename_table :user_projects, :user_challenges

    # Compatibility views so in-flight step B code keeps working during the
    # rolling deploy. Dropped in a follow-up migration once this deploy has
    # fully rolled out.
    execute <<~SQL
      CREATE VIEW projects AS SELECT * FROM challenges;
      CREATE VIEW user_projects AS
        SELECT id, user_id, challenge_id AS project_id, started_at, completed_at, created_at, updated_at
        FROM user_challenges;
    SQL
  end

  def down
    execute "DROP VIEW user_projects"
    execute "DROP VIEW projects"

    rename_table :user_challenges, :user_projects
    rename_table :challenges, :projects
    rename_column :user_projects, :challenge_id, :project_id

    execute "UPDATE friendly_id_slugs SET sluggable_type = 'Project' WHERE sluggable_type = 'Challenge'"
    execute "UPDATE exercise_submissions SET context_type = 'UserProject' WHERE context_type = 'UserChallenge'"
    execute "UPDATE assistant_conversations SET context_type = 'Project' WHERE context_type = 'Challenge'"
  end
end
