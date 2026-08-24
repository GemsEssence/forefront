module Forefront
  class ApplicationPolicy
    attr_reader :current_admin, :record

    def initialize(current_admin, record)
      @current_admin = current_admin
      @record = record
    end

    def pundit_user
      current_admin
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

      attr_reader :current_admin, :scope

      def pundit_user
        current_admin
      end

      def super_admin?
        current_admin.super_admin?
      end
    end

    private

    def super_admin?
      current_admin.super_admin?
    end
  end
end
