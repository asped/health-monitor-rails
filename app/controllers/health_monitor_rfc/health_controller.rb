# frozen_string_literal: true

module HealthMonitorRfc
  class HealthController < ActionController::Base
    protect_from_forgery with: :exception

    RESTRICTED_ENV_VARS = %i[status notes output checks].freeze

    if Rails.version.starts_with? '3'
      before_filter :authenticate_with_basic_auth
    else
      before_action :authenticate_with_basic_auth
    end

    def health
      @statuses = statuses
      http_response = @statuses.delete(:httpResponse)

      respond_to do |format|
        format.html
        format.json do
          render json: @statuses.to_json, status: http_response, content_type: 'application/health+json'
        end
        format.xml do
          render xml: @statuses.to_xml(root: 'result'), status: http_response
        end
      end
    end

    private

    def statuses
      res = HealthMonitorRfc.check(request: request, params: providers_params)
      res.merge(env_vars)
    end

    def env_vars
      v = HealthMonitorRfc.configuration.environment_variables || {}
      v.except(*RESTRICTED_ENV_VARS)
    end

    def authenticate_with_basic_auth
      return true unless HealthMonitorRfc.configuration.basic_auth_credentials

      credentials = HealthMonitorRfc.configuration.basic_auth_credentials
      authenticate_or_request_with_http_basic do |name, password|
        name == credentials[:username] && password == credentials[:password]
      end
    end

    def providers_params
      params.permit(:format, providers: [])
    end
  end
end
