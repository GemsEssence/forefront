module Forefront
  class ProductPolicy < ApplicationPolicy
    def index?
      true
    end

    def show?
      true
    end

    def new?
      manages_products?
    end

    def create?
      manages_products?
    end

    def edit?
      manages_products?
    end

    def update?
      manages_products?
    end

    def generate_api_key?
      pundit_user.admin?
    end

    class Scope < Scope
      def resolve
        scope.all
      end
    end

    private

    def manages_products?
      pundit_user.admin? || pundit_user.manager?
    end
  end
end
