module Forefront
  # What a Staff member needs to work on, sorted by when (the "My work"
  # page): their unfinished Tickets and Leads, pending Followups and unpaid
  # Installments. A Manager sees their team's; an Admin, everyone's.
  class MyWork
    # at: a Followup's time, which makes it overdue once it has passed.
    Item = Struct.new(:label, :date, :at, :path_target, :owner, keyword_init: true)

    SECTIONS = {
      "overdue" => "Overdue", "today" => "Today", "next_7_days" => "Next 7 days", "undated" => "No date set"
    }.freeze

    attr_reader :viewer, :today

    def initialize(viewer, now: Time.current)
      @viewer = viewer
      @now = now
      @today = now.to_date
    end

    def team?
      !viewer.sales_person?
    end

    # { "overdue" => [Item, ...], ... }, each sorted by date. Work due more
    # than a week out isn't listed.
    def sections
      @sections ||= SECTIONS.keys.index_with { [] }.tap do |sorted|
        items.each do |item|
          section = section_for(item)
          sorted[section] << item if section
        end
        sorted.each_value { |list| list.sort_by! { |item| [ item.date || today, item.label ] } }
      end
    end

    def unanswered_reveals
      ContactReveal.where(admin: viewer).includes(:customer).order(created_at: :desc)
                   .uniq(&:customer_id).reject(&:answered?)
    end

    private

    def people
      if viewer.admin?
        Admin.people
      elsif viewer.manager?
        Admin.where(id: viewer.direct_report_ids << viewer.id)
      else
        Admin.where(id: viewer.id)
      end
    end

    def items
      work = Ticket.unfinished.where(assigned_to: people).includes(:assigned_to).to_a +
             Lead.active.where(assigned_to: people).includes(:assigned_to).to_a
      work.map { |record| Item.new(label: record.title, date: record.due_at, path_target: record, owner: record.assigned_to) } +
        followup_items + installment_items
    end

    # Installments are listed themselves, so their reminder Followups aren't.
    def followup_items
      Followup.pending.where(assigned_to: people).where.not(followupable_type: Installment.name).includes(:followupable, :assigned_to).map do |followup|
        Item.new(label: "Followup (#{followup.followup_type}) on #{followup.followupable.title}",
                 date: followup.scheduled_for&.to_date, at: followup.scheduled_for,
                 path_target: followup.followupable, owner: followup.assigned_to)
      end
    end

    def installment_items
      Installment.pending.joins(payment: :lead).where(forefront_leads: { assigned_to_id: people.select(:id) })
                 .includes(payment: { lead: :assigned_to }).map do |installment|
        lead = installment.payment.lead
        Item.new(label: "Installment of #{money(installment.amount)} on #{lead.title}", date: installment.due_on,
                 path_target: lead, owner: lead.assigned_to)
      end
    end

    def section_for(item)
      date = item.date
      return "undated" if date.nil?
      return "overdue" if date < today || (item.at && item.at < @now)
      return "today" if date == today

      "next_7_days" if date <= today + 7
    end

    def money(amount)
      @money ||= Object.new.extend(ActionView::Helpers::NumberHelper, CurrencyHelper)
      @money.format_money(amount)
    end
  end
end
