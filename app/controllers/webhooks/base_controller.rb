# Base controller for all webhook endpoints
#
# Webhooks don't use the standard Rails authentication stack - instead they
# use signature verification (implementation-specific to each webhook provider).
#
# This base controller provides:
# - ActionController::API inheritance (no session, cookies, views, CSRF)
class Webhooks::BaseController < ActionController::API
end
