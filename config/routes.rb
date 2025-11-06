Rails.application.routes.draw do
  # Sidekiq Web UI with Basic Auth
  require "sidekiq/web"
  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    ActiveSupport::SecurityUtils.secure_compare(
      ::Digest::SHA256.hexdigest(username),
      ::Digest::SHA256.hexdigest(Jiki.secrets.sidekiq_username)
    ) &
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(password),
        ::Digest::SHA256.hexdigest(Jiki.secrets.sidekiq_password)
      )
  end
  mount Sidekiq::Web => "/sidekiq"

  # Auth routes (Devise)
  devise_for :users,
    path: "auth",
    path_names: {
      sign_in: "login",
      sign_out: "logout",
      registration: "signup"
    },
    controllers: {
      sessions: "auth/sessions",
      registrations: "auth/registrations",
      passwords: "auth/passwords"
    },
    skip: [:omniauth_callbacks]

  # External (public, unauthenticated) endpoints
  namespace :external do
    resources :concepts, only: %i[index show], param: :concept_slug
  end

  # Internal (authenticated user) endpoints
  namespace :internal do
    resource :me, only: [:show]

    resources :levels, only: [:index]
    resources :user_levels, only: [:index]

    # Always have the param as lesson slug - auto-prefixed in the second
    resources :lessons, only: [:show], param: :lesson_slug
    resources :lessons, only: [], param: :slug do
      resources :exercise_submissions, only: [:create]
    end

    # Projects with exercise submissions
    resources :projects, only: %i[index show], param: :project_slug
    resources :projects, only: [], param: :slug do
      resources :exercise_submissions, only: [:create], controller: 'projects/exercise_submissions'
    end

    resources :user_lessons, only: [:show], param: :lesson_slug do
      member do
        post :start
        patch :complete
      end
    end

    resources :user_projects, only: [:show], param: :project_slug

    resources :concepts, only: %i[index show], param: :concept_slug

    resource :assistant_conversations, only: [] do
      post :user_messages, action: :create_user_message
      post :assistant_messages, action: :create_assistant_message
    end
  end

  # Admin routes
  namespace :admin do
    resources :concepts, only: %i[index show create update destroy]
    resources :projects, only: %i[index show create update destroy]
    resources :email_templates, only: %i[index show create update destroy] do
      collection do
        get :types
        get :summary
      end
    end
    resources :users, only: %i[index show update destroy]
    resources :levels, only: %i[index create update] do
      resources :lessons, only: %i[index create update], controller: "levels/lessons"
    end

    namespace :video_production do
      resources :pipelines, only: %i[index show create update destroy], param: :uuid do
        resources :nodes, only: %i[index show create update destroy], param: :uuid do
          member do
            post :execute
            get :output
          end
        end
      end
    end
  end

  # SPI (Service Provider Interface) endpoints
  # Network-guarded endpoints for service-to-service communication
  # No authentication required - security handled at network level
  namespace :spi do
    namespace :video_production do
      post :executor_callback
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
end
