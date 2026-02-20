Rails.application.routes.draw do
  # Solid Queue Monitor with Basic Auth
  require "solid_queue_monitor"
  SolidQueueMonitor::Engine.middleware.use Rack::Auth::Basic do |username, password|
    ActiveSupport::SecurityUtils.secure_compare(
      ::Digest::SHA256.hexdigest(username),
      ::Digest::SHA256.hexdigest(Jiki.secrets.job_monitor_username)
    ) &
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(password),
        ::Digest::SHA256.hexdigest(Jiki.secrets.job_monitor_password)
      )
  end
  mount SolidQueueMonitor::Engine, at: "/solid_queue"

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
      passwords: "auth/passwords",
      confirmations: "auth/confirmations"
    },
    skip: [:omniauth_callbacks]

  # Additional auth endpoints (outside devise scope)
  namespace :auth do
    post "google", to: "google_oauth#create"
    post "unsubscribe/:token", to: "unsubscribe#create", as: :unsubscribe
    get "discourse/sso", to: "discourse#sso"
    post "account_deletion/request", to: "account_deletions#request_deletion"
    post "account_deletion/confirm", to: "account_deletions#confirm"

    # Two-factor authentication
    post "verify-2fa", to: "two_factor#verify"
    post "setup-2fa", to: "two_factor#setup"
  end

  # External (public, unauthenticated) endpoints
  namespace :external do
    resources :concepts, only: %i[index show], param: :concept_slug

    resources :email_preferences, only: %i[show update], param: :token do
      member do
        post :unsubscribe_all
        post :subscribe_all
      end
    end
  end

  # Internal (authenticated user) endpoints
  namespace :internal do
    resource :me, only: [:show]
    resource :profile, only: [:show] do
      resource :avatar, only: %i[update destroy], controller: 'profile/avatars'
    end

    resource :settings, only: [:show] do
      patch :name
      patch :email
      patch :password
      patch :locale
      patch :handle
      patch :streaks
      patch 'notifications/:slug', action: :notification, as: :notification
    end

    resources :courses, only: %i[index show]

    resources :user_courses, only: %i[index show] do
      member do
        post :enroll
        patch :language
      end
    end

    resources :levels, only: [:index] do
      member do
        get :milestone
      end
    end
    resources :user_levels, only: [:index], param: :level_slug do
      member do
        patch :complete
      end
    end

    # Always have the param as lesson slug - auto-prefixed in the second
    resources :lessons, only: [:show], param: :lesson_slug
    resources :lessons, only: [], param: :slug do
      resources :exercise_submissions, only: [:create] do
        collection do
          get :latest
        end
      end
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

    resources :badges, only: [:index] do
      member do
        patch :reveal
      end
    end

    resource :assistant_conversations, only: [:create] do
      post :user_messages, action: :create_user_message
      post :assistant_messages, action: :create_assistant_message
    end

    # Subscription management
    namespace :subscriptions do
      post :checkout_session
      post :verify_checkout
      post :portal_session
      post :update
      delete :cancel
      post :reactivate
    end

    # Payment history
    resources :payments, only: [:index]
  end

  # Admin routes
  namespace :admin do
    resources :concepts, only: %i[index show create update destroy]
    resources :projects, only: %i[index show create update destroy]
    resources :users, only: %i[index show update destroy]
    resources :levels, only: %i[index create update] do
      resources :lessons, only: %i[index create update], controller: "levels/lessons"
      scope module: :level do
        resources :translations, only: [] do
          collection do
            post :translate
          end
        end
      end
    end
    resources :lessons, only: [] do
      scope module: :lesson do
        resources :translations, only: [] do
          collection do
            post :translate
          end
        end
      end
    end
    resources :images, only: [:create]
  end

  # Webhooks endpoints
  # Unauthenticated - security handled by signature verification
  namespace :webhooks do
    post 'stripe', to: 'stripe#create'
    post 'ses', to: 'ses#create'
  end

  # Dev endpoints
  # Development-only utilities - return 404 in production
  namespace :dev do
    resources :users, param: :handle, only: [] do
      member do
        delete :clear_stripe_history
      end
    end
  end

  # Health check endpoint for ECS/ALB (verifies database connectivity)
  get "health-check", to: "external/health#check"

  # Defines the root path route ("/")
  # root "posts#index"
end
