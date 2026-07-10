# LEGACY: UserProjects were renamed to UserChallenges, but polymorphic rows
# (exercise_submissions.context_type) still store "UserProject", so the
# constant must keep resolving. Remove once that data has been migrated.
UserProject = UserChallenge
