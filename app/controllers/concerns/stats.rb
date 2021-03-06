module Stats
  extend ActiveSupport::Concern

  TIME_RANGE_FILTERS = %w[last_24_hours last_3_days current_month custom]

  SORT_BY_FIELDS = %w[winrate share]
  DEFAULT_SORT_BY = :winrate

  ORDER_FIELDS = %w[asc desc]
  DEFAULT_ORDER = :desc

  included do
    before_action :read_params
  end

  def user_results
    @results ||= begin
                   results = current_user.results
                   if @time_range
                     results = results.where('created_at >= ? AND created_at <= ?', @time_range_start, @time_range_end)
                   end
                   results = results.where(mode: Result.modes[@mode]) if @mode
                   results = results.where(hero_id: @as_hero.id) if @as_hero
                   results = results.where(deck_id: @as_deck.id) if @as_deck
                   results = results.where(opponent_id: @vs_hero.id) if @vs_hero
                   results = results.where(opponent_deck_id: @vs_deck.id) if @vs_deck
                   results
                 end
  end

  def user_arenas
    @user_arenas ||= begin
                       user_arenas = current_user.arenas
                       if @time_range
                         user_arenas = user_arenas.where('arenas.created_at >= ? AND arenas.created_at <= ?', @time_range_start, @time_range_end)
                       end
                       user_arenas = user_arenas.where('arenas.hero_id = ?', @as_hero.id) if @as_hero
                       user_arenas = user_arenas.where('arenas.opponent_id = ?', @vs_hero.id) if @vs_hero
                       user_arenas
                     end
  end

  def read_params
    if params[:mode].present? && Result.modes.has_key?(params[:mode].to_sym)
      @mode = params[:mode].to_sym
    end

    if params[:time_range].present? && TIME_RANGE_FILTERS.include?(params[:time_range])
      @time_range = params[:time_range].to_sym

      if @time_range == :custom
        @custom_range = Date.parse(params[:start])..Date.parse(params[:end])
      end

      @time_range_start = min_date_for_time_range
      @time_range_end = max_date_for_time_range
    end

    @sort_by ||= DEFAULT_SORT_BY
    if params[:sort_by].present? && SORT_BY_FIELDS.include?(params[:sort_by])
      @sort_by = params[:sort_by].to_sym
    end

    @order ||= DEFAULT_ORDER
    if params[:order].present? && ORDER_FIELDS.include?(params[:order])
      @order = params[:order].to_sym
    end

    if params[:as_deck].present?
      @as_deck = current_user.decks.find_by_id(params[:as_deck])
    end

    if params[:vs_deck].present?
      @vs_deck = current_user.decks.find_by_id(params[:vs_deck])
    end

    if params[:as_hero].present?
      @as_hero = Hero.where('LOWER(name) = ?', params[:as_hero]).first
    end

    if params[:vs_hero].present?
      @vs_hero = Hero.where('LOWER(name) = ?', params[:vs_hero]).first
    end
  end

  def min_date_for_time_range
    case @time_range
    when :last_24_hours
      24.hours.ago
    when :last_3_days
      3.days.ago
    when :current_month
      Date.today.beginning_of_month
    when :custom
      @custom_range.min
    else
      Date.today
    end
  end

  def max_date_for_time_range
    case @time_range
    when :custom
      @custom_range.max
    else
      Date.tomorrow
    end
  end

  def winrate(wins, losses)
    total = wins + losses
    return 0 if total == 0
    return wins.to_f / total
  end

  def sort_grouped_stats(grouped_stats)
    sorted = grouped_stats.sort_by do |group, stats|
      case @sort_by
      when :share
        stats[:total]
      else
        [winrate(stats[:wins], stats[:losses]), stats[:total]]
      end
    end
    sorted = sorted.reverse if @order == :desc
    Hash[sorted]
  end
end
