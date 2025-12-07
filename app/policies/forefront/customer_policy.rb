module Forefront
  class CustomerPolicy
    attr_reader :current_admin, :customer

    def initialize(current_admin, customer)
      @current_admin = current_admin
      @customer = customer
    end

    def index?
      true
    end

    def show?
      true
    end

    def create?
      true
    end

    def new?
      create?
    end

    def update?
      true
    end

    def edit?
      update?
    end

    def destroy?
      super_admin?
    end

    class Scope
      def initialize(current_admin, scope)
        @current_admin = current_admin
        @scope = scope
      end

      def resolve
        @scope
      end

      private

      def super_admin?
        @current_admin.super_admin?
      end
    end

    private

    def super_admin?
      current_admin.super_admin?
    end
  end
end
