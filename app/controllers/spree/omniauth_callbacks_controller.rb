# frozen_string_literal: true

class Spree::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  include Spree::Core::ControllerHelpers::Common
  include Spree::Core::ControllerHelpers::Order
  include Spree::Core::ControllerHelpers::Auth
  include Spree::Core::ControllerHelpers::Store
  include RouteResolver

  class << self
    def provides_callback_for(*providers)
      providers.each do |provider|
        define_method(provider) { omniauth_callback }
      end
    end
  end

  SolidusSocial::OAUTH_PROVIDERS.each do |provider|
    provides_callback_for provider.key.to_sym
  end

  after_action :set_current_order, only: SolidusSocial::OAUTH_PROVIDERS.map(&:key)

  def omniauth_callback
    if request.env['omniauth.error'].present?
      flash[:error] = I18n.t('devise.omniauth_callbacks.failure', kind: auth_hash['provider'], reason: I18n.t('spree.user_was_not_valid'))
      redirect_back_or_default(resolve_route_for(:root_url))
      return
    end

    authentication = Spree::UserAuthentication.find_by(provider: auth_hash['provider'], uid: auth_hash['uid'])

    if authentication.present? && authentication.try(:user).present?
      flash[:notice] = I18n.t('devise.omniauth_callbacks.success', kind: auth_hash['provider'])
      sign_in_and_redirect :spree_user, authentication.user
    elsif spree_current_user
      spree_current_user.apply_omniauth(auth_hash)
      spree_current_user.save!
      flash[:notice] = I18n.t('devise.sessions.signed_in')
      redirect_back_or_default(resolve_route_for(:account_url))
    else
      user = Spree.user_class.find_by(email: auth_hash['info']['email']) || Spree.user_class.new
      user.apply_omniauth(auth_hash)
      if user.save
        flash[:notice] = I18n.t('devise.omniauth_callbacks.success', kind: auth_hash['provider'])
        sign_in_and_redirect :spree_user, user
      else
        session[:omniauth] = auth_hash.except('extra')
        flash[:notice] = I18n.t('spree.one_more_step', kind: auth_hash['provider'].capitalize)
        redirect_to resolve_route_for(:new_spree_user_registration_url)
        return
      end
    end

    if current_order
      user = spree_current_user || authentication.user
      current_order.associate_user!(user)
      session[:guest_token] = nil
    end
  end

  def failure
    set_flash_message :alert, :failure, kind: failed_strategy.name.to_s.humanize, reason: failure_message
    redirect_to resolve_route_for(:login_path)
  end

  def passthru
    render file: "#{Rails.root}/public/404.html", formats: [:html], status: :not_found, layout: false
  end

  def auth_hash
    request.env['omniauth.auth']
  end

  def after_sign_in_path_for(resource_or_scope)
    stored_location_for(resource_or_scope) || resolve_route_for(:account_path)
  end
end
