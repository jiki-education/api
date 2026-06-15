# Configure Prosopite to ignore specific files with known N+1 queries
# These should be fixed eventually, but are temporarily ignored

return unless defined?(Prosopite)

Prosopite.allow_stack_paths = [
  'app/commands/level/create_all_from_json.rb',
  # Loops over a small fixed list of onboarding kinds; each issues one bucketed
  # query for a distinct cohort of users — not an N+1.
  'app/commands/user/onboarding/create_due_notifications.rb'
]
