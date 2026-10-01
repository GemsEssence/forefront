module Forefront
  class SettingsPolicy < ApplicationPolicy
    def show?
      pundit_user.admin?
    end

    def update?
      pundit_user.admin?
    end
  end
end
