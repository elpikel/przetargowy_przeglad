defmodule PrzetargowyPrzegladWeb.AdminComponents do
  use Phoenix.Component

  attr :href, :string, required: true
  attr :current, :boolean, default: false
  slot :inner_block, required: true

  def admin_nav_link(assigns) do
    ~H"""
    <a
      href={@href}
      class={[
        "rounded-md px-3 py-2 text-sm font-medium",
        @current && "bg-slate-900 text-white",
        !@current && "text-gray-300 hover:bg-slate-700 hover:text-white"
      ]}
    >
      {render_slot(@inner_block)}
    </a>
    """
  end

  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :subtitle, :string, default: nil
  attr :color, :string, default: "blue"

  def stat_card(assigns) do
    ~H"""
    <div class="bg-white overflow-hidden shadow rounded-lg">
      <div class="p-5">
        <div class="flex items-center">
          <div class="flex-shrink-0">
            <div class={[
              "rounded-md p-3",
              @color == "blue" && "bg-blue-500",
              @color == "green" && "bg-green-500",
              @color == "yellow" && "bg-yellow-500",
              @color == "red" && "bg-red-500"
            ]}>
              <span class="text-white text-xl">
                {case @color do
                  "blue" -> "📊"
                  "green" -> "✅"
                  "yellow" -> "⏳"
                  "red" -> "❌"
                  _ -> "📈"
                end}
              </span>
            </div>
          </div>
          <div class="ml-5 w-0 flex-1">
            <dl>
              <dt class="text-sm font-medium text-gray-500 truncate">
                {@title}
              </dt>
              <dd class="text-2xl font-semibold text-gray-900">
                {@value}
              </dd>
              <%= if @subtitle do %>
                <dd class="text-sm text-gray-500">
                  {@subtitle}
                </dd>
              <% end %>
            </dl>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
