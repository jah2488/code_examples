module CustomSorts
  class HomeSort
    NEW = "new".freeze
    TOP = "top".freeze
    RELEVANCY = "relevancy".freeze
    DATE_DONE = "date-done".freeze
    MOST_COMMENTED = "most-commented".freeze

    ASSOCIATIONS = [ProgressEntry, Task, Lesson].freeze

    attr_reader :current_sort, :user

    def initialize(sort_type, user = nil)
      @current_sort = sort_type
      @user = user
    end

    def load
      filtered_objects = filter_objects_by(fetch_objects, set_sort)
      filtered_objects.reverse!.first
    end

    private

    def fetch_objects
      return [] unless user
      [
        user.progress_entries,
        user.tasks,
        user.lessons
      ].flat_map(&:fetch_for_home)
    end

    def filter_objects_by(objects, sort)
      if current_sort == DATE_DONE
        objects.sort_by(&:sort_date_done)
      else
        objects.sort_by do |obj|
          [ obj[sort], obj[:updated_at] ]
        end
      end
    end

    def set_sort
      case current_sort
      when TOP            then :cached_weighted_score
      when MOST_COMMENTED then :comments_count
      when DATE_DONE      then :completed_at
      when NEW            then :updated_at
      when RELEVANCY      then :updated_at
      else; :updated_at
      end
    end
  end
end
