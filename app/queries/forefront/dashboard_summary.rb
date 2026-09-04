module Forefront
  class DashboardSummary
    attr_reader :current_admin

    def initialize(current_admin)
      @current_admin = current_admin
    end

    def visible_admins
      if current_admin.admin?
        Admin.sales_person
      elsif current_admin.manager?
        current_admin.direct_reports.sales_person
      else
        Admin.where(id: current_admin.id)
      end
    end

    def show_leaderboard?
      current_admin.admin? || current_admin.manager?
    end

    def total_revenue
      payments_for(visible_admins).sum { |payment| payment.fully_paid? ? payment.total_amount : 0 }
    end

    def open_leads_count
      Lead.where(assigned_to_id: visible_admins.select(:id)).active.count
    end

    def won_leads_count
      Lead.where(assigned_to_id: visible_admins.select(:id)).won.count
    end

    def overdue_followups_count
      Followup.pending.where(assigned_to_id: visible_admins.select(:id)).where("scheduled_for < ?", Time.current).count
    end

    def target_summary
      targets = Target.where(admin_id: visible_admins.select(:id)).includes(product: :leads)
      counts = { achieved: 0, missed: 0, in_progress: 0 }

      targets.each do |target|
        if target.achieved?
          counts[:achieved] += 1
        elsif target.missed?
          counts[:missed] += 1
        else
          counts[:in_progress] += 1
        end
      end

      counts
    end

    def leaderboard
      visible_admins.map { |admin| { admin: admin, revenue: revenue_for(admin) } }
                     .sort_by { |row| -row[:revenue] }
    end

    private

    def payments_for(admins)
      Payment.joins(:lead).where(forefront_leads: { assigned_to_id: admins.select(:id) }).includes(:installments)
    end

    def revenue_for(admin)
      payments_for(Admin.where(id: admin.id)).sum { |payment| payment.fully_paid? ? payment.total_amount : 0 }
    end
  end
end
