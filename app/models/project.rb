# LEGACY: Projects were renamed to Challenges, but polymorphic rows
# (assistant_conversations.context_type, friendly_id_slugs.sluggable_type)
# still store "Project", so the constant must keep resolving.
# Remove once that data has been migrated.
Project = Challenge
