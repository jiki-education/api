class ActiveRecord::Base
  def self.disable_sti!
    self.inheritance_column = 'does_not_have_one'
  end

  def just_created? = id_previously_changed?

  def self.find_create_or_find_by!(*args, &block)
    find_by!(*args)
  rescue ActiveRecord::RecordNotFound
    begin
      create_or_find_by!(*args, &block)
    rescue ActiveRecord::RecordInvalid => e
      # create_or_find_by! only rescues the DB-level RecordNotUnique. If the
      # model also has a uniqueness validation on the same columns, a row
      # committed by a concurrent request is seen by the validation's SELECT
      # first, raising RecordInvalid before the DB constraint gets a chance.
      raise unless e.record.errors.any? { |error| error.type == :taken }

      find_by!(*args)
    end
  end

  def self.create_or_find!(attributes, &block)
    create!(attributes, &block)
  rescue ActiveRecord::RecordNotUnique
    find_by!(attributes)
  end
end

class ActiveRecord::Relation
  def to_active_relation
    self
  end
end

class Array
  def to_active_relation
    return User.none if empty?

    ids = map(&:id)
    klass = first.class.base_class

    # PostgreSQL: Use unnest WITH ORDINALITY for ordering by array position
    # This is more performant than array_position for large datasets
    klass.joins(
      "JOIN unnest(ARRAY[#{ids.join(',')}]) WITH ORDINALITY AS arr(id, ord) ON #{klass.table_name}.id = arr.id"
    ).order("arr.ord")
  end
end
