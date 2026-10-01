module Forefront
  module SidebarHelper
    # A sidebar link, highlighted while you're on that page or one under it
    # (a Lead's page keeps "Leads" lit). The Dashboard is lit only on itself.
    def sidebar_link(label, path, &badge)
      here = request.path == path || (path != root_path && request.path.start_with?("#{path}/"))
      classes = here ? "bg-indigo-50 text-indigo-700" : "text-gray-700 hover:bg-gray-100 hover:text-gray-900"
      link_to path, class: "flex items-center justify-between rounded-md px-3 py-2 text-sm font-medium #{classes}",
                    aria: { current: (here ? "page" : nil) } do
        safe_join([ label, (capture(&badge) if badge) ].compact)
      end
    end
  end
end
