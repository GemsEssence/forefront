module Pundit
  class PolicyFinder
    # Override for Rails engines with namespaced policies
    def policy(object)
      klass = case object
      when String, Symbol
        object.to_s.camelize.constantize
      else
        object.class
      end

      # Try to find in the same namespace first (for Rails engines)
      module_name = klass.module_parent.name
      policy_class_name = "#{module_name}::#{klass.name.demodulize}Policy"
      
      begin
        policy_class_name.constantize
      rescue NameError
        # Fall back to default Pundit behavior
        "#{klass.name}Policy".constantize
      end
    end
  end
end
