# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_28_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "assistant_conversations", force: :cascade do |t|
    t.bigint "context_id", null: false
    t.string "context_type", null: false
    t.datetime "created_at", null: false
    t.json "messages", default: [], null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["context_type", "context_id"], name: "index_assistant_conversations_on_context"
    t.index ["user_id", "context_type", "context_id"], name: "index_assistant_conversations_on_user_and_context", unique: true
    t.index ["user_id"], name: "index_assistant_conversations_on_user_id"
  end

  create_table "badge_translations", force: :cascade do |t|
    t.bigint "badge_id", null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.text "fun_fact", null: false
    t.string "locale", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["badge_id", "locale"], name: "index_badge_translations_on_badge_id_and_locale", unique: true
    t.index ["badge_id"], name: "index_badge_translations_on_badge_id"
  end

  create_table "badges", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.text "fun_fact"
    t.string "icon", null: false
    t.string "name", null: false
    t.integer "num_awardees", default: 0, null: false
    t.boolean "secret", default: false, null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_badges_on_name", unique: true
    t.index ["type"], name: "index_badges_on_type", unique: true
  end

  create_table "concepts", force: :cascade do |t|
    t.integer "children_count", default: 0, null: false
    t.text "content_html", null: false
    t.text "content_markdown", null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.bigint "parent_concept_id"
    t.string "premium_video_id"
    t.string "premium_video_provider"
    t.string "slug", null: false
    t.string "standard_video_id"
    t.string "standard_video_provider"
    t.string "title", null: false
    t.bigint "unlocked_by_lesson_id"
    t.datetime "updated_at", null: false
    t.index ["parent_concept_id"], name: "index_concepts_on_parent_concept_id"
    t.index ["slug"], name: "index_concepts_on_slug", unique: true
    t.index ["unlocked_by_lesson_id"], name: "index_concepts_on_unlocked_by_lesson_id"
  end

  create_table "courses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.integer "position", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_courses_on_position", unique: true
    t.index ["slug"], name: "index_courses_on_slug", unique: true
  end

  create_table "email_templates", force: :cascade do |t|
    t.text "body_mjml", null: false
    t.text "body_text", null: false
    t.datetime "created_at", null: false
    t.string "locale", null: false
    t.string "slug"
    t.text "subject", null: false
    t.integer "type", null: false
    t.datetime "updated_at", null: false
    t.index ["type", "slug", "locale"], name: "index_email_templates_on_type_and_slug_and_locale", unique: true
  end

  create_table "exercise_submission_files", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "digest", null: false
    t.bigint "exercise_submission_id", null: false
    t.string "filename", null: false
    t.datetime "updated_at", null: false
    t.index ["exercise_submission_id"], name: "index_exercise_submission_files_on_exercise_submission_id"
  end

  create_table "exercise_submissions", force: :cascade do |t|
    t.bigint "context_id", null: false
    t.string "context_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["context_type", "context_id"], name: "index_exercise_submissions_on_context"
    t.index ["uuid"], name: "index_exercise_submissions_on_uuid", unique: true
  end

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.datetime "created_at"
    t.string "scope"
    t.string "slug", null: false
    t.integer "sluggable_id", null: false
    t.string "sluggable_type", limit: 50
    t.index ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true
    t.index ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type"
    t.index ["sluggable_type", "sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_type_and_sluggable_id"
  end

  create_table "lesson_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.bigint "lesson_id", null: false
    t.string "locale", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["lesson_id", "locale"], name: "index_lesson_translations_on_lesson_id_and_locale", unique: true
    t.index ["lesson_id"], name: "index_lesson_translations_on_lesson_id"
  end

  create_table "lessons", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "data", default: {}, null: false
    t.text "description", null: false
    t.bigint "level_id", null: false
    t.integer "position", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["level_id", "position"], name: "index_lessons_on_level_id_and_position", unique: true
    t.index ["level_id"], name: "index_lessons_on_level_id"
    t.index ["slug"], name: "index_lessons_on_slug", unique: true
    t.index ["type"], name: "index_lessons_on_type"
  end

  create_table "level_translations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.bigint "level_id", null: false
    t.string "locale", null: false
    t.text "milestone_content", null: false
    t.text "milestone_summary", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["level_id", "locale"], name: "index_level_translations_on_level_id_and_locale", unique: true
    t.index ["level_id"], name: "index_level_translations_on_level_id"
  end

  create_table "levels", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.text "milestone_content", null: false
    t.text "milestone_summary", null: false
    t.integer "position", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id", "position"], name: "index_levels_on_course_id_and_position", unique: true
    t.index ["course_id"], name: "index_levels_on_course_id"
    t.index ["slug"], name: "index_levels_on_slug", unique: true
  end

  create_table "payments", force: :cascade do |t|
    t.integer "amount_in_cents", null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.jsonb "data", default: {}, null: false
    t.string "external_receipt_url"
    t.string "payment_processor_id", null: false
    t.string "product", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["data"], name: "index_payments_on_data", using: :gin
    t.index ["payment_processor_id"], name: "index_payments_on_payment_processor_id", unique: true
    t.index ["user_id", "created_at"], name: "index_payments_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.string "exercise_slug", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.bigint "unlocked_by_lesson_id"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_projects_on_slug", unique: true
    t.index ["unlocked_by_lesson_id"], name: "index_projects_on_unlocked_by_lesson_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "user_acquired_badges", force: :cascade do |t|
    t.bigint "badge_id", null: false
    t.datetime "created_at", null: false
    t.boolean "revealed", default: false, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["badge_id"], name: "index_user_acquired_badges_on_badge_id"
    t.index ["user_id", "badge_id"], name: "index_user_acquired_badges_on_user_id_and_badge_id", unique: true
    t.index ["user_id"], name: "index_user_acquired_badges_on_user_id"
  end

  create_table "user_activity_data", force: :cascade do |t|
    t.jsonb "activity_days", default: {}, null: false
    t.datetime "created_at", null: false
    t.integer "current_streak", default: 0, null: false
    t.integer "longest_streak", default: 0, null: false
    t.integer "total_active_days", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["activity_days"], name: "index_user_activity_data_on_activity_days", using: :gin
    t.index ["user_id"], name: "index_user_activity_data_on_user_id", unique: true
  end

  create_table "user_courses", force: :cascade do |t|
    t.datetime "completed_at"
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.bigint "current_user_level_id"
    t.string "language"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["course_id"], name: "index_user_courses_on_course_id"
    t.index ["current_user_level_id"], name: "index_user_courses_on_current_user_level_id"
    t.index ["user_id", "course_id"], name: "index_user_courses_on_user_id_and_course_id", unique: true
    t.index ["user_id"], name: "index_user_courses_on_user_id"
  end

  create_table "user_data", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_bounce_reason"
    t.datetime "email_bounced_at"
    t.datetime "email_complaint_at"
    t.string "email_complaint_type"
    t.string "email_verification_token"
    t.datetime "last_email_opened_at"
    t.string "membership_type", default: "standard", null: false
    t.boolean "notifications_enabled", default: true, null: false
    t.boolean "receive_activity_emails", default: true, null: false
    t.boolean "receive_event_emails", default: true, null: false
    t.boolean "receive_milestone_emails", default: true, null: false
    t.boolean "receive_product_updates", default: true, null: false
    t.boolean "streaks_enabled", default: false, null: false
    t.string "stripe_customer_id"
    t.string "stripe_subscription_id"
    t.string "stripe_subscription_status"
    t.integer "subscription_status", default: 0, null: false
    t.datetime "subscription_valid_until"
    t.jsonb "subscriptions", default: [], null: false
    t.string "timezone"
    t.bigint "unlocked_concept_ids", default: [], null: false, array: true
    t.string "unsubscribe_token", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["membership_type"], name: "index_user_data_on_membership_type"
    t.index ["stripe_customer_id"], name: "index_user_data_on_stripe_customer_id", unique: true
    t.index ["stripe_subscription_id"], name: "index_user_data_on_stripe_subscription_id"
    t.index ["subscription_status"], name: "index_user_data_on_subscription_status"
    t.index ["subscriptions"], name: "index_user_data_on_subscriptions", using: :gin
    t.index ["unlocked_concept_ids"], name: "index_user_data_on_unlocked_concept_ids", using: :gin
    t.index ["unsubscribe_token"], name: "index_user_data_on_unsubscribe_token", unique: true
    t.index ["user_id"], name: "index_user_data_on_user_id", unique: true
  end

  create_table "user_lessons", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "lesson_id", null: false
    t.datetime "started_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["lesson_id"], name: "index_user_lessons_on_lesson_id"
    t.index ["user_id", "lesson_id"], name: "index_user_lessons_on_user_id_and_lesson_id", unique: true
    t.index ["user_id"], name: "index_user_lessons_on_user_id"
  end

  create_table "user_levels", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "current_user_lesson_id"
    t.integer "email_status", default: 0, null: false
    t.bigint "level_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["current_user_lesson_id"], name: "index_user_levels_on_current_user_lesson_id"
    t.index ["level_id"], name: "index_user_levels_on_level_id"
    t.index ["user_id", "level_id"], name: "index_user_levels_on_user_id_and_level_id", unique: true
    t.index ["user_id"], name: "index_user_levels_on_user_id"
  end

  create_table "user_projects", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.bigint "project_id", null: false
    t.datetime "started_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["project_id"], name: "index_user_projects_on_project_id"
    t.index ["user_id", "project_id"], name: "index_user_projects_on_user_id_and_project_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "google_id"
    t.string "handle", null: false
    t.string "locale", default: "en", null: false
    t.string "name"
    t.string "provider"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["google_id"], name: "index_users_on_google_id", unique: true
    t.index ["handle"], name: "index_users_on_handle", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "video_production_nodes", force: :cascade do |t|
    t.jsonb "asset"
    t.jsonb "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.jsonb "inputs", default: {}, null: false
    t.boolean "is_valid", default: false, null: false
    t.jsonb "metadata"
    t.jsonb "output"
    t.bigint "pipeline_id", null: false
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.jsonb "validation_errors", default: {}, null: false
    t.index ["pipeline_id", "status"], name: "index_video_production_nodes_on_pipeline_id_and_status"
    t.index ["pipeline_id"], name: "index_video_production_nodes_on_pipeline_id"
    t.index ["status"], name: "index_video_production_nodes_on_status"
    t.index ["type"], name: "index_video_production_nodes_on_type"
    t.index ["uuid"], name: "index_video_production_nodes_on_uuid", unique: true
  end

  create_table "video_production_pipelines", force: :cascade do |t|
    t.jsonb "config", default: {}, null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.string "version", default: "1.0", null: false
    t.index ["updated_at"], name: "index_video_production_pipelines_on_updated_at"
    t.index ["uuid"], name: "index_video_production_pipelines_on_uuid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "assistant_conversations", "users"
  add_foreign_key "badge_translations", "badges"
  add_foreign_key "concepts", "concepts", column: "parent_concept_id", on_delete: :nullify
  add_foreign_key "concepts", "lessons", column: "unlocked_by_lesson_id"
  add_foreign_key "exercise_submission_files", "exercise_submissions"
  add_foreign_key "lesson_translations", "lessons"
  add_foreign_key "lessons", "levels"
  add_foreign_key "level_translations", "levels"
  add_foreign_key "levels", "courses"
  add_foreign_key "payments", "users"
  add_foreign_key "projects", "lessons", column: "unlocked_by_lesson_id"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "user_acquired_badges", "badges"
  add_foreign_key "user_acquired_badges", "users"
  add_foreign_key "user_activity_data", "users"
  add_foreign_key "user_courses", "courses"
  add_foreign_key "user_courses", "user_levels", column: "current_user_level_id"
  add_foreign_key "user_courses", "users"
  add_foreign_key "user_data", "users"
  add_foreign_key "user_lessons", "lessons"
  add_foreign_key "user_lessons", "users"
  add_foreign_key "user_levels", "levels"
  add_foreign_key "user_levels", "user_lessons", column: "current_user_lesson_id"
  add_foreign_key "user_levels", "users"
  add_foreign_key "user_projects", "projects"
  add_foreign_key "user_projects", "users"
  add_foreign_key "video_production_nodes", "video_production_pipelines", column: "pipeline_id", on_delete: :cascade
end
