# Configure Prosopite to ignore specific files with known N+1 queries
# These should be fixed eventually, but are temporarily ignored

return unless defined?(Prosopite)

Prosopite.allow_stack_paths = [
  'app/commands/level/create_all_from_json.rb',
  # Iterates each due user to create a notification if one doesn't already
  # exist. The per-user existence check in User::Notification::Create is
  # inherent to "create one per user, ever" and can't be batched away.
  # (User::Data is preloaded via includes(:data), so premium? is not an N+1.)
  'app/commands/user/onboarding/create_due_notifications.rb'
]
